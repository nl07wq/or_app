import 'dart:convert';

import '../../../data/indexed_db/indexed_db_database_contract.dart';
import '../../../data/indexed_db/indexed_db_migration_metadata.dart';
import '../../../data/indexed_db/indexed_db_quarantined_record.dart';
import '../../../data/indexed_db/indexed_db_schema.dart';
import '../../../data/indexed_db/indexed_db_store_names.dart';
import '../../repositories/repository_exception.dart';
import '../models/persisted_daily_log_confirmation_record.dart';
import '../repository/indexed_db_daily_log_confirmation_repository.dart';
import 'daily_log_confirmation_legacy_reader.dart';

class DailyLogConfirmationMigrationResult {
  final bool alreadyCompleted;
  final bool sourceKeyPresent;
  final int sourceCount;
  final int validCount;
  final int invalidCount;
  final int conflictCount;
  final int writtenCount;
  final int existingMatchCount;
  final Set<String> confirmationRecordIds;
  final Set<String> quarantineRecordIds;

  DailyLogConfirmationMigrationResult({
    required this.alreadyCompleted,
    required this.sourceKeyPresent,
    required this.sourceCount,
    required this.validCount,
    required this.invalidCount,
    required this.conflictCount,
    required this.writtenCount,
    required this.existingMatchCount,
    required Iterable<String> confirmationRecordIds,
    required Iterable<String> quarantineRecordIds,
  }) : confirmationRecordIds = Set.unmodifiable(confirmationRecordIds),
       quarantineRecordIds = Set.unmodifiable(quarantineRecordIds);
}

class DailyLogConfirmationMigrationService {
  static const migrationId =
      'shared_preferences_daily_log_confirmation_v1_to_indexeddb_v3';
  static const _leaseDuration = Duration(minutes: 5);

  final IndexedDbDatabase _database;
  final DailyLogConfirmationLegacyReader _legacyReader;
  final DateTime Function() _now;
  final String _ownerId;

  DailyLogConfirmationMigrationService(
    this._database, {
    DailyLogConfirmationLegacyReader? legacyReader,
    DateTime Function()? now,
    String? ownerId,
  }) : _legacyReader = legacyReader ?? DailyLogConfirmationLegacyReader(),
       _now = now ?? DateTime.now,
       _ownerId =
           ownerId ??
           'daily-log-confirmation-migration-'
               '${DateTime.now().microsecondsSinceEpoch}';

