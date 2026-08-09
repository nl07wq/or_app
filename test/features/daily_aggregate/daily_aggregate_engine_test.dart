import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/models/activity_data.dart';
import 'package:or_app/core/models/digestive_event.dart';
import 'package:or_app/core/models/morning_data.dart';
import 'package:or_app/core/models/training_session_v2.dart';
import 'package:or_app/core/models/work_type.dart';
import 'package:or_app/features/activity/repository/activity_repository.dart';
import 'package:or_app/features/daily_aggregate/models/daily_aggregate_v1.dart';
import 'package:or_app/features/daily_aggregate/services/daily_aggregate_engine.dart';
import 'package:or_app/features/food/models/food_nutrition_aggregate.dart';
import 'package:or_app/features/food/models/food_unified_read_model.dart';
import 'package:or_app/features/food/models/nutrition_models.dart';
import 'package:or_app/features/status/repositories/status_repository.dart';
import 'package:or_app/features/training/models/training_record_read_model.dart';
import 'package:or_app/features/training/repository/training_session_repository.dart';

void main() {
  const date = '2026-08-09';

  test('builds one compressed daily aggregate from formal records', () async {
    final result = await _engine(
      status: _status(),
      food: [_meal(), _water(750)],
      activity: ActivityData(
        date: DateTime(2026, 8, 9),
        measuredSteps: 10000,
        carryOver: 100,
        digestiveEvents: [
          DigestiveEvent(
            id: 'digestive-1',
            sequence: 1,
            amount: 2,
            shape: 2,
            relief: 1,
            recordedAt: DateTime.utc(2026, 8, 9, 12),
          ),
        ],
      ),
      previousActivity: ActivityData(
        date: DateTime(2026, 8, 8),
        measuredSteps: 8000,
        carryOver: 50,
      ),
      training: [_trainingRecord()],
    ).build(date);

    expect(result.operationDate, date);
    expect(result.weightKg, 95.6);
    expect(result.bodyFatPercent, 32.5);
    expect(result.sleepDurationMinutes, 450);
    expect(result.sleepScore, 82);
    expect(result.sleepType, SleepType.sleep);
    expect(result.plantarFasciitisLevel, 2);
    expect(result.workStartTime, '09:00');
    expect(result.workEndTime, '18:00');
    expect(result.workBreakMinutes, 60);
    expect(result.actualWorkMinutes, 480);
    expect(result.intakeCaloriesKcal, 600);
    expect(result.proteinG, 45);
    expect(result.fatG, 20);
    expect(result.carbsG, 70);
    expect(result.hydrationMl, 750);
    expect(result.officialSteps, 10050);
    expect(result.measuredSteps, 10000);
    expect(result.trainingPerformed, isTrue);
    expect(result.digestiveCount, 1);
    expect(result.sourceType, DailyAggregateSourceType.records);
  });

  test('preserves nap type and null sleep score', () async {
    final result = await _engine(
      status: _status(sleepType: SleepType.nap, sleepScore: null),
    ).build(date);

    expect(result.sleepType, SleepType.nap);
    expect(result.sleepScore, isNull);
  });

  test('trainingPerformed matches formal record existence', () async {
    expect((await _engine().build(date)).trainingPerformed, isFalse);
    expect(
      (await _engine(
        training: [_trainingRecord()],
      ).build(date)).trainingPerformed,
      isTrue,
    );
  });

  test('round-trips the one-record contract through JSON', () async {
    final original = await _engine(
      status: _status(sleepType: SleepType.nap, sleepScore: null),
      food: [_meal(), _water(250)],
    ).build(date);

    final restored = DailyAggregateV1.fromJson(original.toJson());

    expect(restored.toJson(), original.toJson());
    expect(restored.toJson(), isNot(contains('ci')));
    expect(restored.toJson(), isNot(contains('digestiveEvents')));
    expect(restored.toJson(), isNot(contains('operationStatus')));
    expect(restored.toJson(), isNot(contains('estimatedBalanceMinKcal')));
  });
}

DailyAggregateEngine _engine({
  MorningData? status,
  List<FoodUnifiedReadModel> food = const [],
  ActivityData? activity,
  ActivityData? previousActivity,
  List<TrainingRecordReadModel> training = const [],
}) => DailyAggregateEngine(
  statusRepository: _StatusRepository(status),
  readFood: (_) async => food,
  activityRepository: _ActivityRepository(activity, previousActivity),
  trainingRepository: _TrainingRepository(training),
);

MorningData _status({
  SleepType sleepType = SleepType.sleep,
  int? sleepScore = 82,
}) => MorningData(
  date: '2026-08-09',
  weight: 95.6,
  bodyFat: 32.5,
  sleepHours: 7.5,
  sleepScore: sleepScore,
  sleepType: sleepType,
  footPain: 2,
  workType: WorkType.work,
  workStart: '09:00',
  workEnd: '18:00',
  workBreak: '01:00',
  workHours: 8,
  memo: '',
);

FoodUnifiedReadModel _meal() => FoodUnifiedReadModel(
  identity: const FoodRecordIdentity(FoodRecordKind.dailyMealV2, 'meal-1'),
  localDate: '2026-08-09',
  mealType: 'meal',
  displayName: 'Meal',
  items: const [],
  createdAt: DateTime.utc(2026, 8, 9, 8),
  updatedAt: DateTime.utc(2026, 8, 9, 8),
  nutritionAggregate: FoodNutritionAggregate.fromSnapshots([
    NutritionSnapshot(calories: 600, protein: 45, fat: 20, carbohydrate: 70),
  ]),
);

FoodUnifiedReadModel _water(double volume) => FoodUnifiedReadModel(
  identity: const FoodRecordIdentity(FoodRecordKind.legacyV1, 'water-1'),
  localDate: '2026-08-09',
  mealType: 'water',
  displayName: 'Water',
  items: const [],
  waterMl: volume,
  createdAt: DateTime.utc(2026, 8, 9, 9),
  updatedAt: DateTime.utc(2026, 8, 9, 9),
  nutritionAggregate: FoodNutritionAggregate.fromSnapshots(const []),
);

TrainingRecordReadModel _trainingRecord() => TrainingRecordReadModel.v2(
  id: 'training:00000000-0000-4000-8000-000000000000',
  localDate: '2026-08-09',
  createdAt: DateTime.utc(2026, 8, 9, 10),
  updatedAt: DateTime.utc(2026, 8, 9, 10),
  data: TrainingSessionV2(date: '2026-08-09'),
);

class _StatusRepository implements StatusRepository {
  final MorningData? value;

  _StatusRepository(this.value);

  @override
  Future<MorningData?> findByLocalDate(String localDate) async => value;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ActivityRepository implements ActivityRepository {
  final ActivityData? value;
  final ActivityData? previous;

  _ActivityRepository(this.value, this.previous);

  @override
  Future<ActivityData?> findByDate(DateTime date) async =>
      date.day == 8 ? previous : value;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TrainingRepository implements TrainingSessionRepository {
  final List<TrainingRecordReadModel> values;

  _TrainingRepository(this.values);

  @override
  Future<List<TrainingRecordReadModel>> findRecordsByLocalDate(
    String localDate,
  ) async => values;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
