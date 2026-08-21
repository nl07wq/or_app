enum IndexedDbTransactionMode { readOnly, readWrite }

abstract interface class IndexedDbTransaction {
  Future<void> put(String storeName, Map<String, Object?> record);

  Future<Map<String, Object?>?> findById(String storeName, String id);

  Future<List<Map<String, Object?>>> findAll(String storeName);

  Future<void> deleteById(String storeName, String id);

  Future<void> clear(String storeName);
}

abstract interface class IndexedDbDatabase {
  int get schemaVersion;

  Future<void> put(String storeName, Map<String, Object?> record);

  Future<Map<String, Object?>?> findById(String storeName, String id);

  Future<List<Map<String, Object?>>> findAll(String storeName);

  Future<void> deleteById(String storeName, String id);

  Future<void> clear(String storeName);

  Future<T> runTransaction<T>({
    required Iterable<String> storeNames,
    required IndexedDbTransactionMode mode,
    required Future<T> Function(IndexedDbTransaction transaction) action,
  });
}
