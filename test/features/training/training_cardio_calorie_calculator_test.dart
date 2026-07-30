import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/training/services/training_cardio_calorie_calculator.dart';

void main() {
  test('calculates the formal METs ACSM value without rounding', () {
    final result = TrainingCardioCalorieCalculator.calculate(
      mets: 4,
      durationSeconds: 300,
      weightKg: 96.8,
    );

    expect(result.isComputed, isTrue);
    expect(result.estimatedCaloriesKcal, closeTo(33.88, 1e-12));
    expect(result.weightSnapshotKg, 96.8);
    expect(result.calculationMethod, TrainingCardioCalorieCalculator.method);
    expect(result.calculationVersion, TrainingCardioCalorieCalculator.version);
  });

  test('distinguishes missing inputs', () {
    expect(
      TrainingCardioCalorieCalculator.calculate(
        mets: null,
        durationSeconds: 300,
        weightKg: 96.8,
      ).failureReason,
      TrainingCardioCalculationFailure.missingMets,
    );
    expect(
      TrainingCardioCalorieCalculator.calculate(
        mets: 4,
        durationSeconds: null,
        weightKg: 96.8,
      ).failureReason,
      TrainingCardioCalculationFailure.missingDuration,
    );
    expect(
      TrainingCardioCalorieCalculator.calculate(
        mets: 4,
        durationSeconds: 300,
        weightKg: null,
      ).failureReason,
      TrainingCardioCalculationFailure.missingStatusWeight,
    );
  });

  test('rejects zero, negative, and non-finite values', () {
    expect(
      TrainingCardioCalorieCalculator.calculate(
        mets: 0,
        durationSeconds: 300,
        weightKg: 96.8,
      ).failureReason,
      TrainingCardioCalculationFailure.invalidMets,
    );
    expect(
      TrainingCardioCalorieCalculator.calculate(
        mets: double.nan,
        durationSeconds: 300,
        weightKg: 96.8,
      ).failureReason,
      TrainingCardioCalculationFailure.invalidMets,
    );
    expect(
      TrainingCardioCalorieCalculator.calculate(
        mets: 4,
        durationSeconds: 0,
        weightKg: 96.8,
      ).failureReason,
      TrainingCardioCalculationFailure.invalidDuration,
    );
    expect(
      TrainingCardioCalorieCalculator.calculate(
        mets: 4,
        durationSeconds: 300,
        weightKg: double.infinity,
      ).failureReason,
      TrainingCardioCalculationFailure.invalidWeight,
    );
  });
}
