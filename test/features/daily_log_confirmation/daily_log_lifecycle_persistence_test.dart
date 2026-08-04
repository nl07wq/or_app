import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/services/daily_log_mutation_guard.dart';
import 'package:or_app/core/state/app_initialization_state.dart';
import 'package:or_app/data/indexed_db/indexed_db_database_contract.dart';
import 'package:or_app/data/indexed_db/indexed_db_store_names.dart';
import 'package:or_app/features/daily_log_confirmation/models/daily_log_confirmation_lifecycle.dart';
import 'package:or_app/features/daily_log_confirmation/models/persisted_daily_log_confirmation_record.dart';
import 'package:or_app/features/daily_log_confirmation/repository/indexed_db_daily_log_confirmation_repository.dart';
import 'package:or_app/features/daily_log_confirmation/services/daily_log_confirmation_lifecycle_error.dart';
import 'package:or_app/features/daily_log_confirmation/services/daily_log_confirmation_source_snapshot.dart';
import 'package:or_app/features/daily_log_confirmation/services/daily_log_refinalize_transaction.dart';
import 'package:or_app/features/daily_log_confirmation/services/daily_log_reopen_service.dart';
import 'package:or_app/features/daily_log_confirmation/services/daily_log_reopen_transaction.dart';
import 'package:or_app/features/daily_log_confirmation/services/daily_refinalize_coordinator.dart';
import 'package:or_app/features/import_export/services/backup_canonical_codec.dart';
import 'package:or_app/features/operation_date/models/operation_local_date.dart';
import 'package:or_app/features/operation_date/models/operation_state.dart';
import 'package:or_app/features/repositories/app_repository_container.dart';

import '../../repositories/indexed_db/fake_indexed_db_database.dart';
import 'daily_log_confirmation_test_fixture.dart';

const _localDate = '2026-07-26';
const _recordId = 'confirmation:2026-07-26';
final _createdAt = DateTime.utc(2026, 7, 26, 22, 30);
final _reopenedAt = DateTime.utc(2026, 7, 27, 9);
final _refinalizedAt = DateTime.utc(2026, 7, 27, 10);

