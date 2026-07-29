import '../../../core/models/training_session.dart';
import '../../../core/models/training_session_v2.dart';

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
  static const legacyRecordVersion = 1;
  static const version2RecordVersion = 2;

  // Production writes remain on v1 until the later repository cutover task.
  static const currentRecordVersion = legacyRecordVersion;

  final String id;
  final int recordVersion;
  final String localDate;
  final DateTime createdAt;
  final DateTime updatedAt;
  final TrainingMigrationSource? migrationSource;
  final TrainingSession? _legacyData;
  final TrainingSessionV2? _version2Data;

  PersistedTrainingRecord({
    required this.id,
    this.recordVersion = currentRecordVersion,
    required this.localDate,
    required this.createdAt,
    required this.updatedAt,
    this.migrationSource,
    required TrainingSession data,
  }) : _legacyData = data,
       _version2Data = null {
    if (recordVersion != legacyRecordVersion) {
      throw ArgumentError.value(
        recordVersion,
        'recordVersion',
        'Legacy TRAINING data requires recordVersion 1.',
      );
    }
  }

  PersistedTrainingRecord.v2({
    required this.id,
    required this.localDate,
    required this.createdAt,
    required this.updatedAt,
    this.migrationSource,
    required TrainingSessionV2 data,
  }) : recordVersion = version2RecordVersion,
       _legacyData = null,
       _version2Data = data {
    if (data.hasLegacyUnknown) {
      throw ArgumentError.value(
        data,
        'data',
        'legacyUnknown values are reserved for migration.',
      );
    }
    _validateV2Envelope(id, localDate, data);
  }

  PersistedTrainingRecord.v2ForMigration({
    required this.id,
    required this.localDate,
    required this.createdAt,
    required this.updatedAt,
    required this.migrationSource,
    required TrainingSessionV2 data,
  }) : recordVersion = version2RecordVersion,
       _legacyData = null,
       _version2Data = data {
    if (migrationSource == null) {
      throw ArgumentError.notNull('migrationSource');
    }
    _validateV2Envelope(id, localDate, data);
  }

  TrainingSession get data {
    final value = _legacyData;
    if (value == null) {
      throw StateError('TRAINING recordVersion 2 does not contain v1 data.');
    }
    return value;
  }

  TrainingSessionV2 get dataV2 {
    final value = _version2Data;
    if (value == null) {
      throw StateError('TRAINING recordVersion 1 does not contain v2 data.');
    }
    return value;
  }

  Object get versionedData => _legacyData ?? _version2Data!;

  String get sessionDate => switch (recordVersion) {
    legacyRecordVersion => data.date,
    version2RecordVersion => dataV2.date,
    _ => throw StateError('Unsupported TRAINING recordVersion.'),
  };

  Map<String, Object?> toRecord() => {
    'id': id,
    'recordVersion': recordVersion,
    'localDate': localDate,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    if (migrationSource != null) 'migrationSource': migrationSource!.toJson(),
    'data': switch (recordVersion) {
      legacyRecordVersion => data.toJson(),
      version2RecordVersion => dataV2.toJson(),
      _ => throw StateError('Unsupported TRAINING recordVersion.'),
    },
  };

  factory PersistedTrainingRecord.fromRecord(Map<String, Object?> record) {
    final id = _requiredString(record, 'id');
    validateId(id);
    final recordVersion = record['recordVersion'];
    if (recordVersion is! int ||
        (recordVersion != legacyRecordVersion &&
            recordVersion != version2RecordVersion)) {
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
    final sourceValue = record['migrationSource'];
    if (sourceValue != null && sourceValue is! Map) {
      throw const FormatException('Invalid TRAINING migrationSource.');
    }
    final migrationSource = sourceValue == null
        ? null
        : TrainingMigrationSource.fromJson(
            Map<String, Object?>.from(sourceValue as Map),
          );
    final createdAt = _requiredDate(record, 'createdAt');
    final updatedAt = _requiredDate(record, 'updatedAt');
    if (recordVersion == legacyRecordVersion) {
      final data = TrainingSession.fromJson(
        Map<String, dynamic>.from(dataValue),
      );
      _validateEnvelopeDate(localDateFromSession(data), localDate);
      return PersistedTrainingRecord(
        id: id,
        localDate: localDate,
        createdAt: createdAt,
        updatedAt: updatedAt,
        migrationSource: migrationSource,
        data: data,
      );
    }
    final dataJson = Map<String, Object?>.from(dataValue);
    final data = migrationSource == null
        ? TrainingSessionV2.fromJson(dataJson)
        : TrainingSessionV2.fromMigrationJson(dataJson);
    _validateEnvelopeDate(localDateFromV2Session(data), localDate);
    if (migrationSource == null) {
      return PersistedTrainingRecord.v2(
        id: id,
        localDate: localDate,
        createdAt: createdAt,
        updatedAt: updatedAt,
        data: data,
      );
    }
    return PersistedTrainingRecord.v2ForMigration(
      id: id,
      localDate: localDate,
      createdAt: createdAt,
      updatedAt: updatedAt,
      migrationSource: migrationSource,
      data: data,
    );
  }

  static String localDateFromSession(TrainingSession session) {
    return _localDateFromSource(session.date);
  }

  static String localDateFromV2Session(TrainingSessionV2 session) {
    return _localDateFromSource(session.date);
  }

  static String _localDateFromSource(String source) {
    if (source.length < 10 || DateTime.tryParse(source) == null) {
      throw const FormatException('Invalid TRAINING session date.');
    }
    final localDate = source.substring(0, 10);
    validateLocalDate(localDate);
    return localDate;
  }

  static void _validateEnvelopeDate(String dataDate, String localDate) {
    if (dataDate != localDate) {
      throw const FormatException(
        'TRAINING Envelope does not match its Domain data.',
      );
    }
  }

  static void _validateV2Envelope(
    String id,
    String localDate,
    TrainingSessionV2 data,
  ) {
    validateId(id);
    validateLocalDate(localDate);
    _validateEnvelopeDate(localDateFromV2Session(data), localDate);
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
