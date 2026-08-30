import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/command_center/models/daily_assessment.dart';
import 'package:or_app/features/command_center/widgets/daily_assessment_card.dart';
import 'package:or_app/features/command_center/widgets/daily_assessment_label_mapper.dart';

void main() {
  test(
    'maps canonical assessment labels without changing canonical values',
    () {
      const cases = <(DailyAssessmentMetric, String, String)>[
        (DailyAssessmentMetric.weightTrend, 'RAPID LOSS', '減量ペースがやや速くなっています。'),
        (DailyAssessmentMetric.sleepTime, 'SUFFICIENT', '十分な睡眠時間を確保できています。'),
        (DailyAssessmentMetric.sleepScore, 'GOOD', '睡眠の質は良好です。'),
        (
          DailyAssessmentMetric.plantarFasciitis,
          'SEVERE CONSTRAINT',
          '足底症状が非常に強く、活動負荷を制限する必要があります。',
        ),
        (DailyAssessmentMetric.work, 'REST DAY', '勤務による追加負荷はありません。'),
        (
          DailyAssessmentMetric.calorieBalance,
          'NEAR BALANCE',
          '本日のカロリー収支はほぼ均衡しています。',
        ),
        (DailyAssessmentMetric.protein, 'TARGET MET', 'たんぱく質は目標量を確保できています。'),
        (DailyAssessmentMetric.hydration, 'ADEQUATE', '水分摂取量は概ね確保できています。'),
        (DailyAssessmentMetric.steps, 'LOW LOAD', '本日の歩行負荷は低い状態です。'),
        (
          DailyAssessmentMetric.trainingReadiness,
          'NOT AVAILABLE',
          '現在の記録ではトレーニング間隔を評価できません。',
        ),
      ];

      for (final entry in cases) {
        final item = DailyAssessmentItem(
          module: DailyAssessmentModule.body,
          metric: entry.$1,
          rawValue: null,
          specificAssessment: entry.$2,
          level: null,
        );
        expect(dailyAssessmentSpecificLabel(item), entry.$3);
        expect(item.specificAssessment, entry.$2);
      }
      expect(
        dailyAssessmentConstraintLabel('PLANTAR FASCIITIS'),
        '足底症状が強く、活動負荷を抑える必要があります。',
      );
      expect(
        dailyAssessmentConstraintLabel('WEIGHT TREND'),
        '減量ペースが速いため、体重推移を確認する必要があります。',
      );
      expect(
        dailyAssessmentResourceLabel('RECOVERY CAPACITY'),
        '十分な回復状態を確保できています。',
      );
      expect(
        dailyAssessmentResourceLabel('REST DAY'),
        '公休日のため、勤務負荷のない時間を利用できます。',
      );
    },
  );

  testWidgets('shows structured assessment, levels, and neutral unavailable', (
    tester,
  ) async {
    for (final width in [320.0, 390.0, 900.0]) {
      tester.view.physicalSize = Size(width, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: DailyAssessmentView(assessment: _assessment()),
            ),
          ),
        ),
      );

      for (final module in DailyAssessmentModule.values) {
        expect(find.text(module.label), findsOneWidget);
      }
      for (final level in DailyAssessmentLevel.values) {
        final badges = tester.widgetList<Container>(
          find.byKey(ValueKey('daily-assessment-level-${level.name}')),
        );
        expect(badges, isNotEmpty);
        for (final badge in badges) {
          final decoration = badge.decoration! as BoxDecoration;
          expect(
            (decoration.border! as Border).top.color,
            dailyAssessmentLevelColor(level),
          );
        }
        expect(find.text(level.label), findsWidgets);
      }
      expect(find.text('PRIMARY CONSTRAINT'), findsOneWidget);
      expect(find.text('足底症状が強く、活動負荷を抑える必要があります。'), findsOneWidget);
      expect(find.text('AVAILABLE RESOURCE'), findsOneWidget);
      expect(find.text('十分な回復状態を確保できています。'), findsOneWidget);
      expect(find.text('減量ペースは目標範囲で推移しています。'), findsOneWidget);
      expect(find.text('睡眠時間は概ね確保できています。'), findsOneWidget);
      expect(find.text('足底症状は中程度です。'), findsOneWidget);
      expect(find.text('長時間勤務による負荷が見込まれます。'), findsOneWidget);
      expect(find.text('本日のカロリー赤字が過大です。'), findsOneWidget);
      expect(find.text('水分摂取量は目標を達成しています。'), findsOneWidget);
      expect(find.text('本日の歩行負荷は高い状態です。'), findsOneWidget);
      expect(find.text('LAST TRAINING'), findsOneWidget);
      expect(find.text('41h ago'), findsOneWidget);
      expect(find.text('LAST 7 DAYS'), findsOneWidget);
      expect(find.text('3 sessions'), findsWidgets);
      expect(find.text('CURRENT WEIGHT'), findsOneWidget);
      expect(find.text('91.2 kg'), findsOneWidget);
      expect(find.text('THIS WEEK'), findsOneWidget);
      expect(find.text('RECENT INTERVALS'), findsOneWidget);
      expect(find.text('48h / 72h'), findsOneWidget);
      expect(find.text('CONSECUTIVE DAYS'), findsOneWidget);
      expect(find.text('YES · 2 days'), findsOneWidget);
      expect(find.text('トレーニング間隔は標準範囲です。'), findsOneWidget);
      expect(find.text('順調な減量ペース'), findsNothing);
      expect(find.text('評価不可'), findsNothing);
      expect(find.text('—'), findsNothing);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('distinguishes measured and fallback weight sources', (
    tester,
  ) async {
    Future<void> pump(DailyWeightReference reference) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: DailyAssessmentView(
                assessment: _assessment(currentWeightReference: reference),
              ),
            ),
          ),
        ),
      );
    }

    await pump(
      const DailyWeightReference(
        valueKg: 95,
        source: DailyWeightReferenceSource.measuredToday,
        sampleCount: 1,
        windowDays: 1,
      ),
    );
    expect(find.text('CURRENT WEIGHT'), findsOneWidget);
    expect(find.text('95.0 kg'), findsOneWidget);
    expect(find.text('WEEK AVERAGE'), findsNothing);

    await pump(
      const DailyWeightReference(
        valueKg: 95.5,
        source: DailyWeightReferenceSource.sevenDayMean,
        sampleCount: 3,
        windowDays: 7,
      ),
    );
    expect(find.text('WEEK AVERAGE'), findsOneWidget);
    expect(find.text('95.5 kg'), findsOneWidget);
    expect(find.text('CURRENT WEIGHT'), findsNothing);
    expect(find.text('-0.50 kg/week'), findsOneWidget);

    await pump(
      const DailyWeightReference(
        valueKg: 96,
        source: DailyWeightReferenceSource.fourteenDayMean,
        sampleCount: 3,
        windowDays: 14,
      ),
    );
    expect(find.text('14-DAY AVERAGE'), findsOneWidget);
    expect(find.text('96.0 kg'), findsOneWidget);
    expect(find.text('CURRENT WEIGHT'), findsNothing);

    await pump(const DailyWeightReference.notAvailable());
    expect(find.text('CURRENT WEIGHT'), findsOneWidget);
    expect(find.text('NOT AVAILABLE'), findsWidgets);
  });
}

