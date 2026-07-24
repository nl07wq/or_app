class RepositorySnapshot {
  final List<Map<String, Object?>>? trainingRecords;
  final List<Map<String, Object?>>? morningFactRecords;

  RepositorySnapshot({
    Iterable<Map<String, Object?>>? trainingRecords,
    Iterable<Map<String, Object?>>? morningFactRecords,
  }) : trainingRecords = _freezeRecords(trainingRecords),
       morningFactRecords = _freezeRecords(morningFactRecords);

  static List<Map<String, Object?>>? _freezeRecords(
    Iterable<Map<String, Object?>>? records,
  ) {
    if (records == null) return null;

    return List.unmodifiable(records.map(_freezeMap));
  }

  static Map<String, Object?> _freezeMap(Map<String, Object?> source) {
    return Map.unmodifiable(
      source.map((key, value) => MapEntry(key, _freezeValue(value))),
    );
  }

  static Object? _freezeValue(Object? value) {
    if (value is Map) {
      return Map.unmodifiable(
        value.map(
          (key, nestedValue) =>
              MapEntry(key.toString(), _freezeValue(nestedValue)),
        ),
      );
    }
    if (value is Iterable) {
      return List.unmodifiable(value.map(_freezeValue));
    }
    return value;
  }
}
