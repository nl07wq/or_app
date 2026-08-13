import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/engine/activity_summary.dart';
import 'package:or_app/core/engine/digestive_summary.dart';
import 'package:or_app/core/engine/food_summary.dart';
import 'package:or_app/core/engine/training_summary.dart';
import 'package:or_app/core/models/bowel_movement_record.dart';
import 'package:or_app/core/models/daily_log_confirmation.dart';
import 'package:or_app/core/models/daily_log_confirmation_status.dart';
import 'package:or_app/core/navigation/app_routes.dart';
import 'package:or_app/core/services/daily_log_confirmation_state.dart';
import 'package:or_app/core/state/app_initialization_state.dart';
import 'package:or_app/data/indexed_db/indexed_db_store_names.dart';
import 'package:or_app/features/activity/models/activity_summary_state.dart';
import 'package:or_app/features/dashboard/dashboard_page.dart';
import 'package:or_app/features/dashboard/log_confirmation_detail_page.dart';
import 'package:or_app/features/dashboard/log_confirmation_review_page.dart';
import 'package:or_app/features/dashboard/widgets/daily_log_card.dart';
import 'package:or_app/features/food/models/food_summary_state.dart';
import 'package:or_app/features/import_export/services/backup_export_service.dart';
import 'package:or_app/features/import_export/services/backup_file_export_service.dart';
import 'package:or_app/features/import_export/services/backup_file_gateway.dart';
import 'package:or_app/features/operation_date/models/operation_local_date.dart';
import 'package:or_app/features/operation_date/models/operation_state.dart';
import 'package:or_app/features/repositories/app_repository_container.dart';
import 'package:or_app/features/morning/models/morning_fact.dart';
import 'package:or_app/features/morning/models/morning_fact_state.dart';
import 'package:or_app/features/training/models/training_summary_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../repositories/indexed_db/fake_indexed_db_database.dart';
import '../daily_log_confirmation/daily_log_confirmation_test_fixture.dart';