void main() {
  tearDown(AppRepositoryRegistry.resetForTesting);

  test(
    'Mutation Guard maps missing, v1, finalized v2, and reopened v2',
    () async {
      final database = FakeIndexedDbDatabase();
      final controller = AppInitializationController()..markReady();
      AppRepositoryRegistry.beginStartup(controller: controller);
      AppRepositoryRegistry.install(AppRepositoryContainer.indexedDb(database));

      expect(
        await DailyLogMutationGuard.isDateLocked(DateTime(2026, 7, 26)),
        isFalse,
      );
      await DailyLogMutationGuard.assertDateEditable(DateTime(2026, 7, 26));

      final v1 = _legacyRecord();
      database.seed(
        IndexedDbStoreNames.dailyLogConfirmations,
        _recordId,
        v1.toRecord(),
      );
      expect(
        await DailyLogMutationGuard.isDateLocked(DateTime(2026, 7, 26)),
        isTrue,
      );
      await expectLater(
        DailyLogMutationGuard.assertDateEditable(DateTime(2026, 7, 26)),
        throwsA(isA<ConfirmedDailyLogException>()),
      );

      final finalized = _finalizedV2();
      database.seed(
        IndexedDbStoreNames.dailyLogConfirmations,
        _recordId,
        finalized.toRecord(),
      );
      expect(
        await DailyLogMutationGuard.isDateLocked(DateTime(2026, 7, 26)),
        isTrue,
      );

      final reopened = PersistedDailyLogConfirmationRecord.reopenedFrom(
        existing: finalized,
        reopenedAt: _reopenedAt,
      );
      database.seed(
        IndexedDbStoreNames.dailyLogConfirmations,
        _recordId,
        reopened.toRecord(),
      );
      expect(
        await DailyLogMutationGuard.isDateLocked(DateTime(2026, 7, 26)),
        isFalse,
      );
      await DailyLogMutationGuard.assertDateEditable(DateTime(2026, 7, 26));

      database.seed(IndexedDbStoreNames.dailyLogConfirmations, _recordId, {
        ...finalized.toRecord(),
        'recordVersion': 99,
      });
      await expectLater(
        DailyLogMutationGuard.assertDateEditable(DateTime(2026, 7, 26)),
        throwsA(isA<DailyLogIntegrityException>()),
      );
    },
  );

  test(
    'v1 Reopen preserves Snapshot, digest, revision, and migrationSource',
    () {
      const source = DailyLogConfirmationMigrationSource(
        migrationId: 'migration-original',
        sourceSystem: 'legacy-shared-preferences',
        sourceKey: 'daily-log:2026-07-26',
        sourceIndex: 7,
      );
      final existing = _legacyRecord(migrationSource: source);
      final reopened = PersistedDailyLogConfirmationRecord.reopenedFrom(
        existing: existing,
        reopenedAt: _reopenedAt,
      );

      expect(reopened.recordVersion, 2);
      expect(
        reopened.lifecycleStatus,
        DailyLogConfirmationLifecycleStatus.reopened,
      );
      expect(reopened.revision, 1);
      expect(reopened.data.toJson(), existing.data.toJson());
      expect(reopened.snapshotDigest, existing.projectedSnapshotDigest);
      expect(
        reopened.originalSnapshotDigest,
        existing.projectedOriginalSnapshotDigest,
      );
      expect(reopened.finalizedAt, existing.data.confirmedAt.toUtc());
      expect(reopened.reopenedAt, _reopenedAt);
      expect(
        reopened.reopenReason,
        DailyLogConfirmationReopenReason.userCorrection,
      );
      expect(reopened.previousRevisions, isEmpty);
      expect(reopened.migrationSource?.toJson(), source.toJson());
      expect(reopened.snapshotDigest, matches(RegExp(r'^[0-9a-f]{8}$')));

      final withoutSource = PersistedDailyLogConfirmationRecord.reopenedFrom(
        existing: _legacyRecord(),
        reopenedAt: _reopenedAt,
      );
      expect(withoutSource.migrationSource, isNull);
      expect(withoutSource.toRecord()['migrationSource'], isNull);
    },
  );

  test(
    'v2 Reopen and Re-finalize preserve lineage and append one revision',
    () {
      final finalized = _finalizedV2();
      final reopened = PersistedDailyLogConfirmationRecord.reopenedFrom(
        existing: finalized,
        reopenedAt: _reopenedAt,
      );
      expect(reopened.revision, finalized.revision);
      expect(reopened.data.toJson(), finalized.data.toJson());
      expect(reopened.snapshotDigest, finalized.snapshotDigest);
      expect(reopened.originalSnapshotDigest, finalized.originalSnapshotDigest);
      expect(reopened.previousRevisions, finalized.previousRevisions);
      expect(
        reopened.migrationSource?.toJson(),
        finalized.migrationSource?.toJson(),
      );

      final updatedSnapshot = completeConfirmation(trainingName: 'Revision 2');
      final refinalized = PersistedDailyLogConfirmationRecord.refinalizedFrom(
        existing: reopened,
        data: updatedSnapshot,
        sourceRecordVersions: _sourceSnapshot().sourceRecordVersions,
        refinalizedAt: _refinalizedAt,
      );
      expect(
        refinalized.lifecycleStatus,
        DailyLogConfirmationLifecycleStatus.finalized,
      );
      expect(refinalized.revision, 2);
      expect(
        refinalized.snapshotDigest,
        PersistedDailyLogConfirmationRecord.digestSnapshot(updatedSnapshot),
      );
      expect(
        refinalized.originalSnapshotDigest,
        finalized.originalSnapshotDigest,
      );
      expect(refinalized.lastRefinalizedAt, _refinalizedAt);
      expect(refinalized.reopenedAt, isNull);
      expect(refinalized.reopenReason, isNull);
      expect(refinalized.previousRevisions.map((item) => item.revision), [1]);
      expect(
        refinalized.previousRevisions.single.snapshotDigest,
        finalized.snapshotDigest,
      );
      expect(refinalized.previousRevisions.single.reopenedAt, _reopenedAt);
    },
  );

  test(
    'Reopen transaction preserves operation state, other dates, DD, and DNS',
    () async {
      final database = FakeIndexedDbDatabase();
      final operationState = _seedBase(database, confirmation: _legacyRecord());
      final otherBefore = _seedProtectedRecords(database);
      final transaction = _reopenTransaction(database);

      final result = await transaction.reopen(
        localDate: _localDate,
        reopenedAt: _reopenedAt,
      );

      expect(
        result.lifecycleStatus,
        DailyLogConfirmationLifecycleStatus.reopened,
      );
      expect(result.data.toJson(), _legacyRecord().data.toJson());
      expect(
        database.rawRecord(
          IndexedDbStoreNames.operationState,
          OperationState.canonicalId,
        ),
        operationState,
      );
      _expectProtectedRecords(database, otherBefore);
    },
  );

  test(
    'Reopen returns formal rejection codes without partial updates',
    () async {
      Future<void> expectCode(
        FakeIndexedDbDatabase database,
        DailyLogConfirmationLifecycleErrorCode code,
      ) async {
        final before = database.rawRecord(
          IndexedDbStoreNames.dailyLogConfirmations,
          _recordId,
        );
        await expectLater(
          _reopenTransaction(
            database,
          ).reopen(localDate: _localDate, reopenedAt: _reopenedAt),
          throwsA(
            isA<DailyLogConfirmationLifecycleException>().having(
              (error) => error.code,
              'code',
              code,
            ),
          ),
        );
        expect(
          database.rawRecord(
            IndexedDbStoreNames.dailyLogConfirmations,
            _recordId,
          ),
          before,
        );
      }

      final missing = FakeIndexedDbDatabase();
      _seedOperationState(missing);
      await expectCode(
        missing,
        DailyLogConfirmationLifecycleErrorCode.reopenConfirmationMissing,
      );

      final already = FakeIndexedDbDatabase();
      _seedBase(
        already,
        confirmation: PersistedDailyLogConfirmationRecord.reopenedFrom(
          existing: _finalizedV2(),
          reopenedAt: _reopenedAt,
        ),
      );
      await expectCode(
        already,
        DailyLogConfirmationLifecycleErrorCode.reopenAlreadyReopened,
      );

      final future = FakeIndexedDbDatabase();
      _seedBase(future, confirmation: _finalizedV2());
      _seedOperationState(future, localDate: '2026-07-25');
      await expectCode(
        future,
        DailyLogConfirmationLifecycleErrorCode.reopenFutureDate,
      );

      final invalidSnapshot = FakeIndexedDbDatabase();
      _seedBase(invalidSnapshot, confirmation: _finalizedV2());
      invalidSnapshot.seed(
        IndexedDbStoreNames.dailyLogConfirmations,
        _recordId,
        {..._finalizedV2().toRecord(), 'snapshotDigest': '00000000'},
      );
      await expectCode(
        invalidSnapshot,
        DailyLogConfirmationLifecycleErrorCode.reopenSnapshotInvalid,
      );

      final invalidState = FakeIndexedDbDatabase();
      invalidState.seed(
        IndexedDbStoreNames.dailyLogConfirmations,
        _recordId,
        _finalizedV2().toRecord(),
      );
      await expectCode(
        invalidState,
        DailyLogConfirmationLifecycleErrorCode.reopenOperationStateInvalid,
      );
    },
  );

  test(
    'Reopen rolls back PUT, read-back, and operation-state verification failures',
    () async {
      for (final database in <FakeIndexedDbDatabase>[
        FakeIndexedDbDatabase()
          ..failNextPutForStore = IndexedDbStoreNames.dailyLogConfirmations,
        FakeIndexedDbDatabase()
          ..failNextReadAfterPutForStore =
              IndexedDbStoreNames.dailyLogConfirmations,
        _ChangingOperationStateDatabase(),
      ]) {
        _seedBase(database, confirmation: _finalizedV2());
        final before = database.rawRecord(
          IndexedDbStoreNames.dailyLogConfirmations,
          _recordId,
        );
        await expectLater(
          _reopenTransaction(
            database,
          ).reopen(localDate: _localDate, reopenedAt: _reopenedAt),
          throwsA(isA<DailyLogConfirmationLifecycleException>()),
        );
        expect(
          database.rawRecord(
            IndexedDbStoreNames.dailyLogConfirmations,
            _recordId,
          ),
          before,
        );
      }
    },
  );

  test(
    'Reopen service rejects concurrent execution for the same date',
    () async {
      final database = _DelayedTransactionDatabase();
      _seedBase(database, confirmation: _finalizedV2());
      final service = DailyLogReopenService(
        _reopenTransaction(database),
        now: () => _reopenedAt,
      );

      final first = service.reopen(_localDate);
      await database.transactionStarted.future;
      await expectLater(
        service.reopen(_localDate),
        throwsA(
          isA<DailyLogConfirmationLifecycleException>().having(
            (error) => error.stage,
            'stage',
            'executionGuard',
          ),
        ),
      );
      database.releaseTransaction.complete();
      expect(
        (await first).lifecycleStatus,
        DailyLogConfirmationLifecycleStatus.reopened,
      );
    },
  );

  test(
    'Re-finalize atomically updates revision and preserves unrelated records',
    () async {
      final database = FakeIndexedDbDatabase();
      final reopened = PersistedDailyLogConfirmationRecord.reopenedFrom(
        existing: _finalizedV2(),
        reopenedAt: _reopenedAt,
      );
      final operationState = _seedBase(database, confirmation: reopened);
      final protectedBefore = _seedProtectedRecords(database);
      final sourceSnapshot = _sourceSnapshot();
      final sourceReader = _ScriptedSourceReader(database, sourceSnapshot);
      final transaction = DailyLogRefinalizeTransaction(
        database,
        IndexedDbDailyLogConfirmationRepository(database),
        sourceReader,
      );

      final updated = completeConfirmation(trainingName: 'Revision 2');
      final result = await transaction.refinalize(
        localDate: _localDate,
        snapshot: updated,
        expectedSources: sourceSnapshot,
        refinalizedAt: _refinalizedAt,
      );

      expect(result.revision, 2);
      expect(
        result.lifecycleStatus,
        DailyLogConfirmationLifecycleStatus.finalized,
      );
      expect(
        result.snapshotDigest,
        PersistedDailyLogConfirmationRecord.digestSnapshot(updated),
      );
      expect(result.originalSnapshotDigest, reopened.originalSnapshotDigest);
      expect(result.previousRevisions.map((item) => item.revision), [1]);
      expect(
        result.previousRevisions.single.snapshotDigest,
        reopened.snapshotDigest,
      );
      expect(
        database.rawRecord(
          IndexedDbStoreNames.operationState,
          OperationState.canonicalId,
        ),
        operationState,
      );
      _expectProtectedRecords(database, protectedBefore);
    },
  );

  test(
    'Re-finalize source change and write/read-back failures roll back completely',
    () async {
      final source = _sourceSnapshot();
      final changedSource = _sourceSnapshot(changedRecordId: 'status:changed');

      final sourceChanged = FakeIndexedDbDatabase();
      final reopened = PersistedDailyLogConfirmationRecord.reopenedFrom(
        existing: _finalizedV2(),
        reopenedAt: _reopenedAt,
      );
      _seedBase(sourceChanged, confirmation: reopened);
      final changedReader = _ScriptedSourceReader(
        sourceChanged,
        source,
        transactionResults: [source, changedSource],
      );
      await _expectRefinalizeRollback(sourceChanged, changedReader, source);

      for (final database in <FakeIndexedDbDatabase>[
        FakeIndexedDbDatabase()
          ..failNextPutForStore = IndexedDbStoreNames.dailyLogConfirmations,
        FakeIndexedDbDatabase()
          ..failNextReadAfterPutForStore =
              IndexedDbStoreNames.dailyLogConfirmations,
      ]) {
        _seedBase(database, confirmation: reopened);
        await _expectRefinalizeRollback(
          database,
          _ScriptedSourceReader(database, source),
          source,
        );
      }
    },
  );

  test(
    'Coordinator detects source changes and Snapshot failure before saving',
    () async {
      final source = _sourceSnapshot();
      final changed = _sourceSnapshot(changedRecordId: 'food:changed');
      final database = FakeIndexedDbDatabase();
      final reopened = PersistedDailyLogConfirmationRecord.reopenedFrom(
        existing: _finalizedV2(),
        reopenedAt: _reopenedAt,
      );
      _seedBase(database, confirmation: reopened);
      final repository = IndexedDbDailyLogConfirmationRepository(database);

      final changingReader = _ScriptedSourceReader(
        database,
        source,
        readResults: [source, changed],
      );
      final changingCoordinator = DailyRefinalizeCoordinator(
        repository,
        changingReader,
        DailyLogRefinalizeTransaction(database, repository, changingReader),
        buildDailyConfirmation: (_, _, _) async => completeConfirmation(),
        now: () => _refinalizedAt,
      );
      await expectLater(
        changingCoordinator.refinalize(
          targetLocalDate: OperationLocalDate.parse(_localDate),
        ),
        throwsA(
          isA<DailyLogConfirmationLifecycleException>().having(
            (error) => error.code,
            'code',
            DailyLogConfirmationLifecycleErrorCode.refinalizeSourceChanged,
          ),
        ),
      );
      expect(
        database.rawRecord(
          IndexedDbStoreNames.dailyLogConfirmations,
          _recordId,
        ),
        reopened.toRecord(),
      );

      final failingReader = _ScriptedSourceReader(database, source);
      final failingCoordinator = DailyRefinalizeCoordinator(
        repository,
        failingReader,
        DailyLogRefinalizeTransaction(database, repository, failingReader),
        buildDailyConfirmation: (_, _, _) =>
            throw StateError('snapshot failed'),
        now: () => _refinalizedAt,
      );
      await expectLater(
        failingCoordinator.refinalize(
          targetLocalDate: OperationLocalDate.parse(_localDate),
        ),
        throwsA(
          isA<DailyLogConfirmationLifecycleException>().having(
            (error) => error.code,
            'code',
            DailyLogConfirmationLifecycleErrorCode.refinalizeSnapshotFailed,
          ),
        ),
      );
      expect(
        database.rawRecord(
          IndexedDbStoreNames.dailyLogConfirmations,
          _recordId,
        ),
        reopened.toRecord(),
      );
    },
  );
}

