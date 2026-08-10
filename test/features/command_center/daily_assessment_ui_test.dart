import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/command_center/models/daily_assessment.dart';
import 'package:or_app/features/command_center/widgets/daily_assessment_card.dart';

void main() {
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
      expect(find.text('PLANTAR FASCIITIS'), findsOneWidget);
      expect(find.text('AVAILABLE RESOURCE'), findsOneWidget);
      expect(find.text('RECOVERY CAPACITY'), findsOneWidget);
      expect(find.text('NOT AVAILABLE'), findsOneWidget);
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
