import '../../../data/indexed_db/indexed_db_database_contract.dart';
import '../../../data/indexed_db/indexed_db_migration_metadata.dart';
import '../../../data/indexed_db/indexed_db_quarantined_record.dart';
import '../../../data/indexed_db/indexed_db_schema.dart';
import '../../../data/indexed_db/indexed_db_store_names.dart';
import '../../repositories/repository_exception.dart';
import '../models/persisted_training_record.dart';
import '../repository/indexed_db_training_repository.dart';
import '../repository/training_record_id_generator.dart';
import 'training_legacy_reader.dart';

typedef TrainingLegacyIdFactory =
    String Function(
      Map<String, dynamic> sessionJson,
      int sourceIndex,
      int duplicateOrdinal,
    );

class TrainingMigrationResult {
  final bool alreadyCompleted;
  final int sourceCount;
  final int validCount;
  final int invalidCount;
  final int conflictCount;
  final int writtenCount;
  final int existingMatchCount;
  final Set<String> trainingRecordIds;
  final Set<String> quarantineRecordIds;

  TrainingMigrationResult({
    required this.alreadyCompleted,
    required this.sourceCount,
    required this.validCount,
    required this.invalidCount,
    required this.conflictCount,
    required this.writtenCount,
    required this.existingMatchCount,
    required Iterable<String> trainingRecordIds,
    required Iterable<String> quarantineRecordIds,
  }) : trainingRecordIds = Set.unmodifiable(trainingRecordIds),
       quarantineRecordIds = Set.unmodifiable(quarantineRecordIds);
}

class TrainingMigrationService {
  static const migrationId = 'shared_preferences_training_v1_to_indexeddb_v3';
  static const _leaseDuration = Duration(minutes: 5);

  final IndexedDbDatabase _database;
  final TrainingLegacyReader _legacyReader;
  final TrainingLegacyIdFactory _legacyIdFactory;
  final DateTime Function() _now;
  final String _ownerId;

  TrainingMigrationService(
    this._database, {
    TrainingLegacyReader? legacyReader,
    TrainingLegacyIdFactory? legacyIdFactory,
    DateTime Function()? now,
    String? ownerId,
  }) : _legacyReader = legacyReader ?? TrainingLegacyReader(),
       _legacyIdFactory =
           legacyIdFactory ??
           ((json, sourceIndex, ordinal) =>
               const TrainingLegacyIdGenerator().generate(
                 sessionJson: json,
                 sourceIndex: sourceIndex,
                 duplicateOrdinal: ordinal,
               )),
       _now = now ?? DateTime.now,
       _ownerId =
           ownerId ??
           'training-migration-${DateTime.now().microsecondsSinceEpoch}';

