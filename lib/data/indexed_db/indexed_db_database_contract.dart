abstract interface class IndexedDbDatabase {
  Future<void> put(String storeName, Map<String, Object?> record);

  Future<Map<String, Object?>?> findById(String storeName, String id);

  Future<List<Map<String, Object?>>> findAll(String storeName);

  Future<void> deleteById(String storeName, String id);

  Future<void> clear(String storeName);
}
