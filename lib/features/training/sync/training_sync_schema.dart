import '../../../core/data/default_training_templates.dart';
import '../../../core/models/cardio_entry_v2.dart';
import '../../../core/models/cardio_entry.dart';
import '../../../core/models/training_equipment_snapshot.dart';
import '../../../core/models/training_exercise_v2.dart';
import '../../../core/models/training_session_v2.dart';
import '../../../core/models/training_set_v2.dart';
import '../repository/custom_training_exercise_repository.dart';
import '../services/equipment_catalog.dart';
import '../services/exercise_equipment_mapping.dart';
import '../services/exercise_name_localization.dart';

class TrainingSyncPayload {
  const TrainingSyncPayload({
    required this.recordId,
    required this.exerciseIds,
    required this.session,
  });

  final String recordId;
  final List<String> exerciseIds;
  final TrainingSessionV2 session;
}

abstract final class TrainingSyncSchema {
  static const sessionFields = {
    'recordId',
    'localDate',
    'name',
    'grade',
    'memo',
    'dynamicStretchCompleted',
    'cooldownStretchCompleted',
    'overallEvaluation',
  };
  static const exerciseFields = {
    'exerciseId',
    'exerciseName',
    'equipment',
    'sets',
    'evaluation',
    'nextTarget',
  };
  static const equipmentFields = {'id', 'name'};
  static const setFields = {
    'type',
    'weightKg',
    'reps',
    'rpe',
    'restAfterSeconds',
  };
  static const cardioFields = {
    'purpose',
    'type',
    'durationSeconds',
    'distanceKm',
    'mets',
    'averageHeartRateBpm',
    'maximumHeartRateBpm',
    'averageSpeedKmh',
    'estimatedCaloriesKcal',
    'weightSnapshotKg',
    'calculationMethod',
    'calculationVersion',
    'notes',
  };