  Future<TrainingMigrationResult> migrate() async {
    IndexedDbMigrationMetadata? activeMetadata;
    try {
      activeMetadata = await _acquireLease();
      if (activeMetadata.status == IndexedDbMigrationStatus.completed) {
        return _verifyCompleted(activeMetadata);
      }

      final legacy = await _legacyReader.read();
      if (legacy.validRecords.length + legacy.invalidRecords.length !=
          legacy.sourceCount) {
        throw const FormatException(
          'TRAINING Legacy valid and invalid counts do not match source.',
        );
      }
      final timestamp = _now().toUtc();
      final plan = _buildPlan(legacy, timestamp);
      final sourceIds = plan.candidates.map((candidate) => candidate.record.id);
      final writing = activeMetadata.copyWith(
        status: IndexedDbMigrationStatus.writing,
        updatedAt: timestamp,
        sourceCounts: {TrainingLegacyReader.sourceKey: legacy.sourceCount},
        validCounts: {
          'validRecordCount': plan.preliminaryValidCount,
          'invalidRecordCount': plan.invalidCount,
          'conflictRecordCount': plan.legacyConflictCount,
          'writtenRecordCount': 0,
          'verifiedRecordCount': 0,
          'existingMatchCount': 0,
        },
        quarantinedCounts: {
          'invalid': plan.invalidCount,
          'conflict': plan.legacyConflictCount,
        },
        expectedRecordIds: const {},
        sourceDigest: _digest(legacy.rawRecords),
        sourceIdDigest: _digest(sourceIds.toList()..sort()),
        targetIdDigest: null,
        targetDigest: null,
        errorCode: null,
        errorMessage: null,
      );
      await _writeMetadata(writing);
      activeMetadata = writing;

      final outcome = await _writePlan(plan, writing, timestamp);
      activeMetadata = outcome.preparedMetadata;
      if (outcome.conflictCount > 0) {
        throw RepositoryException(
          operation: 'training.migration.conflict',
          code: RepositoryErrorCode.migrationFailed,
          cause: StateError(
            '${outcome.conflictCount} TRAINING conflicts detected.',
          ),
        );
      }

      final verifying = outcome.preparedMetadata.copyWith(
        status: IndexedDbMigrationStatus.verifying,
        updatedAt: _now().toUtc(),
      );
      await _writeMetadata(verifying);
      activeMetadata = verifying;
      await _verifyOutcome(outcome);

      final completedAt = _now().toUtc();
      final completed = verifying.copyWith(
        status: IndexedDbMigrationStatus.completed,
        updatedAt: completedAt,
        completedAt: completedAt,
        ownerId: null,
        leaseExpiresAt: null,
        validCounts: {
          ...verifying.validCounts,
          'verifiedRecordCount': outcome.expectedRecords.length,
        },
      );
      await _writeMetadata(completed);
      return outcome.toResult(alreadyCompleted: false);
    } catch (error) {
      if (activeMetadata != null &&
          activeMetadata.status != IndexedDbMigrationStatus.completed) {
        await _markFailed(activeMetadata, error);
      }
      if (error is RepositoryException) rethrow;
      throw RepositoryException(
        operation: 'training.migration',
        code: RepositoryErrorCode.migrationFailed,
        cause: error,
      );
    }
  }

