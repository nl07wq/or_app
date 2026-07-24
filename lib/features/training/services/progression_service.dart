import '../../../core/models/training_set.dart';
import '../../../core/repositories/training_repository.dart';
import '../models/progression_result.dart';
import 'exercise_name_localization.dart';

class ProgressionService {
  ProgressionService._();

  static Future<ProgressionResult?> loadLatest({
    required String exerciseName,
    required String? equipmentId,
  }) async {
    final exerciseKey = exerciseIdentityKey(exerciseName);
    if (exerciseKey.isEmpty) return null;

    final sessions = await TrainingRepository.getAll();
    for (final session in sessions) {
      for (final exercise in session.exercises) {
        final isMatch =
            exerciseIdentityKey(exercise.exerciseName) == exerciseKey &&
            exercise.equipmentId == equipmentId;
        if (!isMatch) continue;
        if (exercise.sets.isEmpty) return null;

        return evaluate(_topSet(exercise.sets));
      }
    }

    return null;
  }

  static ProgressionResult evaluate(TrainingSet topSet) {
    const suggestedRepsMin = 8;
    const suggestedRepsMax = 10;

    if (topSet.reps >= 10) {
      return ProgressionResult(
        lastWeight: topSet.weight,
        lastReps: topSet.reps,
        suggestedWeight: topSet.weight + 2.5,
        suggestedRepsMin: suggestedRepsMin,
        suggestedRepsMax: suggestedRepsMax,
        recommendation: ProgressionRecommendation.increaseWeight,
        reason: 'Previous target achieved.',
      );
    }

    if (topSet.reps >= 8) {
      return ProgressionResult(
        lastWeight: topSet.weight,
        lastReps: topSet.reps,
        suggestedWeight: topSet.weight,
        suggestedRepsMin: suggestedRepsMin,
        suggestedRepsMax: suggestedRepsMax,
        recommendation: ProgressionRecommendation.maintainWeight,
        reason: 'Build reps at the current weight.',
      );
    }

    return ProgressionResult(
      lastWeight: topSet.weight,
      lastReps: topSet.reps,
      suggestedWeight: topSet.weight,
      suggestedRepsMin: suggestedRepsMin,
      suggestedRepsMax: suggestedRepsMax,
      recommendation: ProgressionRecommendation.repeatWeight,
      reason: 'Repeat the current weight.',
    );
  }

  static TrainingSet _topSet(List<TrainingSet> sets) {
    return sets.reduce((current, candidate) {
      if (candidate.weight > current.weight) return candidate;
      if (candidate.weight == current.weight && candidate.reps > current.reps) {
        return candidate;
      }
      return current;
    });
  }
}
