part of 'training_v2_migration_executor.dart';

class TrainingV2MigrationTransaction {
  final IndexedDbDatabase _database;
  final String migrationId;
  final String source;
  final String sourceSection;

  const TrainingV2MigrationTransaction(
    this._database, {
    required this.migrationId,
    required this.source,
    required this.sourceSection,
  });

  Future<TrainingV2MigrationWriteOutcome> write(
    TrainingV2MigrationPlan plan,
    IndexedDbMigrationMetadata metadata,
    DateTime timestamp,
  ) {
    return _database.runTransaction<TrainingV2MigrationWriteOutcome>(
      storeNames: const [
        IndexedDbStoreNames.trainingRecords,
        IndexedDbStoreNames.migrationQuarantine,
        IndexedDbStoreNames.migrationMetadata,
      ],
      mode: IndexedDbTransactionMode.readWrite,
      action: (transaction) async {
        final targets = <PersistedTrainingRecord>[];
        final quarantine = <IndexedDbQuarantinedRecord>[
          for (final problem in plan.problems)
            _quarantine(
              sourceId: problem.sourceId,
              sourceIndex: problem.sourceIndex,
              rawPayload: problem.rawPayload,
              category: problem.category,
              errorCode: problem.errorCode,
              errorMessage: problem.errorMessage,
              timestamp: timestamp,
            ),
        ];
        var written = 0;
        var skipped = 0;
        var conflicts = 0;
        for (final candidate in plan.candidates) {
          final existingValue = await transaction.findById(
            IndexedDbStoreNames.trainingRecords,
            candidate.target.id,
          );
          if (existingValue == null) {
            await transaction.put(
              IndexedDbStoreNames.trainingRecords,
              candidate.target.toRecord(),
            );
            targets.add(candidate.target);
            written++;
            continue;
          }
          if (TrainingV2MigrationIntegrity.canonicalJson(existingValue) ==
              TrainingV2MigrationIntegrity.canonicalJson(
                candidate.target.toRecord(),
              )) {
            targets.add(PersistedTrainingRecord.fromRecord(existingValue));
            skipped++;
            continue;
          }
          conflicts++;
          quarantine.add(
            _quarantine(
              sourceId: candidate.sourceId,
              sourceIndex: candidate.sourceIndex,
              rawPayload: candidate.rawPayload,
              category: 'conflict',
              errorCode: 'targetIdConflict',
              errorMessage:
                  'TRAINING target ${candidate.target.id} already differs.',
              timestamp: timestamp,
              conflictingRecordId: candidate.target.id,
              existingPayloadDigest:
                  TrainingV2MigrationIntegrity.digestCanonical([existingValue]),
              legacyPayloadDigest: TrainingV2MigrationIntegrity.digestCanonical(
                [candidate.target.toRecord()],
              ),
            ),
          );
        }
        for (final record in quarantine) {
          await transaction.put(
            IndexedDbStoreNames.migrationQuarantine,
            record.toRecord(),
          );
        }
        final targetIds = targets.map((record) => record.id).toList()..sort();
        final quarantineIds = quarantine.map((record) => record.id).toList()
          ..sort();
        final invalid = TrainingV2MigrationIntegrity.problemCount(
          plan,
          'invalid',
        );
        final needsReview = TrainingV2MigrationIntegrity.problemCount(
          plan,
          'needs-review',
        );
        final valid = plan.candidates.length - conflicts;
        final prepared = metadata.copyWith(
          status: IndexedDbMigrationStatus.prepared,
          updatedAt: timestamp,
          validCounts: {
            'validRecordCount': valid,
            'invalidRecordCount': invalid,
            'needsReviewRecordCount': needsReview,
            'conflictRecordCount': conflicts,
            'writtenRecordCount': written,
            'skippedRecordCount': skipped,
            'verifiedRecordCount': 0,
          },
          quarantinedCounts: {
            'invalid': invalid,
            'needsReview': needsReview,
            'conflict': conflicts,
          },
          expectedRecordIds: {
            IndexedDbStoreNames.trainingRecords: targetIds,
            IndexedDbStoreNames.migrationQuarantine: quarantineIds,
          },
          targetIdDigest: TrainingV2MigrationIntegrity.digest(targetIds),
          targetDigest: TrainingV2MigrationIntegrity.digestCanonical(
            targets.map((record) => record.toRecord()),
          ),
        );
        await transaction.put(
          IndexedDbStoreNames.migrationMetadata,
          prepared.toRecord(),
        );
        return TrainingV2MigrationWriteOutcome(
          metadata: prepared,
          targets: targets,
          quarantine: quarantine,
        );
      },
    );
  }

  IndexedDbQuarantinedRecord _quarantine({
    required String sourceId,
    required int sourceIndex,
    required Object? rawPayload,
    required String category,
    required String errorCode,
    required String errorMessage,
    required DateTime timestamp,
    String? conflictingRecordId,
    String? existingPayloadDigest,
    String? legacyPayloadDigest,
  }) {
    final idDigest = TrainingRecordLineage.stableDigest(
      '$migrationId\u0000$sourceId\u0000$category',
    );
    return IndexedDbQuarantinedRecord(
      id: 'quarantine:training-v2:$idDigest:$category',
      migrationId: migrationId,
      sourceSystem: source,
      sourceKey: sourceId,
      sourceSection: sourceSection,
      sourceIndex: sourceIndex,
      rawPayload: rawPayload,
      errorCode: errorCode,
      errorMessage: errorMessage,
      conflictingRecordId: conflictingRecordId,
      existingPayloadDigest: existingPayloadDigest,
      legacyPayloadDigest: legacyPayloadDigest,
      conflictType: category == 'conflict' ? errorCode : null,
      quarantinedAt: timestamp,
    );
  }
}

class TrainingV2MigrationWriteOutcome {
  final IndexedDbMigrationMetadata metadata;
  final List<PersistedTrainingRecord> targets;
  final List<IndexedDbQuarantinedRecord> quarantine;

  TrainingV2MigrationWriteOutcome({
    required this.metadata,
    required Iterable<PersistedTrainingRecord> targets,
    required Iterable<IndexedDbQuarantinedRecord> quarantine,
  }) : targets = List.unmodifiable(targets),
       quarantine = List.unmodifiable(quarantine);

  int get conflictCount => metadata.validCounts['conflictRecordCount'] ?? 0;

  TrainingV2MigrationResult toResult({required bool alreadyCompleted}) {
    return TrainingV2MigrationResult(
      alreadyCompleted: alreadyCompleted,
      sourceCount: metadata.sourceCounts.values.single,
      validCount: metadata.validCounts['validRecordCount']!,
      invalidCount: metadata.validCounts['invalidRecordCount']!,
      needsReviewCount: metadata.validCounts['needsReviewRecordCount']!,
      conflictCount: conflictCount,
      writtenCount: metadata.validCounts['writtenRecordCount']!,
      skippedCount: metadata.validCounts['skippedRecordCount']!,
      targetIds: targets.map((record) => record.id),
      quarantineIds: quarantine.map((record) => record.id),
    );
  }
}
