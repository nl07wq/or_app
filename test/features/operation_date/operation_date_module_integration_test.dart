import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/models/activity_data.dart';
import 'package:or_app/core/models/food_item.dart';
import 'package:or_app/core/models/meal_data.dart';
import 'package:or_app/core/models/morning_data.dart';
import 'package:or_app/core/models/training_session_v2.dart';
import 'package:or_app/core/models/work_type.dart';
import 'package:or_app/core/repositories/food_repository.dart';
import 'package:or_app/core/repositories/morning_repository.dart';
import 'package:or_app/core/repositories/training_repository.dart';
import 'package:or_app/core/services/app_clock.dart';
import 'package:or_app/core/services/daily_log_confirmation_state.dart';
import 'package:or_app/core/services/daily_state_restore_service.dart';
import 'package:or_app/core/state/app_initialization_state.dart';
import 'package:or_app/features/activity/activity_entry_page.dart';
import 'package:or_app/features/activity/models/activity_summary_state.dart';
import 'package:or_app/features/activity/repository/activity_repository.dart';
import 'package:or_app/features/food/models/food_summary_state.dart';
import 'package:or_app/features/food/services/food_submit_service.dart';
import 'package:or_app/features/morning/models/morning_fact_state.dart';
import 'package:or_app/features/morning/services/morning_submit_service.dart';
import 'package:or_app/features/operation_date/models/operation_local_date.dart';
import 'package:or_app/features/operation_date/models/operation_state.dart';
import 'package:or_app/features/operation_date/repository/operation_state_repository.dart';
import 'package:or_app/features/operation_date/services/operation_date_service.dart';
import 'package:or_app/features/repositories/app_repository_container.dart';
import 'package:or_app/features/training/models/training_summary_state.dart';
import 'package:or_app/features/training/training_entry_page.dart';
import 'package:or_app/features/training/widgets/training_session_v2_form.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../repositories/indexed_db/fake_indexed_db_database.dart';
import 'operation_date_test_fixture.dart';

void main() {
  const operationLocalDate = '2026-07-31';
  final deviceDate = DateTime(2026, 8, 1, 9);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppClock.setSystemNowForTesting(() => deviceDate);
    DailyStateRestoreService.resetForTesting();
  });

  tearDown(() {
    AppClock.resetForTesting();
    DailyStateRestoreService.resetForTesting();
    AppRepositoryRegistry.resetForTesting();
  });

  test('new STATUS and FOOD records use the Operation Date', () async {
    final operationDateService = await operationDateServiceFor(
      operationLocalDate,
    );
    final statusError = await MorningSubmitService.submit(
      workType: WorkType.holiday,
      sleepType: SleepType.sleep,
      weightText: '80',
      bodyFatText: '20',
      sleepText: '7:30',
      sleepScoreText: '80',
      footPainText: '1',
      workStart: '',
      workEnd: '',
      workBreak: '',
      memo: '',
      operationDateService: operationDateService,
    );
    await FoodSubmitService.save(
      const MealData(
        date: '2026-08-01',
        mealType: 'Breakfast',
        items: [
          FoodItem(
            name: 'Meal',
            calories: 500,
            protein: 30,
            fat: 10,
            carbohydrate: 60,
          ),
        ],
        memo: '',
        id: 'device-time-id',
      ),
      operationDateService: operationDateService,
    );

    expect(statusError, isNull);
    expect(
      (await MorningRepository.getAll()).single.date.substring(0, 10),
      operationLocalDate,
    );
    final food = (await FoodRepository.getAll()).single;
    expect(food.date, operationLocalDate);
    expect(food.id, 'device-time-id');
  });

  testWidgets('new TRAINING and ACTIVITY default to the Operation Date', (
    tester,
  ) async {
    final database = FakeIndexedDbDatabase();
    seedOperationState(database, operationLocalDate);
    final controller = AppInitializationController()..markReady();
    AppRepositoryRegistry.beginStartup(controller: controller);
    AppRepositoryRegistry.install(AppRepositoryContainer.indexedDb(database));

    await tester.pumpWidget(const MaterialApp(home: TrainingEntryPage()));
    await tester.pumpAndSettle();
    final trainingForm = tester.widget<TrainingSessionV2Form>(
      find.byType(TrainingSessionV2Form),
    );
    expect(trainingForm.controller.date.substring(0, 10), operationLocalDate);

    await tester.pumpWidget(const MaterialApp(home: ActivityEntryPage()));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('SAVE DRAFT'));
    await tester.tap(find.text('SAVE DRAFT'));
    await tester.pumpAndSettle();

    final operationDraft = await AppRepositoryRegistry.container.activityDrafts
        .findByDate(DateTime.parse(operationLocalDate));
    final deviceDraft = await AppRepositoryRegistry.container.activityDrafts
        .findByDate(deviceDate);
    expect(operationDraft?.localDate, operationLocalDate);
    expect(deviceDraft, isNull);
  });

  test('explicit summary dates do not use the device date', () async {
    SharedPreferences.setMockInitialValues({
      'morning_records': [
        _status('2026-07-31', weight: 80).toJsonString(),
        _status('2026-08-01', weight: 90).toJsonString(),
      ],
      'meal_records': [
        _meal('operation-meal', operationLocalDate, 500).toJsonString(),
        _meal('device-meal', '2026-08-01', 900).toJsonString(),
      ],
    });

    await refreshMorningFact(localDate: operationLocalDate);
    await refreshFoodSummary(localDate: operationLocalDate);

    expect(morningFactNotifier.value?.weight, 80);
    expect(foodSummaryNotifier.value?.calories, 500);
  });

  test(
    'Daily State Restore uses one Operation Date for every module',
    () async {
      final database = FakeIndexedDbDatabase();
      seedOperationState(database, operationLocalDate);
      final controller = AppInitializationController()..markReady();
      AppRepositoryRegistry.beginStartup(controller: controller);
      AppRepositoryRegistry.install(AppRepositoryContainer.indexedDb(database));

      await MorningRepository.save(_status(operationLocalDate, weight: 80));
      await FoodRepository.save(_meal('meal', operationLocalDate, 500));
      await TrainingRepository.saveNewV2(
        TrainingSessionV2(date: '${operationLocalDate}T10:00:00'),
      );
      await const LocalActivityRepository().save(
        ActivityData(
          date: DateTime.parse(operationLocalDate),
          measuredSteps: 8000,
          carryOver: 0,
        ),
      );

      await DailyStateRestoreService.restore();

      expect(
        morningFactNotifier.value?.date.toIso8601String().substring(0, 10),
        operationLocalDate,
      );
      expect(foodSummaryNotifier.value?.calories, 500);
      expect(trainingSummaryNotifier.value?.completed, isTrue);
      expect(activitySummaryNotifier.value.steps, 8000);
      expect(
        dailyLogConfirmationNotifier.value.date,
        DateTime.parse(operationLocalDate),
      );
    },
  );

  test(
    'Daily State Restore resolves the Operation Date exactly once',
    () async {
      final repository = _CountingOperationStateRepository(operationLocalDate);

      await DailyStateRestoreService.restore(
        operationDateService: OperationDateService(repository),
      );

      expect(repository.requireCurrentCalls, 1);
    },
  );

  test(
    'missing Operation State fails without a device-date fallback',
    () async {
      await expectLater(
        DailyStateRestoreService.restore(),
        throwsA(isA<StateError>()),
      );
    },
  );
}

