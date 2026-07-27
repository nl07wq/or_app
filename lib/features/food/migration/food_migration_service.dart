import 'dart:convert';

import '../../../core/models/meal_data.dart';
import '../../../data/indexed_db/indexed_db_database_contract.dart';
import '../../../data/indexed_db/indexed_db_migration_metadata.dart';
import '../../../data/indexed_db/indexed_db_quarantined_record.dart';
import '../../../data/indexed_db/indexed_db_schema.dart';
import '../../../data/indexed_db/indexed_db_store_names.dart';
import '../../repositories/repository_exception.dart';
import '../models/persisted_food_record.dart';
import '../repository/indexed_db_food_repository.dart';
import 'food_legacy_reader.dart';

class FoodMigrationResult {
  final bool alreadyCompleted;
  final int sourceCount;
  final int validCount;
  final int invalidCount;
  final int conflictCount;
  final int writtenCount;
  final int existingMatchCount;
  final Set<String> foodRecordIds;
  final Set<String> quarantineRecordIds;

  FoodMigrationResult({
    required this.alreadyCompleted,
    required this.sourceCount,
    required this.validCount,
    required this.invalidCount,
    required this.conflictCount,
    required this.writtenCount,
    required this.existingMatchCount,
    required Iterable<String> foodRecordIds,
    required Iterable<String> quarantineRecordIds,
  }) : foodRecordIds = Set.unmodifiable(foodRecordIds),
       quarantineRecordIds = Set.unmodifiable(quarantineRecordIds);
}

class FoodMigrationService {
  static const migrationId = 'shared_preferences_food_v1_to_indexeddb_v3';
  static const _leaseDuration = Duration(minutes: 5);

  final IndexedDbDatabase _database;
  final FoodLegacyReader _legacyReader;
  final DateTime Function() _now;
  final String _ownerId;

  FoodMigrationService(
    this._database, {
    FoodLegacyReader? legacyReader,
    DateTime Function()? now,
    String? ownerId,
  }) : _legacyReader = legacyReader ?? FoodLegacyReader(),
       _now = now ?? DateTime.now,
       _ownerId =
           ownerId ?? 'food-migration-${DateTime.now().microsecondsSinceEpoch}';

