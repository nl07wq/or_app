import 'dart:convert';

import '../../../data/indexed_db/indexed_db_database_contract.dart';
import '../../../data/indexed_db/indexed_db_migration_metadata.dart';
import '../../../data/indexed_db/indexed_db_quarantined_record.dart';
import '../../../data/indexed_db/indexed_db_schema.dart';
import '../../../data/indexed_db/indexed_db_store_names.dart';
import '../../repositories/repository_exception.dart';
import '../models/custom_training_exercise.dart';
import '../models/persisted_custom_training_exercise_record.dart';
import '../repository/custom_training_exercise_id_generator.dart';
import '../repository/indexed_db_custom_training_exercise_repository.dart';
import '../services/exercise_name_localization.dart';
import 'custom_training_exercise_legacy_reader.dart';

class CustomTrainingExerciseMigrationResult {
  final bool alreadyCompleted;
  final int sourceCount;
  final int validCount;
  final int invalidCount;
  final int duplicateCount;
  final int conflictCount;
  final int writtenCount;
  final int existingMatchCount;
  final Set<String> recordIds;
  final Set<String> quarantineRecordIds;

  CustomTrainingExerciseMigrationResult({
    required this.alreadyCompleted,
    required this.sourceCount,
    required this.validCount,
    required this.invalidCount,
    required this.duplicateCount,
    required this.conflictCount,
    required this.writtenCount,
    required this.existingMatchCount,
    required Iterable<String> recordIds,
    required Iterable<String> quarantineRecordIds,
  }) : recordIds = Set.unmodifiable(recordIds),
       quarantineRecordIds = Set.unmodifiable(quarantineRecordIds);
}

class CustomTrainingExerciseMigrationService {
  static const migrationId =
      'shared_preferences_custom_training_exercises_v1_to_indexeddb_v3';
  static const _leaseDuration = Duration(minutes: 5);

  final IndexedDbDatabase _database;
  final CustomTrainingExerciseLegacyReader _legacyReader;
  final DateTime Function() _now;
  final String _ownerId;

  CustomTrainingExerciseMigrationService(
    this._database, {
    CustomTrainingExerciseLegacyReader? legacyReader,
    DateTime Function()? now,
    String? ownerId,
  }) : _legacyReader = legacyReader ?? CustomTrainingExerciseLegacyReader(),
       _now = now ?? DateTime.now,
       _ownerId =
           ownerId ??
           'custom-exercise-migration-'
               '${DateTime.now().microsecondsSinceEpoch}';

