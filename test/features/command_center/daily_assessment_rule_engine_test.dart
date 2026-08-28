import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/models/morning_data.dart';
import 'package:or_app/core/models/work_type.dart';
import 'package:or_app/features/body_history/models/body_history_models.dart';
import 'package:or_app/features/command_center/core/daily_assessment_rule_engine.dart';
import 'package:or_app/features/command_center/models/daily_assessment.dart';

void main() {
  const engine = DailyAssessmentRuleEngine();

  test(
    'applies formal threshold boundaries and preserves null versus zero',
    () {
      for (final value in [
        (239, DailyAssessmentLevel.limit),
        (240, DailyAssessmentLevel.adjust),
        (299, DailyAssessmentLevel.adjust),
        (300, DailyAssessmentLevel.watch),
        (359, DailyAssessmentLevel.watch),
        (360, DailyAssessmentLevel.stable),
        (419, DailyAssessmentLevel.stable),
        (420, DailyAssessmentLevel.support),
      ]) {
        expect(
          _item(
            engine,
            status: _status(sleepHours: value.$1 / 60),
          ).call(DailyAssessmentMetric.sleepTime).level,
          value.$2,
        );
      }
      for (final value in [
        (49, DailyAssessmentLevel.limit),
        (50, DailyAssessmentLevel.adjust),
        (64, DailyAssessmentLevel.adjust),
        (65, DailyAssessmentLevel.watch),
        (74, DailyAssessmentLevel.watch),
        (75, DailyAssessmentLevel.stable),
        (84, DailyAssessmentLevel.stable),
        (85, DailyAssessmentLevel.support),
      ]) {
        expect(
          _item(
            engine,
            status: _status(sleepScore: value.$1),
          ).call(DailyAssessmentMetric.sleepScore).level,
          value.$2,
        );
      }
      for (var level = 1; level <= 5; level++) {
        expect(
          _item(
            engine,
            status: _status(footPain: level),
          ).call(DailyAssessmentMetric.plantarFasciitis).level,
          DailyAssessmentLevel.values[level - 1],
        );
      }
      expect(
        _item(
          engine,
          status: _status(workType: WorkType.holiday),
        ).call(DailyAssessmentMetric.work).level,
        DailyAssessmentLevel.support,
      );
      for (final value in [
        (8.0, DailyAssessmentLevel.stable),
        (8.01, DailyAssessmentLevel.watch),
        (10.0, DailyAssessmentLevel.watch),
        (10.01, DailyAssessmentLevel.adjust),
      ]) {
        expect(
          _item(
            engine,
            status: _status(workHours: value.$1),
          ).call(DailyAssessmentMetric.work).level,
          value.$2,
        );
      }

      for (final value in [
        (-1300.01, DailyAssessmentLevel.limit),
        (-1300.0, DailyAssessmentLevel.adjust),
        (-1000.01, DailyAssessmentLevel.adjust),
        (-1000.0, DailyAssessmentLevel.watch),
        (-800.01, DailyAssessmentLevel.watch),
        (-800.0, DailyAssessmentLevel.support),
        (-300.0, DailyAssessmentLevel.support),
        (-299.0, DailyAssessmentLevel.stable),
        (200.0, DailyAssessmentLevel.stable),
        (201.0, DailyAssessmentLevel.watch),
        (500.0, DailyAssessmentLevel.watch),
        (500.01, DailyAssessmentLevel.adjust),
      ]) {
        expect(
          _item(
            engine,
            balance: value.$1,
          ).call(DailyAssessmentMetric.calorieBalance).level,
          value.$2,
        );
      }
      for (final value in [
        (69.9, DailyAssessmentLevel.limit),
        (70.0, DailyAssessmentLevel.adjust),
        (90.0, DailyAssessmentLevel.watch),
        (110.0, DailyAssessmentLevel.stable),
        (130.0, DailyAssessmentLevel.support),
      ]) {
        expect(
          _item(
            engine,
            protein: value.$1,
          ).call(DailyAssessmentMetric.protein).level,
          value.$2,
        );
      }
      for (final value in [
        (999.0, DailyAssessmentLevel.limit),
        (1000.0, DailyAssessmentLevel.adjust),
        (1500.0, DailyAssessmentLevel.watch),
        (2000.0, DailyAssessmentLevel.stable),
        (2500.0, DailyAssessmentLevel.support),
      ]) {
        expect(
          _item(
            engine,
            hydration: value.$1,
          ).call(DailyAssessmentMetric.hydration).level,
          value.$2,
        );
      }
      for (final value in [
        (0, DailyAssessmentLevel.stable),
        (6000, DailyAssessmentLevel.stable),
        (6001, DailyAssessmentLevel.stable),
        (10000, DailyAssessmentLevel.stable),
        (10001, DailyAssessmentLevel.watch),
        (14000, DailyAssessmentLevel.watch),
        (14001, DailyAssessmentLevel.adjust),
      ]) {
        final item = _item(
          engine,
          steps: value.$1,
        ).call(DailyAssessmentMetric.steps);
        expect(item.level, value.$2);
        if (value.$1 == 0) expect(item.rawValue, 0);
      }
      expect(_item(engine).call(DailyAssessmentMetric.steps).level, isNull);
    },
  );

  test('evaluates 14-day weight trend boundaries', () {
    for (final value in [
      (-0.91, 'RAPID LOSS', DailyAssessmentLevel.watch),
      (-0.90, 'ON TRACK', DailyAssessmentLevel.support),
      (-0.30, 'ON TRACK', DailyAssessmentLevel.support),
      (-0.29, 'SLOW PROGRESS', DailyAssessmentLevel.stable),
      (-0.10, 'PLATEAU WATCH', DailyAssessmentLevel.watch),
      (0.10, 'PLATEAU WATCH', DailyAssessmentLevel.watch),
      (0.11, 'UPWARD TREND', DailyAssessmentLevel.adjust),
    ]) {
      final item = _item(
        engine,
        weights: _weights(change: value.$1),
      ).call(DailyAssessmentMetric.weightTrend);
      expect(item.specificAssessment, value.$2);
      expect(item.level, value.$3);
    }
    expect(
      _item(
        engine,
        weights: _weights(change: -0.5).take(13).toList(),
      ).call(DailyAssessmentMetric.weightTrend).specificAssessment,
      'NOT AVAILABLE',
    );

    final olderNoise = BodyHistoryDataPoint(
      operationDate: '2026-07-01',
      weightKg: 120,
      bodyFatPercent: null,
      source: BodyHistorySource.status,
    );
    final withOlderNoise = _item(
      engine,
      weights: [olderNoise, ..._weights(change: -0.5).reversed],
    ).call(DailyAssessmentMetric.weightTrend);
    expect(withOlderNoise.specificAssessment, 'ON TRACK');
  });

  test('does not backfill missing current-day sleep from history', () {
    final result = engine.evaluate(
      _facts(status: _status(sleepHours: null, sleepScore: null)),
    );
    expect(
      _find(result, DailyAssessmentMetric.sleepTime).specificAssessment,
      'NOT AVAILABLE',
    );
    expect(
      _find(result, DailyAssessmentMetric.sleepScore).specificAssessment,
      'NOT AVAILABLE',
    );
  });

  test('strength-specific nutrition rule ignores cardio-only training', () {
    final cardioOnly = engine.evaluate(
      _facts(
        protein: 100,
        trainingPerformed: true,
        strengthTrainingPerformed: false,
      ),
    );
    expect(
      cardioOnly.primaryConstraints,
      isNot(contains('NUTRITION PRIORITY')),
    );

    final strength = engine.evaluate(
      _facts(
        protein: 100,
        trainingPerformed: true,
        strengthTrainingPerformed: true,
      ),
    );
    expect(strength.primaryConstraints, contains('NUTRITION PRIORITY'));
  });

  test('applies only deterministic cross rules and resource rules', () {
    final result = engine.evaluate(
      _facts(
        status: _status(
          sleepHours: 3.9,
          sleepScore: 90,
          footPain: 4,
          workHours: 11,
        ),
        balance: -1100,
        protein: 100,
        hydration: 1800,
        steps: 12001,
        trainingPerformed: true,
      ),
    );
    expect(result.primaryConstraints, contains('SLEEP × EXTENDED WORK LOAD'));
    expect(result.primaryConstraints, contains('FOOT LOAD CONSTRAINT'));
    expect(result.primaryConstraints, contains('RECOVERY PRIORITY'));
    expect(result.primaryConstraints, contains('NUTRITION PRIORITY'));
    expect(result.primaryConstraints, contains('HYDRATION PRIORITY'));

    final resources = engine.evaluate(
      _facts(
        status: _status(
          sleepHours: 7.5,
          sleepScore: 90,
          workType: WorkType.holiday,
        ),
      ),
    );
    expect(resources.availableResources, contains('RECOVERY CAPACITY'));
    expect(resources.availableResources, contains('REST DAY'));
    expect(resources.availableResources, isNot(contains('TRAINING READINESS')));
    expect(
      _find(
        resources,
        DailyAssessmentMetric.trainingReadiness,
      ).specificAssessment,
      'NOT AVAILABLE',
    );
  });

  test('applies Training Readiness v1 interval and frequency thresholds', () {
    for (final value in const [
      (23, DailyAssessmentLevel.adjust),
      (24, DailyAssessmentLevel.watch),
      (35, DailyAssessmentLevel.watch),
      (36, DailyAssessmentLevel.stable),
      (71, DailyAssessmentLevel.stable),
      (72, DailyAssessmentLevel.support),
    ]) {
      expect(
        _item(
          engine,
          training: _training(hours: value.$1),
        ).call(DailyAssessmentMetric.trainingReadiness).level,
        value.$2,
      );
    }

    expect(
      _item(
        engine,
        training: _training(hours: 72, last7Days: 4),
      ).call(DailyAssessmentMetric.trainingReadiness).level,
      DailyAssessmentLevel.stable,
    );
    expect(
      _item(
        engine,
        training: _training(hours: 36, last7Days: 5),
      ).call(DailyAssessmentMetric.trainingReadiness).level,
      DailyAssessmentLevel.adjust,
    );
    expect(
      _item(
        engine,
        training: _training(hours: 72, consecutiveDays: 3),
      ).call(DailyAssessmentMetric.trainingReadiness).level,
      DailyAssessmentLevel.stable,
    );
    expect(
      _item(
        engine,
        training: _training(hours: 72, last7Days: 5, consecutiveDays: 3),
      ).call(DailyAssessmentMetric.trainingReadiness).level,
      DailyAssessmentLevel.watch,
    );
    expect(
      _item(
        engine,
        training: _training(days: 2),
      ).call(DailyAssessmentMetric.trainingReadiness).level,
      DailyAssessmentLevel.stable,
    );
  });
}