  Future<IndexedDbMigrationMetadata> _acquireLease() {
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
        final now = _now().toUtc();
        if (existing?.leaseExpiresAt?.isAfter(now) == true &&
            existing?.ownerId != _ownerId) {
          throw RepositoryException(
            operation: 'training.migration.acquireLease',
            code: RepositoryErrorCode.migrationFailed,
            cause: StateError('TRAINING migration lease is already held.'),
          );
        }
        final metadata = IndexedDbMigrationMetadata(
          id: migrationId,
          status: IndexedDbMigrationStatus.validating,
          source: TrainingLegacyReader.sourceSystem,
          targetDatabaseVersion: IndexedDbSchema.databaseVersion,
          attempt: (existing?.attempt ?? 0) + 1,
          startedAt: now,
          updatedAt: now,
          ownerId: _ownerId,
          leaseExpiresAt: now.add(_leaseDuration),
          sourceCounts: existing?.sourceCounts ?? const {},
          validCounts: existing?.validCounts ?? const {},
          quarantinedCounts: existing?.quarantinedCounts ?? const {},
          expectedRecordIds: existing?.expectedRecordIds ?? const {},
          sourceDigest: existing?.sourceDigest,
          sourceIdDigest: existing?.sourceIdDigest,
          targetIdDigest: existing?.targetIdDigest,
          targetDigest: existing?.targetDigest,
        );
        await transaction.put(
          IndexedDbStoreNames.migrationMetadata,
          metadata.toRecord(),
        );
        return metadata;
      },
    );
  }

  _TrainingMigrationPlan _buildPlan(
    TrainingLegacyReadResult legacy,
    DateTime timestamp,
  ) {
    final duplicateCounts = <String, int>{};
    final preliminary = <_TrainingCandidate>[];
    for (final source in legacy.validRecords) {
      final canonical = TrainingLegacyIdGenerator.canonicalJson(
        source.data.toJson(),
      );
      final ordinal = duplicateCounts.update(
        canonical,
        (value) => value + 1,
        ifAbsent: () => 0,
      );
      final id = _legacyIdFactory(
        Map<String, dynamic>.from(source.data.toJson()),
        source.sourceIndex,
        ordinal,
      );
      PersistedTrainingRecord.validateId(id);
      final orderedTimestamp = timestamp.add(
        Duration(microseconds: source.sourceIndex),
      );
      preliminary.add(
        _TrainingCandidate(
          source: source,
          record: PersistedTrainingRecord(
            id: id,
            localDate: PersistedTrainingRecord.localDateFromSession(
              source.data,
            ),
            createdAt: orderedTimestamp,
            updatedAt: orderedTimestamp,
            migrationSource: TrainingMigrationSource(
              migrationId: migrationId,
              sourceSystem: TrainingLegacyReader.sourceSystem,
              sourceKey: TrainingLegacyReader.sourceKey,
              sourceIndex: source.sourceIndex,
              duplicateOrdinal: ordinal,
            ),
            data: source.data,
          ),
        ),
      );
    }

    final byId = <String, List<_TrainingCandidate>>{};
    for (final candidate in preliminary) {
      byId.putIfAbsent(candidate.record.id, () => []).add(candidate);
    }
    final candidates = <_TrainingCandidate>[];
    final quarantine = <IndexedDbQuarantinedRecord>[
      for (final invalid in legacy.invalidRecords)
        _quarantine(
          category: 'invalid',
          sourceIndex: invalid.sourceIndex,
          rawPayload: invalid.rawPayload,
          errorCode: invalid.errorCode,
          errorMessage: invalid.errorMessage,
          timestamp: timestamp,
        ),
    ];
    var legacyConflictCount = 0;
    for (final entry in byId.entries) {
      if (entry.value.length == 1) {
        candidates.add(entry.value.single);
        continue;
      }
      legacyConflictCount += entry.value.length;
      for (final candidate in entry.value) {
        final digest = _domainDigest(candidate.record);
        quarantine.add(
          _quarantine(
            category: 'legacy-conflict',
            sourceIndex: candidate.source.sourceIndex,
            rawPayload: candidate.source.rawPayload,
            errorCode: 'legacyIdConflict',
            errorMessage: 'Generated TRAINING ID ${entry.key} is not unique.',
            timestamp: timestamp,
            conflictingRecordId: entry.key,
            legacyPayloadDigest: digest,
            conflictType: 'legacyIdConflict',
          ),
        );
      }
    }
    candidates.sort(
      (first, second) =>
          first.source.sourceIndex.compareTo(second.source.sourceIndex),
    );
    return _TrainingMigrationPlan(
      sourceCount: legacy.sourceCount,
      invalidCount: legacy.invalidRecords.length,
      legacyConflictCount: legacyConflictCount,
      candidates: candidates,
      quarantinedRecords: quarantine,
    );
  }

  Future<_TrainingWriteOutcome> _writePlan(
    _TrainingMigrationPlan plan,
    IndexedDbMigrationMetadata metadata,
    DateTime timestamp,
  ) {
    return _database.runTransaction<_TrainingWriteOutcome>(
      storeNames: const [
        IndexedDbStoreNames.trainingRecords,
        IndexedDbStoreNames.migrationQuarantine,
        IndexedDbStoreNames.migrationMetadata,
      ],
      mode: IndexedDbTransactionMode.readWrite,
      action: (transaction) async {
        await _removePreviousAttemptRecords(transaction);
        final toWrite = <PersistedTrainingRecord>[];
        final expected = <PersistedTrainingRecord>[];
        final quarantine = List<IndexedDbQuarantinedRecord>.from(
          plan.quarantinedRecords,
        );
        var existingMatchCount = 0;
        var targetConflictCount = 0;

        for (final candidate in plan.candidates) {
          final existingValue = await transaction.findById(
            IndexedDbStoreNames.trainingRecords,
            candidate.record.id,
          );
          if (existingValue == null) {
            toWrite.add(candidate.record);
            expected.add(candidate.record);
            continue;
          }
          PersistedTrainingRecord? existing;
          try {
            existing = PersistedTrainingRecord.fromRecord(existingValue);
          } catch (_) {
            existing = null;
          }
          if (existing != null && _sameDomain(existing, candidate.record)) {
            existingMatchCount++;
            expected.add(existing);
            continue;
          }

          targetConflictCount++;
          final existingDigest = TrainingLegacyIdGenerator.fnv1aDigest(
            TrainingLegacyIdGenerator.canonicalJson(existingValue),
          );
          final legacyDigest = _domainDigest(candidate.record);
          quarantine.add(
            _quarantine(
              category: 'target-conflict',
              sourceIndex: candidate.source.sourceIndex,
              rawPayload: candidate.source.rawPayload,
              errorCode: 'targetIdConflict',
              errorMessage:
                  'TRAINING ID ${candidate.record.id} conflicts with '
                  'IndexedDB.',
              timestamp: timestamp,
              conflictingRecordId: candidate.record.id,
              existingPayloadDigest: existingDigest,
              legacyPayloadDigest: legacyDigest,
              conflictType: 'targetIdConflict',
            ),
          );
        }

        for (final record in toWrite) {
          await transaction.put(
            IndexedDbStoreNames.trainingRecords,
            record.toRecord(),
          );
        }
        for (final record in quarantine) {
          await transaction.put(
            IndexedDbStoreNames.migrationQuarantine,
            record.toRecord(),
          );
        }

        final trainingIds = expected.map((record) => record.id).toSet();
        final quarantineIds = quarantine.map((record) => record.id).toSet();
        if (!_sameSet(
              trainingIds,
              await _expectedTrainingIds(transaction, trainingIds),
            ) ||
            !_sameSet(
              quarantineIds,
              await _migrationQuarantineIds(transaction),
            )) {
          throw const FormatException(
            'TRAINING migration transaction verification failed.',
          );
        }
        final conflictCount = plan.legacyConflictCount + targetConflictCount;
        final validCount = plan.sourceCount - plan.invalidCount - conflictCount;
        if (validCount + plan.invalidCount + conflictCount !=
            plan.sourceCount) {
          throw const FormatException(
            'TRAINING migration source counts differ.',
          );
        }
        final sortedIds = trainingIds.toList()..sort();
        final prepared = metadata.copyWith(
          status: IndexedDbMigrationStatus.prepared,
          updatedAt: timestamp,
          validCounts: {
            'validRecordCount': validCount,
            'invalidRecordCount': plan.invalidCount,
            'conflictRecordCount': conflictCount,
            'writtenRecordCount': toWrite.length,
            'verifiedRecordCount': 0,
            'existingMatchCount': existingMatchCount,
          },
          quarantinedCounts: {
            'invalid': plan.invalidCount,
            'conflict': conflictCount,
          },
          expectedRecordIds: {
            IndexedDbStoreNames.trainingRecords: sortedIds,
            IndexedDbStoreNames.migrationQuarantine: quarantineIds.toList()
              ..sort(),
          },
          targetIdDigest: _digest(sortedIds),
          targetDigest: _recordsDigest(expected),
        );
        await transaction.put(
          IndexedDbStoreNames.migrationMetadata,
          prepared.toRecord(),
        );
        return _TrainingWriteOutcome(
          sourceCount: plan.sourceCount,
          invalidCount: plan.invalidCount,
          legacyConflictCount: plan.legacyConflictCount,
          targetConflictCount: targetConflictCount,
          existingMatchCount: existingMatchCount,
          writtenCount: toWrite.length,
          expectedRecords: expected,
          quarantineRecords: quarantine,
          preparedMetadata: prepared,
        );
      },
    );
  }

  Future<void> _removePreviousAttemptRecords(
    IndexedDbTransaction transaction,
  ) async {
    final trainings = await transaction.findAll(
      IndexedDbStoreNames.trainingRecords,
    );
    for (final value in trainings) {
      final record = PersistedTrainingRecord.fromRecord(value);
      if (record.migrationSource?.migrationId == migrationId) {
        await transaction.deleteById(
          IndexedDbStoreNames.trainingRecords,
          record.id,
        );
      }
    }
    final quarantine = await transaction.findAll(
      IndexedDbStoreNames.migrationQuarantine,
    );
    for (final value in quarantine) {
      final record = IndexedDbQuarantinedRecord.fromRecord(value);
      if (record.migrationId == migrationId) {
        await transaction.deleteById(
          IndexedDbStoreNames.migrationQuarantine,
          record.id,
        );
      }
    }
  }

  Future<Set<String>> _expectedTrainingIds(
    IndexedDbTransaction transaction,
    Set<String> expected,
  ) async {
    final ids = <String>{};
    for (final id in expected) {
      if (await transaction.findById(IndexedDbStoreNames.trainingRecords, id) !=
          null) {
        ids.add(id);
      }
    }
    return ids;
  }

  Future<Set<String>> _migrationQuarantineIds(
    IndexedDbTransaction transaction,
  ) async {
    final records = await transaction.findAll(
      IndexedDbStoreNames.migrationQuarantine,
    );
    return {
      for (final value in records)
        if (IndexedDbQuarantinedRecord.fromRecord(value).migrationId ==
            migrationId)
          value['id'] as String,
    };
  }

  Future<void> _verifyOutcome(_TrainingWriteOutcome outcome) async {
    final repository = IndexedDbTrainingSessionRepository(_database);
    final readResult = await repository.findAllWithIssues();
    if (readResult.hasIssues) {
      throw RepositoryException(
        operation: 'training.migration.verify',
        code: RepositoryErrorCode.partialCorruption,
        cause: readResult.issues,
      );
    }
    final actual = {
      for (final record in readResult.records)
        if (outcome.expectedIds.contains(record.id)) record.id: record,
    };
    if (!_sameSet(actual.keys, outcome.expectedIds)) {
      throw const FormatException(
        'TRAINING migration IDs differ after commit.',
      );
    }
    for (final expected in outcome.expectedRecords) {
      final actualRecord = actual[expected.id]!;
      if (!_sameDomain(actualRecord, expected) ||
          actualRecord.migrationSource?.sourceIndex !=
              expected.migrationSource?.sourceIndex) {
        throw FormatException(
          'TRAINING migration data differs after commit: ${expected.id}.',
        );
      }
    }
    final quarantineValues = await _database.findAll(
      IndexedDbStoreNames.migrationQuarantine,
    );
    final quarantineIds = {
      for (final value in quarantineValues)
        if (IndexedDbQuarantinedRecord.fromRecord(value).migrationId ==
            migrationId)
          value['id'] as String,
    };
    if (!_sameSet(quarantineIds, outcome.quarantineIds) ||
        outcome.validCount + outcome.invalidCount + outcome.conflictCount !=
            outcome.sourceCount) {
      throw const FormatException(
        'TRAINING migration verification counts differ.',
      );
    }
    final sortedIds = outcome.expectedIds.toList()..sort();
    if (outcome.preparedMetadata.targetIdDigest != _digest(sortedIds) ||
        outcome.preparedMetadata.targetDigest !=
            _recordsDigest(outcome.expectedRecords)) {
      throw const FormatException(
        'TRAINING migration verification digest differs.',
      );
    }
  }

  Future<TrainingMigrationResult> _verifyCompleted(
    IndexedDbMigrationMetadata metadata,
  ) async {
    final expectedTrainingIds =
        metadata.expectedRecordIds[IndexedDbStoreNames.trainingRecords] ??
        const [];
    final expectedQuarantineIds =
        metadata.expectedRecordIds[IndexedDbStoreNames.migrationQuarantine] ??
        const [];
    final actualRecords = <PersistedTrainingRecord>[];
    for (final id in expectedTrainingIds) {
      final value = await _database.findById(
        IndexedDbStoreNames.trainingRecords,
        id,
      );
      if (value != null) {
        actualRecords.add(PersistedTrainingRecord.fromRecord(value));
      }
    }
    final actualTrainingIds = actualRecords.map((record) => record.id).toSet();
    final quarantineValues = await _database.findAll(
      IndexedDbStoreNames.migrationQuarantine,
    );
    final actualQuarantineIds = {
      for (final value in quarantineValues)
        if (IndexedDbQuarantinedRecord.fromRecord(value).migrationId ==
            migrationId)
          value['id'] as String,
    };
    final sortedIds = actualTrainingIds.toList()..sort();
    if (!_sameSet(actualTrainingIds, expectedTrainingIds) ||
        !_sameSet(actualQuarantineIds, expectedQuarantineIds) ||
        metadata.targetIdDigest != _digest(sortedIds) ||
        metadata.targetDigest != _recordsDigest(actualRecords)) {
      throw RepositoryException(
        operation: 'training.migration.verifyCompleted',
        code: RepositoryErrorCode.verificationFailed,
        cause: const FormatException(
          'Completed TRAINING migration no longer matches metadata.',
        ),
      );
    }
    return TrainingMigrationResult(
      alreadyCompleted: true,
      sourceCount: metadata.sourceCounts[TrainingLegacyReader.sourceKey] ?? 0,
      validCount: metadata.validCounts['validRecordCount'] ?? 0,
      invalidCount: metadata.validCounts['invalidRecordCount'] ?? 0,
      conflictCount: metadata.validCounts['conflictRecordCount'] ?? 0,
      writtenCount: metadata.validCounts['writtenRecordCount'] ?? 0,
      existingMatchCount: metadata.validCounts['existingMatchCount'] ?? 0,
      trainingRecordIds: actualTrainingIds,
      quarantineRecordIds: actualQuarantineIds,
    );
  }

  Future<void> _writeMetadata(IndexedDbMigrationMetadata metadata) {
    return _database.put(
      IndexedDbStoreNames.migrationMetadata,
      metadata.toRecord(),
    );
  }

  Future<void> _markFailed(
    IndexedDbMigrationMetadata metadata,
    Object error,
  ) async {
    final failed = metadata.copyWith(
      status: IndexedDbMigrationStatus.failed,
      updatedAt: _now().toUtc(),
      completedAt: null,
      ownerId: null,
      leaseExpiresAt: null,
      errorCode: error is RepositoryException
          ? error.code.name
          : RepositoryErrorCode.migrationFailed.name,
      errorMessage: error.toString(),
    );
    try {
      await _writeMetadata(failed);
    } catch (_) {
      // Preserve the original migration failure.
    }
  }

  static IndexedDbQuarantinedRecord _quarantine({
    required String category,
    required int sourceIndex,
    required String rawPayload,
    required String errorCode,
    required String errorMessage,
    required DateTime timestamp,
    String? conflictingRecordId,
    String? existingPayloadDigest,
    String? legacyPayloadDigest,
    String? conflictType,
  }) {
    return IndexedDbQuarantinedRecord(
      id:
          'quarantine:training:$category:'
          '${sourceIndex.toString().padLeft(8, '0')}',
      migrationId: migrationId,
      sourceSystem: TrainingLegacyReader.sourceSystem,
      sourceKey: TrainingLegacyReader.sourceKey,
      sourceSection: TrainingLegacyReader.sourceKey,
      sourceIndex: sourceIndex,
      rawPayload: rawPayload,
      errorCode: errorCode,
      errorMessage: errorMessage,
      conflictingRecordId: conflictingRecordId,
      existingPayloadDigest: existingPayloadDigest,
      legacyPayloadDigest: legacyPayloadDigest,
      conflictType: conflictType,
      quarantinedAt: timestamp,
    );
  }

  static bool _sameDomain(
    PersistedTrainingRecord first,
    PersistedTrainingRecord second,
  ) {
    return first.localDate == second.localDate &&
        TrainingLegacyIdGenerator.canonicalJson(first.data.toJson()) ==
            TrainingLegacyIdGenerator.canonicalJson(second.data.toJson());
  }

  static String _domainDigest(PersistedTrainingRecord record) {
    return TrainingLegacyIdGenerator.fnv1aDigest(
      TrainingLegacyIdGenerator.canonicalJson({
        'id': record.id,
        'localDate': record.localDate,
        'data': record.data.toJson(),
      }),
    );
  }

  static String _recordsDigest(Iterable<PersistedTrainingRecord> records) {
    final values = records.map(_domainDigest).toList()..sort();
    return _digest(values);
  }

  static bool _sameSet(Iterable<String> first, Iterable<String> second) {
    final firstSet = first.toSet();
    final secondSet = second.toSet();
    return firstSet.length == secondSet.length &&
        firstSet.containsAll(secondSet);
  }

  static String _digest(Iterable<String> values) {
    return TrainingLegacyIdGenerator.fnv1aDigest(values.join('\u0000'));
  }
}

