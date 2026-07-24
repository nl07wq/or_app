import 'export_metadata.dart';

class ExportData {
  static const currentSchemaVersion = '1.0';

  final String schemaVersion;
  final DateTime exportedAt;
  final List<Map<String, Object?>>? training;
  final List<Map<String, Object?>>? morningFact;
  final ExportMetadata metadata;

  ExportData({
    required this.schemaVersion,
    required this.exportedAt,
    Iterable<Map<String, Object?>>? training,
    Iterable<Map<String, Object?>>? morningFact,
    this.metadata = const ExportMetadata(),
  }) : training = _freezeRecords(training),
       morningFact = _freezeRecords(morningFact);

  Map<String, Object?> toJson() {
    return {
      'schemaVersion': schemaVersion,
      'exportedAt': exportedAt.toUtc().toIso8601String(),
      if (training != null) 'training': training,
      if (morningFact != null) 'morningFact': morningFact,
      'metadata': metadata.toJson(),
    };
  }

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