  Future<FoodMigrationResult> migrate() async {
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
          'FOOD Legacy valid and invalid counts do not match source.',
        );
      }
      final timestamp = _now().toUtc();
      final plan = _buildPlan(legacy, timestamp);
      final writing = activeMetadata.copyWith(
        status: IndexedDbMigrationStatus.writing,
        updatedAt: timestamp,
        sourceCounts: {FoodLegacyReader.sourceKey: legacy.sourceCount},
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
        sourceDigest: _digest(
          legacy.validRecords.map((record) => record.data.id),
        ),
        targetDigest: null,
        errorCode: null,
        errorMessage: null,
      );
      await _writeMetadata(writing);
      activeMetadata = writing;

      final outcome = await _writePlan(plan, writing, timestamp);
      activeMetadata = outcome.preparedMetadata;
      if (outcome.targetConflictCount > 0) {
        throw RepositoryException(
          operation: 'food.migration.conflict',
          code: RepositoryErrorCode.migrationFailed,
          cause: StateError(
            '${outcome.targetConflictCount} FOOD target conflicts detected.',
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
        operation: 'food.migration',
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
            operation: 'food.migration.acquireLease',
            code: RepositoryErrorCode.migrationFailed,
            cause: StateError('FOOD migration lease is already held.'),
          );
        }
        final metadata = IndexedDbMigrationMetadata(
          id: migrationId,
          status: IndexedDbMigrationStatus.validating,
          source: FoodLegacyReader.sourceSystem,
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

  _FoodMigrationPlan _buildPlan(
    FoodLegacyReadResult legacy,
    DateTime timestamp,
  ) {
    final groups = <String, List<ValidLegacyFoodRecord>>{};
    for (final record in legacy.validRecords) {
      groups.putIfAbsent(record.data.id, () => []).add(record);
    }
    final candidates = <_FoodCandidate>[];
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

    for (final entry in groups.entries) {
      final records = entry.value;
      final domainValues = records
          .map((record) => _domainJson(record.data))
          .toSet();
      if (domainValues.length > 1) {
        legacyConflictCount += records.length;
        for (final record in records) {
          quarantine.add(
            _quarantine(
              category: 'legacy-conflict',
              sourceIndex: record.sourceIndex,
              rawPayload: record.rawPayload,
              errorCode: 'legacyIdConflict',
              errorMessage:
                  'Legacy FOOD ID ${record.data.id} has differing payloads.',
              timestamp: timestamp,
            ),
          );
        }
        continue;
      }

      final first = records.first;
      final localDate = PersistedFoodRecord.localDateFromMealDate(
        first.data.date,
      );
      final orderedTimestamp = timestamp.add(
        Duration(microseconds: first.sourceIndex),
      );
      candidates.add(
        _FoodCandidate(
          sourceRecords: records,
          record: PersistedFoodRecord(
            id: PersistedFoodRecord.envelopeId(first.data.id),
            localDate: localDate,
            createdAt: orderedTimestamp,
            updatedAt: orderedTimestamp,
            migrationSource: FoodMigrationSource(
              migrationId: migrationId,
              sourceSystem: FoodLegacyReader.sourceSystem,
              sourceKey: FoodLegacyReader.sourceKey,
              sourceIndex: first.sourceIndex,
            ),
            data: first.data,
          ),
        ),
      );
    }

    return _FoodMigrationPlan(
      sourceCount: legacy.sourceCount,
      invalidCount: legacy.invalidRecords.length,
      legacyConflictCount: legacyConflictCount,
      candidates: candidates,
      quarantinedRecords: quarantine,
    );
  }

  Future<_FoodWriteOutcome> _writePlan(
    _FoodMigrationPlan plan,
    IndexedDbMigrationMetadata metadata,
    DateTime timestamp,
  ) {
    return _database.runTransaction<_FoodWriteOutcome>(
      storeNames: const [
        IndexedDbStoreNames.foodRecords,
        IndexedDbStoreNames.migrationQuarantine,
        IndexedDbStoreNames.migrationMetadata,
      ],
      mode: IndexedDbTransactionMode.readWrite,
      action: (transaction) async {
        await _removePreviousAttemptRecords(transaction);
        final toWrite = <PersistedFoodRecord>[];
        final expected = <PersistedFoodRecord>[];
        final quarantine = List<IndexedDbQuarantinedRecord>.from(
          plan.quarantinedRecords,
        );
        var existingMatchCount = 0;
        var targetConflictCount = 0;

        for (final candidate in plan.candidates) {
          final existingValue = await transaction.findById(
            IndexedDbStoreNames.foodRecords,
            candidate.record.id,
          );
          if (existingValue == null) {
            toWrite.add(candidate.record);
            expected.add(candidate.record);
            continue;
          }
          PersistedFoodRecord? existing;
          try {
            existing = PersistedFoodRecord.fromRecord(existingValue);
          } catch (_) {
            existing = null;
          }
          if (existing != null &&
              _domainJson(existing.data) ==
                  _domainJson(candidate.record.data)) {
            existingMatchCount += candidate.sourceRecords.length;
            expected.add(existing);
            continue;
          }

          targetConflictCount += candidate.sourceRecords.length;
          final existingDigest = _digest([jsonEncode(existingValue)]);
          for (final source in candidate.sourceRecords) {
            quarantine.add(
              _quarantine(
                category: 'target-conflict',
                sourceIndex: source.sourceIndex,
                rawPayload: source.rawPayload,
                errorCode: 'targetIdConflict',
                errorMessage:
                    'FOOD ID ${source.data.id} conflicts with IndexedDB. '
                    'existingDigest=$existingDigest '
                    'legacyDigest=${_digest([source.rawPayload])}',
                timestamp: timestamp,
              ),
            );
          }
        }

        for (final record in toWrite) {
          await transaction.put(
            IndexedDbStoreNames.foodRecords,
            record.toRecord(),
          );
        }
        for (final record in quarantine) {
          await transaction.put(
            IndexedDbStoreNames.migrationQuarantine,
            record.toRecord(),
          );
        }

        final foodIds = expected.map((record) => record.id).toSet();
        final quarantineIds = quarantine.map((record) => record.id).toSet();
        final storedFoodIds = await _expectedFoodIds(transaction, foodIds);
        final storedQuarantineIds = await _migrationQuarantineIds(transaction);
        if (!_sameSet(foodIds, storedFoodIds) ||
            !_sameSet(quarantineIds, storedQuarantineIds)) {
          throw const FormatException(
            'FOOD migration transaction verification failed.',
          );
        }

        final conflictCount = plan.legacyConflictCount + targetConflictCount;
        final validCount = plan.sourceCount - plan.invalidCount - conflictCount;
        if (validCount + plan.invalidCount + conflictCount !=
            plan.sourceCount) {
          throw const FormatException('FOOD migration source counts differ.');
        }
        final targetDigest = _digest(foodIds.toList()..sort());
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
            IndexedDbStoreNames.foodRecords: foodIds.toList()..sort(),
            IndexedDbStoreNames.migrationQuarantine: quarantineIds.toList()
              ..sort(),
          },
          targetDigest: targetDigest,
        );
        await transaction.put(
          IndexedDbStoreNames.migrationMetadata,
          prepared.toRecord(),
        );
        return _FoodWriteOutcome(
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
    final foods = await transaction.findAll(IndexedDbStoreNames.foodRecords);
    for (final value in foods) {
      final record = PersistedFoodRecord.fromRecord(value);
      if (record.migrationSource?.migrationId == migrationId) {
        await transaction.deleteById(
          IndexedDbStoreNames.foodRecords,
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

  Future<Set<String>> _expectedFoodIds(
    IndexedDbTransaction transaction,
    Set<String> expected,
  ) async {
    final ids = <String>{};
    for (final id in expected) {
      if (await transaction.findById(IndexedDbStoreNames.foodRecords, id) !=
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

  Future<void> _verifyOutcome(_FoodWriteOutcome outcome) async {
    final repository = IndexedDbFoodRepository(_database);
    final readResult = await repository.findAllWithIssues();
    if (readResult.hasIssues) {
      throw RepositoryException(
        operation: 'food.migration.verify',
        code: RepositoryErrorCode.partialCorruption,
        cause: readResult.issues,
      );
    }
    final actual = {
      for (final record in readResult.records)
        if (outcome.expectedIds.contains(record.id)) record.id: record,
    };
    if (!_sameSet(actual.keys, outcome.expectedIds)) {
      throw const FormatException('FOOD migration IDs differ after commit.');
    }
    final metadataValue = await _database.findById(
      IndexedDbStoreNames.migrationMetadata,
      migrationId,
    );
    if (metadataValue == null) {
      throw const FormatException(
        'FOOD migration metadata is missing after commit.',
      );
    }
    final storedMetadata = IndexedDbMigrationMetadata.fromRecord(metadataValue);
    final actualTargetDigest = _digest(actual.keys.toList()..sort());
    if (storedMetadata.targetDigest != actualTargetDigest ||
        !_sameSet(
          storedMetadata.expectedRecordIds[IndexedDbStoreNames.foodRecords] ??
              const [],
          outcome.expectedIds,
        )) {
      throw const FormatException(
        'FOOD migration digest differs after commit.',
      );
    }
    for (final expected in outcome.expectedRecords) {
      final actualRecord = actual[expected.id]!;
      if (actualRecord.localDate != expected.localDate ||
          _domainJson(actualRecord.data) != _domainJson(expected.data)) {
        throw FormatException(
          'FOOD migration data differs after commit: ${expected.id}.',
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
    if (!_sameSet(quarantineIds, outcome.quarantineIds)) {
      throw const FormatException('FOOD quarantine IDs differ after commit.');
    }
    if (outcome.validCount + outcome.invalidCount + outcome.conflictCount !=
        outcome.sourceCount) {
      throw const FormatException('FOOD migration counts differ.');
    }
  }

  Future<FoodMigrationResult> _verifyCompleted(
    IndexedDbMigrationMetadata metadata,
  ) async {
    _validateCompletedMetadata(metadata);
    final expectedFoodIds =
        metadata.expectedRecordIds[IndexedDbStoreNames.foodRecords] ?? const [];
    final expectedQuarantineIds =
        metadata.expectedRecordIds[IndexedDbStoreNames.migrationQuarantine] ??
        const [];
    final quarantineValues = await _database.findAll(
      IndexedDbStoreNames.migrationQuarantine,
    );
    final actualQuarantineIds = {
      for (final value in quarantineValues)
        if (IndexedDbQuarantinedRecord.fromRecord(value).migrationId ==
            migrationId)
          value['id'] as String,
    };
    if (!_sameSet(actualQuarantineIds, expectedQuarantineIds)) {
      throw _completedVerificationFailure(
        'Completed FOOD migration quarantine no longer matches metadata.',
      );
    }
    return FoodMigrationResult(
      alreadyCompleted: true,
      sourceCount: metadata.sourceCounts[FoodLegacyReader.sourceKey] ?? 0,
      validCount: metadata.validCounts['validRecordCount'] ?? 0,
      invalidCount: metadata.validCounts['invalidRecordCount'] ?? 0,
      conflictCount: metadata.validCounts['conflictRecordCount'] ?? 0,
      writtenCount: metadata.validCounts['writtenRecordCount'] ?? 0,
      existingMatchCount: metadata.validCounts['existingMatchCount'] ?? 0,
      foodRecordIds: expectedFoodIds,
      quarantineRecordIds: actualQuarantineIds,
    );
  }

  static void _validateCompletedMetadata(IndexedDbMigrationMetadata metadata) {
    final targetDigest = metadata.targetDigest;
    final hasExpectedSections =
        metadata.expectedRecordIds.containsKey(
          IndexedDbStoreNames.foodRecords,
        ) &&
        metadata.expectedRecordIds.containsKey(
          IndexedDbStoreNames.migrationQuarantine,
        );
    if (metadata.id != migrationId ||
        metadata.source != FoodLegacyReader.sourceSystem ||
        !IndexedDbSchema.supportsMigrationMetadataVersion(
          metadata.targetDatabaseVersion,
        ) ||
        metadata.status != IndexedDbMigrationStatus.completed ||
        metadata.completedAt == null ||
        targetDigest == null ||
        !RegExp(r'^[0-9a-f]{8}$').hasMatch(targetDigest) ||
        !hasExpectedSections) {
      throw _completedVerificationFailure(
        'Completed FOOD migration metadata is invalid.',
      );
    }
  }

  static RepositoryException _completedVerificationFailure(String message) {
    return RepositoryException(
      operation: 'food.migration.verifyCompleted',
      code: RepositoryErrorCode.verificationFailed,
      cause: FormatException(message),
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
  }) {
    return IndexedDbQuarantinedRecord(
      id:
          'quarantine:food:$category:'
          '${sourceIndex.toString().padLeft(8, '0')}',
      migrationId: migrationId,
      sourceSystem: FoodLegacyReader.sourceSystem,
      sourceKey: FoodLegacyReader.sourceKey,
      sourceSection: FoodLegacyReader.sourceKey,
      sourceIndex: sourceIndex,
      rawPayload: rawPayload,
      errorCode: errorCode,
      errorMessage: errorMessage,
      quarantinedAt: timestamp,
    );
  }

  static String _domainJson(MealData data) => jsonEncode(data.toJson());

  static bool _sameSet(Iterable<String> first, Iterable<String> second) {
    final firstSet = first.toSet();
    final secondSet = second.toSet();
    return firstSet.length == secondSet.length &&
        firstSet.containsAll(secondSet);
  }

  static String _digest(Iterable<String> values) {
    var hash = 0x811c9dc5;
    for (final byte in utf8.encode(values.join('\u0000'))) {
      hash ^= byte;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }
}

class _FoodCandidate {
  final List<ValidLegacyFoodRecord> sourceRecords;
  final PersistedFoodRecord record;

  _FoodCandidate({
    required Iterable<ValidLegacyFoodRecord> sourceRecords,
    required this.record,
  }) : sourceRecords = List.unmodifiable(sourceRecords);
}

class _FoodMigrationPlan {
  final int sourceCount;
  final int invalidCount;
  final int legacyConflictCount;
  final List<_FoodCandidate> candidates;
  final List<IndexedDbQuarantinedRecord> quarantinedRecords;

  _FoodMigrationPlan({
    required this.sourceCount,
    required this.invalidCount,
    required this.legacyConflictCount,
    required Iterable<_FoodCandidate> candidates,
    required Iterable<IndexedDbQuarantinedRecord> quarantinedRecords,
  }) : candidates = List.unmodifiable(candidates),
       quarantinedRecords = List.unmodifiable(quarantinedRecords);

  int get preliminaryValidCount =>
      sourceCount - invalidCount - legacyConflictCount;
}

class _FoodWriteOutcome {
  final int sourceCount;
  final int invalidCount;
  final int legacyConflictCount;
  final int targetConflictCount;
  final int existingMatchCount;
  final int writtenCount;
  final List<PersistedFoodRecord> expectedRecords;
  final List<IndexedDbQuarantinedRecord> quarantineRecords;
  final IndexedDbMigrationMetadata preparedMetadata;

  _FoodWriteOutcome({
    required this.sourceCount,
    required this.invalidCount,
    required this.legacyConflictCount,
    required this.targetConflictCount,
    required this.existingMatchCount,
    required this.writtenCount,
    required Iterable<PersistedFoodRecord> expectedRecords,
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

  FoodMigrationResult toResult({required bool alreadyCompleted}) {
    return FoodMigrationResult(
      alreadyCompleted: alreadyCompleted,
      sourceCount: sourceCount,
      validCount: validCount,
      invalidCount: invalidCount,
      conflictCount: conflictCount,
      writtenCount: writtenCount,
      existingMatchCount: existingMatchCount,
      foodRecordIds: expectedIds,
      quarantineRecordIds: quarantineIds,
    );
  }
}
