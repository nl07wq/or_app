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
        (DailyAssessmentMetric.weightTrend, 'RAPID LOSS', '減量ペース速め'),
        (DailyAssessmentMetric.sleepTime, 'SUFFICIENT', '十分'),
        (DailyAssessmentMetric.sleepScore, 'GOOD', '良好'),
        (DailyAssessmentMetric.plantarFasciitis, 'SEVERE CONSTRAINT', '強い制約'),
        (DailyAssessmentMetric.work, 'REST DAY', '公休日'),
        (DailyAssessmentMetric.calorieBalance, 'NEAR BALANCE', 'ほぼ収支均衡'),
        (DailyAssessmentMetric.protein, 'TARGET MET', '目標達成'),
        (DailyAssessmentMetric.hydration, 'ADEQUATE', '概ね十分'),
        (DailyAssessmentMetric.steps, 'LOW LOAD', '低負荷'),
        (DailyAssessmentMetric.trainingReadiness, 'NOT AVAILABLE', '評価不可'),
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
      expect(dailyAssessmentConstraintLabel('PLANTAR FASCIITIS'), '足底筋膜炎');
      expect(dailyAssessmentConstraintLabel('WEIGHT TREND'), '体重推移');
      expect(dailyAssessmentResourceLabel('RECOVERY CAPACITY'), '回復余力');
      expect(dailyAssessmentResourceLabel('REST DAY'), '公休日');
    },
  );

  testWidgets('shows structured assessment, levels, and neutral unavailable', (
    tester,
  ) async {
    for (final width in [390.0, 900.0]) {
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
      expect(find.text('足底筋膜炎'), findsOneWidget);
      expect(find.text('AVAILABLE RESOURCE'), findsOneWidget);
      expect(find.text('回復余力'), findsOneWidget);
      expect(find.text('順調な減量ペース'), findsOneWidget);
      expect(find.text('概ね十分'), findsOneWidget);
      expect(find.text('中程度'), findsOneWidget);
      expect(find.text('長時間勤務'), findsOneWidget);
      expect(find.text('赤字過大'), findsOneWidget);
      expect(find.text('目標達成'), findsOneWidget);
      expect(find.text('高負荷'), findsOneWidget);
      expect(find.text('評価不可'), findsOneWidget);
      expect(find.text('—'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });
}

DailyAssessment _assessment() => DailyAssessment(
  operationDate: '2026-08-10',
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
    const DailyAssessmentItem(
      module: DailyAssessmentModule.training,
      metric: DailyAssessmentMetric.trainingReadiness,
      rawValue: null,
      specificAssessment: 'NOT AVAILABLE',
      level: null,
    ),
  ],
  primaryConstraints: const ['PLANTAR FASCIITIS'],
  availableResources: const ['RECOVERY CAPACITY'],
);
