import '../../../core/models/training_set_v2.dart';
import '../models/progression_result.dart';
import '../models/training_record_read_model.dart';
import 'training_exercise_identity.dart';
import 'training_v2_previous_service.dart';

abstract final class TrainingV2ProgressionService {
  static ProgressionResult? forRecord({
    required Iterable<TrainingRecordReadModel> preferredRecords,
    required TrainingRecordReadModel targetRecord,
    required TrainingExerciseIdentity identity,
  }) {
    final previous = TrainingV2PreviousService.find(
      preferredRecords: preferredRecords,
      targetRecord: targetRecord,
      identity: identity,
    );
    final topSet = previous?.statistics.topSet;
    return topSet == null ? null : evaluate(topSet);
  }

  static ProgressionResult evaluate(TrainingSetV2 topSet) {
    if (topSet.setType != TrainingSetType.main) {
      throw ArgumentError.value(
        topSet.setType,
        'topSet',
        'Progression requires a Main Set.',
      );
    }
    const suggestedRepsMin = 8;
    const suggestedRepsMax = 10;
    if (topSet.reps >= 10) {
      return ProgressionResult(
        lastWeight: topSet.weightKg,
        lastReps: topSet.reps,
        suggestedWeight: topSet.weightKg + 2.5,
        suggestedRepsMin: suggestedRepsMin,
        suggestedRepsMax: suggestedRepsMax,
        recommendation: ProgressionRecommendation.increaseWeight,
        reason: 'Previous target achieved.',
      );
    }
    if (topSet.reps >= 8) {
      return ProgressionResult(
        lastWeight: topSet.weightKg,
        lastReps: topSet.reps,
        suggestedWeight: topSet.weightKg,
        suggestedRepsMin: suggestedRepsMin,
        suggestedRepsMax: suggestedRepsMax,
        recommendation: ProgressionRecommendation.maintainWeight,
        reason: 'Build reps at the current weight.',
      );
    }
    return ProgressionResult(
      lastWeight: topSet.weightKg,
      lastReps: topSet.reps,
      suggestedWeight: topSet.weightKg,
      suggestedRepsMin: suggestedRepsMin,
      suggestedRepsMax: suggestedRepsMax,
      recommendation: ProgressionRecommendation.repeatWeight,
      reason: 'Repeat the current weight.',
    );
  }
}
