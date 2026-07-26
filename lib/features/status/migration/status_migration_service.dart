import 'dart:convert';

import '../../../data/indexed_db/indexed_db_database_contract.dart';
import '../../../data/indexed_db/indexed_db_migration_metadata.dart';
import '../../../data/indexed_db/indexed_db_quarantined_record.dart';
import '../../../data/indexed_db/indexed_db_schema.dart';
import '../../../data/indexed_db/indexed_db_store_names.dart';
import '../../repositories/repository_exception.dart';
import '../models/persisted_status_record.dart';
import '../repositories/indexed_db_status_repository.dart';
import 'status_legacy_reader.dart';

class StatusMigrationResult {
  final bool alreadyCompleted;
  final int sourceCount;
  final int validCount;
  final int invalidCount;
  final int canonicalCount;
  final int legacyRevisionCount;
  final Set<String> statusRecordIds;
  final Set<String> quarantineRecordIds;

  StatusMigrationResult({
    required this.alreadyCompleted,
    required this.sourceCount,
    required this.validCount,
    required this.invalidCount,
    required this.canonicalCount,
    required this.legacyRevisionCount,
    required Iterable<String> statusRecordIds,
    required Iterable<String> quarantineRecordIds,
  }) : statusRecordIds = Set.unmodifiable(statusRecordIds),
       quarantineRecordIds = Set.unmodifiable(quarantineRecordIds);
}

class StatusMigrationService {
  static const migrationId = 'shared_preferences_status_v1_to_indexeddb_v2';
  static const _leaseDuration = Duration(minutes: 5);

  final IndexedDbDatabase _database;
  final StatusLegacyReader _legacyReader;
  final DateTime Function() _now;
  final String _ownerId;

  StatusMigrationService(
    this._database, {
    StatusLegacyReader? legacyReader,
    DateTime Function()? now,
    String? ownerId,
  }) : _legacyReader = legacyReader ?? StatusLegacyReader(),
       _now = now ?? DateTime.now,
       _ownerId =
           ownerId ??
           'status-migration-${DateTime.now().microsecondsSinceEpoch}';

