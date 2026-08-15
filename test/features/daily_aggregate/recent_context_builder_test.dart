import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/daily_aggregate/models/daily_aggregate_v1.dart';
import 'package:or_app/features/daily_aggregate/services/recent_context_builder.dart';
import 'package:or_app/features/repositories/app_repository_container.dart';

import '../../repositories/indexed_db/fake_indexed_db_database.dart';

void main() {
  for (final metric
      in <
        ({
          String name,
          String Function(double current, double average) classify,
          double major,
          double same,
        })
      >[
        (
          name: 'weight',
          classify: RecentContextComparisonClassifier.weight,
          major: 1.5,
          same: 0.5,
        ),
        (
          name: 'body fat',
          classify: RecentContextComparisonClassifier.bodyFat,
          major: 1,
          same: 0.3,
        ),
        (
          name: 'sleep duration',
          classify: RecentContextComparisonClassifier.sleepDuration,
          major: 20,
          same: 8,
        ),
        (
          name: 'sleep score',
          classify: RecentContextComparisonClassifier.sleepScore,
          major: 15,
          same: 5,
        ),
        (
          name: 'calories',
          classify: RecentContextComparisonClassifier.calories,
          major: 15,
          same: 5,
        ),
        (
          name: 'protein',
          classify: RecentContextComparisonClassifier.protein,
          major: 20,
          same: 8,
        ),
        (
          name: 'hydration',
          classify: RecentContextComparisonClassifier.hydration,
          major: 20,
          same: 8,
        ),
        (
          name: 'official steps',
          classify: RecentContextComparisonClassifier.officialSteps,
          major: 25,
          same: 10,
        ),
        (
          name: 'estimated expenditure',
          classify: RecentContextComparisonClassifier.estimatedExpenditure,
          major: 15,
          same: 5,
        ),
      ]) {
    test('${metric.name} uses its five formal comparison levels', () {
      final average = 100.0;
      double current(double difference) => average + difference;

      expect(metric.classify(current(-metric.major), average), '大きく下回る');
      expect(
        metric.classify(current(-(metric.major + metric.same) / 2), average),
        '下回る',
      );
      expect(metric.classify(average, average), '同水準');
      expect(
        metric.classify(current((metric.major + metric.same) / 2), average),
        '上回る',
      );
      expect(metric.classify(current(metric.major), average), '大きく上回る');
    });
  }

  test('foot condition uses symptom-specific point labels', () {
    expect(
      RecentContextComparisonClassifier.footCondition(12, 10),
      '平均より明確に高い',
    );
    expect(RecentContextComparisonClassifier.footCondition(11, 10), '平均よりやや高い');
    expect(RecentContextComparisonClassifier.footCondition(10, 10), '同水準');
    expect(RecentContextComparisonClassifier.footCondition(9, 10), '平均よりやや低い');
    expect(RecentContextComparisonClassifier.footCondition(8, 10), '平均より明確に低い');
  });

  test('calorie balance uses absolute kcal boundaries', () {
    expect(
      RecentContextComparisonClassifier.estimatedCalorieBalance(-400, 0),
      '大きく下回る',
    );
    expect(
      RecentContextComparisonClassifier.estimatedCalorieBalance(-200, 0),
      '下回る',
    );
    expect(
      RecentContextComparisonClassifier.estimatedCalorieBalance(150, 0),
      '同水準',
    );
    expect(
      RecentContextComparisonClassifier.estimatedCalorieBalance(200, 0),
      '上回る',
    );
    expect(
      RecentContextComparisonClassifier.estimatedCalorieBalance(400, 0),
      '大きく上回る',
    );
  });

  test('numeric zero is classified while a null current fact is not', () async {
    expect(RecentContextComparisonClassifier.officialSteps(0, 0), '同水準');

    final container = AppRepositoryContainer.indexedDb(FakeIndexedDbDatabase());
    await container.dailyAggregates.put(
      _aggregate('2026-08-09', calories: 2000),
    );
    await container.dailyAggregates.put(
      _aggregate('2026-08-10', calories: null),
    );

    final context = await container.recentContextBuilder.build(
      targetDate: '2026-08-10',
      window: RecentContextWindow.dailyDebrief,
    );

    expect(context.intakeCaloriesKcal.end, 2000);
    expect(context.intakeCaloriesKcal.comparisonLevel, isNull);
  });

  test('daily brief uses records from D-7 through D-1 only', () async {
    final container = AppRepositoryContainer.indexedDb(FakeIndexedDbDatabase());
    final repository = container.dailyAggregates;
    await repository.put(_aggregate('2026-08-03', weightKg: 10, steps: 1000));
    await repository.put(
      _aggregate(
        '2026-08-04',
        weightKg: 999,
        steps: 999999,
        sourceType: DailyAggregateSourceType.legacyDns,
      ),
    );
    await repository.put(_aggregate('2026-08-05', weightKg: null, steps: 0));
    await repository.put(_aggregate('2026-08-06', weightKg: 0, steps: 3000));
    await repository.put(_aggregate('2026-08-09', weightKg: 20, steps: 5000));
    await repository.put(_aggregate('2026-08-10', weightKg: 50, steps: 7000));
    await repository.put(_aggregate('2026-08-11', weightKg: 60, steps: 9000));

    final context = await container.recentContextBuilder.build(
      targetDate: '2026-08-10',
      window: RecentContextWindow.dailyBrief,
    );

    expect(context.windowStart, '2026-08-03');
    expect(context.windowEnd, '2026-08-09');
    expect(context.requestedDays, 7);
    expect(context.weightKg.average, 10);
    expect(context.weightKg.start, 10);
    expect(context.weightKg.end, 20);
    expect(context.weightKg.validCount, 3);
    expect(context.officialSteps.average, 2250);
    expect(context.officialSteps.start, 1000);
    expect(context.officialSteps.end, 5000);
    expect(context.officialSteps.validCount, 4);
    expect(context.weightKg.comparisonLevel, isNull);
    expect(context.toJson().toString(), isNot(contains('comparisonLevel')));
    expect(context.toJson().toString(), isNot(contains('measuredSteps')));
  });

  test(
    'daily debrief uses records from D-6 through D without filling nulls',
    () async {
      final container = AppRepositoryContainer.indexedDb(
        FakeIndexedDbDatabase(),
      );
      final repository = container.dailyAggregates;
      await repository.put(
        _aggregate('2026-08-03', calories: 1000, hydrationMl: 1000),
      );
      await repository.put(
        _aggregate('2026-08-04', calories: null, hydrationMl: 0),
      );
      await repository.put(
        _aggregate('2026-08-08', calories: 2000, hydrationMl: null),
      );
      await repository.put(
        _aggregate('2026-08-10', calories: 3000, hydrationMl: 3000),
      );
      await repository.put(
        _aggregate('2026-08-11', calories: 9000, hydrationMl: 9000),
      );

      final context = await container.recentContextBuilder.build(
        targetDate: '2026-08-10',
        window: RecentContextWindow.dailyDebrief,
      );

      expect(context.windowStart, '2026-08-04');
      expect(context.windowEnd, '2026-08-10');
      expect(context.intakeCaloriesKcal.average, 2500);
      expect(context.intakeCaloriesKcal.start, 2000);
      expect(context.intakeCaloriesKcal.end, 3000);
      expect(context.intakeCaloriesKcal.validCount, 2);
      expect(context.hydrationMl.average, 1500);
      expect(context.hydrationMl.start, 0);
      expect(context.hydrationMl.end, 3000);
      expect(context.hydrationMl.validCount, 2);
      expect(context.bodyFatPercent.average, 20);
      expect(context.sleepDurationMinutes.average, 420);
      expect(context.sleepScore.average, 80);
      expect(context.plantarFasciitisLevel.average, 2);
      expect(context.proteinG.average, 150);
      expect(context.estimatedExpenditureKcal.average, 2300);
      expect(context.estimatedCalorieBalanceKcal.average, -300);
      expect(context.intakeCaloriesKcal.comparisonLevel, '大きく上回る');
      expect(context.hydrationMl.comparisonLevel, '大きく上回る');
      expect(context.toJson().toString(), contains('comparisonLevel'));
      expect(context.toJson().toString(), isNot(contains('trainingPerformed')));
      expect(context.toJson().toString(), isNot(contains('actualWorkMinutes')));
    },
  );
}

DailyAggregateV1 _aggregate(
  String date, {
  double? weightKg = 80,
  int? steps = 4000,
  double? calories = 2000,
  double? hydrationMl = 2000,
  DailyAggregateSourceType sourceType = DailyAggregateSourceType.records,
}) => DailyAggregateV1(
  operationDate: date,
  weightKg: weightKg,
  bodyFatPercent: 20,
  sleepDurationMinutes: 420,
  sleepScore: 80,
  sleepType: null,
  plantarFasciitisLevel: 2,
  workStartTime: null,
  workEndTime: null,
  workBreakMinutes: null,
  actualWorkMinutes: null,
  intakeCaloriesKcal: calories,
  estimatedExpenditureKcal: 2300,
  estimatedCalorieBalanceKcal: -300,
  proteinG: 150,
  fatG: 60,
  carbsG: 250,
  hydrationMl: hydrationMl,
  officialSteps: steps,
  measuredSteps: 123456,
  trainingPerformed: false,
  digestiveCount: 1,
  sourceType: sourceType,
);