MorningData _status(String localDate, {required double weight}) => MorningData(
  date: '${localDate}T08:00:00',
  weight: weight,
  bodyFat: 20,
  sleepHours: 7.5,
  sleepScore: 80,
  footPain: 1,
  workType: WorkType.holiday,
  workStart: '',
  workEnd: '',
  workBreak: '',
  workHours: 0,
  memo: '',
);

MealData _meal(String id, String localDate, double calories) => MealData(
  date: localDate,
  mealType: 'Breakfast',
  items: [
    FoodItem(
      name: id,
      calories: calories,
      protein: 30,
      fat: 10,
      carbohydrate: 60,
    ),
  ],
  memo: '',
  id: id,
);

extension on MorningData {
  String toJsonString() => _encode(toJson());
}

extension on MealData {
  String toJsonString() => _encode(toJson());
}

String _encode(Object? value) {
  // Keep compatibility storage fixtures local to this integration test.
  return const JsonEncoder().convert(value);
}

class _CountingOperationStateRepository implements OperationStateRepository {
  final OperationState state;
  int requireCurrentCalls = 0;

  _CountingOperationStateRepository(String localDate)
    : state = OperationState(
        operationDate: OperationLocalDate.parse(localDate),
        createdAt: DateTime.utc(2026, 7, 31),
        updatedAt: DateTime.utc(2026, 7, 31),
      );

  @override
  Future<OperationState> requireCurrent() async {
    requireCurrentCalls++;
    return state;
  }

  @override
  Future<OperationState?> findCurrent() async => state;

  @override
  Future<OperationState> validateCurrent() async => state;

  @override
  Future<OperationState> createInitial(OperationLocalDate operationDate) =>
      throw UnimplementedError();

  @override
  Future<OperationState> save(
    OperationState state, {
    required int expectedRevision,
  }) => throw UnimplementedError();

  @override
  Future<OperationState> compareAndSaveRevision(
    OperationState state, {
    required int expectedRevision,
  }) => throw UnimplementedError();
}