class _TrainingCandidate {
  final ValidLegacyTrainingRecord source;
  final PersistedTrainingRecord record;

  const _TrainingCandidate({required this.source, required this.record});
}

class _TrainingMigrationPlan {
  final int sourceCount;
  final int invalidCount;
  final int legacyConflictCount;
  final List<_TrainingCandidate> candidates;
  final List<IndexedDbQuarantinedRecord> quarantinedRecords;

  _TrainingMigrationPlan({
    required this.sourceCount,
    required this.invalidCount,
    required this.legacyConflictCount,
    required Iterable<_TrainingCandidate> candidates,
    required Iterable<IndexedDbQuarantinedRecord> quarantinedRecords,
  }) : candidates = List.unmodifiable(candidates),
       quarantinedRecords = List.unmodifiable(quarantinedRecords);

  int get preliminaryValidCount =>
      sourceCount - invalidCount - legacyConflictCount;
}

class _TrainingWriteOutcome {
  final int sourceCount;
  final int invalidCount;
  final int legacyConflictCount;
  final int targetConflictCount;
  final int existingMatchCount;
  final int writtenCount;
  final List<PersistedTrainingRecord> expectedRecords;
  final List<IndexedDbQuarantinedRecord> quarantineRecords;
  final IndexedDbMigrationMetadata preparedMetadata;