PersistedDailyLogConfirmationRecord _legacyRecord({
  DailyLogConfirmationMigrationSource? migrationSource,
}) => PersistedDailyLogConfirmationRecord(
  id: _recordId,
  localDate: _localDate,
  createdAt: _createdAt,
  updatedAt: _createdAt,
  data: completeConfirmation(),
  migrationSource: migrationSource,
);

PersistedDailyLogConfirmationRecord _finalizedV2() =>
    PersistedDailyLogConfirmationRecord.initialFinalizedV2(
      id: _recordId,
      localDate: _localDate,
      data: completeConfirmation(),
      timestamp: _createdAt,
      migrationSource: const DailyLogConfirmationMigrationSource(
        migrationId: 'migration-original',
        sourceSystem: 'legacy-shared-preferences',
        sourceKey: 'daily-log:2026-07-26',
        sourceIndex: 7,
      ),
    );

Map<String, Object?> _seedOperationState(
  FakeIndexedDbDatabase database, {
  String localDate = '2026-07-27',
}) {
  final previousDate = DateTime.parse(
    localDate,
  ).subtract(const Duration(days: 1));
  final state = OperationState(
    operationDate: OperationLocalDate.parse(localDate),
    lastFinalizedDate: OperationLocalDate.fromDateTime(previousDate),
    createdAt: DateTime.utc(2026, 7, 27),
    updatedAt: DateTime.utc(2026, 7, 27),
  ).toRecord();
  database.seed(
    IndexedDbStoreNames.operationState,
    OperationState.canonicalId,
    state,
  );
  return state;
}

