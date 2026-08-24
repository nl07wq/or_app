import '../../../core/models/training_equipment_snapshot.dart';
import '../../../core/models/training_set_v2.dart';

class TrainingPlanProposal {
  TrainingPlanProposal({
    required this.operationDate,
    required List<TrainingPlanExercise> exercises,
    this.note,
  }) : exercises = List.unmodifiable(exercises) {
    if (exercises.isEmpty) {
      throw const FormatException('Training Plan requires exercises.');
    }
    final identities = <String>{};
    if (exercises.any((exercise) => !identities.add(exercise.identity))) {
      throw const FormatException('Training Plan exercise is duplicated.');
    }
  }

  final String operationDate;
  final List<TrainingPlanExercise> exercises;
  final String? note;
}

class TrainingPlanExercise {
  TrainingPlanExercise({
    required this.identity,
    required this.name,
    required this.equipment,
    required List<TrainingPlanSet> sets,
  }) : sets = List.unmodifiable(sets) {
    if (identity.trim().isEmpty || name.trim().isEmpty || sets.isEmpty) {
      throw const FormatException('Invalid Training Plan exercise.');
    }
    for (final (index, set) in sets.indexed) {
      if (set.order != index + 1) {
        throw const FormatException('Training Plan set order is invalid.');
      }
    }
  }

  final String identity;
  final String name;
  final TrainingEquipmentSnapshot? equipment;
  final List<TrainingPlanSet> sets;
}

class TrainingPlanSet {
  TrainingPlanSet({
    required this.order,
    required this.setType,
    required this.plannedWeightKg,
    required this.targetMinReps,
    required this.targetMaxReps,
    this.restAfterSeconds,
  }) {
    if (order < 1 ||
        !plannedWeightKg.isFinite ||
        plannedWeightKg < 0 ||
        targetMinReps < 1 ||
        targetMaxReps < targetMinReps ||
        restAfterSeconds != null && restAfterSeconds! < 0 ||
        setType == TrainingSetType.legacyUnknown) {
      throw const FormatException('Invalid Training Plan set.');
    }
  }

  final int order;
  final TrainingSetType setType;
  final double plannedWeightKg;
  final int targetMinReps;
  final int targetMaxReps;
  final int? restAfterSeconds;
}
