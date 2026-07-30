enum TrainingCardioCalculationFailure {
  missingMets,
  missingDuration,
  missingStatusWeight,
  invalidMets,
  invalidDuration,
  invalidWeight,
}

class TrainingCardioCalorieResult {
  final double? estimatedCaloriesKcal;
  final double? weightSnapshotKg;
  final String? calculationMethod;
  final int? calculationVersion;
  final TrainingCardioCalculationFailure? failureReason;

  const TrainingCardioCalorieResult._({
    required this.estimatedCaloriesKcal,
    required this.weightSnapshotKg,
    required this.calculationMethod,
    required this.calculationVersion,
    required this.failureReason,
  });

  const TrainingCardioCalorieResult.computed({
    required double estimatedCaloriesKcal,
    required double weightSnapshotKg,
  }) : this._(
         estimatedCaloriesKcal: estimatedCaloriesKcal,
         weightSnapshotKg: weightSnapshotKg,
         calculationMethod: TrainingCardioCalorieCalculator.method,
         calculationVersion: TrainingCardioCalorieCalculator.version,
         failureReason: null,
       );

  const TrainingCardioCalorieResult.uncomputed(
    TrainingCardioCalculationFailure reason,
  ) : this._(
        estimatedCaloriesKcal: null,
        weightSnapshotKg: null,
        calculationMethod: null,
        calculationVersion: null,
        failureReason: reason,
      );

  bool get isComputed => estimatedCaloriesKcal != null;
}

abstract final class TrainingCardioCalorieCalculator {
  static const method = 'metsAcsmV1';
  static const version = 1;

  static TrainingCardioCalorieResult calculate({
    required double? mets,
    required int? durationSeconds,
    required double? weightKg,
  }) {
    if (mets == null) {
      return const TrainingCardioCalorieResult.uncomputed(
        TrainingCardioCalculationFailure.missingMets,
      );
    }
    if (durationSeconds == null) {
      return const TrainingCardioCalorieResult.uncomputed(
        TrainingCardioCalculationFailure.missingDuration,
      );
    }
    if (weightKg == null) {
      return const TrainingCardioCalorieResult.uncomputed(
        TrainingCardioCalculationFailure.missingStatusWeight,
      );
    }
    if (!mets.isFinite || mets <= 0) {
      return const TrainingCardioCalorieResult.uncomputed(
        TrainingCardioCalculationFailure.invalidMets,
      );
    }
    if (durationSeconds <= 0) {
      return const TrainingCardioCalorieResult.uncomputed(
        TrainingCardioCalculationFailure.invalidDuration,
      );
    }
    if (!weightKg.isFinite || weightKg <= 0) {
      return const TrainingCardioCalorieResult.uncomputed(
        TrainingCardioCalculationFailure.invalidWeight,
      );
    }
    final durationMinutes = durationSeconds / 60;
    final calories = mets * 3.5 * weightKg / 200 * durationMinutes;
    return TrainingCardioCalorieResult.computed(
      estimatedCaloriesKcal: calories,
      weightSnapshotKg: weightKg,
    );
  }
}