Map<String, Object?> _seedBase(
  FakeIndexedDbDatabase database, {
  required PersistedDailyLogConfirmationRecord confirmation,
}) {
  database.seed(
    IndexedDbStoreNames.dailyLogConfirmations,
    confirmation.id,
    confirmation.toRecord(),
  );
  return _seedOperationState(database);
}

Map<String, Map<String, Object?>> _seedProtectedRecords(
  FakeIndexedDbDatabase database,
) {
  final records = <String, Map<String, Object?>>{
    IndexedDbStoreNames.dailyLogConfirmations: {
      'id': 'confirmation:2026-07-25',
      'recordVersion': 1,
      'marker': 'other-confirmation',
    },
    IndexedDbStoreNames.dailyDebriefRecords: {
      'id': '2026-07-26',
      'marker': 'daily-debrief',
    },
    IndexedDbStoreNames.legacyDailySummaryRecords: {
      'id': 'legacy:2026-07-26',
      'marker': 'legacy-dns',
    },
    IndexedDbStoreNames.statusRecords: {
      'id': 'status:2026-07-26',
      'marker': 'status',
    },
    IndexedDbStoreNames.foodRecords: {
      'id': 'food:2026-07-26',
      'marker': 'food',
    },
    IndexedDbStoreNames.activityRecords: {
      'id': 'activity:2026-07-26',
      'marker': 'activity',
    },
    IndexedDbStoreNames.trainingRecords: {
      'id': 'training:2026-07-26',
      'marker': 'training',
    },
  };
  for (final entry in records.entries) {
    database.seed(entry.key, entry.value['id']! as String, entry.value);
  }
  return records;
}