  Future<DailyLogConfirmationMigrationResult> migrate() async {
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
          'Daily Log Confirmation Legacy counts do not match source.',
        );
      }
      final timestamp = _now().toUtc();
      final plan = _buildPlan(legacy, timestamp);
      final sourceIds = [
        for (final record in legacy.validRecords)
          PersistedDailyLogConfirmationRecord.canonicalId(record.localDate),
      ];
      final writing = activeMetadata.copyWith(
        status: IndexedDbMigrationStatus.writing,
        updatedAt: timestamp,
        sourceCounts: {
          DailyLogConfirmationLegacyReader.sourceKey: legacy.sourceCount,
          'sourceKeyPresent': legacy.sourceKeyPresent ? 1 : 0,
        },
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
        sourceIdDigest: _digest(sourceIds),
        targetIdDigest: null,
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
          operation: 'dailyLogConfirmation.migration.conflict',
          code: RepositoryErrorCode.migrationFailed,
          cause: StateError(
            '${outcome.targetConflictCount} Daily Log Confirmation target '
            'conflicts detected.',
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
      return outcome.toResult(
        alreadyCompleted: false,
        sourceKeyPresent: legacy.sourceKeyPresent,
      );
    } catch (error) {
      if (activeMetadata != null &&
          activeMetadata.status != IndexedDbMigrationStatus.completed) {
        await _markFailed(activeMetadata, error);
      }
      if (error is RepositoryException) rethrow;
      throw RepositoryException(
        operation: 'dailyLogConfirmation.migration',
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
            operation: 'dailyLogConfirmation.migration.acquireLease',
            code: RepositoryErrorCode.migrationFailed,
            cause: StateError(
              'Daily Log Confirmation migration lease is already held.',
            ),
          );
        }
        final metadata = IndexedDbMigrationMetadata(
          id: migrationId,
          status: IndexedDbMigrationStatus.validating,
          source: DailyLogConfirmationLegacyReader.sourceSystem,
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

  _DailyLogConfirmationMigrationPlan _buildPlan(
    DailyLogConfirmationLegacyReadResult legacy,
    DateTime timestamp,
  ) {
    final groups = <String, List<ValidLegacyDailyLogConfirmationRecord>>{};
    for (final record in legacy.validRecords) {
      groups.putIfAbsent(record.localDate, () => []).add(record);
    }
    final candidates = <_DailyLogConfirmationCandidate>[];
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
      final ordered =
          List<ValidLegacyDailyLogConfirmationRecord>.from(entry.value)
            ..sort((first, second) {
              final byConfirmedAt = first.data.confirmedAt.compareTo(
                second.data.confirmedAt,
              );
              return byConfirmedAt != 0
                  ? byConfirmedAt
                  : first.sourceIndex.compareTo(second.sourceIndex);
            });
      final canonical = ordered.last;
      final id = PersistedDailyLogConfirmationRecord.canonicalId(entry.key);
      final orderedTimestamp = timestamp.add(
        Duration(microseconds: canonical.sourceIndex),
      );
      candidates.add(
        _DailyLogConfirmationCandidate(
          source: canonical,
          record: PersistedDailyLogConfirmationRecord(
            id: id,
            snapshotVersion: canonical.snapshotVersion,
            localDate: entry.key,
            createdAt: orderedTimestamp,
            updatedAt: orderedTimestamp,
            migrationSource: DailyLogConfirmationMigrationSource(
              migrationId: migrationId,
              sourceSystem: DailyLogConfirmationLegacyReader.sourceSystem,
              sourceKey: DailyLogConfirmationLegacyReader.sourceKey,
              sourceIndex: canonical.sourceIndex,
            ),
            data: canonical.data,
          ),
        ),
      );
      for (final revision in ordered.take(ordered.length - 1)) {
        legacyConflictCount++;
        quarantine.add(
          _quarantine(
            category: 'legacy-revision',
            sourceIndex: revision.sourceIndex,
            rawPayload: revision.rawPayload,
            errorCode: 'legacySameDateRevision',
            errorMessage:
                'Older same-date Daily Log Confirmation preserved for audit.',
            timestamp: timestamp,
            conflictingRecordId: id,
            legacyPayloadDigest: _canonicalDigest(revision.data.toJson()),
            conflictType: 'legacySameDateRevision',
          ),
        );
      }
    }
    candidates.sort(
      (first, second) =>
          first.source.sourceIndex.compareTo(second.source.sourceIndex),
    );
    return _DailyLogConfirmationMigrationPlan(
      sourceCount: legacy.sourceCount,
      invalidCount: legacy.invalidRecords.length,
      legacyConflictCount: legacyConflictCount,
      candidates: candidates,
      quarantinedRecords: quarantine,
    );
  }

  Future<_DailyLogConfirmationWriteOutcome> _writePlan(
    _DailyLogConfirmationMigrationPlan plan,
    IndexedDbMigrationMetadata metadata,
    DateTime timestamp,
  ) {
    return _database.runTransaction<_DailyLogConfirmationWriteOutcome>(
      storeNames: const [
        IndexedDbStoreNames.dailyLogConfirmations,
        IndexedDbStoreNames.migrationQuarantine,
        IndexedDbStoreNames.migrationMetadata,
      ],
      mode: IndexedDbTransactionMode.readWrite,
      action: (transaction) async {
        await _removePreviousAttemptRecords(transaction);
        final toWrite = <PersistedDailyLogConfirmationRecord>[];
        final expected = <PersistedDailyLogConfirmationRecord>[];
        final quarantine = List<IndexedDbQuarantinedRecord>.from(
          plan.quarantinedRecords,
        );
        var existingMatchCount = 0;
        var targetConflictCount = 0;

        for (final candidate in plan.candidates) {
          final existingValue = await transaction.findById(
            IndexedDbStoreNames.dailyLogConfirmations,
            candidate.record.id,
          );
          if (existingValue == null) {
            toWrite.add(candidate.record);
            expected.add(candidate.record);
            continue;
          }
          PersistedDailyLogConfirmationRecord? existing;
          try {
            existing = PersistedDailyLogConfirmationRecord.fromRecord(
              existingValue,
            );
          } catch (_) {
            existing = null;
          }
          if (existing != null && _sameDomain(existing, candidate.record)) {
            existingMatchCount++;
            expected.add(existing);
            continue;
          }
          targetConflictCount++;
          final existingDigest = _canonicalDigest(existingValue);
          final legacyDigest = _recordDigest(candidate.record);
          quarantine.add(
            _quarantine(
              category: 'target-conflict',
              sourceIndex: candidate.source.sourceIndex,
              rawPayload: candidate.source.rawPayload,
              errorCode: 'targetIdConflict',
              errorMessage:
                  'Daily Log Confirmation ${candidate.record.id} conflicts '
                  'with IndexedDB.',
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
            IndexedDbStoreNames.dailyLogConfirmations,
            record.toRecord(),
          );
        }
        for (final record in quarantine) {
          await transaction.put(
            IndexedDbStoreNames.migrationQuarantine,
            record.toRecord(),
          );
        }

        final confirmationIds = expected.map((record) => record.id).toSet();
        final quarantineIds = quarantine.map((record) => record.id).toSet();
        if (!_sameSet(
              confirmationIds,
              await _expectedConfirmationIds(transaction, confirmationIds),
            ) ||
            !_sameSet(
              quarantineIds,
              await _migrationQuarantineIds(transaction),
            )) {
          throw const FormatException(
            'Daily Log Confirmation transaction verification failed.',
          );
        }
        final conflictCount = plan.legacyConflictCount + targetConflictCount;
        final validCount = plan.sourceCount - plan.invalidCount - conflictCount;
        if (validCount + plan.invalidCount + conflictCount !=
            plan.sourceCount) {
          throw const FormatException(
            'Daily Log Confirmation source counts differ.',
          );
        }
        final sortedIds = confirmationIds.toList()..sort();
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
            IndexedDbStoreNames.dailyLogConfirmations: sortedIds,
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
        return _DailyLogConfirmationWriteOutcome(
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
    final records = await transaction.findAll(
      IndexedDbStoreNames.dailyLogConfirmations,
    );
    for (final value in records) {
      final source = value['migrationSource'];
      if (source is Map && source['migrationId'] == migrationId) {
        final id = value['id'];
        if (id is String) {
          await transaction.deleteById(
            IndexedDbStoreNames.dailyLogConfirmations,
            id,
          );
        }
      }
    }
    final quarantine = await transaction.findAll(
      IndexedDbStoreNames.migrationQuarantine,
    );
    for (final value in quarantine) {
      if (value['migrationId'] == migrationId && value['id'] is String) {
        await transaction.deleteById(
          IndexedDbStoreNames.migrationQuarantine,
          value['id']! as String,
        );
      }
    }
  }

  Future<Set<String>> _expectedConfirmationIds(
    IndexedDbTransaction transaction,
    Set<String> expected,
  ) async {
    final ids = <String>{};
    for (final id in expected) {
      if (await transaction.findById(
            IndexedDbStoreNames.dailyLogConfirmations,
            id,
          ) !=
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
        if (value['migrationId'] == migrationId && value['id'] is String)
          value['id']! as String,
    };
  }

  Future<void> _verifyOutcome(_DailyLogConfirmationWriteOutcome outcome) async {
    final repository = IndexedDbDailyLogConfirmationRepository(_database);
    final readResult = await repository.findAllWithIssues();
    if (readResult.hasIssues) {
      throw RepositoryException(
        operation: 'dailyLogConfirmation.migration.verify',
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
        'Daily Log Confirmation IDs differ after commit.',
      );
    }
    for (final expected in outcome.expectedRecords) {
      final actualRecord = actual[expected.id]!;
      if (!_sameDomain(actualRecord, expected)) {
        throw FormatException(
          'Daily Log Confirmation differs after commit: ${expected.id}.',
        );
      }
    }
    final quarantineValues = await _database.findAll(
      IndexedDbStoreNames.migrationQuarantine,
    );
    final quarantineIds = {
      for (final value in quarantineValues)
        if (value['migrationId'] == migrationId && value['id'] is String)
          value['id']! as String,
    };
    if (!_sameSet(quarantineIds, outcome.quarantineIds) ||
        outcome.validCount + outcome.invalidCount + outcome.conflictCount !=
            outcome.sourceCount) {
      throw const FormatException(
        'Daily Log Confirmation verification counts differ.',
      );
    }
    final sortedIds = outcome.expectedIds.toList()..sort();
    if (outcome.preparedMetadata.targetIdDigest != _digest(sortedIds) ||
        outcome.preparedMetadata.targetDigest !=
            _recordsDigest(outcome.expectedRecords)) {
      throw const FormatException(
        'Daily Log Confirmation verification digest differs.',
      );
    }
  }

  Future<DailyLogConfirmationMigrationResult> _verifyCompleted(
    IndexedDbMigrationMetadata metadata,
  ) async {
    final expectedIds =
        metadata.expectedRecordIds[IndexedDbStoreNames.dailyLogConfirmations] ??
        const [];
    final expectedQuarantineIds =
        metadata.expectedRecordIds[IndexedDbStoreNames.migrationQuarantine] ??
        const [];
    final actualRecords = <PersistedDailyLogConfirmationRecord>[];
    for (final id in expectedIds) {
      final value = await _database.findById(
        IndexedDbStoreNames.dailyLogConfirmations,
        id,
      );
      if (value != null) {
        actualRecords.add(
          PersistedDailyLogConfirmationRecord.fromRecord(value),
        );
      }
    }
    final actualIds = actualRecords.map((record) => record.id).toSet();
    final quarantineValues = await _database.findAll(
      IndexedDbStoreNames.migrationQuarantine,
    );
    final actualQuarantineIds = {
      for (final value in quarantineValues)
        if (value['migrationId'] == migrationId && value['id'] is String)
          value['id']! as String,
    };
    final sortedIds = actualIds.toList()..sort();
    if (!_sameSet(actualIds, expectedIds) ||
        !_sameSet(actualQuarantineIds, expectedQuarantineIds) ||
        metadata.targetIdDigest != _digest(sortedIds) ||
        metadata.targetDigest != _recordsDigest(actualRecords)) {
      throw RepositoryException(
        operation: 'dailyLogConfirmation.migration.verifyCompleted',
        code: RepositoryErrorCode.verificationFailed,
        cause: const FormatException(
          'Completed Daily Log Confirmation migration no longer matches '
          'metadata.',
        ),
      );
    }
    return DailyLogConfirmationMigrationResult(
      alreadyCompleted: true,
      sourceKeyPresent: metadata.sourceCounts['sourceKeyPresent'] == 1,
      sourceCount:
          metadata.sourceCounts[DailyLogConfirmationLegacyReader.sourceKey] ??
          0,
      validCount: metadata.validCounts['validRecordCount'] ?? 0,
      invalidCount: metadata.validCounts['invalidRecordCount'] ?? 0,
      conflictCount: metadata.validCounts['conflictRecordCount'] ?? 0,
      writtenCount: metadata.validCounts['writtenRecordCount'] ?? 0,
      existingMatchCount: metadata.validCounts['existingMatchCount'] ?? 0,
      confirmationRecordIds: actualIds,
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
          'quarantine:daily-log-confirmation:$category:'
          '${sourceIndex.toString().padLeft(8, '0')}',
      migrationId: migrationId,
      sourceSystem: DailyLogConfirmationLegacyReader.sourceSystem,
      sourceKey: DailyLogConfirmationLegacyReader.sourceKey,
      sourceSection: DailyLogConfirmationLegacyReader.sourceKey,
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
    PersistedDailyLogConfirmationRecord first,
    PersistedDailyLogConfirmationRecord second,
  ) {
    return first.localDate == second.localDate &&
        first.snapshotVersion == second.snapshotVersion &&
        _canonicalJson(first.data.toJson()) ==
            _canonicalJson(second.data.toJson());
  }

  static String _recordDigest(PersistedDailyLogConfirmationRecord record) {
    return _canonicalDigest({
      'id': record.id,
      'snapshotVersion': record.snapshotVersion,
      'localDate': record.localDate,
      'data': record.data.toJson(),
    });
  }

  static String _recordsDigest(
    Iterable<PersistedDailyLogConfirmationRecord> records,
  ) {
    final values = records.map(_recordDigest).toList()..sort();
    return _digest(values);
  }

  static String _canonicalDigest(Object? value) {
    return _fnv1a(_canonicalJson(value));
  }

  static String _canonicalJson(Object? value) {
    return jsonEncode(_canonicalValue(value));
  }

  static Object? _canonicalValue(Object? value) {
    if (value is Map) {
      final entries = value.entries.toList()
        ..sort((first, second) {
          return first.key.toString().compareTo(second.key.toString());
        });
      return <String, Object?>{
        for (final entry in entries)
          entry.key.toString(): _canonicalValue(entry.value),
      };
    }
    if (value is Iterable) {
      return <Object?>[for (final item in value) _canonicalValue(item)];
    }
    return value;
  }

  static String _digest(Iterable<String> values) {
    return _fnv1a(values.join('\u0000'));
  }

  static String _fnv1a(String value) {
    var hash = 0x811c9dc5;
    for (final byte in utf8.encode(value)) {
      hash ^= byte;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  static bool _sameSet(Iterable<String> first, Iterable<String> second) {
    final firstSet = first.toSet();
    final secondSet = second.toSet();
    return firstSet.length == secondSet.length &&
        firstSet.containsAll(secondSet);
  }
}

class _DailyLogConfirmationCandidate {
  final ValidLegacyDailyLogConfirmationRecord source;
  final PersistedDailyLogConfirmationRecord record;

  const _DailyLogConfirmationCandidate({
    required this.source,
    required this.record,
  });
}

class _DailyLogConfirmationMigrationPlan {
  final int sourceCount;
  final int invalidCount;
  final int legacyConflictCount;
  final List<_DailyLogConfirmationCandidate> candidates;
  final List<IndexedDbQuarantinedRecord> quarantinedRecords;

  _DailyLogConfirmationMigrationPlan({
    required this.sourceCount,
    required this.invalidCount,
    required this.legacyConflictCount,
    required Iterable<_DailyLogConfirmationCandidate> candidates,
    required Iterable<IndexedDbQuarantinedRecord> quarantinedRecords,
  }) : candidates = List.unmodifiable(candidates),
       quarantinedRecords = List.unmodifiable(quarantinedRecords);

  int get preliminaryValidCount =>
      sourceCount - invalidCount - legacyConflictCount;
}

class _DailyLogConfirmationWriteOutcome {
  final int sourceCount;
  final int invalidCount;
  final int legacyConflictCount;
  final int targetConflictCount;
  final int existingMatchCount;
  final int writtenCount;
  final List<PersistedDailyLogConfirmationRecord> expectedRecords;
  final List<IndexedDbQuarantinedRecord> quarantineRecords;
  final IndexedDbMigrationMetadata preparedMetadata;

  _DailyLogConfirmationWriteOutcome({
    required this.sourceCount,
    required this.invalidCount,
    required this.legacyConflictCount,
    required this.targetConflictCount,
    required this.existingMatchCount,
    required this.writtenCount,
    required Iterable<PersistedDailyLogConfirmationRecord> expectedRecords,
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

  DailyLogConfirmationMigrationResult toResult({
    required bool alreadyCompleted,
    required bool sourceKeyPresent,
  }) {
    return DailyLogConfirmationMigrationResult(
      alreadyCompleted: alreadyCompleted,
      sourceKeyPresent: sourceKeyPresent,
      sourceCount: sourceCount,
      validCount: validCount,
      invalidCount: invalidCount,
      conflictCount: conflictCount,
      writtenCount: writtenCount,
      existingMatchCount: existingMatchCount,
      confirmationRecordIds: expectedIds,
      quarantineRecordIds: quarantineIds,
    );
  }
}
