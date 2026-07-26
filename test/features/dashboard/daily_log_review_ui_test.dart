import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/engine/activity_summary.dart';
import 'package:or_app/core/engine/food_summary.dart';
import 'package:or_app/core/engine/training_summary.dart';
import 'package:or_app/core/models/bowel_movement_record.dart';
import 'package:or_app/core/models/daily_log_confirmation_status.dart';
import 'package:or_app/core/navigation/app_routes.dart';
import 'package:or_app/core/services/daily_log_confirmation_state.dart';
import 'package:or_app/core/state/app_initialization_state.dart';
import 'package:or_app/features/activity/models/activity_summary_state.dart';
import 'package:or_app/features/dashboard/dashboard_page.dart';
import 'package:or_app/features/dashboard/log_confirmation_detail_page.dart';
import 'package:or_app/features/dashboard/log_confirmation_review_page.dart';
import 'package:or_app/features/dashboard/widgets/daily_log_card.dart';
import 'package:or_app/features/food/models/food_summary_state.dart';
import 'package:or_app/features/morning/models/morning_fact.dart';
import 'package:or_app/features/morning/models/morning_fact_state.dart';
import 'package:or_app/features/training/models/training_summary_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../daily_log_confirmation/daily_log_confirmation_test_fixture.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    appInitializationController.markReady();
    dailyLogConfirmationNotifier.value = DailyLogConfirmationStatus.unconfirmed(
      DateTime.now(),
    );
    morningFactNotifier.value = null;
    foodSummaryNotifier.value = null;
    activitySummaryNotifier.value = const ActivitySummary.empty();
    trainingSummaryNotifier.value = null;
    trainingCardioCaloriesNotifier.value = 0;
  });

  testWidgets('DAILY LOG distinguishes required and optional states', (
    tester,
  ) async {
    await _pumpDashboard(tester);

    expect(find.text('DAILY LOG'), findsOneWidget);
    expect(find.bySemanticsLabel('STATUS incomplete'), findsOneWidget);
    expect(find.bySemanticsLabel('FOOD incomplete'), findsOneWidget);
    expect(
      find.bySemanticsLabel('TRAINING not recorded optional'),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('ACTIVITY incomplete'), findsOneWidget);
    expect(find.text('DAILY REVIEW'), findsOneWidget);
  });

  testWidgets('DAILY LOG reports recorded modules as completed', (
    tester,
  ) async {
    morningFactNotifier.value = _morning();
    foodSummaryNotifier.value = _food();
    activitySummaryNotifier.value = _activity();
    trainingSummaryNotifier.value = _training();

    await _pumpDashboard(tester);

    expect(find.bySemanticsLabel('STATUS completed'), findsOneWidget);
    expect(find.bySemanticsLabel('FOOD completed'), findsOneWidget);
    expect(find.bySemanticsLabel('TRAINING completed'), findsOneWidget);
    expect(find.bySemanticsLabel('ACTIVITY completed'), findsOneWidget);
  });

  testWidgets('STATUS required validation rejects a missing body fat value', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DailyLogCard(
            morningFact: _morning().copyWith(bodyFat: null),
            foodSummary: _food(),
            activitySummary: _activity(),
            trainingSummary: null,
            onReview: null,
          ),
        ),
      ),
    );

    expect(find.bySemanticsLabel('STATUS incomplete'), findsOneWidget);
  });

  testWidgets('DAILY LOG uses required error for incomplete Activity', (
    tester,
  ) async {
    await _pumpDailyLogCard(
      tester,
      width: 800,
      activity: const ActivitySummary(
        steps: 0,
        isRecorded: true,
        status: ActivitySummaryStatus.incomplete,
      ),
    );

    expect(find.bySemanticsLabel('ACTIVITY incomplete'), findsOneWidget);
    expect(find.byIcon(Icons.pending_outlined), findsNothing);
  });

  testWidgets('ACTIVITY completion follows valid official step calculation', (
    tester,
  ) async {
    await _pumpDailyLogCard(
      tester,
      width: 800,
      activity: const ActivitySummary(
        steps: 0,
        measuredSteps: 0,
        isRecorded: true,
        status: ActivitySummaryStatus.incomplete,
        calculationBasis: ActivityCalculationBasis(
          rawSteps: 0,
          currentCarryOver: 0,
          previousCarryOverDeduction: 0,
          officialSteps: 0,
        ),
      ),
    );

    expect(find.bySemanticsLabel('ACTIVITY completed'), findsOneWidget);
    expect(find.byIcon(Icons.pending_outlined), findsNothing);
  });

  testWidgets('DAILY LOG uses a two by two grid at desktop width', (
    tester,
  ) async {
    await _pumpDailyLogCard(tester, width: 800);

    final status = tester.getTopLeft(
      find.bySemanticsLabel('STATUS incomplete'),
    );
    final food = tester.getTopLeft(find.bySemanticsLabel('FOOD incomplete'));
    final training = tester.getTopLeft(
      find.bySemanticsLabel('TRAINING not recorded optional'),
    );
    final activity = tester.getTopLeft(
      find.bySemanticsLabel('ACTIVITY incomplete'),
    );

    expect(status.dy, food.dy);
    expect(training.dy, activity.dy);
    expect(training.dy, greaterThan(status.dy));
    expect(food.dx, greaterThan(status.dx));
  });

  testWidgets('DAILY LOG falls back without overflow at 320 pixels', (
    tester,
  ) async {
    await _pumpDailyLogCard(tester, width: 320);

    expect(tester.takeException(), isNull);
    expect(find.text('DAILY REVIEW'), findsOneWidget);
  });

  testWidgets('DAILY REVIEW button keeps the existing named route', (
    tester,
  ) async {
    morningFactNotifier.value = _morning();

    await tester.pumpWidget(
      MaterialApp(
        home: const DashboardPage(),
        onGenerateRoute: (settings) {
          if (settings.name == AppRoutes.logConfirmationReview) {
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => settings.arguments! as LogConfirmationReviewPage,
            );
          }
          return null;
        },
      ),
    );
    await tester.pump();
    await tester.scrollUntilVisible(
      find.text('DAILY REVIEW'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('DAILY REVIEW'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, 'DAILY REVIEW'), findsOneWidget);
  });

  testWidgets('finalized Dashboard uses DAILY LOG terminology and route', (
    tester,
  ) async {
    final confirmation = completeConfirmation();
    RouteSettings? openedRoute;
    dailyLogConfirmationNotifier.value = DailyLogConfirmationStatus.confirmed(
      confirmation,
    );

    await _pumpDashboard(
      tester,
      onGenerateRoute: (settings) {
        openedRoute = settings;
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const Scaffold(body: Text('DETAIL ROUTE')),
        );
      },
    );
    await tester.scrollUntilVisible(
      find.text('VIEW DAILY LOG'),
      300,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.widgetWithText(AppBar, 'O.R.L.O.'), findsOneWidget);
    expect(find.text('DAILY LOG FINALIZED'), findsOneWidget);
    expect(find.textContaining('Finalized at'), findsOneWidget);
    expect(find.text('VIEW DAILY LOG'), findsOneWidget);
    expect(find.bySemanticsLabel('VIEW DAILY LOG'), findsOneWidget);
    expect(find.byIcon(Icons.article_outlined), findsOneWidget);
    expect(find.text('CORRECT LOG'), findsOneWidget);
    expect(find.bySemanticsLabel('CORRECT LOG'), findsOneWidget);
    expect(find.byIcon(Icons.edit_note_outlined), findsOneWidget);
    expect(find.text("TODAY'S LOG CONFIRMED"), findsNothing);
    expect(find.textContaining('Confirmed at'), findsNothing);
    expect(find.text('View Confirmation'), findsNothing);
    expect(find.text('Correct Log'), findsNothing);

    await tester.tap(find.text('VIEW DAILY LOG'));
    await tester.pumpAndSettle();

    expect(openedRoute?.name, AppRoutes.logConfirmationDetail);
    expect(openedRoute?.arguments, confirmation.date);
    expect(find.text('DETAIL ROUTE'), findsOneWidget);
  });

  testWidgets('CORRECT LOG keeps the existing reopen confirmation flow', (
    tester,
  ) async {
    final confirmation = completeConfirmation();
    dailyLogConfirmationNotifier.value = DailyLogConfirmationStatus.confirmed(
      confirmation,
    );

    await _pumpDashboard(tester);
    await tester.scrollUntilVisible(
      find.text('CORRECT LOG'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('CORRECT LOG'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AlertDialog, 'Correct Log'), findsOneWidget);
    expect(find.text('編集を再開'), findsOneWidget);
  });

  testWidgets('Daily Review renders only available formal summary values', (
    tester,
  ) async {
    await _pumpReview(
      tester,
      morning: _morning(memo: ''),
      food: _food(),
      activity: _activity(),
      training: _training(),
      estimatedTotalBurn: 2850,
    );

    expect(find.text('Weight 96.8 kg'), findsOneWidget);
    expect(find.text('Body Fat 32.4%'), findsOneWidget);
    expect(find.text('Sleep 4h 16m'), findsOneWidget);
    expect(find.text('Sleep Score 61'), findsOneWidget);
    expect(find.text('Foot Pain 1'), findsOneWidget);
    expect(find.text('Work Time 8.0 h'), findsOneWidget);
    expect(find.text('Memo —'), findsOneWidget);
    expect(find.text('3 Meals'), findsOneWidget);
    expect(find.text('• 2,130 kcal'), findsOneWidget);
    expect(find.text('3,200 / 3,500 ml'), findsOneWidget);
    expect(find.text('EST. TOTAL BURN  2,850 kcal'), findsOneWidget);
    expect(find.text('3 Exercises • 9 Sets'), findsOneWidget);
    expect(find.text('Steps 8,900'), findsOneWidget);
    expect(find.text('Today 7,659'), findsOneWidget);
    expect(find.text('Carry Over +1,241'), findsOneWidget);
    expect(find.text('Bowel Shape 2'), findsOneWidget);
    expect(find.text('Bowel Amount 1'), findsOneWidget);
    expect(find.textContaining('Cardio'), findsNothing);
    expect(find.textContaining('ENERGY BALANCE'), findsNothing);
  });

  testWidgets('Daily Review uses neutral missing states and safe fallbacks', (
    tester,
  ) async {
    await _pumpReview(
      tester,
      morning: null,
      food: null,
      activity: const ActivitySummary.empty(),
      training: null,
      estimatedTotalBurn: null,
    );

    expect(find.text('Not recorded'), findsNWidgets(5));
    expect(find.text('EST. TOTAL BURN  Not available'), findsOneWidget);
    expect(
      find.text('Complete required records: STATUS, FOOD, ACTIVITY'),
      findsOneWidget,
    );
    expect(find.text('FINALIZE DAY'), findsOneWidget);
    expect(
      tester
          .widget<ElevatedButton>(
            find.ancestor(
              of: find.text('FINALIZE DAY'),
              matching: find.byType(ElevatedButton),
            ),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('Quick Water remains visible without inventing a meal', (
    tester,
  ) async {
    await _pumpReview(
      tester,
      morning: _morning(),
      food: const FoodSummary(
        calories: 0,
        protein: 0,
        fat: 0,
        carbohydrates: 0,
        hydrationMl: 500,
        mealCount: 0,
      ),
      activity: const ActivitySummary.empty(),
      training: null,
      estimatedTotalBurn: 2100,
    );

    expect(find.text('500 / 3,500 ml'), findsOneWidget);
    expect(find.text('0 Meals'), findsNothing);
    expect(
      find.text('Complete required records: FOOD, ACTIVITY'),
      findsOneWidget,
    );
  });

  testWidgets('Training remains optional for finalization', (tester) async {
    await _pumpReview(
      tester,
      morning: _morning(),
      food: _food(),
      activity: _activity(),
      training: null,
      estimatedTotalBurn: 2100,
    );

    expect(find.text('Complete required records:'), findsNothing);
    expect(
      tester
          .widget<ElevatedButton>(
            find.ancestor(
              of: find.text('FINALIZE DAY'),
              matching: find.byType(ElevatedButton),
            ),
          )
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('an invalid existing Training blocks finalization', (
    tester,
  ) async {
    await _pumpReview(
      tester,
      morning: _morning(),
      food: _food(),
      activity: _activity(),
      training: const TrainingSummary(
        completed: false,
        exerciseCount: 1,
        setCount: 1,
        duration: null,
        sessionName: null,
      ),
      estimatedTotalBurn: 2100,
    );

    expect(find.text('Complete required records: TRAINING'), findsOneWidget);
    expect(
      tester
          .widget<ElevatedButton>(
            find.ancestor(
              of: find.text('FINALIZE DAY'),
              matching: find.byType(ElevatedButton),
            ),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('confirmed detail uses the shared Snapshot-only review body', (
    tester,
  ) async {
    final confirmation = completeConfirmation();
    SharedPreferences.setMockInitialValues({
      'daily_log_confirmations': [jsonEncode(confirmation.toJson())],
    });

    await tester.pumpWidget(
      MaterialApp(
        home: LogConfirmationDetailPage(targetDate: confirmation.date),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, 'DAILY LOG'), findsOneWidget);
    expect(find.text('DAILY LOG FINALIZED'), findsOneWidget);
    for (final label in [
      'STATUS review',
      'FOOD review',
      'WATER review',
      'ENERGY review',
      'TRAINING review',
      'ACTIVITY review',
    ]) {
      expect(find.bySemanticsLabel(RegExp(label)), findsOneWidget);
    }
    expect(find.text('EST. TOTAL BURN  2,876 kcal'), findsOneWidget);
    expect(
      find.textContaining('Finalized at 2026-07-26 22:30'),
      findsOneWidget,
    );
    expect(find.text('DAILY REVIEW'), findsNothing);
    expect(find.textContaining('Confirmed at'), findsNothing);
    expect(find.text('FINALIZE DAY'), findsNothing);
    expect(find.text('BACK TO EDIT'), findsNothing);
    expect(find.text('LOG CONFIRMATION'), findsNothing);
    expect(find.text('MORNING'), findsNothing);
  });

  testWidgets('old confirmed detail does not backfill missing energy', (
    tester,
  ) async {
    final confirmation = completeConfirmation();
    final oldJson = confirmation.toJson()..remove('estimatedTotalBurnKcal');
    SharedPreferences.setMockInitialValues({
      'daily_log_confirmations': [jsonEncode(oldJson)],
    });
    trainingCardioCaloriesNotifier.value = 9999;

    await tester.pumpWidget(
      MaterialApp(
        home: LogConfirmationDetailPage(targetDate: confirmation.date),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('EST. TOTAL BURN  Not available'), findsOneWidget);
    expect(find.textContaining('9,999'), findsNothing);
  });

  testWidgets('confirmed detail remains overflow-free at 320 pixels', (
    tester,
  ) async {
    final confirmation = completeConfirmation();
    SharedPreferences.setMockInitialValues({
      'daily_log_confirmations': [jsonEncode(confirmation.toJson())],
    });
    tester.view.physicalSize = const Size(320, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: LogConfirmationDetailPage(targetDate: confirmation.date),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('DAILY LOG FINALIZED'), findsOneWidget);
  });

  testWidgets('Daily Review shows no inferred carry over or bowel values', (
    tester,
  ) async {
    await _pumpReview(
      tester,
      morning: _morning(),
      food: _food(),
      activity: const ActivitySummary(
        steps: 8900,
        measuredSteps: 8900,
        isRecorded: true,
        calculationBasis: ActivityCalculationBasis(
          rawSteps: 8900,
          currentCarryOver: 0,
          previousCarryOverDeduction: 0,
          officialSteps: 8900,
        ),
      ),
      training: null,
      estimatedTotalBurn: 2100,
    );

    expect(find.text('Carry Over —'), findsOneWidget);
    expect(find.text('Bowel Shape —'), findsOneWidget);
    expect(find.text('Bowel Amount —'), findsOneWidget);
  });

  testWidgets('Daily Review remains overflow-free on a narrow screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpReview(
      tester,
      morning: _morning(memo: '非常に長いメモ' * 30),
      food: _food(),
      activity: _activity(),
      training: _training(),
      estimatedTotalBurn: 2850,
    );

    expect(tester.takeException(), isNull);
    expect(find.text('FINALIZE DAY'), findsOneWidget);
    expect(find.text('BACK TO EDIT'), findsOneWidget);
  });

  testWidgets('Daily Review exposes sections and actions to semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    await _pumpReview(
      tester,
      morning: _morning(),
      food: _food(),
      activity: _activity(),
      training: _training(),
      estimatedTotalBurn: 2850,
    );

    for (final label in [
      'STATUS review',
      'FOOD review',
      'WATER review',
      'ENERGY review',
      'TRAINING review',
      'ACTIVITY review',
    ]) {
      expect(find.bySemanticsLabel(RegExp(label)), findsOneWidget);
    }
    expect(find.bySemanticsLabel(RegExp('FINALIZE DAY')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('BACK TO EDIT')), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('Daily Review shows the finalization explanation and subtitle', (
    tester,
  ) async {
    await _pumpReview(
      tester,
      morning: _morning(),
      food: null,
      activity: const ActivitySummary.empty(),
      training: null,
      estimatedTotalBurn: 2100,
    );

    expect(
      find.text(
        'Finalizing locks today’s normal edit and delete actions. '
        'Use the correction flow if changes are needed later.',
      ),
      findsOneWidget,
    );
    expect(find.text('Finalize today’s records'), findsOneWidget);
  });
}

Future<void> _pumpDailyLogCard(
  WidgetTester tester, {
  required double width,
  ActivitySummary activity = const ActivitySummary.empty(),
}) async {
  tester.view.physicalSize = Size(width, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: DailyLogCard(
          morningFact: null,
          foodSummary: null,
          activitySummary: activity,
          trainingSummary: null,
          onReview: null,
        ),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _pumpDashboard(
  WidgetTester tester, {
  RouteFactory? onGenerateRoute,
}) async {
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(home: const DashboardPage(), onGenerateRoute: onGenerateRoute),
  );
  await tester.pump();
}

Future<void> _pumpReview(
  WidgetTester tester, {
  required MorningFact? morning,
  required FoodSummary? food,
  required ActivitySummary activity,
  required TrainingSummary? training,
  required double? estimatedTotalBurn,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: LogConfirmationReviewPage(
        morning: morning,
        food: food,
        activity: activity,
        training: training,
        estimatedTotalBurn: estimatedTotalBurn,
      ),
    ),
  );
  await tester.pump();
}

MorningFact _morning({String? memo = 'Ready'}) {
  return MorningFact(
    date: DateTime(2026, 7, 26),
    weight: 96.8,
    bodyFat: 32.4,
    sleepDuration: const Duration(hours: 4, minutes: 16),
    sleepScore: 61,
    workHours: 8,
    footPain: 1,
    medications: const [],
    freeNotes: memo,
  );
}

FoodSummary _food() {
  return const FoodSummary(
    calories: 2130,
    protein: 142.5,
    fat: 61.2,
    carbohydrates: 238.4,
    hydrationMl: 3200,
    mealCount: 3,
  );
}

TrainingSummary _training() {
  return const TrainingSummary(
    completed: true,
    exerciseCount: 3,
    setCount: 9,
    duration: null,
    sessionName: null,
  );
}

ActivitySummary _activity() {
  return ActivitySummary(
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
}
