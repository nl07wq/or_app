import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/engine/activity_summary.dart';
import 'package:or_app/core/engine/food_summary.dart';
import 'package:or_app/core/models/bowel_movement_record.dart';
import 'package:or_app/features/dashboard/log_confirmation_review_page.dart';
import 'package:or_app/features/dashboard/widgets/daily_log_card.dart';
import 'package:or_app/features/morning/models/morning_fact.dart';
import 'package:or_app/features/operation_date/models/operation_state.dart';

void main() {
  testWidgets('open daily log keeps finalize visible and blocked', (
    tester,
  ) async {
    await _pumpCard(tester, phase: OperationPhase.open, finalizeReady: false);

    expect(find.text('CREATE DAILY DEBRIEF'), findsNothing);
    expect(find.text('FINALIZE DAY'), findsOneWidget);
    expect(find.text('FINALIZE BLOCKED'), findsOneWidget);
    expect(find.text('DAILY DEBRIEF REQUIRED'), findsOneWidget);
    expect(find.text('UNDO DAILY CLOSE'), findsNothing);
  });

  testWidgets('awaiting daily log exposes finalize and one undo action', (
    tester,
  ) async {
    await _pumpCard(
      tester,
      phase: OperationPhase.awaitingDebrief,
      finalizeReady: true,
    );

    expect(find.text('CREATE DAILY DEBRIEF'), findsNothing);
    expect(find.text('FINALIZE DAY'), findsOneWidget);
    expect(find.text('FINALIZE READY'), findsOneWidget);
    expect(find.text('UNDO DAILY CLOSE'), findsOneWidget);
  });

  testWidgets('awaiting daily log blocks finalize without active debrief', (
    tester,
  ) async {
    await _pumpCard(
      tester,
      phase: OperationPhase.awaitingDebrief,
      finalizeReady: false,
    );

    final button = tester.widget<ElevatedButton>(
      find.ancestor(
        of: find.text('FINALIZE DAY'),
        matching: find.byType(ElevatedButton),
      ),
    );
    expect(button.onPressed, isNull);
    expect(find.text('FINALIZE BLOCKED'), findsOneWidget);
  });

  testWidgets('daily review confirmation prepares close once without backup', (
    tester,
  ) async {
    var preparationCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: LogConfirmationReviewPage(
          morning: _morning(),
          food: _food(),
          activity: _activity(),
          training: null,
          estimatedTotalBurn: 2100,
          targetDate: DateTime(2026, 8, 13),
          confirmDailyLog: (_) async => preparationCount++,
        ),
      ),
    );

    await tester.tap(find.text('CONFIRM'));
    await tester.pumpAndSettle();
    expect(find.text('CREATE DAILY DEBRIEF'), findsOneWidget);
    await tester.tap(find.text('YES'));
    await tester.pumpAndSettle();

    expect(preparationCount, 1);
    expect(find.text('BACKUP'), findsNothing);
  });
}

Future<void> _pumpCard(
  WidgetTester tester, {
  required OperationPhase phase,
  required bool finalizeReady,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: DailyLogCard(
          morningFact: _morning(),
          foodSummary: _food(),
          activitySummary: _activity(),
          trainingSummary: null,
          phase: phase,
          finalizeReady: finalizeReady,
          onPrimaryAction: () {},
          onUndo: phase == OperationPhase.awaitingDebrief ? () {} : null,
        ),
      ),
    ),
  );
}

MorningFact _morning() => MorningFact(
  date: DateTime(2026, 8, 13),
  weight: 96.8,
  bodyFat: 32.4,
  sleepDuration: const Duration(hours: 4, minutes: 16),
  sleepScore: 61,
  workHours: 8,
  footPain: 1,
  medications: const [],
  freeNotes: null,
);

FoodSummary _food() => const FoodSummary(
  calories: 2130,
  protein: 142.5,
  fat: 61.2,
  carbohydrates: 238.4,
  hydrationMl: 3200,
  mealCount: 3,
);

ActivitySummary _activity() => ActivitySummary(
  steps: 8900,
  measuredSteps: 7659,
  carryOver: 1241,
  isRecorded: true,
  bowelMovement: BowelMovementRecord.recorded(amount: 1, shape: 2),
  calculationBasis: const ActivityCalculationBasis(
    rawSteps: 7659,
    currentCarryOver: 1241,
    previousCarryOverDeduction: 0,
    officialSteps: 8900,
  ),
);