DailyAssessment _assessment({
  DailyWeightReference currentWeightReference = const DailyWeightReference(
    valueKg: 91.2,
    source: DailyWeightReferenceSource.measuredToday,
    sampleCount: 1,
    windowDays: 1,
  ),
}) => DailyAssessment(
  operationDate: '2026-08-10',
  currentWeightReference: currentWeightReference,
  assessments: [
    const DailyAssessmentItem(
      module: DailyAssessmentModule.body,
      metric: DailyAssessmentMetric.weightTrend,
      rawValue: -0.5,
      specificAssessment: 'ON TRACK',
      level: DailyAssessmentLevel.support,
    ),
    const DailyAssessmentItem(
      module: DailyAssessmentModule.recovery,
      metric: DailyAssessmentMetric.sleepTime,
      rawValue: 390,
      specificAssessment: 'ADEQUATE',
      level: DailyAssessmentLevel.stable,
    ),
    const DailyAssessmentItem(
      module: DailyAssessmentModule.condition,
      metric: DailyAssessmentMetric.plantarFasciitis,
      rawValue: 3,
      specificAssessment: 'MODERATE',
      level: DailyAssessmentLevel.watch,
    ),
    const DailyAssessmentItem(
      module: DailyAssessmentModule.workLoad,
      metric: DailyAssessmentMetric.work,
      rawValue: 11.0,
      specificAssessment: 'EXTENDED LOAD',
      level: DailyAssessmentLevel.adjust,
    ),
    const DailyAssessmentItem(
      module: DailyAssessmentModule.nutrition,
      metric: DailyAssessmentMetric.calorieBalance,
      rawValue: -1400.0,
      specificAssessment: 'EXTREME DEFICIT',
      level: DailyAssessmentLevel.limit,
    ),
    const DailyAssessmentItem(
      module: DailyAssessmentModule.hydration,
      metric: DailyAssessmentMetric.hydration,
      rawValue: 2500.0,
      specificAssessment: 'TARGET MET',
      level: DailyAssessmentLevel.support,
    ),
    const DailyAssessmentItem(
      module: DailyAssessmentModule.recentLoad,
      metric: DailyAssessmentMetric.steps,
      rawValue: 10001,
      specificAssessment: 'HIGH LOAD',
      level: DailyAssessmentLevel.watch,
    ),
    DailyAssessmentItem(
      module: DailyAssessmentModule.training,
      metric: DailyAssessmentMetric.trainingReadiness,
      rawValue: TrainingReadinessFacts(
        lastTraining: TrainingReadinessIntervalFact.hours(41),
        last7DaysSessionCount: 3,
        currentWeekSessionCount: 3,
        consecutiveTrainingDays: 2,
        recentIntervals: [
          TrainingReadinessIntervalFact.hours(48),
          TrainingReadinessIntervalFact.hours(72),
        ],
      ),
      specificAssessment: 'STANDARD INTERVAL',
      level: DailyAssessmentLevel.stable,
    ),
  ],
  primaryConstraints: const ['PLANTAR FASCIITIS'],
  availableResources: const ['RECOVERY CAPACITY'],
);
