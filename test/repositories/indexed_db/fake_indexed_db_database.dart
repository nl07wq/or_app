import 'package:or_app/data/indexed_db/indexed_db_database_contract.dart';
import 'package:or_app/data/indexed_db/indexed_db_store_names.dart';

class FakeIndexedDbDatabase implements IndexedDbDatabase {
  final Map<String, Map<String, Map<String, Object?>>> _stores = {
    for (final storeName in IndexedDbStoreNames.all) storeName: {},
  };

  @override
  Future<void> put(String storeName, Map<String, Object?> record) async {
    final id = record['id'];
    if (id is! String) throw const FormatException('Record ID is required.');
    _store(storeName)[id] = _copyMap(record);
  }

  @override
  Future<Map<String, Object?>?> findById(String storeName, String id) async {
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

  void seed(String storeName, String id, Map<String, Object?> record) {
    _store(storeName)[id] = _copyMap(record);
  }

  Map<String, Map<String, Object?>> _store(String storeName) {
    final store = _stores[storeName];
    if (store == null) throw StateError('Unknown store: $storeName');
    return store;
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
