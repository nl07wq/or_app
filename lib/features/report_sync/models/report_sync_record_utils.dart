abstract final class ReportSyncRecordUtils {
  static final _digestPattern = RegExp(r'^[0-9a-f]{64}$');
  static bool isDigest(Object? value) =>
      value is String && _digestPattern.hasMatch(value);
  static void exactFields(Map<String, Object?> json, Set<String> fields) {
    if (json.keys.toSet().difference(fields).isNotEmpty ||
        fields.difference(json.keys.toSet()).isNotEmpty) {
      throw const FormatException('Record fields do not match the schema.');
    }
  }

  static String string(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is! String || value.isEmpty) {
      throw FormatException('$key is invalid.');
    }
    return value;
  }

  static String? nullableString(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value == null) return null;
    if (value is! String || value.isEmpty) {
      throw FormatException('$key is invalid.');
    }
    return value;
  }

  static DateTime date(Map<String, Object?> json, String key) {
    final value = DateTime.tryParse(string(json, key));
    if (value == null || !value.isUtc) {
      throw FormatException('$key is invalid.');
    }
    return value;
  }

  static String localDate(Map<String, Object?> json, String key) {
    final value = string(json, key);
    final parsed = DateTime.tryParse('${value}T00:00:00Z');
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value) ||
        parsed == null ||
        parsed.toIso8601String().substring(0, 10) != value) {
      throw FormatException('$key is invalid.');
    }
    return value;
  }

  static String digest(Map<String, Object?> json, String key) {
    final value = string(json, key);
    if (!_digestPattern.hasMatch(value)) {
      throw FormatException('$key is invalid.');
    }
    return value;
  }

  static String? nullableDigest(Map<String, Object?> json, String key) {
    final value = nullableString(json, key);
    if (value != null && !_digestPattern.hasMatch(value)) {
      throw FormatException('$key is invalid.');
    }
    return value;
  }

  static List<String> strings(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is! List ||
        value.any((item) => item is! String || item.isEmpty)) {
      throw FormatException('$key is invalid.');
    }
    return List.unmodifiable(value.cast<String>());
  }
}
