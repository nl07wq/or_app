import '../../../core/models/training_exercise.dart';
import '../../../core/models/training_exercise_v2.dart';
import 'equipment_catalog.dart';
import 'exercise_name_localization.dart';

class TrainingExerciseIdentity {
  static const _noEquipment = 'none';

  final String exerciseKey;
  final String equipmentKey;

  const TrainingExerciseIdentity._({
    required this.exerciseKey,
    required this.equipmentKey,
  });

  factory TrainingExerciseIdentity.v1(TrainingExercise exercise) {
    return TrainingExerciseIdentity.fromV1(
      exerciseName: exercise.exerciseName,
      equipmentId: exercise.equipmentId,
    );
  }

  factory TrainingExerciseIdentity.fromV1({
    required String exerciseName,
    required String? equipmentId,
  }) {
    final normalizedEquipmentId = _normalizeOptional(equipmentId);
    return TrainingExerciseIdentity._(
      exerciseKey: exerciseIdentityKey(exerciseName),
      equipmentKey: normalizedEquipmentId == null
          ? _noEquipment
          : 'catalog:$normalizedEquipmentId',
    );
  }

  factory TrainingExerciseIdentity.v2(TrainingExerciseV2 exercise) {
    final equipment = exercise.equipment;
    return TrainingExerciseIdentity._(
      exerciseKey: exerciseIdentityKey(exercise.exerciseName),
      equipmentKey: equipment == null
          ? _noEquipment
          : canonicalEquipmentIdentityKey(
              catalogId: equipment.catalogId,
              name: equipment.name,
            ),
    );
  }

  bool get isValid => exerciseKey.isNotEmpty;

  @override
  bool operator ==(Object other) {
    return other is TrainingExerciseIdentity &&
        exerciseKey == other.exerciseKey &&
        equipmentKey == other.equipmentKey;
  }

  @override
  int get hashCode => Object.hash(exerciseKey, equipmentKey);

  static String? _normalizeOptional(String? value) {
    final normalized = value?.trim().toLowerCase();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }
}
