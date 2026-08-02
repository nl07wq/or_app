import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/data/indexed_db/indexed_db_store_names.dart';
import 'package:or_app/features/operation_sync/models/operation_sync_history.dart';
import 'package:or_app/features/operation_sync/models/operation_sync_issue.dart';
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
}

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
