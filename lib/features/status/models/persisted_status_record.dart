import '../../../core/models/morning_data.dart';

enum StatusRecordKind { canonical, legacyRevision }

class StatusMigrationSource {
  final String migrationId;
  final String sourceSystem;
  final String sourceKey;
  final int sourceIndex;

  const StatusMigrationSource({
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

  factory StatusMigrationSource.fromJson(Map<String, Object?> json) {
    final migrationId = json['migrationId'];
    final sourceSystem = json['sourceSystem'];
    final sourceKey = json['sourceKey'];
    final sourceIndex = json['sourceIndex'];
    if (migrationId is! String ||
        sourceSystem is! String ||
        sourceKey is! String ||
        sourceIndex is! int ||
        sourceIndex < 0) {
      throw const FormatException('Invalid STATUS migration source.');
    }
    return StatusMigrationSource(
      migrationId: migrationId,
      sourceSystem: sourceSystem,
      sourceKey: sourceKey,
      sourceIndex: sourceIndex,
    );
  }
}

class PersistedStatusRecord {
  static const currentRecordVersion = 1;

  final String id;
  final int recordVersion;
  final String localDate;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? canonicalDate;
  final StatusRecordKind recordKind;
  final StatusMigrationSource? migrationSource;
  final MorningData data;

  const PersistedStatusRecord({
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

  factory PersistedStatusRecord.fromRecord(Map<String, Object?> record) {
    final id = _requiredString(record, 'id');
    final recordVersion = record['recordVersion'];
    if (recordVersion is! int || recordVersion != currentRecordVersion) {
      throw FormatException(
        'Unsupported STATUS recordVersion: $recordVersion.',
      );
    }

    final localDate = _requiredLocalDate(record, 'localDate');
    final recordKind = StatusRecordKind.values.firstWhere(
      (kind) => kind.name == record['recordKind'],
      orElse: () => throw const FormatException('Invalid STATUS recordKind.'),
    );
    final canonicalDate = _optionalLocalDate(record, 'canonicalDate');
    if (recordKind == StatusRecordKind.canonical) {
      if (canonicalDate != localDate || id != canonicalId(localDate)) {
        throw const FormatException('Invalid canonical STATUS record.');
      }
    } else {
      if (canonicalDate != null ||
          !RegExp(
            '^legacy-status:${RegExp.escape(localDate)}:\\d{4}\$',
          ).hasMatch(id)) {
        throw const FormatException('Invalid legacy STATUS revision.');
      }
    }

    final migrationSourceValue = record['migrationSource'];
    if (migrationSourceValue != null && migrationSourceValue is! Map) {
      throw const FormatException('Invalid STATUS migrationSource.');
    }
    final dataValue = record['data'];
    if (dataValue is! Map) {
      throw const FormatException('Invalid STATUS data.');
    }
    final data = MorningData.fromJson(Map<String, dynamic>.from(dataValue));
    if (localDateFromSource(data.date) != localDate) {
      throw const FormatException('STATUS localDate does not match data.');
    }

    return PersistedStatusRecord(
      id: id,
      recordVersion: recordVersion,
      localDate: localDate,
      createdAt: _requiredDate(record, 'createdAt'),
      updatedAt: _requiredDate(record, 'updatedAt'),
      canonicalDate: canonicalDate,
      recordKind: recordKind,
      migrationSource: migrationSourceValue == null
          ? null
          : StatusMigrationSource.fromJson(
              Map<String, Object?>.from(migrationSourceValue as Map),
            ),
      data: data,
    );
  }

  static String canonicalId(String localDate) {
    validateLocalDate(localDate);
    return 'status:$localDate';
  }

  static String legacyRevisionId(String localDate, int sequence) {
    validateLocalDate(localDate);
    if (sequence < 1 || sequence > 9999) {
      throw RangeError.range(sequence, 1, 9999, 'sequence');
    }
    return 'legacy-status:$localDate:${sequence.toString().padLeft(4, '0')}';
  }

  static String localDateFromSource(String sourceDate) {
    if (sourceDate.length < 10) {
      throw const FormatException('Invalid STATUS source date.');
    }
    final localDate = sourceDate.substring(0, 10);
    validateLocalDate(localDate);
    if (DateTime.tryParse(sourceDate) == null) {
      throw const FormatException('Invalid STATUS source date.');
    }
    return localDate;
  }

  static void validateLocalDate(String localDate) {
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(localDate);
    if (match == null) {
      throw const FormatException('Invalid STATUS localDate.');
    }
    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final day = int.parse(match.group(3)!);
    final parsed = DateTime(year, month, day);
    if (parsed.year != year || parsed.month != month || parsed.day != day) {
      throw const FormatException('Invalid STATUS localDate.');
    }
  }

  static String _requiredString(Map<String, Object?> record, String key) {
    final value = record[key];
    if (value is! String || value.isEmpty) {
      throw FormatException('Invalid STATUS $key.');
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
      throw FormatException('Invalid STATUS $key.');
    }
    validateLocalDate(value);
    return value;
  }

  static DateTime _requiredDate(Map<String, Object?> record, String key) {
    final value = record[key];
    if (value is! String) {
      throw FormatException('Invalid STATUS $key.');
    }
    final date = DateTime.tryParse(value);
    if (date == null) {
      throw FormatException('Invalid STATUS $key.');
    }
    return date;
  }
}