void _expectProtectedRecords(
  FakeIndexedDbDatabase database,
  Map<String, Map<String, Object?>> records,
) {
  for (final entry in records.entries) {
    expect(
      database.rawRecord(entry.key, entry.value['id']! as String),
      entry.value,
    );
  }
}

DailyLogReopenTransaction _reopenTransaction(FakeIndexedDbDatabase database) =>
    DailyLogReopenTransaction(
      database,
      IndexedDbDailyLogConfirmationRepository(database),
    );

DailyLogConfirmationSourceSnapshot _sourceSnapshot({
  String changedRecordId = 'status:2026-07-26',
}) => DailyLogConfirmationSourceSnapshot(
  localDate: _localDate,
  records: [
    DailyLogConfirmationSourceIdentity(
      store: IndexedDbStoreNames.statusRecords,
      recordId: changedRecordId,
      recordVersion: 1,
      localDate: _localDate,
      canonicalDigest: BackupCanonicalCodec.digest({'status': changedRecordId}),
    ),
    DailyLogConfirmationSourceIdentity(
      store: IndexedDbStoreNames.foodRecords,
      recordId: 'food:2026-07-26',
      recordVersion: 1,
      localDate: _localDate,
      canonicalDigest: BackupCanonicalCodec.digest({'food': 1}),
    ),
    DailyLogConfirmationSourceIdentity(
      store: IndexedDbStoreNames.activityRecords,
      recordId: 'activity:2026-07-26',
      recordVersion: 1,
      localDate: _localDate,
      canonicalDigest: BackupCanonicalCodec.digest({'activity': 1}),
    ),
    DailyLogConfirmationSourceIdentity(
      store: IndexedDbStoreNames.trainingRecords,
      recordId: 'training:2026-07-26',
      recordVersion: 2,
      localDate: _localDate,
      canonicalDigest: BackupCanonicalCodec.digest({'training': 2}),
    ),
  ],
);

