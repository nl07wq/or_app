import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/engine/activity_summary.dart';
import 'package:or_app/core/engine/digestive_summary.dart';
import 'package:or_app/core/engine/food_summary.dart';
import 'package:or_app/core/engine/training_summary.dart';
import 'package:or_app/core/models/activity_data.dart';
import 'package:or_app/core/models/digestive_event.dart';
import 'package:or_app/core/models/meal_data.dart';
import 'package:or_app/core/models/morning_data.dart';
import 'package:or_app/core/models/work_type.dart';
import 'package:or_app/core/services/daily_log_confirmation_service.dart';
import 'package:or_app/core/services/daily_log_confirmation_validation.dart';
import 'package:or_app/core/state/app_initialization_state.dart';
import 'package:or_app/features/morning/models/morning_fact.dart';
import 'package:or_app/features/repositories/app_repository_container.dart';
import 'package:or_app/features/food/services/food_summary_service.dart';

import '../../repositories/indexed_db/fake_indexed_db_database.dart';

void main() {
  test('STATUS record presence completes nullable STATUS', () {
    final missing = DailyLogConfirmationValidation.validate(
      morning: null,
      food: _food(meals: 1, waterRecorded: true),
      activity: _activity(digestive: _explicitZero()),
      training: null,
    );
    expect(
      missing.statusCompleteness.state,
      DailyLogCompletenessState.notRecorded,
    );
    expect(
      _validate(morning: _morning()).statusCompleteness.state,
      DailyLogCompletenessState.complete,
    );
  });

  test('FOOD completeness independently requires FOOD and WATER records', () {
    final neither = _validate(food: _food(meals: 0, waterRecorded: false));
    expect(
      neither.foodCompleteness.state,
      DailyLogCompletenessState.notRecorded,
    );
    expect(neither.foodCompleteness.missingRequirements, ['FOOD', 'WATER']);

    final foodOnly = _validate(food: _food(meals: 1, waterRecorded: false));
    expect(
      foodOnly.foodCompleteness.state,
      DailyLogCompletenessState.incomplete,
    );
    expect(foodOnly.foodCompleteness.missingRequirements, ['WATER']);

    final waterOnly = _validate(food: _food(meals: 0, waterRecorded: true));
    expect(
      waterOnly.foodCompleteness.state,
      DailyLogCompletenessState.incomplete,
    );
    expect(waterOnly.foodCompleteness.missingRequirements, ['FOOD']);

    final both = _validate(food: _food(meals: 1, waterRecorded: true));
    expect(both.foodCompleteness.state, DailyLogCompletenessState.complete);
  });

  test('formal zero WATER is recorded but does not imply goal achievement', () {
    final result = _validate(
      food: _food(meals: 1, waterRecorded: true, hydrationMl: 0),
    );
    expect(result.foodCompleteness.isComplete, isTrue);
    expect(result.foodValid, isTrue);
  });

  test('FoodSummaryService preserves explicit zero WATER record presence', () {
    final summary = FoodSummaryService.forLocalDate(const [
      MealData(
        id: 'meal',
        date: '2026-08-27',
        mealType: 'Dinner',
        items: [],
        memo: '',
      ),
      MealData(
        id: 'water-zero',
        date: '2026-08-27',
        mealType: 'Water',
        items: [],
        memo: '',
        waterMl: 0,
      ),
    ], '2026-08-27');

    expect(summary.hydrationMl, 0);
    expect(summary.waterRecorded, isTrue);
    expect(_validate(food: summary).foodValid, isTrue);
  });

  test('ACTIVITY independently requires STEPS and DIGESTIVE', () {
    final neither = _validate(activity: const ActivitySummary.empty());
    expect(
      neither.activityCompleteness.state,
      DailyLogCompletenessState.notRecorded,
    );
    expect(neither.activityCompleteness.missingRequirements, [
      'STEPS',
      'DIGESTIVE',
    ]);

    final stepsOnly = _validate(activity: _activity(digestive: null));
    expect(stepsOnly.activityCompleteness.missingRequirements, ['DIGESTIVE']);

    final digestiveOnly = _validate(
      activity: _activity(stepsRecorded: false, digestive: _explicitZero()),
    );
    expect(digestiveOnly.activityCompleteness.missingRequirements, ['STEPS']);

    final both = _validate(activity: _activity(digestive: _explicitZero()));
    expect(both.activityCompleteness.state, DailyLogCompletenessState.complete);
  });

  test('optional Training never blocks finalization', () {
    final missing = _validate();
    expect(missing.trainingRecorded, isFalse);
    expect(missing.canFinalize, isTrue);

    const invalidTraining = TrainingSummary(
      completed: false,
      exerciseCount: 0,
      setCount: 0,
      duration: null,
      sessionName: null,
    );
    final invalid = _validate(training: invalidTraining);
    expect(invalid.trainingValid, isFalse);
    expect(invalid.canFinalize, isTrue);
    expect(invalid.blockingModules, isEmpty);
  });

  test('service guard rejects a single missing WATER requirement', () async {
    appInitializationController.markReady();
    final container = AppRepositoryContainer.indexedDb(FakeIndexedDbDatabase());
    AppRepositoryRegistry.install(container);
    addTearDown(AppRepositoryRegistry.resetForTesting);

    await container.status.save(
      const MorningData(
        date: '2026-08-27',
        weight: null,
        bodyFat: null,
        sleepHours: null,
        sleepScore: null,
        footPain: 0,
        workType: WorkType.holiday,
        workStart: '',
        workEnd: '',
        workBreak: '',
        workHours: 0,
        memo: '',
      ),
    );
    await container.food.save(
      const MealData(
        id: 'meal',
        date: '2026-08-27',
        mealType: 'Dinner',
        items: [],
        memo: '',
      ),
    );
    await container.activity.save(
      ActivityData(
        date: DateTime(2026, 8, 27),
        measuredSteps: 0,
        digestiveEvents: [
          DigestiveEvent(
            id: 'digestive-none',
            sequence: 1,
            amount: 0,
            shape: null,
            relief: null,
            recordedAt: DateTime(2026, 8, 27, 20),
          ),
        ],
      ),
    );

    await expectLater(
      DailyLogConfirmationService.buildForLocalDate('2026-08-27'),
      throwsA(
        isA<DailyLogValidationException>().having(
          (error) => error.invalidModules,
          'invalidModules',
          [DailyLogModule.food],
        ),
      ),
    );
  });
}

