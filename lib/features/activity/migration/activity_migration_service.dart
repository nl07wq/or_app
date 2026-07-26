import 'dart:convert';

import '../../../data/indexed_db/indexed_db_database_contract.dart';
import '../../../data/indexed_db/indexed_db_migration_metadata.dart';
import '../../../data/indexed_db/indexed_db_quarantined_record.dart';
import '../../../data/indexed_db/indexed_db_schema.dart';
import '../../../data/indexed_db/indexed_db_store_names.dart';
import '../../repositories/repository_exception.dart';
import '../models/persisted_activity_record.dart';
import '../repository/indexed_db_activity_repository.dart';
import 'activity_legacy_reader.dart';

class ActivityMigrationResult {
  final bool alreadyCompleted;
  final int sourceCount;
  final int validCount;
  final int invalidCount;
  final int canonicalCount;
  final int legacyRevisionCount;
  final Set<String> activityRecordIds;
  final Set<String> quarantineRecordIds;

  ActivityMigrationResult({
    required this.alreadyCompleted,
    required this.sourceCount,
    required this.validCount,
    required this.invalidCount,
    required this.canonicalCount,
    required this.legacyRevisionCount,
    required Iterable<String> activityRecordIds,
    required Iterable<String> quarantineRecordIds,
  }) : activityRecordIds = Set.unmodifiable(activityRecordIds),
       quarantineRecordIds = Set.unmodifiable(quarantineRecordIds);
}

class ActivityMigrationService {
  static const migrationId = 'shared_preferences_activity_v1_to_indexeddb_v2';
  static const _leaseDuration = Duration(minutes: 5);

  final IndexedDbDatabase _database;
  final ActivityLegacyReader _legacyReader;
  final DateTime Function() _now;
  final String _ownerId;

  ActivityMigrationService(
    this._database, {
    ActivityLegacyReader? legacyReader,
    DateTime Function()? now,
    String? ownerId,
  }) : _legacyReader = legacyReader ?? ActivityLegacyReader(),
       _now = now ?? DateTime.now,
       _ownerId =
           ownerId ??
           'activity-migration-${DateTime.now().microsecondsSinceEpoch}';