DailyAssessmentItem Function(DailyAssessmentMetric) _item(
  DailyAssessmentRuleEngine engine, {
  MorningData? status,
  double? balance,
  double? protein,
  double? hydration,
  int? steps,
  bool trainingPerformed = false,
  bool? strengthTrainingPerformed,
  List<BodyHistoryDataPoint> weights = const [],
  TrainingReadinessFacts? training,
}) {
  final result = engine.evaluate(
    _facts(
      status: status,
      balance: balance,
      protein: protein,
      hydration: hydration,
      steps: steps,
      trainingPerformed: trainingPerformed,
      strengthTrainingPerformed: strengthTrainingPerformed,
      weights: weights,
      training: training,
    ),
  );
  return (metric) => _find(result, metric);
}

DailyAssessmentItem _find(
  DailyAssessment result,
  DailyAssessmentMetric metric,
) => result.assessments.singleWhere((item) => item.metric == metric);

DailyAssessmentFacts _facts({
  MorningData? status,
  double? balance,
  double? protein,
  double? hydration,
  int? steps,
  bool trainingPerformed = false,
  bool? strengthTrainingPerformed,
  List<BodyHistoryDataPoint> weights = const [],
  TrainingReadinessFacts? training,
}) => DailyAssessmentFacts(
  operationDate: '2026-08-10',
  currentStatus: status,
  currentCalorieBalanceKcal: balance,
  currentProteinG: protein,
  currentHydrationMl: hydration,
  currentOfficialSteps: steps,
  currentTrainingPerformed: trainingPerformed,
  currentStrengthTrainingPerformed:
      strengthTrainingPerformed ?? trainingPerformed,
  weightHistory: weights,
  trainingReadiness: training,
);

