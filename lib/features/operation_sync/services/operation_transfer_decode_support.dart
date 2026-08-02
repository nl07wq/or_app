import '../models/operation_sync_issue.dart';

abstract final class OperationTransferDecodeSupport {
  static const maxPackageBytes = 32 * 1024 * 1024;
  static const maxSectionCount = 16;
  static const maxRecordsPerSection = 50000;
  static const maxPackageRecords = 100000;

  static void expectKeys(Map<String, Object?> json, Set<String> expected) {
    final actual = json.keys.toSet();
    if (actual.difference(expected).isNotEmpty ||
        expected.difference(actual).isNotEmpty) {
      throw const OperationSyncException(
        OperationSyncIssueCode.integrityFailure,
        'Operation Transfer fields are invalid.',
      );
    }
  }

  static Map<String, Object?> map(Map<String, Object?> json, String key) {
    return object(json[key], key);
  }

  static Map<String, Object?> object(Object? value, String key) {
    if (value is! Map) {
      throw OperationSyncException(
        OperationSyncIssueCode.integrityFailure,
        '$key must be an object.',
      );
    }
    return Map<String, Object?>.from(value);
  }

  static List<Object?> list(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is! List) {
      throw OperationSyncException(
        OperationSyncIssueCode.integrityFailure,
        '$key must be an array.',
      );
    }
    return value;
  }

  static String string(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is! String || value.isEmpty) {
      throw OperationSyncException(
        OperationSyncIssueCode.integrityFailure,
        '$key must be a non-empty string.',
      );
    }
    return value;
  }

  static int nonNegativeInt(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is! int || value < 0) {
      throw OperationSyncException(
        OperationSyncIssueCode.integrityFailure,
        '$key must be a non-negative integer.',
      );
    }
    return value;
  }

  static String digest(Map<String, Object?> json, String key) {
    final value = string(json, key);
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(value)) {
      throw OperationSyncException(
        OperationSyncIssueCode.integrityFailure,
        '$key must be a lowercase SHA-256 digest.',
      );
    }
    return value;
  }

  static String uuid(Map<String, Object?> json, String key) {
    final value = string(json, key);
    if (!RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    ).hasMatch(value)) {
      throw OperationSyncException(
        OperationSyncIssueCode.integrityFailure,
        '$key must be a lowercase UUID.',
      );
    }
    return value;
  }

  static DateTime timestamp(Map<String, Object?> json, String key) {
    final value = string(json, key);
    final parsed = DateTime.tryParse(value);
    if (parsed == null ||
        !parsed.isUtc ||
        parsed.toUtc().toIso8601String() != value) {
      throw OperationSyncException(
        OperationSyncIssueCode.integrityFailure,
        '$key must be a canonical UTC timestamp.',
      );
    }
    return parsed;
  }

  static String localDate(Map<String, Object?> json, String key) {
    final value = string(json, key);
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
      throw OperationSyncException(
        OperationSyncIssueCode.integrityFailure,
        '$key must be YYYY-MM-DD.',
      );
    }
    final parsed = DateTime.tryParse('${value}T00:00:00Z');
    if (parsed == null || parsed.toIso8601String().substring(0, 10) != value) {
      throw OperationSyncException(
        OperationSyncIssueCode.integrityFailure,
        '$key is not a valid date.',
      );
    }
    return value;
  }

  static T stableEnum<T>(
    Iterable<T> values,
    Object? raw,
    String Function(T) id,
    String key,
  ) {
    if (raw is! String) return _unsupported(key);
    return values.firstWhere(
      (value) => id(value) == raw,
      orElse: () => _unsupported(key),
    );
  }

  static Never _unsupported(String key) {
    throw OperationSyncException(
      OperationSyncIssueCode.versionUnsupported,
      '$key is unsupported.',
    );
  }
}
