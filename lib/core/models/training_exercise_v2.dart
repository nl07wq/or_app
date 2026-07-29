import 'training_equipment_snapshot.dart';
import 'training_set_v2.dart';

class TrainingNextTarget {
  final double? targetWeightKg;
  final List<int> targetReps;
  final String? notes;

  TrainingNextTarget({
    this.targetWeightKg,
    List<int> targetReps = const [],
    String? notes,
  }) : targetReps = List.unmodifiable(targetReps),
       notes = _normalizeOptional(notes) {
    if (targetWeightKg != null &&
        (!targetWeightKg!.isFinite || targetWeightKg! < 0)) {
      throw ArgumentError.value(
        targetWeightKg,
        'targetWeightKg',
        'Target weight must be finite and not negative.',
      );
    }
    if (this.targetReps.any((reps) => reps < 1)) {
      throw ArgumentError.value(
        targetReps,
        'targetReps',
        'Every target rep value must be at least 1.',
      );
    }
  }

  Map<String, Object?> toJson() => {
    'targetWeightKg': targetWeightKg,
    'targetReps': targetReps,
    'notes': notes,
  };

  factory TrainingNextTarget.fromJson(Map<String, Object?> json) {
    final weight = json['targetWeightKg'];
    final reps = json['targetReps'];
    final notes = json['notes'];
    if ((weight != null && weight is! num) ||
        reps is! List ||
        reps.any((value) => value is! int) ||
        (notes != null && notes is! String)) {
      throw const FormatException('Invalid TRAINING nextTarget.');
    }
    return TrainingNextTarget(
      targetWeightKg: (weight as num?)?.toDouble(),
      targetReps: reps.cast<int>(),
      notes: notes as String?,
    );
  }
}

class TrainingExerciseV2 {
  final String exerciseName;
  final int order;
  final TrainingEquipmentSnapshot? equipment;
  final List<TrainingSetV2> sets;
  final String? evaluation;
  final TrainingNextTarget? nextTarget;

  TrainingExerciseV2({
    required String exerciseName,
    required this.order,
    this.equipment,
    List<TrainingSetV2> sets = const [],
    String? evaluation,
    this.nextTarget,
  }) : exerciseName = exerciseName.trim(),
       sets = List.unmodifiable(sets),
       evaluation = _normalizeOptional(evaluation) {
    _validate(allowLegacyUnknown: false);
  }

  TrainingExerciseV2.forMigration({
    required String exerciseName,
    required this.order,
    this.equipment,
    List<TrainingSetV2> sets = const [],
    String? evaluation,
    this.nextTarget,
  }) : exerciseName = exerciseName.trim(),
       sets = List.unmodifiable(sets),
       evaluation = _normalizeOptional(evaluation) {
    _validate(allowLegacyUnknown: true);
  }

  bool get hasLegacyUnknown => sets.any((set) => set.hasLegacyUnknown);

  Map<String, Object?> toJson() => {
    'exerciseName': exerciseName,
    'order': order,
    'equipment': equipment?.toJson(),
    'sets': sets.map((set) => set.toJson()).toList(),
    'evaluation': evaluation,
    'nextTarget': nextTarget?.toJson(),
  };

  factory TrainingExerciseV2.fromJson(Map<String, Object?> json) =>
      TrainingExerciseV2._decode(json, allowLegacyUnknown: false);

  factory TrainingExerciseV2.fromMigrationJson(Map<String, Object?> json) =>
      TrainingExerciseV2._decode(json, allowLegacyUnknown: true);

  static TrainingExerciseV2 _decode(
    Map<String, Object?> json, {
    required bool allowLegacyUnknown,
  }) {
    final exerciseName = json['exerciseName'];
    final order = json['order'];
    final equipment = json['equipment'];
    final sets = json['sets'];
    final evaluation = json['evaluation'];
    final nextTarget = json['nextTarget'];
    if (exerciseName is! String ||
        order is! int ||
        (equipment != null && equipment is! Map) ||
        sets is! List ||
        (evaluation != null && evaluation is! String) ||
        (nextTarget != null && nextTarget is! Map)) {
      throw const FormatException('Invalid TRAINING v2 exercise.');
    }
    final decodedSets = sets.map((value) {
      if (value is! Map) {
        throw const FormatException('Invalid TRAINING v2 set.');
      }
      final map = Map<String, Object?>.from(value);
      return allowLegacyUnknown
          ? TrainingSetV2.fromMigrationJson(map)
          : TrainingSetV2.fromJson(map);
    }).toList();
    final arguments = (
      exerciseName: exerciseName,
      order: order,
      equipment: equipment == null
          ? null
          : TrainingEquipmentSnapshot.fromJson(
              Map<String, Object?>.from(equipment as Map),
            ),
      sets: decodedSets,
      evaluation: evaluation as String?,
      nextTarget: nextTarget == null
          ? null
          : TrainingNextTarget.fromJson(
              Map<String, Object?>.from(nextTarget as Map),
            ),
    );
    if (allowLegacyUnknown) {
      return TrainingExerciseV2.forMigration(
        exerciseName: arguments.exerciseName,
        order: arguments.order,
        equipment: arguments.equipment,
        sets: arguments.sets,
        evaluation: arguments.evaluation,
        nextTarget: arguments.nextTarget,
      );
    }
    return TrainingExerciseV2(
      exerciseName: arguments.exerciseName,
      order: arguments.order,
      equipment: arguments.equipment,
      sets: arguments.sets,
      evaluation: arguments.evaluation,
      nextTarget: arguments.nextTarget,
    );
  }

  void _validate({required bool allowLegacyUnknown}) {
    if (exerciseName.isEmpty) {
      throw ArgumentError.value(
        exerciseName,
        'exerciseName',
        'Exercise name must not be empty.',
      );
    }
    if (order < 1) {
      throw ArgumentError.value(order, 'order', 'Order must be at least 1.');
    }
    if (!allowLegacyUnknown && hasLegacyUnknown) {
      throw ArgumentError.value(
        sets,
        'sets',
        'legacyUnknown setType is reserved for migration.',
      );
    }
    final setNumbers = <int>{};
    if (sets.any((set) => !setNumbers.add(set.setNo))) {
      throw ArgumentError.value(
        sets,
        'sets',
        'Set numbers must be unique within an exercise.',
      );
    }
  }
}

String? _normalizeOptional(String? value) {
  final normalized = value?.trim();
  return normalized == null || normalized.isEmpty ? null : normalized;
}