DailyLogValidationResult _validate({
  MorningFact? morning,
  FoodSummary? food,
  ActivitySummary? activity,
  TrainingSummary? training,
}) => DailyLogConfirmationValidation.validate(
  morning: morning ?? _morning(),
  food: food ?? _food(meals: 1, waterRecorded: true),
  activity: activity ?? _activity(digestive: _explicitZero()),
  training: training,
);

MorningFact _morning() => MorningFact(
  date: DateTime(2026, 8, 27),
  weight: null,
  bodyFat: null,
  sleepDuration: null,
  sleepScore: null,
  workHours: 0,
  footPain: 0,
  medications: const [],
  freeNotes: null,
);

FoodSummary _food({
  required int meals,
  required bool waterRecorded,
  double hydrationMl = 500,
}) => FoodSummary(
  calories: 0,
  protein: 0,
  fat: 0,
  carbohydrates: 0,
  hydrationMl: hydrationMl,
  mealCount: meals,
  waterRecorded: waterRecorded,
);

ActivitySummary _activity({
  bool stepsRecorded = true,
  DigestiveSummary? digestive,
}) => ActivitySummary(
  steps: 0,
  measuredSteps: 0,
  isRecorded: true,
  digestiveSummary: digestive,
  calculationBasis: ActivityCalculationBasis(
    rawSteps: stepsRecorded ? 0 : null,
    currentCarryOver: 0,
    previousCarryOverDeduction: 0,
    officialSteps: stepsRecorded ? 0 : null,
  ),
);

DigestiveSummary _explicitZero() => DigestiveSummary(
  eventCount: 0,
  totalAmount: 0,
  latestShape: null,
  latestRelief: null,
  shapeTrend: const [],
  reliefTrend: const [],
  hasExplicitNoMovement: true,
);
