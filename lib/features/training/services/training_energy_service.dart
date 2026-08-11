import '../../../core/engine/training_summary.dart';
import '../../../core/models/training_session_v2.dart';
import '../models/training_record_read_model.dart';
import 'training_cardio_energy_service.dart';
import 'training_strength_calorie_calculator.dart';

class TrainingEnergySummary {
  final double? trainingEstimatedCaloriesKcal;
  final double? trainingStrengthCaloriesKcal;
  final double? trainingCardioCaloriesKcal;
  final TrainingEnergyCalculationStatus status;

  const TrainingEnergySummary({
    required this.trainingEstimatedCaloriesKcal,
    required this.trainingStrengthCaloriesKcal,
    required this.trainingCardioCaloriesKcal,
    required this.status,
  });
}

abstract final class TrainingEnergyService {
  static double? totalForSession(TrainingSessionV2 session) {
    final strength = session.estimatedStrengthCaloriesKcal;
    if (strength == null) return null;
    var total = strength;
    for (final entry in session.cardioEntries) {
      if (!TrainingCardioEnergyService.isFormalCalculation(entry)) return null;
      total += entry.estimatedCaloriesKcal!;
    }
    return total;
  }

  static bool requiresStatusWeight(TrainingSessionV2 session) {
    if (TrainingCardioEnergyService.requiresStatusWeight(session)) return true;
    return session.startTime != null &&
        session.endTime != null &&
        session.estimatedStrengthCaloriesKcal == null;
  }

  static TrainingSessionV2 applyForSave({
    required TrainingSessionV2 session,
    required double? statusWeightKg,
  }) {
    final withCardio = TrainingCardioEnergyService.applyForSave(
      session: session,
      statusWeightKg: statusWeightKg,
    );
    if (withCardio.estimatedStrengthCaloriesKcal != null) return withCardio;
    final result = TrainingStrengthCalorieCalculator.calculate(
      session: withCardio,
      weightKg: statusWeightKg,
    );
    return _withStrength(withCardio, result);
  }

  static TrainingEnergySummary summarize({
    required Iterable<TrainingRecordReadModel> preferredRecords,
    required String localDate,
  }) {
    final records = preferredRecords
        .where((record) => record.localDate == localDate)
        .toList(growable: false);
    final cardio = TrainingCardioEnergyService.summarize(
      preferredRecords: records,
      localDate: localDate,
    );
    var computedStrengthCount = 0;
    var uncomputedStrengthCount = 0;
    var strengthCalories = 0.0;
    for (final record in records) {
      final calories = record.v2Data?.estimatedStrengthCaloriesKcal;
      if (calories == null) {
        uncomputedStrengthCount++;
      } else {
        computedStrengthCount++;
        strengthCalories += calories;
      }
    }
    final computed = computedStrengthCount + cardio.computedCardioCount;
    final uncomputed = uncomputedStrengthCount + cardio.uncomputedCardioCount;
    final status = uncomputed == 0
        ? TrainingEnergyCalculationStatus.complete
        : computed == 0
        ? TrainingEnergyCalculationStatus.notCalculated
        : TrainingEnergyCalculationStatus.partial;
    final knownTotal =
        strengthCalories + (cardio.trainingCardioCaloriesKcal ?? 0);
    return TrainingEnergySummary(
      trainingEstimatedCaloriesKcal: computed == 0 && uncomputed > 0
          ? null
          : knownTotal,
      trainingStrengthCaloriesKcal:
          computedStrengthCount == 0 && uncomputedStrengthCount > 0
          ? null
          : strengthCalories,
      trainingCardioCaloriesKcal: cardio.trainingCardioCaloriesKcal,
      status: status,
    );
  }

  static TrainingSessionV2 _withStrength(
    TrainingSessionV2 session,
    TrainingStrengthCalorieResult result,
  ) => TrainingSessionV2(
    date: session.date,
    startTime: session.startTime,
    endTime: session.endTime,
    sessionName: session.sessionName,
    sessionGrade: session.sessionGrade,
    memo: session.memo,
    dynamicStretchCompleted: session.dynamicStretchCompleted,
    cooldownStretchCompleted: session.cooldownStretchCompleted,
    overallEvaluation: session.overallEvaluation,
    estimatedStrengthCaloriesKcal: result.estimatedCaloriesKcal,
    strengthWeightSnapshotKg: result.weightSnapshotKg,
    strengthCalculationMethod: result.calculationMethod,
    strengthCalculationVersion: result.calculationVersion,
    exercises: session.exercises,
    cardioEntries: session.cardioEntries,
  );
}