void obsoleteTestWidgets(String description, WidgetTesterCallback callback) {
  testWidgets(description, callback, skip: true);
}

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
  });

  tearDown(AppRepositoryRegistry.resetForTesting);

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
    expect(find.text('FINALIZE BLOCKED'), findsOneWidget);
    expect(find.text('DAILY DEBRIEF REQUIRED'), findsOneWidget);
    expect(find.text('FINALIZE DAY'), findsOneWidget);
    expect(find.text('CREATE DAILY DEBRIEF'), findsNothing);
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
    expect(find.text('FINALIZE BLOCKED'), findsOneWidget);
    expect(find.text('DAILY DEBRIEF REQUIRED'), findsOneWidget);
  });

  testWidgets('DAILY LOG rows open existing module routes', (tester) async {
    morningFactNotifier.value = _morning();
    foodSummaryNotifier.value = _food();
    activitySummaryNotifier.value = _activity();
    final openedRoutes = <String?>[];

    await _pumpDashboard(
      tester,
      onGenerateRoute: (settings) {
        openedRoutes.add(settings.name);
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => Scaffold(body: Text('ROUTE ${settings.name}')),
        );
      },
    );

    expect(find.text('FINALIZE BLOCKED'), findsOneWidget);
    for (final entry in const [
      ('STATUS completed', AppRoutes.morning),
      ('FOOD completed', AppRoutes.food),
      ('TRAINING not recorded optional', AppRoutes.training),
      ('ACTIVITY completed', AppRoutes.activity),
    ]) {
      await tester.tap(find.bySemanticsLabel(entry.$1));
      await tester.pumpAndSettle();
      expect(openedRoutes.last, entry.$2);
      Navigator.of(tester.element(find.text('ROUTE ${entry.$2}'))).pop();
      await tester.pumpAndSettle();
    }
  });

  testWidgets('STATUS completion preserves nullable body fat contract', (
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
            phase: OperationPhase.open,
            finalizeReady: false,
            onPrimaryAction: null,
          ),
        ),
      ),
    );

    expect(find.bySemanticsLabel('STATUS completed'), findsOneWidget);
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
    expect(find.text('FINALIZE DAY'), findsOneWidget);
  });

  testWidgets('open DAILY LOG does not expose the debrief create route', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final operationDate = DateTime(2026, 7, 31);
    dailyLogConfirmationNotifier.value = DailyLogConfirmationStatus.unconfirmed(
      operationDate,
    );
    morningFactNotifier.value = _morning();
    _installOpenOperationState(operationDate);

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
      find.text('FINALIZE DAY'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('CREATE DAILY DEBRIEF'), findsNothing);
    expect(find.text('FINALIZE BLOCKED'), findsOneWidget);
    expect(find.byType(LogConfirmationReviewPage), findsNothing);
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
    expect(find.text('2,130 kcal'), findsOneWidget);
    expect(find.text('3,200 / 3,500 ml'), findsOneWidget);
    expect(find.text('Est. Total Burn 2,850 kcal'), findsOneWidget);
    expect(find.text('Calorie Balance -720 kcal'), findsOneWidget);
    expect(find.text('3 Exercises'), findsOneWidget);
    expect(find.text('9 Sets'), findsOneWidget);
    expect(find.text('Steps 8,900'), findsOneWidget);
    expect(find.text('Today 7,659'), findsOneWidget);
    expect(find.text('Carry Over +1,241'), findsOneWidget);
    expect(find.text('Bowel Shape 普通便'), findsOneWidget);
    expect(find.text('Bowel Amount 少量'), findsOneWidget);
    for (final oldLabel in [
      '体重',
      '体脂肪率',
      '睡眠スコア',
      '足の痛み',
      '勤務時間',
      'メモ',
      '推定総消費',
      'カロリー収支',
      '歩数',
      '実測歩数',
      '繰越',
    ]) {
      expect(find.textContaining(oldLabel), findsNothing);
    }
    expect(find.textContaining('•'), findsNothing);
    for (final section in ['FOOD review', 'TRAINING review']) {
      expect(
        find.descendant(
          of: find.bySemanticsLabel(RegExp(section)),
          matching: find.textContaining('・'),
        ),
        findsNothing,
      );
    }
    expect(find.text('Training Cardio Not calculated'), findsOneWidget);
    expect(find.textContaining('ENERGY BALANCE'), findsNothing);
  });

  testWidgets('Daily Review shows formal energy breakdown and partial status', (
    tester,
  ) async {
    const training = TrainingSummary(
      completed: true,
      exerciseCount: 1,
      setCount: 1,
      duration: null,
      sessionName: null,
      trainingCardioCaloriesKcal: 32,
      computedCardioCount: 1,
      uncomputedCardioCount: 1,
      energyCalculationStatus: TrainingEnergyCalculationStatus.partial,
      energyCalculationVersion: 1,
    );
    await _pumpReview(
      tester,
      morning: _morning(),
      food: _food(),
      activity: _activity(),
      training: training,
      estimatedTotalBurn: 2961.6,
    );

    expect(find.text('Base Burn 2,930 kcal'), findsOneWidget);
    expect(find.text('Training Cardio 32 kcal'), findsOneWidget);
    expect(find.text('Est. Total Burn 2,962 kcal'), findsOneWidget);
    expect(find.text('Calculation Status Partial'), findsOneWidget);
    expect(find.text('Uncomputed Cardio 1'), findsOneWidget);
    expect(find.text('Energy Calculation Version 1'), findsOneWidget);
    expect(find.text('Calorie Balance -832 kcal'), findsOneWidget);
  });

  testWidgets('Daily Review does not turn uncomputed cardio into zero', (
    tester,
  ) async {
    const training = TrainingSummary(
      completed: true,
      exerciseCount: 0,
      setCount: 0,
      duration: null,
      sessionName: null,
      computedCardioCount: 0,
      uncomputedCardioCount: 1,
      energyCalculationStatus: TrainingEnergyCalculationStatus.notCalculated,
      energyCalculationVersion: 1,
    );
    await _pumpReview(
      tester,
      morning: _morning(),
      food: _food(),
      activity: _activity(),
      training: training,
      estimatedTotalBurn: null,
    );

    expect(find.text('Training Cardio Not calculated'), findsOneWidget);
    expect(find.text('Est. Total Burn —'), findsOneWidget);
    expect(find.text('Calculation Status Not calculated'), findsOneWidget);
    expect(find.text('Calorie Balance —'), findsOneWidget);
  });

  testWidgets('STATUS and FOOD use the approved semantic row groups', (
    tester,
  ) async {
    await _pumpReview(
      tester,
      morning: _morning(),
      food: _food(),
      activity: _activity(),
      training: _training(),
      estimatedTotalBurn: 2850,
    );

    _expectRow('status-weight-body-fat-row', [
      'Weight 96.8 kg',
      'Body Fat 32.4%',
    ]);
    _expectRow('status-sleep-score-row', ['Sleep 4h 16m', 'Sleep Score 61']);
    _expectRow('status-foot-pain-row', ['Foot Pain 1']);
    _expectRow('status-work-memo-row', ['Work Time 8.0 h', 'Memo Ready']);
    _expectRow('food-meals-calories-row', ['3 Meals', '2,130 kcal']);
    _expectRow('food-macros-row', ['P 142.5 g', 'F 61.2 g', 'C 238.4 g']);

    expect(
      tester.getTopLeft(find.text('Weight 96.8 kg')).dy,
      tester.getTopLeft(find.text('Body Fat 32.4%')).dy,
    );
    expect(
      tester.getTopLeft(find.text('Sleep 4h 16m')).dy,
      tester.getTopLeft(find.text('Sleep Score 61')).dy,
    );
    expect(
      tester.getTopLeft(find.text('Work Time 8.0 h')).dy,
      tester.getTopLeft(find.text('Memo Ready')).dy,
    );
    expect(
      tester.getTopLeft(find.text('3 Meals')).dy,
      tester.getTopLeft(find.text('2,130 kcal')).dy,
    );
    expect(
      tester.getTopLeft(find.text('P 142.5 g')).dy,
      tester.getTopLeft(find.text('F 61.2 g')).dy,
    );
    expect(
      tester.getTopLeft(find.text('F 61.2 g')).dy,
      tester.getTopLeft(find.text('C 238.4 g')).dy,
    );
  });

  testWidgets('Calorie Balance uses the approved inclusive neutral band', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    Future<void> expectBalance(double balance, Object? expectedColor) async {
      await _pumpReview(
        tester,
        morning: _morning(),
        food: _foodWithCalories(2000 + balance),
        activity: _activity(),
        training: null,
        estimatedTotalBurn: 2000,
      );
      final sign = balance > 0 ? '+' : '';
      expect(
        find.text('Calorie Balance $sign${balance.round()} kcal'),
        findsOneWidget,
      );
      expect(_balanceValueColor(tester), expectedColor);
    }

    await expectBalance(151, Colors.amber.shade800);
    await expectBalance(150, isNull);
    await expectBalance(0, isNull);
    await expectBalance(-150, isNull);
    await expectBalance(-151, Colors.cyan.shade700);
    expect(
      find.bySemanticsLabel(RegExp(r'Calorie Balance -151 kcal')),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets('FOOD keeps the singular Meal label in its first row', (
    tester,
  ) async {
    await _pumpReview(
      tester,
      morning: _morning(),
      food: const FoodSummary(
        calories: 500,
        protein: 20,
        fat: 15,
        carbohydrates: 70,
        hydrationMl: 500,
        mealCount: 1,
      ),
      activity: _activity(),
      training: null,
      estimatedTotalBurn: 2000,
    );

    _expectRow('food-meals-calories-row', ['1 Meal', '500 kcal']);
    expect(find.text('1 Meals'), findsNothing);
  });

  testWidgets('Calorie Balance remains readable with dark theme colors', (
    tester,
  ) async {
    await _pumpReview(
      tester,
      morning: _morning(),
      food: _foodWithCalories(2151),
      activity: _activity(),
      training: null,
      estimatedTotalBurn: 2000,
      theme: ThemeData.dark(),
    );
    expect(_balanceValueColor(tester), Colors.amberAccent);

    await _pumpReview(
      tester,
      morning: _morning(),
      food: _foodWithCalories(1849),
      activity: _activity(),
      training: null,
      estimatedTotalBurn: 2000,
      theme: ThemeData.dark(),
    );
    expect(_balanceValueColor(tester), Colors.cyanAccent);
  });

  testWidgets('Daily Review shows the new Digestive Summary without Legacy', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await _pumpReview(
      tester,
      morning: _morning(),
      food: _food(),
      activity: _digestiveActivity(
        eventCount: 3,
        totalAmount: 6,
        latestShape: 3,
        latestRelief: 2,
      ),
      training: null,
      estimatedTotalBurn: 2100,
    );

    expect(find.text('Digestive Count 3'), findsOneWidget);
    expect(find.text('Total Amount 6'), findsOneWidget);
    expect(find.text('Latest Shape 軟便'), findsOneWidget);
    expect(find.text('Latest Relief スッキリ'), findsOneWidget);
    expect(find.bySemanticsLabel('Digestive Count'), findsOneWidget);
    expect(find.bySemanticsLabel('Total Amount'), findsOneWidget);
    expect(find.bySemanticsLabel('Latest Shape'), findsOneWidget);
    expect(find.bySemanticsLabel('Latest Relief'), findsOneWidget);
    expect(find.textContaining('Bowel Shape'), findsNothing);
    expect(find.textContaining('Bowel Amount'), findsNothing);
    semantics.dispose();
  });

  testWidgets('Digestive Summary maps every Shape and Relief label', (
    tester,
  ) async {
    for (final values in [
      (shape: 1, relief: 0, shapeLabel: '硬便', reliefLabel: '残便感'),
      (shape: 2, relief: 1, shapeLabel: '普通便', reliefLabel: '普通'),
      (shape: 3, relief: 2, shapeLabel: '軟便', reliefLabel: 'スッキリ'),
    ]) {
      await _pumpReview(
        tester,
        morning: _morning(),
        food: _food(),
        activity: _digestiveActivity(
          eventCount: 1,
          totalAmount: 2,
          latestShape: values.shape,
          latestRelief: values.relief,
        ),
        training: null,
        estimatedTotalBurn: 2100,
      );

      expect(find.text('Latest Shape ${values.shapeLabel}'), findsOneWidget);
      expect(find.text('Latest Relief ${values.reliefLabel}'), findsOneWidget);
    }
  });

  testWidgets('zero Digestive Events without a report stay unshown', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await _pumpReview(
      tester,
      morning: _morning(),
      food: _food(),
      activity: _digestiveActivity(
        eventCount: 0,
        totalAmount: 0,
        latestShape: null,
        latestRelief: null,
      ),
      training: null,
      estimatedTotalBurn: 2100,
    );

    expect(find.text('Digestive None'), findsNothing);
    expect(find.bySemanticsLabel(RegExp('排便なしを報告済み')), findsNothing);
    expect(find.textContaining('Bowel Shape'), findsNothing);
    expect(find.textContaining('Bowel Amount'), findsNothing);
    expect(find.textContaining('Digestive Count'), findsNothing);
    semantics.dispose();
  });

  testWidgets('Daily Review distinguishes an explicit no-movement report', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await _pumpReview(
      tester,
      morning: _morning(),
      food: _food(),
      activity: _digestiveActivity(
        eventCount: 0,
        totalAmount: 0,
        latestShape: null,
        latestRelief: null,
        hasExplicitNoMovement: true,
      ),
      training: null,
      estimatedTotalBurn: 2100,
    );

    expect(find.text('Digestive None'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('排便なしを報告済み')), findsOneWidget);
    expect(find.textContaining('Digestive Count'), findsNothing);
    expect(find.textContaining('Total Amount'), findsNothing);
    expect(find.textContaining('Latest Shape'), findsNothing);
    expect(find.textContaining('Latest Relief'), findsNothing);
    semantics.dispose();
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

    expect(find.text('Not recorded'), findsNWidgets(4));
    expect(find.text('未記録'), findsOneWidget);
    expect(find.text('Est. Total Burn —'), findsOneWidget);
    expect(find.text('Calorie Balance —'), findsOneWidget);
    expect(find.text('必須記録を完了してください: STATUS, FOOD, ACTIVITY'), findsOneWidget);
    expect(find.text('CONFIRM'), findsNothing);
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
    expect(find.text('0食'), findsNothing);
    expect(find.text('必須記録を完了してください: FOOD, ACTIVITY'), findsOneWidget);
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

    expect(find.textContaining('必須記録を完了してください:'), findsNothing);
    expect(find.text('CONFIRM'), findsNothing);
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

    expect(find.text('必須記録を完了してください: TRAINING'), findsOneWidget);
    expect(find.text('CONFIRM'), findsNothing);
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
    _expectRow('status-weight-body-fat-row', [
      'Weight 88.3 kg',
      'Body Fat 24.8%',
    ]);
    _expectRow('food-meals-calories-row', ['4 Meals', '2,346 kcal']);
    expect(find.text('Est. Total Burn 2,876 kcal'), findsOneWidget);
    expect(find.text('Calorie Balance -530 kcal'), findsOneWidget);
    expect(_balanceValueColor(tester), Colors.cyan.shade700);
    expect(find.textContaining('確定日時 2026-07-26 22:30'), findsOneWidget);
    expect(find.text('DAILY REVIEW'), findsNothing);
    expect(find.textContaining('Confirmed at'), findsNothing);
    expect(find.text('FINALIZE DAY'), findsNothing);
    expect(find.text('BACK TO EDIT'), findsNothing);
    expect(find.text('LOG CONFIRMATION'), findsNothing);
    expect(find.text('MORNING'), findsNothing);
  });

  testWidgets('confirmed detail displays its saved Digestive Snapshot only', (
    tester,
  ) async {
    final base = completeConfirmation();
    final confirmation = DailyLogConfirmation(
      date: base.date,
      confirmedAt: base.confirmedAt,
      morning: base.morning,
      food: base.food,
      activity: _digestiveActivity(
        eventCount: 2,
        totalAmount: 4,
        latestShape: 2,
        latestRelief: 0,
      ),
      training: base.training,
      estimatedTotalBurnKcal: base.estimatedTotalBurnKcal,
    );
    SharedPreferences.setMockInitialValues({
      'daily_log_confirmations': [jsonEncode(confirmation.toJson())],
    });
    activitySummaryNotifier.value = _digestiveActivity(
      eventCount: 1,
      totalAmount: 3,
      latestShape: 3,
      latestRelief: 2,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: LogConfirmationDetailPage(targetDate: confirmation.date),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Digestive Count 2'), findsOneWidget);
    expect(find.text('Total Amount 4'), findsOneWidget);
    expect(find.text('Latest Shape 普通便'), findsOneWidget);
    expect(find.text('Latest Relief 残便感'), findsOneWidget);
    expect(find.text('Digestive Count 1'), findsNothing);
    expect(find.text('Latest Shape 軟便'), findsNothing);
  });

  testWidgets('confirmed detail shows explicit no movement from Snapshot', (
    tester,
  ) async {
    final base = completeConfirmation();
    final confirmation = DailyLogConfirmation(
      date: base.date,
      confirmedAt: base.confirmedAt,
      morning: base.morning,
      food: base.food,
      activity: _digestiveActivity(
        eventCount: 0,
        totalAmount: 0,
        latestShape: null,
        latestRelief: null,
        hasExplicitNoMovement: true,
      ),
      training: base.training,
      estimatedTotalBurnKcal: base.estimatedTotalBurnKcal,
    );
    SharedPreferences.setMockInitialValues({
      'daily_log_confirmations': [jsonEncode(confirmation.toJson())],
    });
    activitySummaryNotifier.value = _digestiveActivity(
      eventCount: 1,
      totalAmount: 3,
      latestShape: 3,
      latestRelief: 2,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: LogConfirmationDetailPage(targetDate: confirmation.date),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Digestive None'), findsOneWidget);
    expect(find.text('Digestive Count 1'), findsNothing);
    expect(find.text('Latest Shape 軟便'), findsNothing);
  });

  testWidgets('old Snapshot without zero-report field stays unreported', (
    tester,
  ) async {
    final base = completeConfirmation();
    final confirmation = DailyLogConfirmation(
      date: base.date,
      confirmedAt: base.confirmedAt,
      morning: base.morning,
      food: base.food,
      activity: _digestiveActivity(
        eventCount: 0,
        totalAmount: 0,
        latestShape: null,
        latestRelief: null,
        hasExplicitNoMovement: true,
      ),
      training: base.training,
      estimatedTotalBurnKcal: base.estimatedTotalBurnKcal,
    );
    final oldJson = confirmation.toJson();
    final activityJson = Map<String, dynamic>.from(oldJson['activity'] as Map);
    final digestiveJson = Map<String, dynamic>.from(
      activityJson['digestiveSummary'] as Map,
    )..remove('hasExplicitNoMovement');
    activityJson['digestiveSummary'] = digestiveJson;
    oldJson['activity'] = activityJson;
    SharedPreferences.setMockInitialValues({
      'daily_log_confirmations': [jsonEncode(oldJson)],
    });
    trainingSummaryNotifier.value = const TrainingSummary(
      completed: true,
      exerciseCount: 1,
      setCount: 1,
      duration: null,
      sessionName: null,
      trainingCardioCaloriesKcal: 9999,
      computedCardioCount: 1,
      uncomputedCardioCount: 0,
      energyCalculationStatus: TrainingEnergyCalculationStatus.complete,
      energyCalculationVersion: 1,
    );
    morningFactNotifier.value = _morning().copyWith(weight: 200);

    await tester.pumpWidget(
      MaterialApp(
        home: LogConfirmationDetailPage(targetDate: confirmation.date),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Digestive None'), findsNothing);
    expect(find.textContaining('Digestive Count'), findsNothing);
    expect(find.textContaining('Latest Shape'), findsNothing);
  });

  testWidgets('old confirmed detail does not backfill missing energy', (
    tester,
  ) async {
    final confirmation = completeConfirmation();
    final oldJson = confirmation.toJson()..remove('estimatedTotalBurnKcal');
    SharedPreferences.setMockInitialValues({
      'daily_log_confirmations': [jsonEncode(oldJson)],
    });
    await tester.pumpWidget(
      MaterialApp(
        home: LogConfirmationDetailPage(targetDate: confirmation.date),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Est. Total Burn —'), findsOneWidget);
    expect(find.text('Calorie Balance —'), findsOneWidget);
    expect(_balanceValueColor(tester), isNull);
    expect(find.textContaining('9,999'), findsNothing);
  });

  testWidgets('confirmed detail renders saved formal energy only', (
    tester,
  ) async {
    final confirmation = completeConfirmation().copyWith(
      training: const TrainingSummary(
        completed: true,
        exerciseCount: 1,
        setCount: 1,
        duration: null,
        sessionName: null,
        trainingCardioCaloriesKcal: 32,
        computedCardioCount: 1,
        uncomputedCardioCount: 1,
        energyCalculationStatus: TrainingEnergyCalculationStatus.partial,
        energyCalculationVersion: 1,
      ),
      estimatedTotalBurnKcal: 2900,
    );
    SharedPreferences.setMockInitialValues({
      'daily_log_confirmations': [jsonEncode(confirmation.toJson())],
    });
    trainingSummaryNotifier.value = const TrainingSummary(
      completed: true,
      exerciseCount: 0,
      setCount: 0,
      duration: null,
      sessionName: null,
      trainingCardioCaloriesKcal: 9999,
      computedCardioCount: 1,
      uncomputedCardioCount: 0,
      energyCalculationStatus: TrainingEnergyCalculationStatus.complete,
      energyCalculationVersion: 99,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: LogConfirmationDetailPage(targetDate: confirmation.date),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Training Cardio 32 kcal'), findsOneWidget);
    expect(find.text('Est. Total Burn 2,900 kcal'), findsOneWidget);
    expect(find.text('Calculation Status Partial'), findsOneWidget);
    expect(find.text('Uncomputed Cardio 1'), findsOneWidget);
    expect(find.text('Energy Calculation Version 1'), findsOneWidget);
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
    expect(find.text('CONFIRM'), findsNothing);
    expect(find.text('BACK TO EDIT'), findsNothing);
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
    expect(find.bySemanticsLabel(RegExp('CONFIRM')), findsNothing);
    expect(find.bySemanticsLabel(RegExp('BACK TO EDIT')), findsNothing);
    semantics.dispose();
  });

  obsoleteTestWidgets(
    'Daily Review shows the finalization explanation and subtitle',
    (tester) async {
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
          '確定後は本日の通常編集・削除がロックされます。'
          '変更が必要な場合は訂正フローを使用してください。',
        ),
        findsOneWidget,
      );
      expect(find.text('本日の記録を確定'), findsOneWidget);
    },
  );

  obsoleteTestWidgets(
    'Finalize success shows BACKUP prompt after confirmation',
    (tester) async {
      var confirmed = false;
      final gateway = _RecordingBackupGateway();
      await _pumpReview(
        tester,
        morning: _morning(),
        food: _food(),
        activity: _activity(),
        training: null,
        estimatedTotalBurn: 2100,
        backupExportService: _backupService(gateway),
        confirmDailyLog: (_) async => confirmed = true,
      );

      await tester.tap(find.text('FINALIZE DAY'));
      await tester.pumpAndSettle();

      expect(confirmed, isTrue);
      expect(find.text('BACKUP'), findsOneWidget);
      expect(find.text('本日の記録を確定しました。\n最新のBACKUPを出力しますか？'), findsOneWidget);
      expect(find.text('EXPORT BACKUP'), findsOneWidget);
      expect(find.text('NOT NOW'), findsOneWidget);
      expect(gateway.exportCount, 0);
    },
  );

  obsoleteTestWidgets('NOT NOW skips BACKUP and keeps completed finalization', (
    tester,
  ) async {
    var confirmationCount = 0;
    final gateway = _RecordingBackupGateway();
    await _pumpReview(
      tester,
      morning: _morning(),
      food: _food(),
      activity: _activity(),
      training: null,
      estimatedTotalBurn: 2100,
      backupExportService: _backupService(gateway),
      confirmDailyLog: (_) async => confirmationCount++,
    );

    await tester.tap(find.text('FINALIZE DAY'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('NOT NOW'));
    await tester.pumpAndSettle();

    expect(confirmationCount, 1);
    expect(gateway.exportCount, 0);
    expect(find.text('BACKUP'), findsNothing);
  });

  obsoleteTestWidgets(
    'EXPORT BACKUP reports handoff without claiming iCloud save',
    (tester) async {
      var confirmationCount = 0;
      final gateway = _RecordingBackupGateway();
      await _pumpReview(
        tester,
        morning: _morning(),
        food: _food(),
        activity: _activity(),
        training: null,
        estimatedTotalBurn: 2100,
        backupExportService: _backupService(gateway),
        confirmDailyLog: (_) async => confirmationCount++,
      );

      await tester.tap(find.text('FINALIZE DAY'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('EXPORT BACKUP'));
      await tester.pumpAndSettle();

      expect(confirmationCount, 1);
      expect(gateway.exportCount, 1);
      expect(find.text('Backup exported'), findsOneWidget);
      expect(
        find.text(
          'BACKUPファイルを共有画面へ出力しました。\n'
          '保存先は端末側で確認してください。',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('iCloudへ保存'), findsNothing);
      expect(find.textContaining('iCloud Sync'), findsNothing);
    },
  );

  obsoleteTestWidgets(
    'share cancellation is neutral and preserves finalization',
    (tester) async {
      var confirmationCount = 0;
      final gateway = _RecordingBackupGateway(
        delivery: BackupFileDelivery.cancelled,
      );
      await _pumpReview(
        tester,
        morning: _morning(),
        food: _food(),
        activity: _activity(),
        training: null,
        estimatedTotalBurn: 2100,
        backupExportService: _backupService(gateway),
        confirmDailyLog: (_) async => confirmationCount++,
      );

      await tester.tap(find.text('FINALIZE DAY'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('EXPORT BACKUP'));
      await tester.pumpAndSettle();

      expect(confirmationCount, 1);
      expect(find.text('BACKUPの保存をキャンセルしました。'), findsOneWidget);
      expect(find.text('RETRY'), findsNothing);
    },
  );

  obsoleteTestWidgets(
    'export failure offers retry without rolling back finalization',
    (tester) async {
      var confirmationCount = 0;
      final gateway = _RecordingBackupGateway(failure: StateError('failed'));
      await _pumpReview(
        tester,
        morning: _morning(),
        food: _food(),
        activity: _activity(),
        training: null,
        estimatedTotalBurn: 2100,
        backupExportService: _backupService(gateway),
        confirmDailyLog: (_) async => confirmationCount++,
      );

      await tester.tap(find.text('FINALIZE DAY'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('EXPORT BACKUP'));
      await tester.pumpAndSettle();

      expect(confirmationCount, 1);
      expect(find.text('BACKUPの出力に失敗しました。'), findsOneWidget);
      expect(find.text('RETRY'), findsOneWidget);

      gateway.failure = null;
      await tester.tap(find.text('RETRY'));
      await tester.pumpAndSettle();
      expect(confirmationCount, 1);
      expect(gateway.exportCount, 2);
      expect(find.text('Backup exported'), findsOneWidget);
    },
  );

  obsoleteTestWidgets('Finalize failure never shows BACKUP prompt', (
    tester,
  ) async {
    await _pumpReview(
      tester,
      morning: _morning(),
      food: _food(),
      activity: _activity(),
      training: null,
      estimatedTotalBurn: 2100,
      backupExportService: _backupService(_RecordingBackupGateway()),
      confirmDailyLog: (_) async => throw StateError('confirmation failed'),
    );

    await tester.tap(find.text('FINALIZE DAY'));
    await tester.pumpAndSettle();

    expect(find.text('BACKUP'), findsNothing);
    expect(find.text('DAILY LOGのデータを準備できませんでした。'), findsOneWidget);
  });

  obsoleteTestWidgets(
    'Finalize blocks repeated taps and shows one BACKUP dialog',
    (tester) async {
      var confirmationCount = 0;
      final confirmation = Completer<void>();
      await _pumpReview(
        tester,
        morning: _morning(),
        food: _food(),
        activity: _activity(),
        training: null,
        estimatedTotalBurn: 2100,
        backupExportService: _backupService(_RecordingBackupGateway()),
        confirmDailyLog: (_) async {
          confirmationCount++;
          await confirmation.future;
        },
      );

      final button = tester.widget<ElevatedButton>(
        find.ancestor(
          of: find.text('FINALIZE DAY'),
          matching: find.byType(ElevatedButton),
        ),
      );
      button.onPressed!();
      button.onPressed!();
      await tester.pump();
      expect(confirmationCount, 1);

      confirmation.complete();
      await tester.pumpAndSettle();
      expect(find.text('BACKUP'), findsOneWidget);
    },
  );

  obsoleteTestWidgets('BACKUP prompt remains overflow-free at 320 pixels', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final semantics = tester.ensureSemantics();

    await _pumpReview(
      tester,
      morning: _morning(),
      food: _food(),
      activity: _activity(),
      training: null,
      estimatedTotalBurn: 2100,
      backupExportService: _backupService(_RecordingBackupGateway()),
      confirmDailyLog: (_) async {},
    );
    await tester.ensureVisible(find.text('FINALIZE DAY'));
    await tester.tap(find.text('FINALIZE DAY'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.bySemanticsLabel(RegExp('EXPORT BACKUP')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('NOT NOW')), findsOneWidget);
    semantics.dispose();
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
          phase: OperationPhase.open,
          finalizeReady: false,
          onPrimaryAction: null,
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
  _installOpenOperationState(dailyLogConfirmationNotifier.value.date);
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(home: const DashboardPage(), onGenerateRoute: onGenerateRoute),
  );
  await tester.pump();
}

void _installOpenOperationState(DateTime date) {
  final database = FakeIndexedDbDatabase();
  final timestamp = DateTime.utc(2026, 8, 13);
  database.seed(
    IndexedDbStoreNames.operationState,
    OperationState.canonicalId,
    OperationState(
      operationDate: OperationLocalDate.fromDateTime(date),
      createdAt: timestamp,
      updatedAt: timestamp,
    ).toRecord(),
  );
  AppRepositoryRegistry.install(AppRepositoryContainer.indexedDb(database));
}

Future<void> _pumpReview(
  WidgetTester tester, {
  required MorningFact? morning,
  required FoodSummary? food,
  required ActivitySummary activity,
  required TrainingSummary? training,
  required double? estimatedTotalBurn,
  BackupFileExportService? backupExportService,
  ConfirmDailyLog? confirmDailyLog,
  ThemeData? theme,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: LogConfirmationReviewPage(
        targetDate: morning?.date ?? DateTime(2026, 7, 28),
        morning: morning,
        food: food,
        activity: activity,
        training: training,
        estimatedTotalBurn: estimatedTotalBurn,
        confirmDailyLog: confirmDailyLog,
      ),
    ),
  );
  await tester.pump();
}

void _expectRow(String key, List<String> values) {
  final row = find.byKey(ValueKey(key));
  expect(row, findsOneWidget);
  for (final value in values) {
    expect(
      find.descendant(of: row, matching: find.text(value)),
      findsOneWidget,
    );
  }
}

Color? _balanceValueColor(WidgetTester tester) {
  final text = tester.widget<Text>(
    find.byKey(const ValueKey('calorie-balance')),
  );
  final root = text.textSpan! as TextSpan;
  return (root.children![1] as TextSpan).style?.color;
}

BackupFileExportService _backupService(_RecordingBackupGateway gateway) {
  final database = FakeIndexedDbDatabase();
  final timestamp = DateTime.utc(2026, 7, 27);
  final state = OperationState(
    operationDate: OperationLocalDate.parse('2026-07-27'),
    createdAt: timestamp,
    updatedAt: timestamp,
  );
  database.seed(
    IndexedDbStoreNames.operationState,
    OperationState.canonicalId,
    state.toRecord(),
  );
  return BackupFileExportService(
    exportService: BackupExportService(
      database: database,
      controller: AppInitializationController()..markReady(),
      clock: () => DateTime(2026, 7, 27, 21, 35),
    ),
    fileGateway: gateway,
  );
}

class _RecordingBackupGateway implements BackupFileGateway {
  _RecordingBackupGateway({
    this.delivery = BackupFileDelivery.shared,
    this.failure,
  });

  BackupFileDelivery delivery;
  Object? failure;
  int exportCount = 0;

  @override
  String get origin => 'https://example.test';

  @override
  Future<BackupFileDelivery> shareOrSave({
    required String fileName,
    required String content,
  }) async {
    exportCount++;
    final failure = this.failure;
    if (failure != null) throw failure;
    return delivery;
  }

  @override
  Future<BackupSelectedFile?> selectJson() async => null;
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

FoodSummary _foodWithCalories(double calories) {
  return FoodSummary(
    calories: calories,
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

ActivitySummary _digestiveActivity({
  required int eventCount,
  required int totalAmount,
  required int? latestShape,
  required int? latestRelief,
  bool hasExplicitNoMovement = false,
}) {
  return ActivitySummary(
    steps: 8900,
    measuredSteps: 7659,
    carryOver: 1241,
    isRecorded: true,
    digestiveSummary: DigestiveSummary(
      eventCount: eventCount,
      totalAmount: totalAmount,
      latestShape: latestShape,
      latestRelief: latestRelief,
      shapeTrend: eventCount == 0
          ? const []
          : List<int>.filled(eventCount, latestShape!),
      reliefTrend: eventCount == 0
          ? const []
          : List<int>.filled(eventCount, latestRelief!),
      hasExplicitNoMovement: hasExplicitNoMovement,
    ),
    calculationBasis: const ActivityCalculationBasis(
      rawSteps: 7659,
      currentCarryOver: 1241,
      previousCarryOverDeduction: 0,
      officialSteps: 8900,
    ),
  );
}
