import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/models/activity_data.dart';
import 'package:or_app/core/models/food_item.dart';
import 'package:or_app/core/models/meal_data.dart';
import 'package:or_app/core/models/morning_data.dart';
import 'package:or_app/core/models/work_type.dart';
import 'package:or_app/features/command_center/models/daily_assessment.dart';
import 'package:or_app/features/command_center/services/daily_assessment_fact_loader.dart';
import 'package:or_app/features/daily_aggregate/models/daily_aggregate_v1.dart';
import 'package:or_app/features/operation_date/models/operation_local_date.dart';
import 'package:or_app/features/operation_date/models/operation_state.dart';
import 'package:or_app/features/repositories/app_repository_container.dart';

import '../../repositories/indexed_db/fake_indexed_db_database.dart';

void main() {
  test('uses only current-day facts before finalize and after undo', () async {
    final container = AppRepositoryContainer.indexedDb(FakeIndexedDbDatabase());
    await container.dailyAggregates.put(_previousAggregate());
    final finalizedState = _state(lastFinalizedDate: '2026-08-09');
    final loader = DailyAssessmentFactLoader(
      container,
      clock: () => DateTime.parse('2026-08-10T12:00:00+09:00'),
    );

    final missing = await loader.load(finalizedState);
    expect(missing.currentCalorieBalanceKcal, isNull);
    expect(missing.currentProteinG, isNull);
    expect(missing.currentHydrationMl, isNull);
    expect(missing.currentOfficialSteps, isNull);
    expect(
      missing.currentWeightReference.source,
      DailyWeightReferenceSource.notAvailable,
    );

    await container.status.save(_status());
    await container.food.save(_meal());
    await container.food.save(_water());
    await container.activity.save(
      ActivityData(date: DateTime(2026, 8, 10), measuredSteps: 6000),
    );

    final beforeFinalize = await loader.load(finalizedState);
    expect(beforeFinalize.currentCalorieBalanceKcal, isNotNull);
    expect(beforeFinalize.currentCalorieBalanceKcal, isNot(1216));
    expect(beforeFinalize.currentProteinG, 50);
    expect(beforeFinalize.currentHydrationMl, 750);
    expect(beforeFinalize.currentOfficialSteps, 6000);
    expect(beforeFinalize.currentWeightReference.valueKg, 80);
    expect(
      beforeFinalize.currentWeightReference.source,
      DailyWeightReferenceSource.measuredToday,
    );
    expect(
      beforeFinalize.currentWeightReference.previousFormalWeightKg,
      isNull,
    );

    final afterUndo = await loader.load(_state());
    expect(
      afterUndo.currentCalorieBalanceKcal,
      beforeFinalize.currentCalorieBalanceKcal,
    );
    expect(afterUndo.currentProteinG, 50);
    expect(afterUndo.currentHydrationMl, 750);
    expect(afterUndo.currentOfficialSteps, 6000);
  });

  test('resolves the latest prior formal STATUS weight only', () async {
    final container = AppRepositoryContainer.indexedDb(FakeIndexedDbDatabase());
    await container.status.save(_status(date: '2026-08-01', weight: 95));
    await container.status.save(_status(date: '2026-08-09', weight: 94.5));
    await container.status.save(_status(weight: 94.2));
    await container.status.save(_status(date: '2026-08-11', weight: 70));

    final facts = await DailyAssessmentFactLoader(container).load(_state());

    expect(facts.currentWeightReference.valueKg, 94.2);
    expect(facts.currentWeightReference.previousFormalWeightKg, 94.5);
  });

  test('keeps missing current-day facts independent', () async {
    final container = AppRepositoryContainer.indexedDb(FakeIndexedDbDatabase());
    await container.food.save(_meal());

    final facts = await DailyAssessmentFactLoader(container).load(_state());

    expect(facts.currentProteinG, 50);
    expect(facts.currentHydrationMl, isNull);
    expect(facts.currentOfficialSteps, isNull);
    expect(facts.currentCalorieBalanceKcal, isNull);
  });

  test('loads valid weight history from the final 28 calendar days', () async {
    final container = AppRepositoryContainer.indexedDb(FakeIndexedDbDatabase());
    await container.status.save(_status(date: '2026-07-13', weight: 120));
    for (var index = 0; index < 14; index++) {
      final date = DateTime.utc(2026, 7, 15).add(Duration(days: index * 2));
      await container.status.save(
        _status(
          date:
              '${date.year.toString().padLeft(4, '0')}-'
              '${date.month.toString().padLeft(2, '0')}-'
              '${date.day.toString().padLeft(2, '0')}',
          weight: 90 - index / 10,
        ),
      );
    }

    final facts = await DailyAssessmentFactLoader(container).load(_state());
    final validWeights = facts.weightHistory
        .where((point) => point.weightKg != null)
        .toList();

    expect(validWeights, hasLength(14));
    expect(validWeights.first.operationDate, '2026-07-15');
    expect(validWeights.last.operationDate, '2026-08-10');
    expect(validWeights.map((point) => point.weightKg), isNot(contains(120)));
  });

  test('uses a bounded mean only when current-day weight is missing', () async {
    final container = AppRepositoryContainer.indexedDb(FakeIndexedDbDatabase());
    await container.status.save(_status(date: '2026-08-07', weight: 80));
    await container.status.save(_status(date: '2026-08-08', weight: 82));
    await container.status.save(_status(date: '2026-08-09', weight: 84));
    await container.status.save(_status(weight: null));

    final facts = await DailyAssessmentFactLoader(container).load(_state());

    expect(facts.currentWeightReference.valueKg, 82);
    expect(
      facts.currentWeightReference.source,
      DailyWeightReferenceSource.sevenDayMean,
    );
    expect(facts.currentStatus?.weight, isNull);
  });

  test(
    'uses fourteen-day mean after seven-day reference is insufficient',
    () async {
      final container = AppRepositoryContainer.indexedDb(
        FakeIndexedDbDatabase(),
      );
      await container.status.save(_status(date: '2026-07-30', weight: 80));
      await container.status.save(_status(date: '2026-08-01', weight: 82));
      await container.status.save(_status(date: '2026-08-03', weight: 84));
      await container.status.save(_status(weight: null));

      final facts = await DailyAssessmentFactLoader(container).load(_state());

      expect(facts.currentWeightReference.valueKg, 82);
      expect(
        facts.currentWeightReference.source,
        DailyWeightReferenceSource.fourteenDayMean,
      );
    },
  );

  test(
    'reports unavailable when STATUS exists without a valid reference',
    () async {
      final container = AppRepositoryContainer.indexedDb(
        FakeIndexedDbDatabase(),
      );
      await container.status.save(_status(date: '2026-08-08', weight: 80));
      await container.status.save(_status(date: '2026-08-09', weight: 82));
      await container.status.save(_status(weight: null));

      final facts = await DailyAssessmentFactLoader(container).load(_state());

      expect(facts.currentStatus, isNotNull);
      expect(facts.currentWeightReference.valueKg, isNull);
      expect(
        facts.currentWeightReference.source,
        DailyWeightReferenceSource.notAvailable,
      );
    },
  );

  test(
    'does not use historical fallback when the current STATUS record is absent',
    () async {
      final container = AppRepositoryContainer.indexedDb(
        FakeIndexedDbDatabase(),
      );
      await container.status.save(_status(date: '2026-08-07', weight: 80));
      await container.status.save(_status(date: '2026-08-08', weight: 82));
      await container.status.save(_status(date: '2026-08-09', weight: 84));

      final facts = await DailyAssessmentFactLoader(container).load(_state());

      expect(facts.currentStatus, isNull);
      expect(facts.currentWeightReference.valueKg, isNull);
      expect(
        facts.currentWeightReference.source,
        DailyWeightReferenceSource.notAvailable,
      );
    },
  );
}