  static Future<TrainingSyncPayload> decode({
    required Map<String, Object?> payload,
    required String? operationDate,
    required String idempotencyKey,
    required CustomTrainingExerciseRepository customExercises,
    bool allowNullSessionGrade = false,
    Set<String> equipmentNamesRequiringIdentityResolution = const {},
  }) async {
    _fields(payload, {'session', 'exercises', 'cardio'}, r'$.payload');
    final sessionJson = _map(payload, 'session');
    _fields(
      sessionJson,
      sessionFields,
      r'$.payload.session',
      required: {
        'recordId',
        'localDate',
        'name',
        'grade',
        'dynamicStretchCompleted',
        'cooldownStretchCompleted',
      },
    );
    final recordId = _text(sessionJson, 'recordId');
    if (recordId != idempotencyKey) {
      throw const FormatException('idempotencyKey must equal recordId.');
    }
    final localDate = _text(sessionJson, 'localDate');
    if (operationDate == null || localDate != operationDate) {
      throw const FormatException('Operation Date does not match localDate.');
    }
    final gradeValue = allowNullSessionGrade
        ? _nullableText(sessionJson, 'grade')
        : _text(sessionJson, 'grade');
    final grade = gradeValue == null
        ? null
        : TrainingSessionGrade.fromStableId(gradeValue);
    final dynamicStretch = _boolean(sessionJson, 'dynamicStretchCompleted');
    final cooldownStretch = _boolean(sessionJson, 'cooldownStretchCompleted');
    final exerciseValues = _list(payload, 'exercises');
    final cardioValues = _list(payload, 'cardio');
    final customKeys = (await customExercises.findAll())
        .map((value) => exerciseIdentityKey(value.name))
        .toSet();
    final builtInKeys = {
      for (final template in defaultTrainingTemplates)
        for (final name in template.exercises) exerciseIdentityKey(name),
    };
    final exercises = <TrainingExerciseV2>[];
    final exerciseIds = <String>[];
    for (var index = 0; index < exerciseValues.length; index++) {
      final json = _asMap(exerciseValues[index], 'exercise');
      _fields(
        json,
        exerciseFields,
        r'$.payload.exercises[$index]',
        required: {'exerciseId', 'exerciseName', 'equipment', 'sets'},
      );
      final name = _text(json, 'exerciseName');
      final identity = exerciseIdentityKey(name);
      if (_text(json, 'exerciseId') != identity || identity.isEmpty) {
        throw const FormatException(
          'Exercise identity does not match its name.',
        );
      }
      if (!builtInKeys.contains(identity) && !customKeys.contains(identity)) {
        throw const FormatException('Custom exercise is not registered.');
      }
      final equipment = _equipment(
        json['equipment'],
        name,
        equipmentNamesRequiringIdentityResolution,
      );
      final sets = <TrainingSetV2>[];
      final setValues = _list(json, 'sets');
      for (var setIndex = 0; setIndex < setValues.length; setIndex++) {
        final setJson = _asMap(setValues[setIndex], 'set');
        _fields(
          setJson,
          setFields,
          r'$.payload.exercises[$index].sets[$setIndex]',
          required: {'type', 'weightKg', 'reps'},
        );
        final type = TrainingSetType.fromStableId(_text(setJson, 'type'));
        if (type == TrainingSetType.legacyUnknown) {
          throw const FormatException('legacyUnknown set is forbidden.');
        }
        sets.add(
          TrainingSetV2(
            setNo: setIndex + 1,
            setType: type,
            weightKg: _number(setJson, 'weightKg'),
            reps: _integer(setJson, 'reps'),
            rpe: _nullableInteger(setJson, 'rpe'),
            restAfterSeconds: _nullableInteger(setJson, 'restAfterSeconds'),
          ),
        );
      }
      exercises.add(
        TrainingExerciseV2(
          exerciseName: name,
          order: index + 1,
          equipment: equipment,
          sets: sets,
          evaluation: _nullableText(json, 'evaluation'),
          nextTarget: _nextTarget(json['nextTarget']),
        ),
      );
      exerciseIds.add(identity);
    }
    final cardio = <CardioEntryV2>[];
    for (final value in cardioValues) {
      final json = _asMap(value, 'cardio');
      _fields(
        json,
        cardioFields,
        r'$.payload.cardio',
        required: {'purpose', 'type', 'durationSeconds'},
      );
      final purpose = CardioPurpose.fromStableId(_text(json, 'purpose'));
      if (purpose == CardioPurpose.legacyUnknown) {
        throw const FormatException('legacyUnknown cardio is forbidden.');
      }
      cardio.add(
        CardioEntryV2(
          purpose: purpose,
          type: _cardioType(_text(json, 'type')),
          durationSeconds: _integer(json, 'durationSeconds'),
          distanceKm: _nullableNumber(json, 'distanceKm'),
          mets: _nullableNumber(json, 'mets'),
          averageHeartRateBpm: _nullableInteger(json, 'averageHeartRateBpm'),
          maximumHeartRateBpm: _nullableInteger(json, 'maximumHeartRateBpm'),
          averageSpeedKmh: _nullableNumber(json, 'averageSpeedKmh'),
          estimatedCaloriesKcal: _nullableNumber(json, 'estimatedCaloriesKcal'),
          weightSnapshotKg: _nullableNumber(json, 'weightSnapshotKg'),
          calculationMethod: _nullableText(json, 'calculationMethod'),
          calculationVersion: _nullableInteger(json, 'calculationVersion'),
          notes: _nullableText(json, 'notes'),
        ),
      );
    }
    return TrainingSyncPayload(
      recordId: recordId,
      exerciseIds: List.unmodifiable(exerciseIds),
      session: TrainingSessionV2(
        date: localDate,
        sessionName: _nullableText(sessionJson, 'name'),
        sessionGrade: grade,
        memo: _nullableText(sessionJson, 'memo'),
        dynamicStretchCompleted: dynamicStretch,
        cooldownStretchCompleted: cooldownStretch,
        overallEvaluation: _nullableText(sessionJson, 'overallEvaluation'),
        exercises: exercises,
        cardioEntries: cardio,
      ),
    );
  }

