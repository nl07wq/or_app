import '../../../core/models/activity_data.dart';

enum ActivityRecordKind { canonical, legacyRevision }

class ActivityMigrationSource {
  final String migrationId;
  final String sourceSystem;
  final String sourceKey;
  final int sourceIndex;

  const ActivityMigrationSource({
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

  factory ActivityMigrationSource.fromJson(Map<String, Object?> json) {
    final migrationId = json['migrationId'];
    final sourceSystem = json['sourceSystem'];
    final sourceKey = json['sourceKey'];
    final sourceIndex = json['sourceIndex'];
    if (migrationId is! String ||
        sourceSystem is! String ||
        sourceKey is! String ||
        sourceIndex is! int ||
        sourceIndex < 0) {
      throw const FormatException('Invalid ACTIVITY migration source.');
    }
    return ActivityMigrationSource(
      migrationId: migrationId,
      sourceSystem: sourceSystem,
      sourceKey: sourceKey,
      sourceIndex: sourceIndex,
    );
  }
}

class PersistedActivityRecord {
  static const currentRecordVersion = 1;

  final String id;
  final int recordVersion;
  final String localDate;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? canonicalDate;
  final ActivityRecordKind recordKind;
  final ActivityMigrationSource? migrationSource;
  final ActivityData data;

  const PersistedActivityRecord({
    required this.id,
    this.recordVersion = currentRecordVersion,
    required this.localDate,
    required this.createdAt,
    required this.updatedAt,
    required this.canonicalDate,
    required this.recordKind,
    this.migrationSource,
    required this.data,
  });

  Map<String, Object?> toRecord() => {
    'id': id,
    'recordVersion': recordVersion,
    'localDate': localDate,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    if (canonicalDate != null) 'canonicalDate': canonicalDate,
    'recordKind': recordKind.name,
    if (migrationSource != null) 'migrationSource': migrationSource!.toJson(),
    'data': data.toJson(),
  };

  factory PersistedActivityRecord.fromRecord(Map<String, Object?> record) {
    final id = _requiredString(record, 'id');
    final recordVersion = record['recordVersion'];
    if (recordVersion is! int || recordVersion != currentRecordVersion) {
      throw FormatException(
        'Unsupported ACTIVITY recordVersion: $recordVersion.',
      );
    }

    final localDate = _requiredLocalDate(record, 'localDate');
    final recordKind = ActivityRecordKind.values.firstWhere(
      (kind) => kind.name == record['recordKind'],
      orElse: () => throw const FormatException('Invalid ACTIVITY recordKind.'),
    );
    final canonicalDate = _optionalLocalDate(record, 'canonicalDate');
    if (recordKind == ActivityRecordKind.canonical) {
      if (canonicalDate != localDate || id != canonicalId(localDate)) {
        throw const FormatException('Invalid canonical ACTIVITY record.');
      }
    } else {
      if (canonicalDate != null ||
          !RegExp(
            '^legacy-activity:${RegExp.escape(localDate)}:\\d{4}\$',
          ).hasMatch(id)) {
        throw const FormatException('Invalid legacy ACTIVITY revision.');
      }
    }

    final sourceValue = record['migrationSource'];
    if (sourceValue != null && sourceValue is! Map) {
      throw const FormatException('Invalid ACTIVITY migrationSource.');
    }
    final dataValue = record['data'];
    if (dataValue is! Map) {
      throw const FormatException('Invalid ACTIVITY data.');
    }
    final data = ActivityData.fromJson(Map<String, dynamic>.from(dataValue));
    if (localDateFromDate(data.date) != localDate || data.id != localDate) {
      throw const FormatException(
        'ACTIVITY localDate does not match Domain data.',
      );
    }

    return PersistedActivityRecord(
      id: id,
      recordVersion: recordVersion,
      localDate: localDate,
      createdAt: _requiredDate(record, 'createdAt'),
      updatedAt: _requiredDate(record, 'updatedAt'),
      canonicalDate: canonicalDate,
      recordKind: recordKind,
      migrationSource: sourceValue == null
          ? null
          : ActivityMigrationSource.fromJson(
              Map<String, Object?>.from(sourceValue as Map),
            ),
      data: data,
    );
  }

  static String canonicalId(String localDate) {
    validateLocalDate(localDate);
    return 'activity:$localDate';
  }

  static String legacyRevisionId(String localDate, int sequence) {
    validateLocalDate(localDate);
    if (sequence < 1 || sequence > 9999) {
      throw RangeError.range(sequence, 1, 9999, 'sequence');
    }
    return 'legacy-activity:$localDate:'
        '${sequence.toString().padLeft(4, '0')}';
  }

  static String localDateFromDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  static void validateLocalDate(String localDate) {
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(localDate);
    if (match == null) {
      throw const FormatException('Invalid ACTIVITY localDate.');
    }
    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final day = int.parse(match.group(3)!);
    final parsed = DateTime(year, month, day);
    if (parsed.year != year || parsed.month != month || parsed.day != day) {
      throw const FormatException('Invalid ACTIVITY localDate.');
    }
  }

  static String _requiredString(Map<String, Object?> record, String key) {
    final value = record[key];
    if (value is! String || value.isEmpty) {
      throw FormatException('Invalid ACTIVITY $key.');
    }
    return value;
  }

  static String _requiredLocalDate(Map<String, Object?> record, String key) {
    final value = _requiredString(record, key);
    validateLocalDate(value);
    return value;
  }

  static String? _optionalLocalDate(Map<String, Object?> record, String key) {
    final value = record[key];
    if (value == null) return null;
    if (value is! String) {
      throw FormatException('Invalid ACTIVITY $key.');
    }
    validateLocalDate(value);
    return value;
  }

  static DateTime _requiredDate(Map<String, Object?> record, String key) {
    final value = record[key];
    if (value is! String) {
      throw FormatException('Invalid ACTIVITY $key.');
    }
    final date = DateTime.tryParse(value);
    if (date == null) {
      throw FormatException('Invalid ACTIVITY $key.');
    }
    return date;
  }
}