  Future<StatusMigrationResult> migrate() async {
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
          'STATUS Legacy valid and invalid counts do not match source.',
        );
      }
      final timestamp = _now().toUtc();
      final plan = _buildPlan(legacy, timestamp);
      final writingMetadata = activeMetadata.copyWith(
        status: IndexedDbMigrationStatus.writing,
        updatedAt: timestamp,
        sourceCounts: {StatusLegacyReader.sourceKey: legacy.sourceCount},
        validCounts: {
          'status_records': legacy.validRecords.length,
          'canonical': plan.canonicalCount,
          'legacyRevision': plan.legacyRevisionCount,
        },
        quarantinedCounts: {
          StatusLegacyReader.sourceKey: legacy.invalidRecords.length,
        },
        expectedRecordIds: {
          IndexedDbStoreNames.statusRecords: plan.statusIds.toList()..sort(),
          IndexedDbStoreNames.migrationQuarantine: plan.quarantineIds.toList()
            ..sort(),
        },
        sourceDigest: _digest(legacy.rawRecords),
        errorCode: null,
        errorMessage: null,
      );
      await _writeMetadata(writingMetadata);
      activeMetadata = writingMetadata;

      final preparedMetadata = await _writePlan(
        plan,
        writingMetadata,
        timestamp,
      );
      final verifyingMetadata = preparedMetadata.copyWith(
        status: IndexedDbMigrationStatus.verifying,
        updatedAt: _now().toUtc(),
      );
      await _writeMetadata(verifyingMetadata);
      activeMetadata = verifyingMetadata;
      await _verifyPlan(plan);

      final completedAt = _now().toUtc();
      final completedMetadata = verifyingMetadata.copyWith(
        status: IndexedDbMigrationStatus.completed,
        updatedAt: completedAt,
        completedAt: completedAt,
        ownerId: null,
        leaseExpiresAt: null,
      );
      await _writeMetadata(completedMetadata);
      return plan.toResult(alreadyCompleted: false);
    } catch (error) {
      if (activeMetadata != null &&
          activeMetadata.status != IndexedDbMigrationStatus.completed) {
        await _markFailed(activeMetadata, error);
      }
      if (error is RepositoryException) rethrow;
      throw RepositoryException(
        operation: 'status.migration',
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
            operation: 'status.migration.acquireLease',
            code: RepositoryErrorCode.migrationFailed,
            cause: StateError('STATUS migration lease is already held.'),
          );
        }

        final metadata = IndexedDbMigrationMetadata(
          id: migrationId,
          status: IndexedDbMigrationStatus.validating,
          source: StatusLegacyReader.sourceSystem,
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

  _StatusMigrationPlan _buildPlan(
    StatusLegacyReadResult legacy,
    DateTime timestamp,
  ) {
    final grouped = <String, List<ValidLegacyStatusRecord>>{};
    for (final record in legacy.validRecords) {
      final localDate = PersistedStatusRecord.localDateFromSource(
        record.data.date,
      );
      grouped.putIfAbsent(localDate, () => []).add(record);
    }

    final records = <PersistedStatusRecord>[];
    for (final entry in grouped.entries) {
      final ordered = List<ValidLegacyStatusRecord>.from(entry.value)
        ..sort((first, second) {
          final firstDate = DateTime.parse(first.data.date);
          final secondDate = DateTime.parse(second.data.date);
          final byDate = firstDate.compareTo(secondDate);
          return byDate != 0
              ? byDate
              : first.sourceIndex.compareTo(second.sourceIndex);
        });
      final canonical = ordered.last;
      var revisionSequence = 1;
      for (final legacyRecord in ordered) {
        final isCanonical = identical(legacyRecord, canonical);
        records.add(
          PersistedStatusRecord(
            id: isCanonical
                ? PersistedStatusRecord.canonicalId(entry.key)
                : PersistedStatusRecord.legacyRevisionId(
                    entry.key,
                    revisionSequence++,
                  ),
            localDate: entry.key,
            createdAt: timestamp,
            updatedAt: timestamp,
            canonicalDate: isCanonical ? entry.key : null,
            recordKind: isCanonical
                ? StatusRecordKind.canonical
                : StatusRecordKind.legacyRevision,
            migrationSource: StatusMigrationSource(
              migrationId: migrationId,
              sourceSystem: StatusLegacyReader.sourceSystem,
              sourceKey: StatusLegacyReader.sourceKey,
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
              'quarantine:status:'
              '${invalid.sourceIndex.toString().padLeft(8, '0')}',
          migrationId: migrationId,
          sourceSystem: StatusLegacyReader.sourceSystem,
          sourceKey: StatusLegacyReader.sourceKey,
          sourceSection: StatusLegacyReader.sourceKey,
          sourceIndex: invalid.sourceIndex,
          rawPayload: invalid.rawPayload,
          errorCode: invalid.errorCode,
          errorMessage: invalid.errorMessage,
          quarantinedAt: timestamp,
        ),
    ];
    return _StatusMigrationPlan(
      sourceCount: legacy.sourceCount,
      validCount: legacy.validRecords.length,
      invalidCount: legacy.invalidRecords.length,
      statusRecords: records,
      quarantinedRecords: quarantine,
    );
  }

  Future<IndexedDbMigrationMetadata> _writePlan(
    _StatusMigrationPlan plan,
    IndexedDbMigrationMetadata metadata,
    DateTime timestamp,
  ) {
    return _database.runTransaction<IndexedDbMigrationMetadata>(
      storeNames: const [
        IndexedDbStoreNames.statusRecords,
        IndexedDbStoreNames.migrationQuarantine,
        IndexedDbStoreNames.migrationMetadata,
      ],
      mode: IndexedDbTransactionMode.readWrite,
      action: (transaction) async {
        await _removePreviousAttemptRecords(transaction);
        for (final record in plan.statusRecords) {
          await transaction.put(
            IndexedDbStoreNames.statusRecords,
            record.toRecord(),
          );
        }
        for (final record in plan.quarantinedRecords) {
          await transaction.put(
            IndexedDbStoreNames.migrationQuarantine,
            record.toRecord(),
          );
        }

        final storedStatusIds = await _migrationStatusIds(transaction);
        final storedQuarantineIds = await _migrationQuarantineIds(transaction);
        if (!_sameSet(storedStatusIds, plan.statusIds) ||
            !_sameSet(storedQuarantineIds, plan.quarantineIds)) {
          throw const FormatException(
            'STATUS migration transaction verification failed.',
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
    final status = await transaction.findAll(IndexedDbStoreNames.statusRecords);
    for (final value in status) {
      final record = PersistedStatusRecord.fromRecord(value);
      if (record.migrationSource?.migrationId == migrationId) {
        await transaction.deleteById(
          IndexedDbStoreNames.statusRecords,
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

  Future<Set<String>> _migrationStatusIds(
    IndexedDbTransaction transaction,
  ) async {
    final records = await transaction.findAll(
      IndexedDbStoreNames.statusRecords,
    );
    return {
      for (final value in records)
        if (PersistedStatusRecord.fromRecord(
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

  Future<void> _verifyPlan(_StatusMigrationPlan plan) async {
    final repository = IndexedDbStatusRepository(_database);
    final readResult = await repository.findAllIncludingRevisions();
    if (readResult.hasIssues) {
      throw RepositoryException(
        operation: 'status.migration.verify',
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
      for (final record in plan.statusRecords) record.id: record,
    };
    if (!_sameSet(actual.keys, expected.keys)) {
      throw const FormatException('STATUS migration IDs differ after commit.');
    }
    for (final entry in expected.entries) {
      final actualRecord = actual[entry.key]!;
      final expectedRecord = entry.value;
      if (actualRecord.localDate != expectedRecord.localDate ||
          actualRecord.recordKind != expectedRecord.recordKind ||
          jsonEncode(actualRecord.data.toJson()) !=
              jsonEncode(expectedRecord.data.toJson())) {
        throw FormatException(
          'STATUS migration data differs after commit: ${entry.key}.',
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
      throw const FormatException('STATUS quarantine IDs differ after commit.');
    }
    if (plan.validCount + plan.invalidCount != plan.sourceCount ||
        actual.length != plan.validCount ||
        quarantineIds.length != plan.invalidCount) {
      throw const FormatException('STATUS migration counts differ.');
    }
  }

  Future<StatusMigrationResult> _verifyCompleted(
    IndexedDbMigrationMetadata metadata,
  ) async {
    _validateCompletedMetadata(metadata);
    final expectedStatusIds =
        metadata.expectedRecordIds[IndexedDbStoreNames.statusRecords] ??
        const [];
    final expectedQuarantineIds =
        metadata.expectedRecordIds[IndexedDbStoreNames.migrationQuarantine] ??
        const [];
    final quarantineValues = await _database.findAll(
      IndexedDbStoreNames.migrationQuarantine,
    );
    final quarantineIds = {
      for (final value in quarantineValues)
        if (IndexedDbQuarantinedRecord.fromRecord(value).migrationId ==
            migrationId)
          value['id'] as String,
    };
    if (!_sameSet(quarantineIds, expectedQuarantineIds)) {
      throw _completedVerificationFailure(
        'Completed STATUS migration quarantine no longer matches metadata.',
      );
    }
    return StatusMigrationResult(
      alreadyCompleted: true,
      sourceCount: metadata.sourceCounts[StatusLegacyReader.sourceKey] ?? 0,
      validCount: metadata.validCounts['status_records'] ?? 0,
      invalidCount:
          metadata.quarantinedCounts[StatusLegacyReader.sourceKey] ?? 0,
      canonicalCount: metadata.validCounts['canonical'] ?? 0,
      legacyRevisionCount: metadata.validCounts['legacyRevision'] ?? 0,
      statusRecordIds: expectedStatusIds,
      quarantineRecordIds: quarantineIds,
    );
  }

  static void _validateCompletedMetadata(IndexedDbMigrationMetadata metadata) {
    final expectedStatusIds =
        metadata.expectedRecordIds[IndexedDbStoreNames.statusRecords];
    final expectedQuarantineIds =
        metadata.expectedRecordIds[IndexedDbStoreNames.migrationQuarantine];
    final sourceDigest = metadata.sourceDigest;
    final completedAt = metadata.completedAt;
    final timestampsAreOrdered =
        completedAt != null &&
        !metadata.updatedAt.isBefore(metadata.startedAt) &&
        !completedAt.isBefore(metadata.startedAt) &&
        !completedAt.isAfter(metadata.updatedAt);
    if (metadata.id != migrationId ||
        metadata.source != StatusLegacyReader.sourceSystem ||
        metadata.targetDatabaseVersion != IndexedDbSchema.databaseVersion ||
        metadata.status != IndexedDbMigrationStatus.completed ||
        completedAt == null ||
        metadata.attempt < 1 ||
        !timestampsAreOrdered ||
        sourceDigest == null ||
        !RegExp(r'^[0-9a-f]{8}$').hasMatch(sourceDigest) ||
        expectedStatusIds == null ||
        expectedQuarantineIds == null ||
        !_validExpectedIds(expectedStatusIds, _isStatusRecordId) ||
        !_validExpectedIds(
          expectedQuarantineIds,
          _isStatusQuarantineRecordId,
        )) {
      throw _completedVerificationFailure(
        'Completed STATUS migration metadata is invalid.',
      );
    }
  }

  static bool _validExpectedIds(
    List<String> ids,
    bool Function(String id) validates,
  ) {
    return ids.toSet().length == ids.length && ids.every(validates);
  }

  static bool _isStatusRecordId(String id) {
    final canonical = RegExp(r'^status:(\d{4}-\d{2}-\d{2})$').firstMatch(id);
    if (canonical != null) {
      try {
        PersistedStatusRecord.validateLocalDate(canonical.group(1)!);
        return true;
      } on FormatException {
        return false;
      }
    }
    final revision = RegExp(
      r'^legacy-status:(\d{4}-\d{2}-\d{2}):\d{4}$',
    ).firstMatch(id);
    if (revision == null) return false;
    try {
      PersistedStatusRecord.validateLocalDate(revision.group(1)!);
      return true;
    } on FormatException {
      return false;
    }
  }

  static bool _isStatusQuarantineRecordId(String id) {
    return RegExp(r'^quarantine:status:\d{8,}$').hasMatch(id);
  }

  static RepositoryException _completedVerificationFailure(String message) {
    return RepositoryException(
      operation: 'status.migration.verifyCompleted',
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

class _StatusMigrationPlan {
  final int sourceCount;
  final int validCount;
  final int invalidCount;
  final List<PersistedStatusRecord> statusRecords;
  final List<IndexedDbQuarantinedRecord> quarantinedRecords;

  _StatusMigrationPlan({
    required this.sourceCount,
    required this.validCount,
    required this.invalidCount,
    required Iterable<PersistedStatusRecord> statusRecords,
    required Iterable<IndexedDbQuarantinedRecord> quarantinedRecords,
  }) : statusRecords = List.unmodifiable(statusRecords),
       quarantinedRecords = List.unmodifiable(quarantinedRecords);

  int get canonicalCount => statusRecords
      .where((record) => record.recordKind == StatusRecordKind.canonical)
      .length;

  int get legacyRevisionCount => statusRecords
      .where((record) => record.recordKind == StatusRecordKind.legacyRevision)
      .length;

  Set<String> get statusIds => statusRecords.map((record) => record.id).toSet();

  Set<String> get quarantineIds =>
      quarantinedRecords.map((record) => record.id).toSet();

  StatusMigrationResult toResult({required bool alreadyCompleted}) {
    return StatusMigrationResult(
      alreadyCompleted: alreadyCompleted,
      sourceCount: sourceCount,
      validCount: validCount,
      invalidCount: invalidCount,
      canonicalCount: canonicalCount,
      legacyRevisionCount: legacyRevisionCount,
      statusRecordIds: statusIds,
      quarantineRecordIds: quarantineIds,
    );
  }
}
