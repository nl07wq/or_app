import 'package:or_app/data/indexed_db/indexed_db_database_contract.dart';
import 'package:or_app/data/indexed_db/indexed_db_schema.dart';
import 'package:or_app/data/indexed_db/indexed_db_store_names.dart';

class FakeIndexedDbDatabase implements IndexedDbDatabase {
  Map<String, Map<String, Map<String, Object?>>> _stores = {
    for (final storeName in IndexedDbStoreNames.all) storeName: {},
  };
  Object? failNextTransactionWith;
  int transactionCount = 0;
  int? failOnTransactionNumber;
  Object transactionFailure = StateError('Fake transaction failed.');
  String? failNextPutForStore;
  String? failNextReadAfterPutForStore;
  Object storeOperationFailure = StateError('Fake store operation failed.');
  final Set<String> _pendingReadFailures = {};

  @override
  Future<void> put(String storeName, Map<String, Object?> record) async {
    if (failNextPutForStore == storeName) {
      failNextPutForStore = null;
      throw storeOperationFailure;
    }
    final definition = IndexedDbSchema.storeDefinitions.singleWhere(
      (definition) => definition.name == storeName,
    );
    final id = record[definition.keyPath];
    if (id is! String) throw const FormatException('Record ID is required.');
    for (final index in definition.indexes.where((index) => index.unique)) {
      final value = record[index.keyPath];
      if (value == null) continue;
      final conflicts = _store(storeName).entries.where(
        (entry) => entry.key != id && entry.value[index.keyPath] == value,
      );
      if (conflicts.isNotEmpty) {
        throw StateError(
          'Unique index conflict: $storeName.${index.name}=$value',
        );
      }
    }
    _store(storeName)[id] = _copyMap(record);
    if (failNextReadAfterPutForStore == storeName) {
      failNextReadAfterPutForStore = null;
      _pendingReadFailures.add(storeName);
    }
  }

  @override
  Future<Map<String, Object?>?> findById(String storeName, String id) async {
    if (_pendingReadFailures.remove(storeName)) return null;
    final record = _store(storeName)[id];
    return record == null ? null : _copyMap(record);
  }

  @override
  Future<List<Map<String, Object?>>> findAll(String storeName) async {
    return [for (final record in _store(storeName).values) _copyMap(record)];
  }

  @override
  Future<void> deleteById(String storeName, String id) async {
    _store(storeName).remove(id);
  }

  @override
  Future<void> clear(String storeName) async {
    _store(storeName).clear();
  }

  @override
  Future<T> runTransaction<T>({
    required Iterable<String> storeNames,
    required IndexedDbTransactionMode mode,
    required Future<T> Function(IndexedDbTransaction transaction) action,
  }) async {
    transactionCount++;
    final names = storeNames.toSet();
    if (names.isEmpty) {
      throw ArgumentError.value(storeNames, 'storeNames');
    }
    for (final name in names) {
      _store(name);
    }

    final failure = failNextTransactionWith;
    failNextTransactionWith = null;
    if (failure != null) throw failure;
    if (failOnTransactionNumber == transactionCount) {
      throw transactionFailure;
    }

    final snapshot = _copyStores(_stores);
    try {
      return await action(_FakeIndexedDbTransaction(this, names));
    } catch (_) {
      if (mode == IndexedDbTransactionMode.readWrite) {
        _stores = snapshot;
      }
      rethrow;
    }
  }

  void seed(String storeName, String id, Map<String, Object?> record) {
    _store(storeName)[id] = _copyMap(record);
  }

  Map<String, Object?>? rawRecord(String storeName, String id) {
    final record = _store(storeName)[id];
    return record == null ? null : _copyMap(record);
  }

  Map<String, Map<String, Object?>> _store(String storeName) {
    final store = _stores[storeName];
    if (store == null) throw StateError('Unknown store: $storeName');
    return store;
  }

  Map<String, Map<String, Map<String, Object?>>> _copyStores(
    Map<String, Map<String, Map<String, Object?>>> source,
  ) {
    return {
      for (final storeEntry in source.entries)
        storeEntry.key: {
          for (final recordEntry in storeEntry.value.entries)
            recordEntry.key: _copyMap(recordEntry.value),
        },
    };
  }

  Map<String, Object?> _copyMap(Map source) {
    return {
      for (final entry in source.entries)
        entry.key.toString(): _copyValue(entry.value),
    };
  }

  Object? _copyValue(Object? value) {
    if (value is Map) return _copyMap(value);
    if (value is Iterable) return [for (final item in value) _copyValue(item)];
    return value;
  }
}

class _FakeIndexedDbTransaction implements IndexedDbTransaction {
  final FakeIndexedDbDatabase _database;
  final Set<String> _storeNames;

  const _FakeIndexedDbTransaction(this._database, this._storeNames);

  @override
  Future<void> put(String storeName, Map<String, Object?> record) {
    _checkStore(storeName);
    return _database.put(storeName, record);
  }

  @override
  Future<Map<String, Object?>?> findById(String storeName, String id) {
    _checkStore(storeName);
    return _database.findById(storeName, id);
  }

  @override
  Future<List<Map<String, Object?>>> findAll(String storeName) {
    _checkStore(storeName);
    return _database.findAll(storeName);
  }

  @override
  Future<void> deleteById(String storeName, String id) {
    _checkStore(storeName);
    return _database.deleteById(storeName, id);
  }

  @override
  Future<void> clear(String storeName) {
    _checkStore(storeName);
    return _database.clear(storeName);
  }

  void _checkStore(String storeName) {
    if (!_storeNames.contains(storeName)) {
      throw StateError('Store is outside the transaction: $storeName');
    }
  }
}