TrainingReadinessFacts _training({
  int? hours,
  int? days,
  int last7Days = 1,
  int consecutiveDays = 1,
}) => TrainingReadinessFacts(
  lastTraining: hours != null
      ? TrainingReadinessIntervalFact.hours(hours)
      : TrainingReadinessIntervalFact.calendarDays(days!),
  last7DaysSessionCount: last7Days,
  currentWeekSessionCount: last7Days,
  consecutiveTrainingDays: consecutiveDays,
  recentIntervals: const [],
);

MorningData _status({
  double? sleepHours = 7,
  int? sleepScore = 80,
  int footPain = 2,
  WorkType workType = WorkType.work,
  double workHours = 8,
}) => MorningData(
  date: '2026-08-10',
  weight: 90,
  bodyFat: 20,
  sleepHours: sleepHours,
  sleepScore: sleepScore,
  footPain: footPain,
  workType: workType,
  workStart: '09:00',
  workEnd: '17:00',
  workBreak: '00:00',
  workHours: workHours,
  memo: '',
);

List<BodyHistoryDataPoint> _weights({required double change}) => [
  for (var index = 0; index < 7; index++)
    BodyHistoryDataPoint(
      operationDate: _date(
        DateTime.utc(2026, 7, 28).add(Duration(days: index)),
      ),
      weightKg: 90,
      bodyFatPercent: null,
      source: BodyHistorySource.status,
    ),
  for (var index = 0; index < 7; index++)
    BodyHistoryDataPoint(
      operationDate: _date(DateTime.utc(2026, 8, 4).add(Duration(days: index))),
      weightKg: 90 + change,
      bodyFatPercent: null,
      source: BodyHistorySource.status,
    ),
];

String _date(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';
