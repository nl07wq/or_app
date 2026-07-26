import '../../../core/models/training_session.dart';

class TrainingMigrationSource {
  final String migrationId;
  final String sourceSystem;
  final String sourceKey;
  final int sourceIndex;
  final int duplicateOrdinal;

  const TrainingMigrationSource({
    required this.migrationId,
    required this.sourceSystem,
    required this.sourceKey,
    required this.sourceIndex,
    required this.duplicateOrdinal,
  });

  Map<String, Object?> toJson() => {
    'migrationId': migrationId,
    'sourceSystem': sourceSystem,
    'sourceKey': sourceKey,
    'sourceIndex': sourceIndex,
    'duplicateOrdinal': duplicateOrdinal,
  };

  factory TrainingMigrationSource.fromJson(Map<String, Object?> json) {
    final migrationId = json['migrationId'];
    final sourceSystem = json['sourceSystem'];
    final sourceKey = json['sourceKey'];
    final sourceIndex = json['sourceIndex'];
    final duplicateOrdinal = json['duplicateOrdinal'];
    if (migrationId is! String ||
        migrationId.isEmpty ||
        sourceSystem is! String ||
        sourceSystem.isEmpty ||
        sourceKey is! String ||
        sourceKey.isEmpty ||
        sourceIndex is! int ||
        sourceIndex < 0 ||
        duplicateOrdinal is! int ||
        duplicateOrdinal < 0) {
      throw const FormatException('Invalid TRAINING migration source.');
    }
    return TrainingMigrationSource(
      migrationId: migrationId,
      sourceSystem: sourceSystem,
      sourceKey: sourceKey,
      sourceIndex: sourceIndex,
      duplicateOrdinal: duplicateOrdinal,
    );
  }
}

class TrainingRecord {
  final String id;
  final TrainingSession session;

  const TrainingRecord({required this.id, required this.session});
}

class PersistedTrainingRecord {
  static const currentRecordVersion = 1;

  final String id;
  final int recordVersion;
  final String localDate;
  final DateTime createdAt;
  final DateTime updatedAt;
  final TrainingMigrationSource? migrationSource;
  final TrainingSession data;

  const PersistedTrainingRecord({
    required this.id,
    this.recordVersion = currentRecordVersion,
    required this.localDate,
    required this.createdAt,
    required this.updatedAt,
    this.migrationSource,
    required this.data,
  });

  Map<String, Object?> toRecord() => {
    'id': id,
    'recordVersion': recordVersion,
    'localDate': localDate,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    if (migrationSource != null) 'migrationSource': migrationSource!.toJson(),
    'data': data.toJson(),
  };

  factory PersistedTrainingRecord.fromRecord(Map<String, Object?> record) {
    final id = _requiredString(record, 'id');
    validateId(id);
    final recordVersion = record['recordVersion'];
    if (recordVersion is! int || recordVersion != currentRecordVersion) {
      throw FormatException(
        'Unsupported TRAINING recordVersion: $recordVersion.',
      );
    }
    final localDate = _requiredString(record, 'localDate');
    validateLocalDate(localDate);
    final dataValue = record['data'];
    if (dataValue is! Map) {
      throw const FormatException('Invalid TRAINING data.');
    }
    final data = TrainingSession.fromJson(Map<String, dynamic>.from(dataValue));
    if (localDateFromSession(data) != localDate) {
      throw const FormatException(
        'TRAINING Envelope does not match its Domain data.',
      );
    }
    final sourceValue = record['migrationSource'];
    if (sourceValue != null && sourceValue is! Map) {
      throw const FormatException('Invalid TRAINING migrationSource.');
    }
    return PersistedTrainingRecord(
      id: id,
      recordVersion: recordVersion,
      localDate: localDate,
      createdAt: _requiredDate(record, 'createdAt'),
      updatedAt: _requiredDate(record, 'updatedAt'),
      migrationSource: sourceValue == null
          ? null
          : TrainingMigrationSource.fromJson(
              Map<String, Object?>.from(sourceValue as Map),
            ),
      data: data,
    );
  }

  static String localDateFromSession(TrainingSession session) {
    final source = session.date;
    if (source.length < 10 || DateTime.tryParse(source) == null) {
      throw const FormatException('Invalid TRAINING session date.');
    }
    final localDate = source.substring(0, 10);
    validateLocalDate(localDate);
    return localDate;
  }

  static void validateId(String id) {
    final isNew = RegExp(
      r'^training:[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    ).hasMatch(id);
    final isLegacy = RegExp(
      r'^legacy-training:[0-9a-f]{8}:[0-9]{4}$',
    ).hasMatch(id);
    if (!isNew && !isLegacy) {
      throw const FormatException('Invalid TRAINING persistent ID.');
    }
  }

  static void validateLocalDate(String localDate) {
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(localDate);
    if (match == null) {
      throw const FormatException('Invalid TRAINING localDate.');
    }
    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final day = int.parse(match.group(3)!);
    final parsed = DateTime(year, month, day);
    if (parsed.year != year || parsed.month != month || parsed.day != day) {
      throw const FormatException('Invalid TRAINING localDate.');
    }
  }

  static TrainingSession copySession(TrainingSession session) {
    return TrainingSession.fromJson(
      Map<String, dynamic>.from(_copyMap(session.toJson())),
    );
  }

  static String _requiredString(Map<String, Object?> record, String key) {
    final value = record[key];
    if (value is! String || value.isEmpty) {
      throw FormatException('Invalid TRAINING $key.');
    }
    return value;
  }

  static DateTime _requiredDate(Map<String, Object?> record, String key) {
    final value = record[key];
    if (value is! String) {
      throw FormatException('Invalid TRAINING $key.');
    }
    final date = DateTime.tryParse(value);
    if (date == null) {
      throw FormatException('Invalid TRAINING $key.');
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
