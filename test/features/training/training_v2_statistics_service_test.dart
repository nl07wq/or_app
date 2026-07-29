import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/models/training_set_v2.dart';
import 'package:or_app/features/training/services/training_v2_statistics_service.dart';

import 'training_v2_calculation_test_fixture.dart';

void main() {
  test('calculates only Main Sets', () {
    final result = TrainingV2StatisticsService.calculate(
      v2Exercise(
        sets: [
          v2Set(setNo: 1, type: TrainingSetType.warmUp, weight: 200, reps: 20),
          v2Set(setNo: 2, type: TrainingSetType.main, weight: 80, reps: 10),
          v2Set(setNo: 3, type: TrainingSetType.main, weight: 90, reps: 8),
          v2Set(
            setNo: 4,
            type: TrainingSetType.legacyUnknown,
            weight: 300,
            reps: 30,
          ),
        ],
      ),
    );

    expect(result.mainSetCount, 2);
    expect(result.totalReps, 18);
    expect(result.totalVolume, 1520);
    expect(result.averageWeight, 85);
    expect(result.heaviestSet?.weightKg, 90);
    expect(result.topSet, same(result.heaviestSet));
  });

  test('returns nullable weight metrics when there are no Main Sets', () {
    final result = TrainingV2StatisticsService.calculate(
      v2Exercise(
        sets: [
          v2Set(setNo: 1, type: TrainingSetType.warmUp, weight: 20, reps: 10),
          v2Set(
            setNo: 2,
            type: TrainingSetType.legacyUnknown,
            weight: 30,
            reps: 10,
          ),
        ],
      ),
    );

    expect(result.mainSetCount, 0);
    expect(result.totalReps, 0);
    expect(result.totalVolume, 0);
    expect(result.averageWeight, isNull);
    expect(result.heaviestSet, isNull);
  });

  test('uses reps then lower set number for equal-weight tie breaks', () {
    final result = TrainingV2StatisticsService.calculate(
      v2Exercise(
        sets: [
          v2Set(setNo: 3, type: TrainingSetType.main, weight: 100, reps: 8),
          v2Set(setNo: 2, type: TrainingSetType.main, weight: 100, reps: 10),
          v2Set(setNo: 1, type: TrainingSetType.main, weight: 100, reps: 10),
        ],
      ),
    );

    expect(result.heaviestSet?.setNo, 1);
    expect(result.heaviestSet?.reps, 10);
  });

  test('allows zero weight without inventing volume', () {
    final result = TrainingV2StatisticsService.calculate(
      v2Exercise(
        sets: [
          v2Set(setNo: 1, type: TrainingSetType.main, weight: 0, reps: 20),
        ],
      ),
    );

    expect(result.totalVolume, 0);
    expect(result.averageWeight, 0);
    expect(result.totalReps, 20);
  });
}