OperationState _state({String? lastFinalizedDate}) {
  final timestamp = DateTime.utc(2026, 8, 10);
  return OperationState(
    operationDate: OperationLocalDate.parse('2026-08-10'),
    lastFinalizedDate: lastFinalizedDate == null
        ? null
        : OperationLocalDate.parse(lastFinalizedDate),
    createdAt: timestamp,
    updatedAt: timestamp,
  );
}

MorningData _status({String date = '2026-08-10', double? weight = 80}) =>
    MorningData(
      date: date,
      weight: weight,
      bodyFat: 20,
      sleepHours: 7,
      sleepScore: 80,
      footPain: 2,
      workType: WorkType.holiday,
      workStart: '',
      workEnd: '',
      workBreak: '',
      workHours: 0,
      memo: '',
    );

MealData _meal() => const MealData(
  date: '2026-08-10',
  mealType: 'Lunch',
  items: [
    FoodItem(
      name: 'Meal',
      calories: 600,
      protein: 50,
      fat: 20,
      carbohydrate: 70,
    ),
  ],
  memo: '',
  id: 'meal-current',
);

MealData _water() => const MealData(
  date: '2026-08-10',
  mealType: 'Water',
  items: [],
  memo: '',
  id: 'water-current',
  waterMl: 750,
);

DailyAggregateV1 _previousAggregate() => const DailyAggregateV1(
  operationDate: '2026-08-09',
  weightKg: null,
  bodyFatPercent: null,
  sleepDurationMinutes: null,
  sleepScore: null,
  sleepType: null,
  plantarFasciitisLevel: null,
  workStartTime: null,
  workEndTime: null,
  workBreakMinutes: null,
  actualWorkMinutes: null,
  intakeCaloriesKcal: null,
  estimatedCalorieBalanceKcal: 1216,
  proteinG: 139.7,
  fatG: null,
  carbsG: null,
  hydrationMl: 3250,
  officialSteps: 21930,
  measuredSteps: null,
  trainingPerformed: false,
  digestiveCount: null,
  sourceType: DailyAggregateSourceType.records,
);