  static TrainingEquipmentSnapshot? _equipment(
    Object? value,
    String exerciseName,
    Set<String> namesRequiringIdentityResolution,
  ) {
    if (value == null) return null;
    final json = _asMap(value, 'equipment');
    _fields(
      json,
      equipmentFields,
      r'$.payload.exercises[].equipment',
      required: {'name'},
    );
    final id = _nullableText(json, 'id');
    final name = _text(json, 'name');
    if (id == null) {
      if (!namesRequiringIdentityResolution.contains(name)) {
        return TrainingEquipmentSnapshot(name: name);
      }
      final compatibleIds = compatibleEquipmentIds(exerciseName);
      final matches = builtInEquipment
          .where(
            (equipment) =>
                equipment.displayName == name &&
                compatibleIds.contains(equipment.id),
          )
          .toList(growable: false);
      if (matches.length != 1) {
        throw const FormatException('Equipment identity is invalid.');
      }
      return TrainingEquipmentSnapshot(
        catalogId: matches.single.id,
        name: matches.single.displayName,
      );
    }
    final catalog = equipmentById(id);
    if (catalog == null ||
        catalog.displayName != name ||
        !compatibleEquipmentIds(exerciseName).contains(id)) {
      throw const FormatException('Equipment identity is invalid.');
    }
    return TrainingEquipmentSnapshot(catalogId: id, name: name);
  }

  static TrainingNextTarget? _nextTarget(Object? value) {
    if (value == null) return null;
    return TrainingNextTarget.fromJson(_asMap(value, 'nextTarget'));
  }

  static CardioType _cardioType(String value) {
    try {
      return CardioType.values.byName(value);
    } on ArgumentError {
      throw const FormatException('Unknown cardio type.');
    }
  }

  static void _fields(
    Map<String, Object?> value,
    Set<String> allowed,
    String path, {
    Set<String>? required,
  }) {
    final unknown = value.keys.where((key) => !allowed.contains(key));
    if (unknown.isNotEmpty) {
      throw FormatException('Unknown field at $path: ${unknown.first}');
    }
    final missing = (required ?? allowed).where(
      (key) => !value.containsKey(key),
    );
    if (missing.isNotEmpty) {
      throw FormatException('Missing field at $path: ${missing.first}');
    }
  }

  static Map<String, Object?> _map(Map<String, Object?> value, String key) =>
      _asMap(value[key], key);
  static Map<String, Object?> _asMap(Object? value, String name) {
    if (value is! Map) throw FormatException('$name must be an Object.');
    return Map<String, Object?>.from(value);
  }

  static List<Object?> _list(Map<String, Object?> value, String key) {
    final result = value[key];
    if (result is! List) throw FormatException('$key must be a List.');
    return result;
  }

  static String _text(Map<String, Object?> value, String key) {
    final result = value[key];
    if (result is! String || result.trim().isEmpty) {
      throw FormatException('$key must be text.');
    }
    return result.trim();
  }

  static String? _nullableText(Map<String, Object?> value, String key) {
    final result = value[key];
    if (result == null) return null;
    if (result is! String) throw FormatException('$key must be text or null.');
    return result;
  }

  static bool _boolean(Map<String, Object?> value, String key) {
    final result = value[key];
    if (result is! bool) throw FormatException('$key must be bool.');
    return result;
  }

  static int _integer(Map<String, Object?> value, String key) {
    final result = value[key];
    if (result is! int) throw FormatException('$key must be int.');
    return result;
  }

  static int? _nullableInteger(Map<String, Object?> value, String key) {
    final result = value[key];
    if (result == null) return null;
    if (result is! int) throw FormatException('$key must be int or null.');
    return result;
  }

  static double _number(Map<String, Object?> value, String key) {
    final result = value[key];
    if (result is! num) throw FormatException('$key must be number.');
    return result.toDouble();
  }

  static double? _nullableNumber(Map<String, Object?> value, String key) {
    final result = value[key];
    if (result == null) return null;
    if (result is! num) throw FormatException('$key must be number or null.');
    return result.toDouble();
  }
}
