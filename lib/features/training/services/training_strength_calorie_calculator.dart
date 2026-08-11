import '../../../core/models/training_session_v2.dart';

enum TrainingStrengthCalculationFailure {
  missingTime,
  missingStatusWeight,
  invalidWeight,
}

class TrainingStrengthCalorieResult {
  final double? estimatedCaloriesKcal;
  final double? weightSnapshotKg;
  final String? calculationMethod;
  final int? calculationVersion;
  final TrainingStrengthCalculationFailure? failureReason;

  const TrainingStrengthCalorieResult._({
    required this.estimatedCaloriesKcal,
    required this.weightSnapshotKg,
    required this.calculationMethod,
    required this.calculationVersion,
    required this.failureReason,
  });

  const TrainingStrengthCalorieResult.computed({
    required double estimatedCaloriesKcal,
    required double weightSnapshotKg,
  }) : this._(
         estimatedCaloriesKcal: estimatedCaloriesKcal,
         weightSnapshotKg: weightSnapshotKg,
         calculationMethod: TrainingSessionV2.strengthCalculationMethodId,
         calculationVersion: TrainingSessionV2.strengthCalculationVersionValue,
         failureReason: null,
       );

  const TrainingStrengthCalorieResult.uncomputed(
    TrainingStrengthCalculationFailure reason,
  ) : this._(
        estimatedCaloriesKcal: null,
        weightSnapshotKg: null,
        calculationMethod: null,
        calculationVersion: null,
        failureReason: reason,
      );

  bool get isComputed => estimatedCaloriesKcal != null;
}

abstract final class TrainingStrengthCalorieCalculator {
  static TrainingStrengthCalorieResult calculate({
    required TrainingSessionV2 session,
    required double? weightKg,
  }) {
    final duration = session.strengthDuration;
    if (duration == null) {
      return const TrainingStrengthCalorieResult.uncomputed(
        TrainingStrengthCalculationFailure.missingTime,
      );
    }
    if (weightKg == null) {
      return const TrainingStrengthCalorieResult.uncomputed(
        TrainingStrengthCalculationFailure.missingStatusWeight,
      );
    }
    if (!weightKg.isFinite || weightKg <= 0) {
      return const TrainingStrengthCalorieResult.uncomputed(
        TrainingStrengthCalculationFailure.invalidWeight,
      );
    }
    final calories =
        TrainingSessionV2.strengthMets *
        3.5 *
        weightKg /
        200 *
        (duration.inMilliseconds / Duration.millisecondsPerMinute);
    return TrainingStrengthCalorieResult.computed(
      estimatedCaloriesKcal: calories,
      weightSnapshotKg: weightKg,
    );
  }
}