  Future<ActivityMigrationResult> migrate() async {
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
          'ACTIVITY Legacy valid and invalid counts do not match source.',
        );
      }
      final timestamp = _now().toUtc();
      final plan = _buildPlan(legacy, timestamp);
      final writingMetadata = activeMetadata.copyWith(
        status: IndexedDbMigrationStatus.writing,
        updatedAt: timestamp,
        sourceCounts: {ActivityLegacyReader.sourceKey: legacy.sourceCount},
        validCounts: {
          'activity_records': legacy.validRecords.length,
          'canonical': plan.canonicalCount,
          'legacyRevision': plan.legacyRevisionCount,
        },
        quarantinedCounts: {
          ActivityLegacyReader.sourceKey: legacy.invalidRecords.length,
        },
        expectedRecordIds: {
          IndexedDbStoreNames.activityRecords: plan.activityIds.toList()
            ..sort(),
          IndexedDbStoreNames.migrationQuarantine: plan.quarantineIds.toList()
            ..sort(),
        },
        sourceDigest: _digest(legacy.rawRecords),
        errorCode: null,
        errorMessage: null,
      );
      await _writeMetadata(writingMetadata);
      activeMetadata = writingMetadata;

      final prepared = await _writePlan(plan, writingMetadata, timestamp);
      final verifying = prepared.copyWith(
        status: IndexedDbMigrationStatus.verifying,
        updatedAt: _now().toUtc(),
      );
      await _writeMetadata(verifying);
      activeMetadata = verifying;
      await _verifyPlan(plan);

      final completedAt = _now().toUtc();
      final completed = verifying.copyWith(
        status: IndexedDbMigrationStatus.completed,
        updatedAt: completedAt,
        completedAt: completedAt,
        ownerId: null,
        leaseExpiresAt: null,
      );
      await _writeMetadata(completed);
      return plan.toResult(alreadyCompleted: false);
    } catch (error) {
      if (activeMetadata != null &&
          activeMetadata.status != IndexedDbMigrationStatus.completed) {
        await _markFailed(activeMetadata, error);
      }
      if (error is RepositoryException) rethrow;
      throw RepositoryException(
        operation: 'activity.migration',
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
        final stored = await transaction.findById(
          IndexedDbStoreNames.migrationMetadata,
          migrationId,
        );
        final existing = stored == null
            ? null
            : IndexedDbMigrationMetadata.fromRecord(stored);
        if (existing?.status == IndexedDbMigrationStatus.completed) {
          return existing!;
        }

        final now = _now().toUtc();
        final activeLease = existing?.leaseExpiresAt;
        if (activeLease != null &&
            activeLease.isAfter(now) &&
            existing?.ownerId != _ownerId) {
          throw RepositoryException(
            operation: 'activity.migration.acquireLease',
            code: RepositoryErrorCode.migrationFailed,
            cause: StateError('ACTIVITY migration lease is already held.'),
          );
        }

        final metadata = IndexedDbMigrationMetadata(
          id: migrationId,
          status: IndexedDbMigrationStatus.validating,
          source: ActivityLegacyReader.sourceSystem,
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
        );
        await transaction.put(
          IndexedDbStoreNames.migrationMetadata,
          metadata.toRecord(),
        );
        return metadata;
      },
    );
  }

  _ActivityMigrationPlan _buildPlan(
    ActivityLegacyReadResult legacy,
    DateTime timestamp,
  ) {
    final grouped = <String, List<ValidLegacyActivityRecord>>{};
    for (final record in legacy.validRecords) {
      final localDate = PersistedActivityRecord.localDateFromDate(
        record.data.date,
      );
      grouped.putIfAbsent(localDate, () => []).add(record);
    }

    final records = <PersistedActivityRecord>[];
    for (final entry in grouped.entries) {
      final ordered = List<ValidLegacyActivityRecord>.from(entry.value)
        ..sort((first, second) {
          final byUpdatedAt = first.data.updatedAt.compareTo(
            second.data.updatedAt,
          );
          return byUpdatedAt != 0
              ? byUpdatedAt
              : first.sourceIndex.compareTo(second.sourceIndex);
        });
      final canonical = ordered.last;
      var revisionSequence = 1;
      for (final legacyRecord in ordered) {
        final isCanonical = identical(legacyRecord, canonical);
        records.add(
          PersistedActivityRecord(
            id: isCanonical
                ? PersistedActivityRecord.canonicalId(entry.key)
                : PersistedActivityRecord.legacyRevisionId(
                    entry.key,
                    revisionSequence++,
                  ),
            localDate: entry.key,
            createdAt: legacyRecord.data.createdAt.toUtc(),
            updatedAt: legacyRecord.data.updatedAt.toUtc(),
            canonicalDate: isCanonical ? entry.key : null,
            recordKind: isCanonical
                ? ActivityRecordKind.canonical
                : ActivityRecordKind.legacyRevision,
            migrationSource: ActivityMigrationSource(
              migrationId: migrationId,
              sourceSystem: ActivityLegacyReader.sourceSystem,
              sourceKey: ActivityLegacyReader.sourceKey,
              sourceIndex: legacyRecord.sourceIndex,
            ),
            data: legacyRecord.data,
          ),
        );
      }
    }

    final quarantine = [
      for (final invalid in legacy.invalidRecords)
        IndexedDbQuarantinedRecord(
          id:
              'quarantine:activity:'
              '${invalid.sourceIndex.toString().padLeft(8, '0')}',
          migrationId: migrationId,
          sourceSystem: ActivityLegacyReader.sourceSystem,
          sourceKey: ActivityLegacyReader.sourceKey,
          sourceSection: ActivityLegacyReader.sourceKey,
          sourceIndex: invalid.sourceIndex,
          rawPayload: invalid.rawPayload,
          errorCode: invalid.errorCode,
          errorMessage: invalid.errorMessage,
          quarantinedAt: timestamp,
        ),
    ];
    return _ActivityMigrationPlan(
      sourceCount: legacy.sourceCount,
      validCount: legacy.validRecords.length,
      invalidCount: legacy.invalidRecords.length,
      activityRecords: records,
      quarantinedRecords: quarantine,
    );
  }

  Future<IndexedDbMigrationMetadata> _writePlan(
    _ActivityMigrationPlan plan,
    IndexedDbMigrationMetadata metadata,
    DateTime timestamp,
  ) {
    return _database.runTransaction<IndexedDbMigrationMetadata>(
      storeNames: const [
        IndexedDbStoreNames.activityRecords,
        IndexedDbStoreNames.migrationQuarantine,
        IndexedDbStoreNames.migrationMetadata,
      ],
      mode: IndexedDbTransactionMode.readWrite,
      action: (transaction) async {
        await _removePreviousAttemptRecords(transaction);
        final existing = await transaction.findAll(
          IndexedDbStoreNames.activityRecords,
        );
        final existingIds = {
          for (final value in existing) value['id'] as String?,
        };
        final conflicts = plan.activityIds.where(existingIds.contains);
        if (conflicts.isNotEmpty) {
          throw FormatException(
            'ACTIVITY migration conflicts with existing records: '
            '${conflicts.join(', ')}.',
          );
        }

        for (final record in plan.activityRecords) {
          await transaction.put(
            IndexedDbStoreNames.activityRecords,
            record.toRecord(),
          );
        }
        for (final record in plan.quarantinedRecords) {
          await transaction.put(
            IndexedDbStoreNames.migrationQuarantine,
            record.toRecord(),
          );
        }

        final storedActivityIds = await _migrationActivityIds(transaction);
        final storedQuarantineIds = await _migrationQuarantineIds(transaction);
        if (!_sameSet(storedActivityIds, plan.activityIds) ||
            !_sameSet(storedQuarantineIds, plan.quarantineIds)) {
          throw const FormatException(
            'ACTIVITY migration transaction verification failed.',
          );
        }

        final prepared = metadata.copyWith(
          status: IndexedDbMigrationStatus.prepared,
          updatedAt: timestamp,
        );
        await transaction.put(
          IndexedDbStoreNames.migrationMetadata,
          prepared.toRecord(),
        );
        return prepared;
      },
    );
  }

  Future<void> _removePreviousAttemptRecords(
    IndexedDbTransaction transaction,
  ) async {
    final activities = await transaction.findAll(
      IndexedDbStoreNames.activityRecords,
    );
    for (final value in activities) {
      final record = PersistedActivityRecord.fromRecord(value);
      if (record.migrationSource?.migrationId == migrationId) {
        await transaction.deleteById(
          IndexedDbStoreNames.activityRecords,
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

  Future<Set<String>> _migrationActivityIds(
    IndexedDbTransaction transaction,
  ) async {
    final records = await transaction.findAll(
      IndexedDbStoreNames.activityRecords,
    );
    return {
      for (final value in records)
        if (PersistedActivityRecord.fromRecord(
              value,
            ).migrationSource?.migrationId ==
            migrationId)
          value['id'] as String,
    };
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

  Future<void> _verifyPlan(_ActivityMigrationPlan plan) async {
    final repository = IndexedDbActivityRepository(_database);
    final readResult = await repository.findAllIncludingRevisions();
    if (readResult.hasIssues) {
      throw RepositoryException(
        operation: 'activity.migration.verify',
        code: RepositoryErrorCode.partialCorruption,
        cause: readResult.issues,
      );
    }
    final actual = {
      for (final record in readResult.records)
        if (record.migrationSource?.migrationId == migrationId)
          record.id: record,
    };
    final expected = {
      for (final record in plan.activityRecords) record.id: record,
    };
    if (!_sameSet(actual.keys, expected.keys)) {
      throw const FormatException(
        'ACTIVITY migration IDs differ after commit.',
      );
    }
    for (final entry in expected.entries) {
      final actualRecord = actual[entry.key]!;
      final expectedRecord = entry.value;
      if (actualRecord.localDate != expectedRecord.localDate ||
          actualRecord.recordKind != expectedRecord.recordKind ||
          actualRecord.canonicalDate != expectedRecord.canonicalDate ||
          jsonEncode(actualRecord.data.toJson()) !=
              jsonEncode(expectedRecord.data.toJson())) {
        throw FormatException(
          'ACTIVITY migration data differs after commit: ${entry.key}.',
        );
      }
    }

    final quarantined = await _database.findAll(
      IndexedDbStoreNames.migrationQuarantine,
    );
    final quarantineIds = {
      for (final value in quarantined)
        if (IndexedDbQuarantinedRecord.fromRecord(value).migrationId ==
            migrationId)
          value['id'] as String,
    };
    if (!_sameSet(quarantineIds, plan.quarantineIds)) {
      throw const FormatException(
        'ACTIVITY quarantine IDs differ after commit.',
      );
    }
    if (plan.validCount + plan.invalidCount != plan.sourceCount ||
        actual.length != plan.validCount ||
        quarantineIds.length != plan.invalidCount) {
      throw const FormatException('ACTIVITY migration counts differ.');
    }
  }

  Future<ActivityMigrationResult> _verifyCompleted(
    IndexedDbMigrationMetadata metadata,
  ) async {
    final expectedActivityIds =
        metadata.expectedRecordIds[IndexedDbStoreNames.activityRecords] ??
        const [];
    final expectedQuarantineIds =
        metadata.expectedRecordIds[IndexedDbStoreNames.migrationQuarantine] ??
        const [];
    final repository = IndexedDbActivityRepository(_database);
    final result = await repository.findAllIncludingRevisions();
    if (result.hasIssues) {
      throw RepositoryException(
        operation: 'activity.migration.verifyCompleted',
        code: RepositoryErrorCode.partialCorruption,
        cause: result.issues,
      );
    }
    final activityIds = {
      for (final record in result.records)
        if (record.migrationSource?.migrationId == migrationId) record.id,
    };
    final quarantineValues = await _database.findAll(
      IndexedDbStoreNames.migrationQuarantine,
    );
    final quarantineIds = {
      for (final value in quarantineValues)
        if (IndexedDbQuarantinedRecord.fromRecord(value).migrationId ==
            migrationId)
          value['id'] as String,
    };
    if (!_sameSet(activityIds, expectedActivityIds) ||
        !_sameSet(quarantineIds, expectedQuarantineIds)) {
      throw RepositoryException(
        operation: 'activity.migration.verifyCompleted',
        code: RepositoryErrorCode.verificationFailed,
        cause: const FormatException(
          'Completed ACTIVITY migration no longer matches metadata.',
        ),
      );
    }
    return ActivityMigrationResult(
      alreadyCompleted: true,
      sourceCount: metadata.sourceCounts[ActivityLegacyReader.sourceKey] ?? 0,
      validCount: metadata.validCounts['activity_records'] ?? 0,
      invalidCount:
          metadata.quarantinedCounts[ActivityLegacyReader.sourceKey] ?? 0,
      canonicalCount: metadata.validCounts['canonical'] ?? 0,
      legacyRevisionCount: metadata.validCounts['legacyRevision'] ?? 0,
      activityRecordIds: activityIds,
      quarantineRecordIds: quarantineIds,
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

  static bool _sameSet(Iterable<String> first, Iterable<String> second) {
    final firstSet = first.toSet();
    final secondSet = second.toSet();
    return firstSet.length == secondSet.length &&
        firstSet.containsAll(secondSet);
  }

  static String _digest(Iterable<String> records) {
    var hash = 0x811c9dc5;
    for (final byte in utf8.encode(records.join('\u0000'))) {
      hash ^= byte;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }
}

class _ActivityMigrationPlan {
  final int sourceCount;
  final int validCount;
  final int invalidCount;
  final List<PersistedActivityRecord> activityRecords;
  final List<IndexedDbQuarantinedRecord> quarantinedRecords;

  _ActivityMigrationPlan({
    required this.sourceCount,
    required this.validCount,
    required this.invalidCount,
    required Iterable<PersistedActivityRecord> activityRecords,
    required Iterable<IndexedDbQuarantinedRecord> quarantinedRecords,
  }) : activityRecords = List.unmodifiable(activityRecords),
       quarantinedRecords = List.unmodifiable(quarantinedRecords);

  int get canonicalCount => activityRecords
      .where((record) => record.recordKind == ActivityRecordKind.canonical)
      .length;

  int get legacyRevisionCount => activityRecords
      .where((record) => record.recordKind == ActivityRecordKind.legacyRevision)
      .length;

  Set<String> get activityIds =>
      activityRecords.map((record) => record.id).toSet();

  Set<String> get quarantineIds =>
      quarantinedRecords.map((record) => record.id).toSet();

  ActivityMigrationResult toResult({required bool alreadyCompleted}) {
    return ActivityMigrationResult(
      alreadyCompleted: alreadyCompleted,
      sourceCount: sourceCount,
      validCount: validCount,
      invalidCount: invalidCount,
      canonicalCount: canonicalCount,
      legacyRevisionCount: legacyRevisionCount,
      activityRecordIds: activityIds,
      quarantineRecordIds: quarantineIds,
    );
  }
}