  _TrainingWriteOutcome({
    required this.sourceCount,
    required this.invalidCount,
    required this.legacyConflictCount,
    required this.targetConflictCount,
    required this.existingMatchCount,
    required this.writtenCount,
    required Iterable<PersistedTrainingRecord> expectedRecords,
    required Iterable<IndexedDbQuarantinedRecord> quarantineRecords,
    required this.preparedMetadata,
  }) : expectedRecords = List.unmodifiable(expectedRecords),
       quarantineRecords = List.unmodifiable(quarantineRecords);

  int get conflictCount => legacyConflictCount + targetConflictCount;

  int get validCount => sourceCount - invalidCount - conflictCount;

  Set<String> get expectedIds =>
      expectedRecords.map((record) => record.id).toSet();

  Set<String> get quarantineIds =>
      quarantineRecords.map((record) => record.id).toSet();

  TrainingMigrationResult toResult({required bool alreadyCompleted}) {
    return TrainingMigrationResult(
      alreadyCompleted: alreadyCompleted,
      sourceCount: sourceCount,
      validCount: validCount,
      invalidCount: invalidCount,
      conflictCount: conflictCount,
      writtenCount: writtenCount,
      existingMatchCount: existingMatchCount,
      trainingRecordIds: expectedIds,
      quarantineRecordIds: quarantineIds,
    );
  }
}
