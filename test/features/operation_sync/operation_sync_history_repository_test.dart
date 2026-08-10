import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/data/indexed_db/indexed_db_store_names.dart';
import 'package:or_app/features/operation_sync/models/operation_sync_history.dart';
import 'package:or_app/features/operation_sync/models/operation_sync_issue.dart'
    hide OperationSyncRecordDisposition;
import 'package:or_app/features/operation_sync/repository/indexed_db_operation_sync_history_repository.dart';

import '../../repositories/indexed_db/fake_indexed_db_database.dart';

void main() {
  late FakeIndexedDbDatabase database;
  late IndexedDbOperationSyncHistoryRepository repository;

  setUp(() {
    database = FakeIndexedDbDatabase();
    repository = IndexedDbOperationSyncHistoryRepository(database);
  });

  test('creates immutable history with read-back verification', () async {
    final history = _history('operation-1');
    final created = await repository.create(history);
    expect(created.operationId, history.operationId);
    expect(
      (await repository.readById(history.operationId))?.result,
      OperationSyncHistoryResult.success,
    );
  });

  test('same operation and content is no-op', () async {
    final history = _history('operation-1');
    await repository.create(history);
    await repository.create(history);
    expect(await repository.list(), hasLength(1));
  });

  test('same operation and different content is conflict', () async {
    await repository.create(_history('operation-1'));
    await expectLater(
      repository.create(_history('operation-1', createCount: 2)),
      throwsA(
        isA<OperationSyncException>().having(
          (error) => error.code,
          'code',
          OperationSyncIssueCode.operationStateConflict,
        ),
      ),
    );
  });

  test('lists newest history first and stores no raw payload', () async {
    await repository.create(_history('operation-1'));
    await repository.create(
      _history('operation-2', completedAt: DateTime.utc(2026, 8, 2, 13)),
    );
    expect((await repository.list()).first.operationId, 'operation-2');
    final raw = database.rawRecord(
      IndexedDbStoreNames.operationSyncHistory,
      'operation-1',
    )!;
    expect(raw, isNot(contains('rawPackage')));
    expect(raw, isNot(contains('payload')));
  });

  test('historical V2 reads legacy fields and records REPLACED distinctly', () {
    final current = _historicalRecord(replacedCount: 1);
    final restored = OperationSyncRecord.fromRecord(current.toRecord());
    expect(restored.recordVersion, 2);
    expect(restored.replacedCount, 1);
    expect(
      restored.records.single.disposition,
      OperationSyncRecordDisposition.replaced,
    );

    final legacy = current.toRecord()..remove('replacedCount');
    final legacyRestored = OperationSyncRecord.fromRecord(legacy);
    expect(legacyRestored.recordVersion, 2);
    expect(legacyRestored.replacedCount, 0);
  });
}

OperationSyncRecord _historicalRecord({required int replacedCount}) =>
    OperationSyncRecord(
      operationId: 'historical:test',
      workflowKind: 'historicalDns',
      recordType: 'dailyAggregateV1',
      sourceMode: 'dateRange',
      startDate: '2026-08-08',
      endDate: '2026-08-08',
      receivedCount: 1,
      newCount: 0,
      identicalCount: 0,
      replacedCount: replacedCount,
      conflictCount: 0,
      invalidCount: 0,
      excludedCount: 0,
      blockedCount: 0,
      appliedCount: 1,
      skippedCount: 0,
      exchangeId: 'historical-response',
      responseDigest: 'a' * 64,
      packageDigest: 'b' * 64,
      result: OperationSyncRecordResult.success,
      failureCode: null,
      createdAt: DateTime.utc(2026, 8, 9, 10),
      completedAt: DateTime.utc(2026, 8, 9, 11),
      records: [
        OperationSyncRecordItem(
          sourceRecordId: null,
          operationDate: '2026-08-08',
          sourceDigest: 'c' * 64,
          targetRecordId: '2026-08-08',
          disposition: OperationSyncRecordDisposition.replaced,
          result: OperationSyncRecordResult.success,
          errorCode: null,
        ),
      ],
    );

OperationSyncHistory _history(
  String operationId, {
  int createCount = 1,
  DateTime? completedAt,
}) {
  return OperationSyncHistory(
    operationId: operationId,
    packageId: '11111111-1111-4111-8111-111111111111',
    packageDigest: 'a' * 64,
    sourceType: 'currentAppTransfer',
    transferMode: 'fullTransfer',
    startedAt: DateTime.utc(2026, 8, 2, 10),
    completedAt: completedAt ?? DateTime.utc(2026, 8, 2, 12),
    moduleIds: const ['fixture'],
    recordCount: 1,
    createCount: createCount,
    noChangeCount: 0,
    conflictCount: 0,
    quarantineCount: 0,
    result: OperationSyncHistoryResult.success,
    isRecoveryExecution: false,
  );
}
