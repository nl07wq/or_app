import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/models/training_set.dart';
import 'package:or_app/core/models/training_set_v2.dart';
import 'package:or_app/features/training/models/progression_result.dart';
import 'package:or_app/features/training/services/training_v2_entry_insight_service.dart';

import 'training_v2_calculation_test_fixture.dart';

void main() {
  test('entry insights reuse v2 main-set calculation contracts', () {
    final previous = v2Record(
      id: 'training:previous',
      localDate: '2026-07-28',
      createdAt: DateTime.utc(2026, 7, 28, 12),
      exercises: [
        v2Exercise(
          sets: [
            v2Set(
              setNo: 1,
              type: TrainingSetType.warmUp,
              weight: 999,
              reps: 99,
            ),
            v2Set(setNo: 2, type: TrainingSetType.main, weight: 80, reps: 10),
            v2Set(
              setNo: 3,
              type: TrainingSetType.legacyUnknown,
              weight: 1000,
              reps: 100,
            ),
          ],
        ),
      ],
    );
    final otherEquipment = v2Record(
      id: 'training:other-equipment',
      localDate: '2026-07-29',
      createdAt: DateTime.utc(2026, 7, 29, 12),
      exercises: [
        v2Exercise(
          equipmentId: 'smith_machine',
          equipmentName: 'Smith Machine',
          sets: [
            v2Set(setNo: 1, type: TrainingSetType.main, weight: 500, reps: 10),
          ],
        ),
      ],
    );
    final legacy = v1Record(
      id: 'training:legacy',
      localDate: '2026-07-29',
      createdAt: DateTime.utc(2026, 7, 29, 13),
      sets: const [TrainingSet(setNo: 1, weight: 600, reps: 10)],
    );
    final current = v2Exercise(
      sets: [
        v2Set(setNo: 1, type: TrainingSetType.warmUp, weight: 100, reps: 20),
        v2Set(setNo: 2, type: TrainingSetType.main, weight: 82.5, reps: 8),
      ],
    );

    final insights = TrainingV2EntryInsightService.calculate(
      preferredRecords: [previous, otherEquipment, legacy],
      currentExercise: current,
      sessionDate: '2026-07-30T12:00:00',
    );

    expect(insights.statistics.mainSetCount, 1);
    expect(insights.statistics.totalReps, 8);
    expect(insights.statistics.totalVolume, 660);
    expect(insights.previous?.record.id, previous.id);
    expect(insights.previous?.statistics.mainSetCount, 1);
    expect(insights.progression?.lastWeight, 80);
    expect(insights.progression?.lastReps, 10);
    expect(
      insights.progression?.recommendation,
      ProgressionRecommendation.increaseWeight,
    );
    expect(insights.personalRecord?.highestWeight, 80);
    expect(insights.personalRecord?.highestRepetitions, 10);
  });

  test('entry insights remain neutral without valid main-set history', () {
    final current = v2Exercise(sets: const []);

    final insights = TrainingV2EntryInsightService.calculate(
      preferredRecords: const [],
      currentExercise: current,
      sessionDate: '2026-07-30T12:00:00',
    );

    expect(insights.statistics.mainSetCount, 0);
    expect(insights.previous, isNull);
    expect(insights.progression, isNull);
    expect(insights.personalRecord, isNull);
  });
}
