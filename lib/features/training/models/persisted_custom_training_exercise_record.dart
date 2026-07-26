import '../services/exercise_name_localization.dart';
import 'custom_training_exercise.dart';

class CustomTrainingExerciseMigrationSource {
  final String migrationId;
  final String sourceSystem;
  final String sourceKey;
  final int sourceIndex;

  const CustomTrainingExerciseMigrationSource({
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

  factory CustomTrainingExerciseMigrationSource.fromJson(
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
        'Invalid Custom Training Exercise migration source.',
      );
    }
    return CustomTrainingExerciseMigrationSource(
      migrationId: migrationId,
      sourceSystem: sourceSystem,
      sourceKey: sourceKey,
      sourceIndex: sourceIndex,
    );
  }
}

class PersistedCustomTrainingExerciseRecord {
  static const currentRecordVersion = 1;

  final String id;
  final int recordVersion;
  final String normalizedName;
  final DateTime createdAt;
  final DateTime updatedAt;
  final CustomTrainingExerciseMigrationSource? migrationSource;
  final CustomTrainingExercise data;

  const PersistedCustomTrainingExerciseRecord({
    required this.id,
    this.recordVersion = currentRecordVersion,
    required this.normalizedName,
    required this.createdAt,
    required this.updatedAt,
    this.migrationSource,
    required this.data,
  });

  Map<String, Object?> toRecord() => {
    'id': id,
    'recordVersion': recordVersion,
    'normalizedName': normalizedName,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    if (migrationSource != null) 'migrationSource': migrationSource!.toJson(),
    'data': {'id': data.id, 'name': data.name},
  };

  factory PersistedCustomTrainingExerciseRecord.fromRecord(
    Map<String, Object?> record,
  ) {
    final id = _requiredString(record, 'id');
    validateId(id);
    final recordVersion = record['recordVersion'];
    if (recordVersion is! int || recordVersion != currentRecordVersion) {
      throw FormatException(
        'Unsupported Custom Training Exercise recordVersion: $recordVersion.',
      );
    }
    final normalizedName = _requiredString(record, 'normalizedName');
    final dataValue = record['data'];
    if (dataValue is! Map) {
      throw const FormatException('Invalid Custom Training Exercise data.');
    }
    final dataMap = Map<String, Object?>.from(dataValue);
    final data = CustomTrainingExercise(
      id: _requiredString(dataMap, 'id'),
      name: _requiredString(dataMap, 'name'),
    );
    if (data.id != id || exerciseIdentityKey(data.name) != normalizedName) {
      throw const FormatException(
        'Custom Training Exercise envelope does not match its Domain data.',
      );
    }
    final sourceValue = record['migrationSource'];
    if (sourceValue != null && sourceValue is! Map) {
      throw const FormatException(
        'Invalid Custom Training Exercise migrationSource.',
      );
    }
    return PersistedCustomTrainingExerciseRecord(
      id: id,
      recordVersion: recordVersion,
      normalizedName: normalizedName,
      createdAt: _requiredDate(record, 'createdAt'),
      updatedAt: _requiredDate(record, 'updatedAt'),
      migrationSource: sourceValue == null
          ? null
          : CustomTrainingExerciseMigrationSource.fromJson(
              Map<String, Object?>.from(sourceValue as Map),
            ),
      data: data,
    );
  }

  static void validateId(String id) {
    final isNew = RegExp(
      r'^custom-exercise:[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    ).hasMatch(id);
    final isLegacy = RegExp(
      r'^legacy-custom-exercise:[0-9a-f]{8}$',
    ).hasMatch(id);
    if (!isNew && !isLegacy) {
      throw const FormatException(
        'Invalid Custom Training Exercise persistent ID.',
      );
    }
  }

  static String _requiredString(Map<String, Object?> record, String key) {
    final value = record[key];
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('Invalid Custom Training Exercise $key.');
    }
    return value;
  }

  static DateTime _requiredDate(Map<String, Object?> record, String key) {
    final value = record[key];
    if (value is! String) {
      throw FormatException('Invalid Custom Training Exercise $key.');
    }
    final date = DateTime.tryParse(value);
    if (date == null) {
      throw FormatException('Invalid Custom Training Exercise $key.');
    }
    return date;
  }
}
