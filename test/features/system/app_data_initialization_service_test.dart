import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/data/indexed_db/indexed_db_database_contract.dart';
import 'package:or_app/data/indexed_db/indexed_db_store_names.dart';
import 'package:or_app/features/operation_date/models/operation_state.dart';
import 'package:or_app/features/system/services/app_data_initialization_service.dart';

import '../../repositories/indexed_db/fake_indexed_db_database.dart';

void main() {
  final timestamp = DateTime.utc(2026, 8, 2, 12);

  test(
    'initializes all declared app data in one verified transaction',
    () async {
      final database = FakeIndexedDbDatabase();
      for (final storeName in AppDataInitializationService.storesToClear) {
        database.seed(storeName, 'seed', {'id': 'seed', 'value': storeName});
      }
      database.seed(IndexedDbStoreNames.operationState, 'current', {
        'id': 'current',
        'value': 'old',
      });
      database.seed(IndexedDbStoreNames.operationSyncState, 'current', {
        'id': 'current',
        'value': 'preserved',
      });

      final result = await AppDataInitializationService(
        database,
        clock: () => timestamp,
      ).initialize();

      expect(database.transactionCount, 1);
      expect(
        result.clearedStoreCount,
        AppDataInitializationService.storesToClear.length,
      );
      for (final storeName in AppDataInitializationService.storesToClear) {
        expect(await database.findAll(storeName), isEmpty, reason: storeName);
      }
      final stored = OperationState.fromRecord(
        database.rawRecord(IndexedDbStoreNames.operationState, 'current')!,
      );
      expect(stored.operationDate.value, '2026-08-02');
      expect(stored.phase, OperationPhase.open);
      expect(stored.revision, 0);
      expect(stored.activeAttempt, isNull);
      expect(
        database.rawRecord(IndexedDbStoreNames.operationSyncState, 'current'),
        {'id': 'current', 'value': 'preserved'},
      );
    },
  );

  test('rolls back every cleared store when initialization fails', () async {
    final database = _FailOnOperationStatePutDatabase();
    database.seed(IndexedDbStoreNames.statusRecords, 'status-1', {
      'id': 'status-1',
      'value': 'preserved',
    });
    database.seed(IndexedDbStoreNames.operationState, 'current', {
      'id': 'current',
      'value': 'preserved',
    });

    await expectLater(
      AppDataInitializationService(
        database,
        clock: () => timestamp,
      ).initialize(),
      throwsA(isA<StateError>()),
    );

    expect(database.rawRecord(IndexedDbStoreNames.statusRecords, 'status-1'), {
      'id': 'status-1',
      'value': 'preserved',
    });
    expect(database.rawRecord(IndexedDbStoreNames.operationState, 'current'), {
      'id': 'current',
      'value': 'preserved',
    });
  });

  test('read-back mismatch aborts and rolls back initialization', () async {
    final database = _CorruptOperationStateReadBackDatabase();
    database.seed(IndexedDbStoreNames.foodRecords, 'food-1', {
      'id': 'food-1',
      'value': 'preserved',
    });

    await expectLater(
      AppDataInitializationService(
        database,
        clock: () => timestamp,
      ).initialize(),
      throwsA(isA<StateError>()),
    );

    expect(database.rawRecord(IndexedDbStoreNames.foodRecords, 'food-1'), {
      'id': 'food-1',
      'value': 'preserved',
    });
    expect(
      database.rawRecord(IndexedDbStoreNames.operationState, 'current'),
      isNull,
    );
  });
}

class _FailOnOperationStatePutDatabase extends FakeIndexedDbDatabase {
  @override
  Future<T> runTransaction<T>({
    required Iterable<String> storeNames,
    required IndexedDbTransactionMode mode,
    required Future<T> Function(IndexedDbTransaction transaction) action,
  }) => super.runTransaction(
    storeNames: storeNames,
    mode: mode,
    action: (transaction) => action(_FailOnOperationStatePut(transaction)),
  );
}

class _CorruptOperationStateReadBackDatabase extends FakeIndexedDbDatabase {
  @override
  Future<T> runTransaction<T>({
    required Iterable<String> storeNames,
    required IndexedDbTransactionMode mode,
    required Future<T> Function(IndexedDbTransaction transaction) action,
  }) => super.runTransaction(
    storeNames: storeNames,
    mode: mode,
    action: (transaction) =>
        action(_CorruptOperationStateReadBack(transaction)),
  );
}

class _DelegatingTransaction implements IndexedDbTransaction {
  const _DelegatingTransaction(this.delegate);

  final IndexedDbTransaction delegate;

  @override
  Future<void> clear(String storeName) => delegate.clear(storeName);

  @override
  Future<void> deleteById(String storeName, String id) =>
      delegate.deleteById(storeName, id);

  @override
  Future<List<Map<String, Object?>>> findAll(String storeName) =>
      delegate.findAll(storeName);

  @override
  Future<Map<String, Object?>?> findById(String storeName, String id) =>
      delegate.findById(storeName, id);

  @override
  Future<void> put(String storeName, Map<String, Object?> record) =>
      delegate.put(storeName, record);
}

class _FailOnOperationStatePut extends _DelegatingTransaction {
  const _FailOnOperationStatePut(super.delegate);

  @override
  Future<void> put(String storeName, Map<String, Object?> record) {
    if (storeName == IndexedDbStoreNames.operationState) {
      throw StateError('Injected initialization failure.');
    }
    return super.put(storeName, record);
  }
}

class _CorruptOperationStateReadBack extends _DelegatingTransaction {
  const _CorruptOperationStateReadBack(super.delegate);

  @override
  Future<List<Map<String, Object?>>> findAll(String storeName) {
    if (storeName == IndexedDbStoreNames.operationState) {
      return Future.value(const []);
    }
    return super.findAll(storeName);
  }
}
