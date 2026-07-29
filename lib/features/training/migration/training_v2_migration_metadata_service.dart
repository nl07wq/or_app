part of 'training_v2_migration_executor.dart';

class TrainingV2MigrationMetadataService {
  static const leaseDuration = Duration(minutes: 5);

  final IndexedDbDatabase _database;
  final String migrationId;
  final String source;
  final String sourceSection;
  final DateTime Function() _now;
  final String _ownerId;

  TrainingV2MigrationMetadataService(
    this._database, {
    required this.migrationId,
    required this.source,
    required this.sourceSection,
    DateTime Function()? now,
    String? ownerId,
  }) : _now = now ?? DateTime.now,
       _ownerId =
           ownerId ?? '$migrationId-${DateTime.now().microsecondsSinceEpoch}';

  DateTime nowUtc() => _now().toUtc();

  Future<IndexedDbMigrationMetadata> acquireLease() {
    return _database.runTransaction<IndexedDbMigrationMetadata>(
      storeNames: const [IndexedDbStoreNames.migrationMetadata],
      mode: IndexedDbTransactionMode.readWrite,
      action: (transaction) async {
        final value = await transaction.findById(
          IndexedDbStoreNames.migrationMetadata,
          migrationId,
        );
        final existing = value == null
            ? null
            : IndexedDbMigrationMetadata.fromRecord(value);
        if (existing?.status == IndexedDbMigrationStatus.completed) {
          return existing!;
        }
        final now = nowUtc();
        if (existing?.leaseExpiresAt?.isAfter(now) == true &&
            existing?.ownerId != _ownerId) {
          throw RepositoryException(
            operation: '$migrationId.acquireLease',
            code: RepositoryErrorCode.migrationFailed,
            cause: StateError('TRAINING migration lease is already held.'),
          );
        }
        final metadata = IndexedDbMigrationMetadata(
          id: migrationId,
          status: IndexedDbMigrationStatus.validating,
          source: source,
          targetDatabaseVersion: IndexedDbSchema.databaseVersion,
          attempt: (existing?.attempt ?? 0) + 1,
          startedAt: now,
          updatedAt: now,
          ownerId: _ownerId,
          leaseExpiresAt: now.add(leaseDuration),
        );
        await transaction.put(
          IndexedDbStoreNames.migrationMetadata,
          metadata.toRecord(),
        );
        return metadata;
      },
    );
  }

  IndexedDbMigrationMetadata buildWriting(
    IndexedDbMigrationMetadata active,
    TrainingV2MigrationPlan plan,
  ) {
    final timestamp = nowUtc();
    return active.copyWith(
      status: IndexedDbMigrationStatus.writing,
      updatedAt: timestamp,
      sourceCounts: {sourceSection: plan.sourceCount},
      validCounts: {
        'validRecordCount': plan.candidates.length,
        'invalidRecordCount': TrainingV2MigrationIntegrity.problemCount(
          plan,
          'invalid',
        ),
        'needsReviewRecordCount': TrainingV2MigrationIntegrity.problemCount(
          plan,
          'needs-review',
        ),
        'conflictRecordCount': 0,
        'writtenRecordCount': 0,
        'skippedRecordCount': 0,
        'verifiedRecordCount': 0,
      },
      quarantinedCounts: {
        'invalid': TrainingV2MigrationIntegrity.problemCount(plan, 'invalid'),
        'needsReview': TrainingV2MigrationIntegrity.problemCount(
          plan,
          'needs-review',
        ),
        'conflict': 0,
      },
      expectedRecordIds: const {},
      sourceDigest: TrainingV2MigrationIntegrity.digestCanonical(
        plan.sourcePayloads,
      ),
      sourceIdDigest: TrainingV2MigrationIntegrity.digest(plan.sourceIds),
      targetIdDigest: null,
      targetDigest: null,
      errorCode: null,
      errorMessage: null,
    );
  }

  IndexedDbMigrationMetadata buildVerifying(
    IndexedDbMigrationMetadata metadata,
  ) {
    return metadata.copyWith(
      status: IndexedDbMigrationStatus.verifying,
      updatedAt: nowUtc(),
    );
  }

