import '../../../core/models/daily_log_confirmation.dart';

class DailyLogConfirmationMigrationSource {
  final String migrationId;
  final String sourceSystem;
  final String sourceKey;
  final int sourceIndex;

  const DailyLogConfirmationMigrationSource({
    required this.migrationId,
    required this.sourceSystem,
    required this.sourceKey,
    required this.sourceIndex,
  });

  Map<String, Object?> toJson() => {
    'migrationId': migrationId,
    'sourceSystem': sourceSystem,
    'sourceKey': sourceKey,
    'sourceIndex': sourceIndex,
  };

  factory DailyLogConfirmationMigrationSource.fromJson(
    Map<String, Object?> json,
  ) {
    final migrationId = json['migrationId'];
    final sourceSystem = json['sourceSystem'];
    final sourceKey = json['sourceKey'];
    final sourceIndex = json['sourceIndex'];
    if (migrationId is! String ||
        migrationId.isEmpty ||
        sourceSystem is! String ||
        sourceSystem.isEmpty ||
        sourceKey is! String ||
        sourceKey.isEmpty ||
        sourceIndex is! int ||
        sourceIndex < 0) {
      throw const FormatException(
        'Invalid Daily Log Confirmation migration source.',
      );
    }
    return DailyLogConfirmationMigrationSource(
      migrationId: migrationId,
      sourceSystem: sourceSystem,
      sourceKey: sourceKey,
      sourceIndex: sourceIndex,
    );
  }
}

class UnsupportedDailyLogSnapshotVersionException implements Exception {
  final Object? version;

  const UnsupportedDailyLogSnapshotVersionException(this.version);

  @override
  String toString() =>
      'Unsupported Daily Log Confirmation snapshotVersion: $version.';
}

class PersistedDailyLogConfirmationRecord {
  static const currentRecordVersion = 1;
  static const currentSnapshotVersion = 1;

  final String id;
  final int recordVersion;
  final int snapshotVersion;
  final String localDate;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DailyLogConfirmationMigrationSource? migrationSource;
  final DailyLogConfirmation data;

  const PersistedDailyLogConfirmationRecord({
    required this.id,
    this.recordVersion = currentRecordVersion,
    this.snapshotVersion = currentSnapshotVersion,
    required this.localDate,
    required this.createdAt,
    required this.updatedAt,
    this.migrationSource,
    required this.data,
  });

  Map<String, Object?> toRecord() => {
    'id': id,
    'recordVersion': recordVersion,
    'snapshotVersion': snapshotVersion,
    'localDate': localDate,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    if (migrationSource != null) 'migrationSource': migrationSource!.toJson(),
    'data': data.toJson(),
  };

  factory PersistedDailyLogConfirmationRecord.fromRecord(
    Map<String, Object?> record,
  ) {
    final id = _requiredString(record, 'id');
    final recordVersion = record['recordVersion'];
    if (recordVersion is! int || recordVersion != currentRecordVersion) {
      throw FormatException(
        'Unsupported Daily Log Confirmation recordVersion: $recordVersion.',
      );
    }
    final snapshotVersion = record['snapshotVersion'];
    if (snapshotVersion is! int) {
      throw const FormatException(
        'Invalid Daily Log Confirmation snapshotVersion.',
      );
    }
    if (snapshotVersion != currentSnapshotVersion) {
      throw UnsupportedDailyLogSnapshotVersionException(snapshotVersion);
    }
    final localDate = _requiredString(record, 'localDate');
    validateLocalDate(localDate);
    if (id != canonicalId(localDate)) {
      throw const FormatException(
        'Invalid Daily Log Confirmation persistent ID.',
      );
    }
    final dataValue = record['data'];
    if (dataValue is! Map) {
      throw const FormatException('Invalid Daily Log Confirmation data.');
    }
    final data = DailyLogConfirmation.fromJson(
      Map<String, dynamic>.from(dataValue),
    );
    if (localDateFromDate(data.date) != localDate) {
      throw const FormatException(
        'Daily Log Confirmation localDate does not match Domain data.',
      );
    }
    final sourceValue = record['migrationSource'];
    if (sourceValue != null && sourceValue is! Map) {
      throw const FormatException(
        'Invalid Daily Log Confirmation migrationSource.',
      );
    }
    return PersistedDailyLogConfirmationRecord(
      id: id,
      recordVersion: recordVersion,
      snapshotVersion: snapshotVersion,
      localDate: localDate,
      createdAt: _requiredDate(record, 'createdAt'),
      updatedAt: _requiredDate(record, 'updatedAt'),
      migrationSource: sourceValue == null
          ? null
          : DailyLogConfirmationMigrationSource.fromJson(
              Map<String, Object?>.from(sourceValue as Map),
            ),
      data: data,
    );
  }

  static String canonicalId(String localDate) {
    validateLocalDate(localDate);
    return 'confirmation:$localDate';
  }

  static String localDateFromDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  static void validateLocalDate(String localDate) {
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(localDate);
    if (match == null) {
      throw const FormatException('Invalid Daily Log Confirmation localDate.');
    }
    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final day = int.parse(match.group(3)!);
    final parsed = DateTime(year, month, day);
    if (parsed.year != year || parsed.month != month || parsed.day != day) {
      throw const FormatException('Invalid Daily Log Confirmation localDate.');
    }
  }

  static DailyLogConfirmation copyData(DailyLogConfirmation data) {
    return DailyLogConfirmation.fromJson(
      Map<String, dynamic>.from(_copyMap(data.toJson())),
    );
  }

  static String _requiredString(Map<String, Object?> record, String key) {
    final value = record[key];
    if (value is! String || value.isEmpty) {
      throw FormatException('Invalid Daily Log Confirmation $key.');
    }
    return value;
  }

  static DateTime _requiredDate(Map<String, Object?> record, String key) {
    final value = record[key];
    if (value is! String) {
      throw FormatException('Invalid Daily Log Confirmation $key.');
    }
    final date = DateTime.tryParse(value);
    if (date == null) {
      throw FormatException('Invalid Daily Log Confirmation $key.');
    }
    return date;
  }

  static Map<String, Object?> _copyMap(Map source) {
    return {
      for (final entry in source.entries)
        entry.key.toString(): _copyValue(entry.value),
    };
  }

  static Object? _copyValue(Object? value) {
    if (value is Map) return _copyMap(value);
    if (value is Iterable) return [for (final item in value) _copyValue(item)];
    return value;
  }
}