Future<void> _expectRefinalizeRollback(
  FakeIndexedDbDatabase database,
  DailyLogConfirmationSourceSnapshotReader sourceReader,
  DailyLogConfirmationSourceSnapshot expectedSources,
) async {
  final before = database.rawRecord(
    IndexedDbStoreNames.dailyLogConfirmations,
    _recordId,
  );
  final transaction = DailyLogRefinalizeTransaction(
    database,
    IndexedDbDailyLogConfirmationRepository(database),
    sourceReader,
  );
  await expectLater(
    transaction.refinalize(
      localDate: _localDate,
      snapshot: completeConfirmation(trainingName: 'Revision 2'),
      expectedSources: expectedSources,
      refinalizedAt: _refinalizedAt,
    ),
    throwsA(isA<DailyLogConfirmationLifecycleException>()),
  );
  expect(
    database.rawRecord(IndexedDbStoreNames.dailyLogConfirmations, _recordId),
    before,
  );
}

class _ScriptedSourceReader extends DailyLogConfirmationSourceSnapshotReader {
  final DailyLogConfirmationSourceSnapshot fallback;
  final List<DailyLogConfirmationSourceSnapshot> readResults;
  final List<DailyLogConfirmationSourceSnapshot> transactionResults;
  int _readIndex = 0;
  int _transactionIndex = 0;

  _ScriptedSourceReader(
    super.database,
    this.fallback, {
    this.readResults = const [],
    this.transactionResults = const [],
  });

  @override
  Future<DailyLogConfirmationSourceSnapshot> read(String localDate) async =>
      _readIndex < readResults.length ? readResults[_readIndex++] : fallback;

  @override
  Future<DailyLogConfirmationSourceSnapshot> readInTransaction(
    IndexedDbTransaction transaction,
    String localDate,
  ) async => _transactionIndex < transactionResults.length
      ? transactionResults[_transactionIndex++]
      : fallback;
}

class _ChangingOperationStateDatabase extends FakeIndexedDbDatabase {
  int _operationStateReads = 0;

  @override
  Future<List<Map<String, Object?>>> findAll(String storeName) async {
    final records = await super.findAll(storeName);
    if (storeName == IndexedDbStoreNames.operationState &&
        ++_operationStateReads == 2) {
      return [
        {
          ...records.single,
          'revision': (records.single['revision']! as int) + 1,
        },
      ];
    }
    return records;
  }
}

class _DelayedTransactionDatabase extends FakeIndexedDbDatabase {
  final transactionStarted = Completer<void>();
  final releaseTransaction = Completer<void>();

  @override
  Future<T> runTransaction<T>({
    required Iterable<String> storeNames,
    required IndexedDbTransactionMode mode,
    required Future<T> Function(IndexedDbTransaction transaction) action,
  }) async {
    transactionStarted.complete();
    await releaseTransaction.future;
    return super.runTransaction(
      storeNames: storeNames,
      mode: mode,
      action: action,
    );
  }
}