  IndexedDbMigrationMetadata buildCompleted(
    IndexedDbMigrationMetadata metadata, {
    required int verifiedRecordCount,
  }) {
    final completedAt = nowUtc();
    return metadata.copyWith(
      status: IndexedDbMigrationStatus.completed,
      updatedAt: completedAt,
      completedAt: completedAt,
      ownerId: null,
      leaseExpiresAt: null,
      validCounts: {
        ...metadata.validCounts,
        'verifiedRecordCount': verifiedRecordCount,
      },
    );
  }

  Future<void> write(IndexedDbMigrationMetadata metadata) {
    return _database.put(
      IndexedDbStoreNames.migrationMetadata,
      metadata.toRecord(),
    );
  }

  Future<void> markFailed(
    IndexedDbMigrationMetadata metadata,
    Object error,
  ) async {
    try {
      await write(
        metadata.copyWith(
          status: IndexedDbMigrationStatus.failed,
          updatedAt: nowUtc(),
          completedAt: null,
          ownerId: null,
          leaseExpiresAt: null,
          errorCode: error is RepositoryException
              ? error.code.name
              : RepositoryErrorCode.migrationFailed.name,
          errorMessage: error.toString(),
        ),
      );
    } catch (_) {
      // Preserve the original migration failure.
    }
  }

  void validateCompleted(
    IndexedDbMigrationMetadata metadata,
    TrainingV2MigrationIntegrity integrity,
  ) {
    final targets =
        metadata.expectedRecordIds[IndexedDbStoreNames.trainingRecords];
    final quarantine =
        metadata.expectedRecordIds[IndexedDbStoreNames.migrationQuarantine];
    final sourceCount = metadata.sourceCounts[sourceSection];
    final valid = metadata.validCounts['validRecordCount'];
    final invalid = metadata.validCounts['invalidRecordCount'];
    final needsReview = metadata.validCounts['needsReviewRecordCount'];
    final conflicts = metadata.validCounts['conflictRecordCount'];
    final written = metadata.validCounts['writtenRecordCount'];
    final skipped = metadata.validCounts['skippedRecordCount'];
    final verified = metadata.validCounts['verifiedRecordCount'];
    final completedAt = metadata.completedAt;
    final counts = [
      sourceCount,
      valid,
      invalid,
      needsReview,
      conflicts,
      written,
      skipped,
      verified,
    ];
    final validStructure =
        metadata.id == migrationId &&
        metadata.source == source &&
        metadata.status == IndexedDbMigrationStatus.completed &&
        IndexedDbSchema.supportsMigrationMetadataVersion(
          metadata.targetDatabaseVersion,
        ) &&
        metadata.attempt > 0 &&
        completedAt != null &&
        !metadata.updatedAt.isBefore(metadata.startedAt) &&
        !completedAt.isBefore(metadata.startedAt) &&
        !completedAt.isAfter(metadata.updatedAt) &&
        counts.every((value) => value != null && value >= 0) &&
        valid! + invalid! + needsReview! + conflicts! == sourceCount &&
        written! + skipped! == valid &&
        verified! == valid &&
        targets != null &&
        quarantine != null &&
        targets.toSet().length == targets.length &&
        quarantine.toSet().length == quarantine.length &&
        targets.length == valid &&
        quarantine.length == invalid + needsReview + conflicts &&
        targets.every(TrainingV2MigrationIntegrity.isTrainingId) &&
        quarantine.every((id) => id.startsWith('quarantine:training-v2:')) &&
        metadata.quarantinedCounts['invalid'] == invalid &&
        metadata.quarantinedCounts['needsReview'] == needsReview &&
        metadata.quarantinedCounts['conflict'] == conflicts &&
        TrainingV2MigrationIntegrity.isDigest(metadata.sourceDigest) &&
        TrainingV2MigrationIntegrity.isDigest(metadata.sourceIdDigest) &&
        TrainingV2MigrationIntegrity.isDigest(metadata.targetIdDigest) &&
        TrainingV2MigrationIntegrity.isDigest(metadata.targetDigest) &&
        metadata.targetIdDigest == TrainingV2MigrationIntegrity.digest(targets);
    if (!validStructure) {
      throw completedFailure(
        'Completed TRAINING v2 migration metadata is invalid.',
      );
    }
  }

  RepositoryException completedFailure(String message) {
    return RepositoryException(
      operation: '$migrationId.verifyCompleted',
      code: RepositoryErrorCode.verificationFailed,
      cause: FormatException(message),
    );
  }
}