  Future<CustomTrainingExerciseMigrationResult> migrate() async {
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
          'Custom Training Exercise Legacy counts do not match source.',
        );
      }
      final timestamp = _now().toUtc();
      final plan = _buildPlan(legacy, timestamp);
      final writing = activeMetadata.copyWith(
        status: IndexedDbMigrationStatus.writing,
        updatedAt: timestamp,
        sourceCounts: {
          CustomTrainingExerciseLegacyReader.sourceKey: legacy.sourceCount,
        },
        validCounts: {
          'validRecordCount': legacy.validRecords.length,
          'invalidRecordCount': legacy.invalidRecords.length,
          'duplicateRecordCount': plan.duplicateQuarantine.length,
          'conflictRecordCount': 0,
          'writtenRecordCount': 0,
          'verifiedRecordCount': 0,
          'existingMatchCount': 0,
          'aggregatedRecordCount': plan.candidates.length,
        },
        quarantinedCounts: {
          'invalid': legacy.invalidRecords.length,
          'duplicate': plan.duplicateQuarantine.length,
          'conflict': 0,
        },
        expectedRecordIds: const {},
        sourceDigest: _digest(legacy.rawValue),
        sourceIdDigest: _digest(
          plan.candidates.map((candidate) => candidate.record.id).toList()
            ..sort(),
        ),
        targetIdDigest: null,
        targetDigest: null,
        errorCode: null,
        errorMessage: null,
      );
      await _writeMetadata(writing);
      activeMetadata = writing;

      final outcome = await _writePlan(plan, writing, timestamp);
      activeMetadata = outcome.metadata;
      if (outcome.conflictCount > 0) {
        throw RepositoryException(
          operation: 'customTrainingExercise.migration.conflict',
          code: RepositoryErrorCode.migrationFailed,
          cause: StateError(
            '${outcome.conflictCount} Custom Training Exercise '
            'conflict(s) detected.',
          ),
        );
      }

      final verifying = outcome.metadata.copyWith(
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
        operation: 'customTrainingExercise.migration',
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
            operation: 'customTrainingExercise.migration.acquireLease',
            code: RepositoryErrorCode.migrationFailed,
            cause: StateError(
              'Custom Training Exercise migration lease is already held.',
            ),
          );
        }
        final metadata = IndexedDbMigrationMetadata(
          id: migrationId,
          status: IndexedDbMigrationStatus.validating,
          source: CustomTrainingExerciseLegacyReader.sourceSystem,
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

  _CustomExerciseMigrationPlan _buildPlan(
    CustomTrainingExerciseLegacyReadResult legacy,
    DateTime timestamp,
  ) {
    final candidates = <_CustomExerciseCandidate>[];
    final duplicates = <IndexedDbQuarantinedRecord>[];
    final firstByNormalizedName = <String, ValidLegacyCustomTrainingExercise>{};

    for (final source in legacy.validRecords) {
      final normalizedName = exerciseIdentityKey(source.name);
      final first = firstByNormalizedName[normalizedName];
      if (first != null) {
        duplicates.add(
          _quarantine(
            category: 'duplicate',
            sourceIndex: source.sourceIndex,
            rawPayload: source.rawPayload,
            errorCode: first.name == source.name
                ? 'duplicateName'
                : 'duplicateNormalizedName',
            errorMessage:
                'The first Legacy Custom Training Exercise is canonical.',
            conflictingRecordId: const CustomTrainingExerciseLegacyIdGenerator()
                .generate(first.name),
            timestamp: timestamp,
          ),
        );
        continue;
      }
      firstByNormalizedName[normalizedName] = source;
      final id = const CustomTrainingExerciseLegacyIdGenerator().generate(
        source.name,
      );
      final orderedTimestamp = timestamp.add(
        Duration(microseconds: source.sourceIndex),
      );
      candidates.add(
        _CustomExerciseCandidate(
          source: source,
          record: PersistedCustomTrainingExerciseRecord(
            id: id,
            normalizedName: normalizedName,
            createdAt: orderedTimestamp,
            updatedAt: orderedTimestamp,
            migrationSource: CustomTrainingExerciseMigrationSource(
              migrationId: migrationId,
              sourceSystem: CustomTrainingExerciseLegacyReader.sourceSystem,
              sourceKey: CustomTrainingExerciseLegacyReader.sourceKey,
              sourceIndex: source.sourceIndex,
            ),
            data: CustomTrainingExercise(id: id, name: source.name),
          ),
        ),
      );
    }

    final invalid = [
      for (final source in legacy.invalidRecords)
        _quarantine(
          category: 'invalid',
          sourceIndex: source.sourceIndex,
          rawPayload: source.rawPayload,
          errorCode: source.errorCode,
          errorMessage: source.errorMessage,
          timestamp: timestamp,
        ),
    ];
    return _CustomExerciseMigrationPlan(
      sourceCount: legacy.sourceCount,
      validCount: legacy.validRecords.length,
      candidates: candidates,
      invalidQuarantine: invalid,
      duplicateQuarantine: duplicates,
    );
  }

  Future<_CustomExerciseMigrationOutcome> _writePlan(
    _CustomExerciseMigrationPlan plan,
    IndexedDbMigrationMetadata metadata,
    DateTime timestamp,
  ) {
    return _database.runTransaction<_CustomExerciseMigrationOutcome>(
      storeNames: const [
        IndexedDbStoreNames.customTrainingExercises,
        IndexedDbStoreNames.migrationQuarantine,
        IndexedDbStoreNames.migrationMetadata,
      ],
      mode: IndexedDbTransactionMode.readWrite,
      action: (transaction) async {
        final existingValues = await transaction.findAll(
          IndexedDbStoreNames.customTrainingExercises,
        );
        final existingById = <String, PersistedCustomTrainingExerciseRecord>{};
        final existingByNormalized =
            <String, PersistedCustomTrainingExerciseRecord>{};
        for (final value in existingValues) {
          final record = PersistedCustomTrainingExerciseRecord.fromRecord(
            value,
          );
          existingById[record.id] = record;
          existingByNormalized[record.normalizedName] = record;
        }

        final expected = <PersistedCustomTrainingExerciseRecord>[];
        final quarantine = <IndexedDbQuarantinedRecord>[
          ...plan.invalidQuarantine,
          ...plan.duplicateQuarantine,
        ];
        var writtenCount = 0;
        var existingMatchCount = 0;
        var conflictCount = 0;
        for (final candidate in plan.candidates) {
          final existingId = existingById[candidate.record.id];
          if (existingId != null) {
            if (_sameContent(existingId, candidate.record)) {
              existingMatchCount++;
              expected.add(existingId);
            } else {
              conflictCount++;
              quarantine.add(
                _conflictQuarantine(
                  candidate,
                  existingId,
                  'sameIdDifferentContent',
                  timestamp,
                ),
              );
            }
            continue;
          }
          final existingName =
              existingByNormalized[candidate.record.normalizedName];
          if (existingName != null) {
            conflictCount++;
            quarantine.add(
              _conflictQuarantine(
                candidate,
                existingName,
                'sameNormalizedNameDifferentId',
                timestamp,
              ),
            );
            continue;
          }
          await transaction.put(
            IndexedDbStoreNames.customTrainingExercises,
            candidate.record.toRecord(),
          );
          writtenCount++;
          expected.add(candidate.record);
          existingById[candidate.record.id] = candidate.record;
          existingByNormalized[candidate.record.normalizedName] =
              candidate.record;
        }
        for (final record in quarantine) {
          await transaction.put(
            IndexedDbStoreNames.migrationQuarantine,
            record.toRecord(),
          );
        }

        final expectedIds = expected.map((record) => record.id).toList()
          ..sort();
        final prepared = metadata.copyWith(
          status: IndexedDbMigrationStatus.prepared,
          updatedAt: _now().toUtc(),
          ownerId: _ownerId,
          leaseExpiresAt: _now().toUtc().add(_leaseDuration),
          validCounts: {
            ...metadata.validCounts,
            'conflictRecordCount': conflictCount,
            'writtenRecordCount': writtenCount,
            'existingMatchCount': existingMatchCount,
          },
          quarantinedCounts: {
            ...metadata.quarantinedCounts,
            'conflict': conflictCount,
          },
          expectedRecordIds: {
            IndexedDbStoreNames.customTrainingExercises: expectedIds,
          },
          targetIdDigest: _digest(expectedIds),
          targetDigest: _digest(
            expected.map((record) => record.toRecord()).toList(),
          ),
        );
        await transaction.put(
          IndexedDbStoreNames.migrationMetadata,
          prepared.toRecord(),
        );
        return _CustomExerciseMigrationOutcome(
          plan: plan,
          metadata: prepared,
          expectedRecords: expected,
          quarantineRecordIds: quarantine.map((record) => record.id).toSet(),
          writtenCount: writtenCount,
          existingMatchCount: existingMatchCount,
          conflictCount: conflictCount,
        );
      },
    );
  }

  Future<void> _verifyOutcome(_CustomExerciseMigrationOutcome outcome) async {
    final repository = IndexedDbCustomTrainingExerciseRepository(_database);
    final result = await repository.findAllWithIssues();
    if (result.hasIssues) {
      throw RepositoryException(
        operation: 'customTrainingExercise.migration.verify',
        code: RepositoryErrorCode.verificationFailed,
        cause: result.issues,
      );
    }
    final byId = {for (final record in result.records) record.id: record};
    for (final expected in outcome.expectedRecords) {
      final actual = byId[expected.id];
      if (actual == null || !_sameContent(actual, expected)) {
        throw RepositoryException(
          operation: 'customTrainingExercise.migration.verify',
          code: RepositoryErrorCode.verificationFailed,
          cause: StateError(
            'Custom Training Exercise verification failed: ${expected.id}',
          ),
        );
      }
    }
  }

  Future<CustomTrainingExerciseMigrationResult> _verifyCompleted(
    IndexedDbMigrationMetadata metadata,
  ) async {
    final expectedIds =
        metadata.expectedRecordIds[IndexedDbStoreNames
            .customTrainingExercises] ??
        const <String>[];
    final records = <PersistedCustomTrainingExerciseRecord>[];
    for (final id in expectedIds) {
      final stored = await _database.findById(
        IndexedDbStoreNames.customTrainingExercises,
        id,
      );
      if (stored == null) {
        throw RepositoryException(
          operation: 'customTrainingExercise.migration.verifyCompleted',
          code: RepositoryErrorCode.verificationFailed,
          cause: StateError('Completed migration record is missing: $id'),
        );
      }
      records.add(PersistedCustomTrainingExerciseRecord.fromRecord(stored));
    }
    final actualIds = records.map((record) => record.id).toList()..sort();
    if (_digest(actualIds) != metadata.targetIdDigest ||
        _digest(records.map((record) => record.toRecord()).toList()) !=
            metadata.targetDigest) {
      throw RepositoryException(
        operation: 'customTrainingExercise.migration.verifyCompleted',
        code: RepositoryErrorCode.verificationFailed,
        cause: StateError(
          'Completed Custom Training Exercise migration digest mismatch.',
        ),
      );
    }
    return CustomTrainingExerciseMigrationResult(
      alreadyCompleted: true,
      sourceCount:
          metadata.sourceCounts[CustomTrainingExerciseLegacyReader.sourceKey] ??
          0,
      validCount: metadata.validCounts['validRecordCount'] ?? 0,
      invalidCount: metadata.validCounts['invalidRecordCount'] ?? 0,
      duplicateCount: metadata.validCounts['duplicateRecordCount'] ?? 0,
      conflictCount: metadata.validCounts['conflictRecordCount'] ?? 0,
      writtenCount: metadata.validCounts['writtenRecordCount'] ?? 0,
      existingMatchCount: metadata.validCounts['existingMatchCount'] ?? 0,
      recordIds: expectedIds,
      quarantineRecordIds: const {},
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
    try {
      final now = _now().toUtc();
      await _writeMetadata(
        metadata.copyWith(
          status: IndexedDbMigrationStatus.failed,
          updatedAt: now,
          ownerId: null,
          leaseExpiresAt: null,
          errorCode: error is RepositoryException
              ? error.code.name
              : RepositoryErrorCode.migrationFailed.name,
          errorMessage: error.toString(),
        ),
      );
    } catch (_) {
      // Preserve the original migration error.
    }
  }

  static bool _sameContent(
    PersistedCustomTrainingExerciseRecord first,
    PersistedCustomTrainingExerciseRecord second,
  ) {
    return first.id == second.id &&
        first.normalizedName == second.normalizedName &&
        first.data.id == second.data.id &&
        first.data.name == second.data.name;
  }

  static IndexedDbQuarantinedRecord _conflictQuarantine(
    _CustomExerciseCandidate candidate,
    PersistedCustomTrainingExerciseRecord existing,
    String conflictType,
    DateTime timestamp,
  ) {
    return _quarantine(
      category: 'conflict',
      sourceIndex: candidate.source.sourceIndex,
      rawPayload: candidate.source.rawPayload,
      errorCode: 'migrationConflict',
      errorMessage: 'Custom Training Exercise conflicts with IndexedDB.',
      conflictingRecordId: existing.id,
      existingPayloadDigest: _digest(existing.toRecord()),
      legacyPayloadDigest: _digest(candidate.record.toRecord()),
      conflictType: conflictType,
      timestamp: timestamp,
    );
  }

  static IndexedDbQuarantinedRecord _quarantine({
    required String category,
    required int sourceIndex,
    required Object? rawPayload,
    required String errorCode,
    required String errorMessage,
    String? conflictingRecordId,
    String? existingPayloadDigest,
    String? legacyPayloadDigest,
    String? conflictType,
    required DateTime timestamp,
  }) {
    return IndexedDbQuarantinedRecord(
      id: '$migrationId:$category:${sourceIndex.toString().padLeft(6, '0')}',
      migrationId: migrationId,
      sourceSystem: CustomTrainingExerciseLegacyReader.sourceSystem,
      sourceKey: CustomTrainingExerciseLegacyReader.sourceKey,
      sourceSection: 'customTrainingExercises',
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

  static String _digest(Object? value) {
    return CustomTrainingExerciseLegacyIdGenerator.fnv1aDigest(
      _canonicalJson(value),
    );
  }

  static String _canonicalJson(Object? value) => jsonEncode(_canonical(value));

  static Object? _canonical(Object? value) {
    if (value is Map) {
      final keys = value.keys.map((key) => key.toString()).toList()..sort();
      return <String, Object?>{
        for (final key in keys) key: _canonical(value[key]),
      };
    }
    if (value is Iterable) {
      return <Object?>[for (final item in value) _canonical(item)];
    }
    return value;
  }
}

class _CustomExerciseCandidate {
  final ValidLegacyCustomTrainingExercise source;
  final PersistedCustomTrainingExerciseRecord record;

  const _CustomExerciseCandidate({required this.source, required this.record});
}

class _CustomExerciseMigrationPlan {
  final int sourceCount;
  final int validCount;
  final List<_CustomExerciseCandidate> candidates;
  final List<IndexedDbQuarantinedRecord> invalidQuarantine;
  final List<IndexedDbQuarantinedRecord> duplicateQuarantine;

  const _CustomExerciseMigrationPlan({
    required this.sourceCount,
    required this.validCount,
    required this.candidates,
    required this.invalidQuarantine,
    required this.duplicateQuarantine,
  });
}

class _CustomExerciseMigrationOutcome {
  final _CustomExerciseMigrationPlan plan;
  final IndexedDbMigrationMetadata metadata;
  final List<PersistedCustomTrainingExerciseRecord> expectedRecords;
  final Set<String> quarantineRecordIds;
  final int writtenCount;
  final int existingMatchCount;
  final int conflictCount;

  const _CustomExerciseMigrationOutcome({
    required this.plan,
    required this.metadata,
    required this.expectedRecords,
    required this.quarantineRecordIds,
    required this.writtenCount,
    required this.existingMatchCount,
    required this.conflictCount,
  });

  CustomTrainingExerciseMigrationResult toResult({
    required bool alreadyCompleted,
  }) {
    return CustomTrainingExerciseMigrationResult(
      alreadyCompleted: alreadyCompleted,
      sourceCount: plan.sourceCount,
      validCount: plan.validCount,
      invalidCount: plan.invalidQuarantine.length,
      duplicateCount: plan.duplicateQuarantine.length,
      conflictCount: conflictCount,
      writtenCount: writtenCount,
      existingMatchCount: existingMatchCount,
      recordIds: expectedRecords.map((record) => record.id),
      quarantineRecordIds: quarantineRecordIds,
    );
  }
}
