import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/engine/activity_summary.dart';
import 'package:or_app/core/engine/digestive_summary.dart';
import 'package:or_app/core/engine/food_summary.dart';
import 'package:or_app/core/engine/training_summary.dart';
import 'package:or_app/core/models/daily_log_confirmation_status.dart';
import 'package:or_app/core/navigation/app_routes.dart';
import 'package:or_app/core/services/daily_log_confirmation_state.dart';
import 'package:or_app/core/state/app_initialization_state.dart';
import 'package:or_app/core/widgets/operation_button.dart';
import 'package:or_app/core/widgets/operation_card.dart';
import 'package:or_app/core/widgets/operation_flip_tile.dart';
import 'package:or_app/features/activity/models/activity_summary_state.dart';
import 'package:or_app/features/activity/models/activity_draft.dart';
import 'package:or_app/features/dashboard/dashboard_page.dart';
import 'package:or_app/features/food/models/food_summary_state.dart';
import 'package:or_app/features/morning/models/morning_fact.dart';
import 'package:or_app/features/morning/models/morning_fact_state.dart';
import 'package:or_app/features/repositories/app_repository_container.dart';
import 'package:or_app/features/report_sync/models/morning_brief_record.dart';
import 'package:or_app/features/report_sync/models/morning_brief_state.dart';
import 'package:or_app/features/training/models/training_summary_state.dart';

import '../../repositories/indexed_db/fake_indexed_db_database.dart';
import '../operation_date/operation_date_test_fixture.dart';

void main() {
  setUp(() {
    appInitializationController.markReady();
    dailyLogConfirmationNotifier.value = DailyLogConfirmationStatus.unconfirmed(
      DateTime(2026, 7, 28),
    );
    morningFactNotifier.value = null;
    foodSummaryNotifier.value = null;
    activitySummaryNotifier.value = const ActivitySummary.empty();
    trainingSummaryNotifier.value = null;
    morningBriefRevisionNotifier.value = 0;
  });

  testWidgets('uses the approved two-column order and full-width ACTIVITY', (
    tester,
  ) async {
    await _pumpDashboard(tester, width: 800);

    expect(find.text('OPERATION PROGRESS'), findsOneWidget);
    expect(find.text('DAILY LOG'), findsOneWidget);
    expect(find.byIcon(Icons.timeline_outlined), findsOneWidget);
    expect(find.byIcon(Icons.fact_check_outlined), findsWidgets);
    expect(find.text('MORNING ROUTINE'), findsNothing);
    expect(find.text('Morning Routine'), findsNothing);
    final header = tester.widget<Text>(find.text('OPERATION PROGRESS'));
    expect(header.style?.fontSize, 18);
    expect(header.style?.fontWeight, FontWeight.bold);

    final status = _tile('STATUS');
    final food = _tile('FOOD');
    final calories = _tile('CALORIES');
    final protein = _tile('PROTEIN');
    final water = _tile('WATER');
    final training = _tile('TRAINING');
    final activity = _tile('ACTIVITY');

    expect(tester.getTopLeft(status).dy, tester.getTopLeft(food).dy);
    expect(tester.getTopLeft(calories).dy, tester.getTopLeft(protein).dy);
    expect(tester.getTopLeft(water).dy, tester.getTopLeft(training).dy);
    expect(
      tester.getTopLeft(calories).dy,
      greaterThan(tester.getTopLeft(status).dy),
    );
    expect(
      tester.getTopLeft(water).dy,
      greaterThan(tester.getTopLeft(calories).dy),
    );
    expect(
      tester.getTopLeft(activity).dy,
      greaterThan(tester.getTopLeft(water).dy),
    );
    expect(
      tester.getSize(activity).width,
      closeTo(tester.getSize(status).width * 2 + 12, 0.1),
    );

    for (final label in _labels) {
      final progressFinder = find.descendant(
        of: _tile(label),
        matching: find.byType(LinearProgressIndicator),
      );
      expect(progressFinder, findsOneWidget);
      final indicator = tester.widget<LinearProgressIndicator>(progressFinder);
      expect(indicator.color, isNull);
      expect(indicator.backgroundColor, isNull);
    }
  });

  testWidgets('OPERATION DATE uses three static flip tiles without overflow', (
    tester,
  ) async {
    final database = FakeIndexedDbDatabase();
    seedOperationState(database, '2026-07-28');
    AppRepositoryRegistry.install(AppRepositoryContainer.indexedDb(database));
    addTearDown(AppRepositoryRegistry.resetForTesting);

    for (final width in [320.0, 390.0, 900.0]) {
      await _pumpDashboard(tester, width: width);
      await tester.pumpAndSettle();

      expect(find.text('JUL'), findsOneWidget);
      expect(find.text('28'), findsOneWidget);
      expect(find.text('TUE'), findsOneWidget);
      expect(find.text('2026-07-28'), findsNothing);
      final row = find.byKey(const ValueKey('operation-date-flip-row'));
      final month = find.byKey(const ValueKey('operation-date-tile-0'));
      final day = find.byKey(const ValueKey('operation-date-tile-1'));
      final weekday = find.byKey(const ValueKey('operation-date-tile-2'));
      final operationDateCard = find.ancestor(
        of: find.text('OPERATION DATE'),
        matching: find.byType(OperationCard),
      );

      expect(
        find.ancestor(of: month, matching: find.byType(Expanded)),
        findsNothing,
      );
      expect(tester.getSize(month), const Size(52, 36));
      expect(tester.getSize(day), const Size(52, 36));
      expect(tester.getSize(weekday), const Size(52, 36));
      expect(tester.getSize(row).width, 168);
      expect(
        tester.getSize(row).width,
        lessThan(tester.getSize(operationDateCard).width * 0.75),
      );
      expect(tester.getTopLeft(day).dx - tester.getTopRight(month).dx, 6);
      expect(tester.getTopLeft(weekday).dx - tester.getTopRight(day).dx, 6);
      expect(
        tester.getTopLeft(row).dx,
        lessThan(tester.getCenter(operationDateCard).dx),
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('successful DAILY REVIEW return flips only changed date tiles', (
    tester,
  ) async {
    final database = FakeIndexedDbDatabase();
    seedOperationState(database, '2026-08-11');
    AppRepositoryRegistry.install(AppRepositoryContainer.indexedDb(database));
    addTearDown(AppRepositoryRegistry.resetForTesting);
    tester.view.physicalSize = const Size(390, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: const DashboardPage(),
        onGenerateRoute: (settings) => PageRouteBuilder<Object?>(
          settings: settings,
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
          pageBuilder: (context, _, _) => Scaffold(
            body: TextButton(
              onPressed: () {
                seedOperationState(database, '2026-08-12');
                Navigator.pop(context, true);
              },
              child: const Text('COMPLETE FINALIZE'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('AUG'), findsOneWidget);
    expect(find.text('11'), findsOneWidget);
    expect(find.text('TUE'), findsOneWidget);

    await Scrollable.ensureVisible(
      tester.element(find.text('DAILY REVIEW')),
      alignment: 0.5,
    );
    await tester.pump();
    expect(_dashboardScrollPosition(tester).pixels, greaterThan(0));
    await tester.tap(find.text('DAILY REVIEW'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('COMPLETE FINALIZE'));
    await tester.pump();

    expect(_dashboardScrollPosition(tester).pixels, 0);
    expect(find.text('AUG'), findsOneWidget);
    expect(find.text('11'), findsOneWidget);
    expect(find.text('12'), findsNothing);
    expect(find.text('TUE'), findsOneWidget);
    expect(find.text('WED'), findsNothing);

    await tester.pump();
    await tester.pump();
    final monthTile = find.byKey(const ValueKey('operation-date-tile-0'));
    final dayTile = find.byKey(const ValueKey('operation-date-tile-1'));
    final weekdayTile = find.byKey(const ValueKey('operation-date-tile-2'));
    expect(
      find.descendant(
        of: monthTile,
        matching: find.byKey(const ValueKey('mechanical-flip-static')),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: dayTile,
        matching: find.byKey(const ValueKey('mechanical-flip-old-upper')),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: weekdayTile,
        matching: find.byKey(const ValueKey('mechanical-flip-old-upper')),
      ),
      findsNothing,
    );
    expect(find.text('AUG'), findsOneWidget);
    expect(find.text('11'), findsWidgets);
    expect(find.text('12'), findsWidgets);
    expect(find.text('TUE'), findsOneWidget);
    expect(find.text('WED'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.pump(const Duration(milliseconds: 59));
    expect(
      find.descendant(
        of: weekdayTile,
        matching: find.byKey(const ValueKey('mechanical-flip-old-upper')),
      ),
      findsNothing,
    );
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    expect(
      find.descendant(
        of: weekdayTile,
        matching: find.byKey(const ValueKey('mechanical-flip-old-upper')),
      ),
      findsOneWidget,
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      find.descendant(
        of: dayTile,
        matching: find.byKey(const ValueKey('mechanical-flip-new-lower')),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: weekdayTile,
        matching: find.byKey(const ValueKey('mechanical-flip-old-upper')),
      ),
      findsOneWidget,
    );
    await tester.pumpAndSettle();
    expect(find.text('11'), findsNothing);
    expect(find.text('12'), findsOneWidget);
    expect(find.text('TUE'), findsNothing);
    expect(find.text('WED'), findsOneWidget);
    expect(
      find.descendant(
        of: dayTile,
        matching: find.byKey(const ValueKey('mechanical-flip-static')),
      ),
      findsOneWidget,
    );

    morningFactNotifier.value = _morning();
    await tester.pump();
    expect(find.text('AUG'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    expect(find.text('WED'), findsOneWidget);
  });

  testWidgets('failed DAILY REVIEW return does not refresh or flip date', (
    tester,
  ) async {
    final database = FakeIndexedDbDatabase();
    seedOperationState(database, '2026-08-11');
    AppRepositoryRegistry.install(AppRepositoryContainer.indexedDb(database));
    addTearDown(AppRepositoryRegistry.resetForTesting);
    tester.view.physicalSize = const Size(800, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: const DashboardPage(),
        routes: {
          AppRoutes.logConfirmationReview: (context) => Scaffold(
            body: TextButton(
              onPressed: () {
                seedOperationState(database, '2026-08-12');
                Navigator.pop(context, false);
              },
              child: const Text('FAIL FINALIZE'),
            ),
          ),
        },
      ),
    );
    await tester.pumpAndSettle();
    await Scrollable.ensureVisible(
      tester.element(find.text('DAILY REVIEW')),
      alignment: 0.5,
    );
    await tester.pump();
    final scrollOffset = _dashboardScrollPosition(tester).pixels;
    expect(scrollOffset, greaterThan(0));
    await tester.tap(find.text('DAILY REVIEW'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('FAIL FINALIZE'));
    await tester.pumpAndSettle();

    expect(find.text('AUG'), findsOneWidget);
    expect(find.text('11'), findsOneWidget);
    expect(find.text('TUE'), findsOneWidget);
    expect(find.text('12'), findsNothing);
    expect(find.text('WED'), findsNothing);
    expect(_dashboardScrollPosition(tester).pixels, scrollOffset);
  });

  testWidgets('normal module navigation preserves Dashboard scroll position', (
    tester,
  ) async {
    final database = FakeIndexedDbDatabase();
    seedOperationState(database, '2026-08-11');
    AppRepositoryRegistry.install(AppRepositoryContainer.indexedDb(database));
    addTearDown(AppRepositoryRegistry.resetForTesting);
    tester.view.physicalSize = const Size(800, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: const DashboardPage(),
        routes: {
          AppRoutes.morning: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('RETURN TO DASHBOARD'),
            ),
          ),
        },
      ),
    );
    await tester.pumpAndSettle();
    await Scrollable.ensureVisible(
      tester.element(find.bySemanticsLabel('STATUS incomplete')),
      alignment: 0.5,
    );
    await tester.pump();
    final scrollOffset = _dashboardScrollPosition(tester).pixels;
    expect(scrollOffset, greaterThan(0));

    await tester.tap(find.bySemanticsLabel('STATUS incomplete'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('RETURN TO DASHBOARD'));
    await tester.pumpAndSettle();

    expect(_dashboardScrollPosition(tester).pixels, scrollOffset);
  });

  testWidgets('month crossing flips month day and weekday tiles', (
    tester,
  ) async {
    final database = FakeIndexedDbDatabase();
    seedOperationState(database, '2026-08-31');
    AppRepositoryRegistry.install(AppRepositoryContainer.indexedDb(database));
    addTearDown(AppRepositoryRegistry.resetForTesting);
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: const DashboardPage(),
        onGenerateRoute: (settings) => PageRouteBuilder<Object?>(
          settings: settings,
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
          pageBuilder: (context, _, _) => Scaffold(
            body: TextButton(
              onPressed: () {
                seedOperationState(database, '2026-09-01');
                Navigator.pop(context, true);
              },
              child: const Text('COMPLETE MONTH FINALIZE'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('DAILY REVIEW'));
    await tester.tap(find.text('DAILY REVIEW'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('COMPLETE MONTH FINALIZE'));
    await tester.pump();

    expect(find.text('AUG'), findsOneWidget);
    expect(find.text('SEP'), findsNothing);
    expect(find.text('31'), findsOneWidget);
    expect(find.text('01'), findsNothing);
    expect(find.text('MON'), findsOneWidget);
    expect(find.text('TUE'), findsNothing);

    await tester.pump();
    await tester.pump();

    final tiles = [
      for (var index = 0; index < 3; index++)
        tester.widget<OperationMechanicalFlipTile>(
          find.byKey(ValueKey('operation-date-tile-$index')),
        ),
    ];
    expect(
      OperationMechanicalFlipTile.duration,
      const Duration(milliseconds: 320),
    );
    expect(tiles[0].startDelay, Duration.zero);
    expect(tiles[1].startDelay, const Duration(milliseconds: 60));
    expect(tiles[2].startDelay, const Duration(milliseconds: 120));
    expect(find.text('AUG'), findsWidgets);
    expect(find.text('SEP'), findsWidgets);
    expect(find.text('31'), findsOneWidget);
    expect(find.text('01'), findsNothing);
    expect(find.text('MON'), findsOneWidget);
    expect(find.text('TUE'), findsNothing);
    await tester.pump(const Duration(milliseconds: 60));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.text('AUG'), findsNothing);
    expect(find.text('SEP'), findsOneWidget);
    expect(find.text('31'), findsNothing);
    expect(find.text('01'), findsOneWidget);
    expect(find.text('MON'), findsNothing);
    expect(find.text('TUE'), findsOneWidget);
  });

  testWidgets('keeps existing values, targets, progress, and module states', (
    tester,
  ) async {
    morningFactNotifier.value = _morning();
    foodSummaryNotifier.value = const FoodSummary(
      calories: 1100,
      protein: 50,
      fat: 30,
      carbohydrates: 120,
      hydrationMl: 1750,
      mealCount: 2,
    );
    trainingSummaryNotifier.value = const TrainingSummary(
      completed: true,
      exerciseCount: 2,
      setCount: 6,
      duration: null,
      sessionName: null,
    );
    activitySummaryNotifier.value = const ActivitySummary(
      steps: 12345,
      measuredSteps: 12345,
      isRecorded: true,
    );

    await _pumpDashboard(tester, width: 800);

    _expectTileText('STATUS', '完了');
    _expectTileText('FOOD', '2 / 3');
    _expectTileText('CALORIES', '1100 / 2200 kcal');
    _expectTileText('PROTEIN', '50.0 / 100 g');
    _expectTileText('WATER', '1750 / 3500 ml');
    _expectTileText('TRAINING', 'Recorded');
    _expectTileText('ACTIVITY', '12,345 steps');
    expect(
      find.descendant(
        of: _tile('ACTIVITY'),
        matching: find.textContaining('Digestive'),
      ),
      findsNothing,
    );

    expect(_progress(tester, 'STATUS'), 1);
    expect(_progress(tester, 'FOOD'), closeTo(2 / 3, 1e-12));
    expect(_progress(tester, 'CALORIES'), 0.5);
    expect(_progress(tester, 'PROTEIN'), 0.5);
    expect(_progress(tester, 'WATER'), 0.5);
    expect(_progress(tester, 'TRAINING'), 1);
    expect(_progress(tester, 'ACTIVITY'), 1);
  });

  testWidgets(
    'DAILY COMMAND has no COMMAND CENTER navigation but quick access remains',
    (tester) async {
      final database = FakeIndexedDbDatabase();
      seedOperationState(database, '2026-07-28');
      AppRepositoryRegistry.install(AppRepositoryContainer.indexedDb(database));
      addTearDown(AppRepositoryRegistry.resetForTesting);

      await _pumpDashboard(tester, width: 390);
      await tester.pumpAndSettle();

      final dailyCommandCard = find.ancestor(
        of: find.text('OPERATION STATUS'),
        matching: find.byType(OperationCard),
      );
      expect(dailyCommandCard, findsOneWidget);
      expect(
        find.descendant(
          of: dailyCommandCard,
          matching: find.widgetWithText(TextButton, 'COMMAND CENTER'),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: dailyCommandCard,
          matching: find.byIcon(Icons.chevron_right),
        ),
        findsNothing,
      );
      expect(
        find.widgetWithText(OperationButton, 'COMMAND CENTER'),
        findsOneWidget,
      );
    },
  );

  testWidgets('DAILY COMMAND uses same-date MB and refreshes without restart', (
    tester,
  ) async {
    final database = FakeIndexedDbDatabase();
    seedOperationState(database, '2026-07-28');
    AppRepositoryRegistry.install(AppRepositoryContainer.indexedDb(database));
    addTearDown(AppRepositoryRegistry.resetForTesting);
    await AppRepositoryRegistry.container.morningBriefs.create(
      _brief('2026-07-27', intent: 'OTHER DATE INTENT'),
    );

    await _pumpDashboard(tester, width: 390);
    await tester.pumpAndSettle();
    expect(find.text('STANDBY'), findsOneWidget);
    expect(find.text('OTHER DATE INTENT'), findsNothing);

    await AppRepositoryRegistry.container.morningBriefs.create(
      _brief('2026-07-28', intent: 'LIVE COMMANDER INTENT'),
    );
    notifyMorningBriefChanged();
    await tester.pumpAndSettle();

    expect(find.text('GREEN'), findsOneWidget);
    expect(find.text('LIVE COMMANDER INTENT'), findsOneWidget);
    expect(find.text('COMMANDER INTENT'), findsOneWidget);
    expect(find.text('ARGO COMMENT'), findsNothing);
    expect(find.text('BODY'), findsNothing);
    expect(find.text('RECOVERY'), findsNothing);
    expect(find.text('CARRYOVER'), findsNothing);
    expect(find.text('OVERALL'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps missing STATUS, FOOD, TRAINING, and ACTIVITY contracts', (
    tester,
  ) async {
    await _pumpDashboard(tester, width: 800);

    _expectTileText('STATUS', '未完了');
    _expectTileText('FOOD', '0 / 3');
    _expectTileText('TRAINING', 'Not recorded');
    _expectTileText('ACTIVITY', 'Not recorded');
    expect(
      find.descendant(
        of: _tile('ACTIVITY'),
        matching: find.textContaining('Digestive'),
      ),
      findsNothing,
    );
    expect(
      find.descendant(of: _tile('ACTIVITY'), matching: find.text('0 steps')),
      findsNothing,
    );
    expect(find.text('実施'), findsNothing);
    expect(find.text('未実施'), findsNothing);
    expect(_progress(tester, 'TRAINING'), 0);
    expect(_progress(tester, 'ACTIVITY'), 0);
  });

  testWidgets('shows one formal Digestive Event in ACTIVITY', (tester) async {
    activitySummaryNotifier.value = ActivitySummary(
      steps: 6000,
      isRecorded: true,
      digestiveSummary: _digestiveSummary(amounts: const [2]),
    );

    await _pumpDashboard(tester, width: 800);

    _expectTileText('ACTIVITY', '6,000 steps');
    _expectTileText('ACTIVITY', 'Digestive Count 1');
    _expectTileText('ACTIVITY', 'Total Amount 2');
    expect(_progress(tester, 'ACTIVITY'), 1);
  });

  testWidgets('totals multiple formal Digestive Events in ACTIVITY', (
    tester,
  ) async {
    activitySummaryNotifier.value = ActivitySummary(
      steps: 0,
      isRecorded: true,
      digestiveSummary: _digestiveSummary(amounts: const [2, 3]),
    );

    await _pumpDashboard(tester, width: 800);

    _expectTileText('ACTIVITY', '0 steps');
    _expectTileText('ACTIVITY', 'Digestive Count 2');
    _expectTileText('ACTIVITY', 'Total Amount 5');
    expect(_progress(tester, 'ACTIVITY'), 1);
  });

  testWidgets('does not complete ACTIVITY from a Draft alone', (tester) async {
    final database = FakeIndexedDbDatabase();
    final controller = AppInitializationController()..markReady();
    AppRepositoryRegistry.beginStartup(controller: controller);
    AppRepositoryRegistry.install(AppRepositoryContainer.indexedDb(database));
    addTearDown(AppRepositoryRegistry.resetForTesting);

    final now = DateTime.utc(2020);
    await AppRepositoryRegistry.container.activityDrafts.save(
      ActivityDraft(
        localDate: '2026-07-28',
        measuredStepsInput: '4321',
        createdAt: now,
        updatedAt: now,
      ),
    );

    await _pumpDashboard(tester, width: 800);

    _expectTileText('ACTIVITY', 'Not recorded');
    expect(
      find.descendant(
        of: _tile('ACTIVITY'),
        matching: find.textContaining('Digestive'),
      ),
      findsNothing,
    );
    expect(_progress(tester, 'ACTIVITY'), 0);
  });

  testWidgets('shows explicit no movement only for a formal Record', (
    tester,
  ) async {
    activitySummaryNotifier.value = ActivitySummary(
      steps: 4000,
      isRecorded: true,
      digestiveSummary: _digestiveSummary(
        amounts: const [],
        hasExplicitNoMovement: true,
      ),
    );

    await _pumpDashboard(tester, width: 800);

    _expectTileText('ACTIVITY', '4,000 steps');
    _expectTileText('ACTIVITY', 'Digestive None');
    expect(find.textContaining('Count 0'), findsNothing);
    expect(find.textContaining('Total Amount 0'), findsNothing);
    expect(_progress(tester, 'ACTIVITY'), 1);
  });

  testWidgets('omits Digestive details when a formal Record has no input', (
    tester,
  ) async {
    activitySummaryNotifier.value = ActivitySummary(
      steps: 0,
      isRecorded: true,
      digestiveSummary: _digestiveSummary(amounts: const []),
    );

    await _pumpDashboard(tester, width: 800);

    _expectTileText('ACTIVITY', '0 steps');
    expect(
      find.descendant(
        of: _tile('ACTIVITY'),
        matching: find.textContaining('Digestive'),
      ),
      findsNothing,
    );
    expect(_progress(tester, 'ACTIVITY'), 1);
  });

  testWidgets('uses two columns at a normal smartphone width', (tester) async {
    await _pumpDashboard(tester, width: 390);

    expect(
      tester.getTopLeft(_tile('STATUS')).dy,
      tester.getTopLeft(_tile('FOOD')).dy,
    );
    expect(
      tester.getTopLeft(_tile('WATER')).dy,
      tester.getTopLeft(_tile('TRAINING')).dy,
    );
    _expectProgressTilesFit(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('falls back to one column without overflow at 320 pixels', (
    tester,
  ) async {
    await _pumpDashboard(tester, width: 320);

    final positions = [
      for (final label in _labels) tester.getTopLeft(_tile(label)),
    ];
    for (var index = 1; index < positions.length; index++) {
      expect(positions[index].dx, positions.first.dx);
      expect(positions[index].dy, greaterThan(positions[index - 1].dy));
    }
    _expectProgressTilesFit(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('switches tile columns at 280 pixels of available tile width', (
    tester,
  ) async {
    await _pumpDashboard(tester, width: 343);
    expect(tester.getSize(_progressTiles()).width, 279);
    expect(
      tester.getTopLeft(_tile('STATUS')).dx,
      tester.getTopLeft(_tile('FOOD')).dx,
    );

    await _pumpDashboard(tester, width: 344);
    expect(tester.getSize(_progressTiles()).width, 280);
    expect(
      tester.getTopLeft(_tile('STATUS')).dy,
      tester.getTopLeft(_tile('FOOD')).dy,
    );
    _expectProgressTilesFit(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps Medium layout through 899 pixels and centers content', (
    tester,
  ) async {
    await _pumpDashboard(tester, width: 899);

    expect(
      find.byKey(const ValueKey('operation-progress-compact-layout')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('operation-progress-large-layout')),
      findsNothing,
    );
    expect(find.text('OPERATION SUMMARY'), findsNothing);
    expect(tester.getCenter(_mainContent()).dx, closeTo(899 / 2, 0.1));
    expect(
      tester.getTopLeft(_tile('STATUS')).dy,
      tester.getTopLeft(_tile('FOOD')).dy,
    );
    _expectProgressTilesFit(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('uses Large summary and two-column Progress at 900 pixels', (
    tester,
  ) async {
    await _pumpDashboard(tester, width: 900);

    expect(
      find.byKey(const ValueKey('operation-progress-large-layout')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('operation-progress-compact-layout')),
      findsNothing,
    );
    expect(find.text('OPERATION SUMMARY'), findsOneWidget);
    expect(
      tester.getTopLeft(_operationSummary()).dx,
      lessThan(tester.getTopLeft(_progressTiles()).dx),
    );
    expect(
      tester.getSize(_operationSummary()).width,
      lessThan(tester.getSize(_progressTiles()).width),
    );
    expect(
      tester.getTopLeft(_tile('STATUS')).dy,
      tester.getTopLeft(_tile('FOOD')).dy,
    );
    expect(
      tester.getSize(_tile('ACTIVITY')).width,
      closeTo(tester.getSize(_progressTiles()).width, 0.1),
    );
    _expectProgressTilesFit(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps Large layout stable at 1024 and 1280 pixels', (
    tester,
  ) async {
    for (final width in [1024.0, 1280.0]) {
      await _pumpDashboard(tester, width: width);

      expect(tester.getCenter(_mainContent()).dx, closeTo(width / 2, 0.1));
      expect(
        tester.getTopLeft(_operationSummary()).dx,
        lessThan(tester.getTopLeft(_progressTiles()).dx),
      );
      expect(
        tester.getTopLeft(_tile('STATUS')).dy,
        tester.getTopLeft(_tile('FOOD')).dy,
      );
      expect(
        tester.getSize(_tile('ACTIVITY')).width,
        closeTo(tester.getSize(_progressTiles()).width, 0.1),
      );
      _expectProgressTilesFit(tester);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('caps and centers Main Content on 1440 and 1920 displays', (
    tester,
  ) async {
    await _pumpDashboard(tester, width: 1440);

    expect(tester.getSize(_mainContent()).width, 1280);
    expect(tester.getCenter(_mainContent()).dx, 720);
    expect(tester.getSize(_tile('ACTIVITY')).width, closeTo(734.4, 0.1));
    expect(tester.takeException(), isNull);

    await _pumpDashboard(tester, width: 1920);

    expect(tester.getSize(_mainContent()).width, 1280);
    expect(tester.getCenter(_mainContent()).dx, 960);
    expect(tester.getTopLeft(_mainContent()).dx, 320);
    _expectProgressTilesFit(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Large DAILY LOG stays two-column with full-width review action',
    (tester) async {
      for (final width in [900.0, 1280.0, 1920.0]) {
        await _pumpDashboard(tester, width: width);

        final status = find.bySemanticsLabel('STATUS incomplete');
        final food = find.bySemanticsLabel('FOOD incomplete');
        final training = find.bySemanticsLabel(
          'TRAINING not recorded optional',
        );
        final activity = find.bySemanticsLabel('ACTIVITY incomplete');
        final reviewButton = find.text('DAILY REVIEW');

        expect(tester.getTopLeft(status).dy, tester.getTopLeft(food).dy);
        expect(tester.getTopLeft(training).dy, tester.getTopLeft(activity).dy);
        expect(
          tester.getTopLeft(training).dy,
          greaterThan(tester.getTopLeft(status).dy),
        );
        expect(
          tester.getTopLeft(reviewButton).dy,
          greaterThan(tester.getTopLeft(training).dy),
        );
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets('keeps WATER tile tap behavior', (tester) async {
    await _pumpDashboard(tester, width: 800);

    await tester.tap(_tile('WATER'));
    await tester.pumpAndSettle();

    expect(find.text('QUICK WATER LOG'), findsOneWidget);
    expect(find.text('250 ml'), findsOneWidget);
    expect(find.text('Save Water'), findsOneWidget);
  });

  testWidgets('Quick Water saves to the Operation Date', (tester) async {
    final database = FakeIndexedDbDatabase();
    seedOperationState(database, '2026-07-31');
    final controller = AppInitializationController()..markReady();
    AppRepositoryRegistry.beginStartup(controller: controller);
    AppRepositoryRegistry.install(AppRepositoryContainer.indexedDb(database));
    addTearDown(AppRepositoryRegistry.resetForTesting);

    await _pumpDashboard(tester, width: 800);
    await tester.tap(_tile('WATER'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('250 ml'));
    await tester.pumpAndSettle();

    final records = await AppRepositoryRegistry.container.food.findAll();
    expect(records.single.date, '2026-07-31');
  });

  testWidgets('renders the grid without overflow in light and dark themes', (
    tester,
  ) async {
    await _pumpDashboard(tester, width: 390, theme: ThemeData.light());
    _expectProgressTilesFit(tester);

    await _pumpDashboard(tester, width: 390, theme: ThemeData.dark());
    _expectProgressTilesFit(tester);
  });

  testWidgets('shows total Training energy without CARDIO ONLY', (
    tester,
  ) async {
    morningFactNotifier.value = _morning();
    trainingSummaryNotifier.value = const TrainingSummary(
      completed: true,
      exerciseCount: 0,
      setCount: 0,
      duration: null,
      sessionName: null,
      trainingCardioCaloriesKcal: 32,
      trainingStrengthCaloriesKcal: 68,
      trainingEstimatedCaloriesKcal: 100,
      computedCardioCount: 1,
      uncomputedCardioCount: 0,
      energyCalculationStatus: TrainingEnergyCalculationStatus.complete,
      totalEnergyCalculationStatus: TrainingEnergyCalculationStatus.complete,
      energyCalculationVersion: 1,
    );
    await _pumpDashboard(tester, width: 800);
    expect(find.text('100 kcal'), findsOneWidget);
    expect(find.text('2880 kcal'), findsOneWidget);
    expect(find.textContaining('CARDIO ONLY'), findsNothing);

    trainingSummaryNotifier.value = const TrainingSummary(
      completed: true,
      exerciseCount: 0,
      setCount: 0,
      duration: null,
      sessionName: null,
      trainingCardioCaloriesKcal: 32,
      trainingStrengthCaloriesKcal: 68,
      trainingEstimatedCaloriesKcal: 100,
      computedCardioCount: 1,
      uncomputedCardioCount: 1,
      energyCalculationStatus: TrainingEnergyCalculationStatus.partial,
      totalEnergyCalculationStatus: TrainingEnergyCalculationStatus.partial,
      energyCalculationVersion: 1,
    );
    await tester.pump();
    expect(find.text('100 kcal\nPartial'), findsOneWidget);
    expect(find.text('2880 kcal\nPartial'), findsOneWidget);

    trainingSummaryNotifier.value = const TrainingSummary(
      completed: true,
      exerciseCount: 0,
      setCount: 0,
      duration: null,
      sessionName: null,
      computedCardioCount: 0,
      uncomputedCardioCount: 1,
      energyCalculationStatus: TrainingEnergyCalculationStatus.notCalculated,
      totalEnergyCalculationStatus:
          TrainingEnergyCalculationStatus.notCalculated,
      energyCalculationVersion: 1,
    );
    await tester.pump();
    expect(find.text('Not calculated'), findsNWidgets(2));
    expect(find.text('0 kcal'), findsNothing);
  });
}

const _labels = [
  'STATUS',
  'FOOD',
  'CALORIES',
  'PROTEIN',
  'WATER',
  'TRAINING',
  'ACTIVITY',
];

Finder _tile(String label) => find.byKey(ValueKey('operation-progress-$label'));

Finder _mainContent() => find.byKey(const ValueKey('dashboard-main-content'));

Finder _operationSummary() => find.byKey(const ValueKey('operation-summary'));

Finder _progressTiles() =>
    find.byKey(const ValueKey('operation-progress-tiles'));

Finder _dashboardScrollable() => find.descendant(
  of: find.byKey(const ValueKey('dashboard-scroll-view')),
  matching: find.byType(Scrollable),
);

ScrollPosition _dashboardScrollPosition(WidgetTester tester) =>
    tester.state<ScrollableState>(_dashboardScrollable()).position;

void _expectTileText(String label, String text) {
  expect(
    find.descendant(of: _tile(label), matching: find.text(text)),
    findsOneWidget,
  );
}

double? _progress(WidgetTester tester, String label) {
  return tester
      .widget<LinearProgressIndicator>(
        find.descendant(
          of: _tile(label),
          matching: find.byType(LinearProgressIndicator),
        ),
      )
      .value;
}

void _expectProgressTilesFit(WidgetTester tester) {
  for (final label in _labels) {
    final tileRect = tester.getRect(_tile(label));
    final descendants = find.descendant(
      of: _tile(label),
      matching: find.byWidgetPredicate(
        (widget) => widget is Text || widget is LinearProgressIndicator,
      ),
    );

    for (final element in descendants.evaluate()) {
      final renderObject = element.renderObject;
      if (renderObject is! RenderBox || !renderObject.hasSize) continue;
      final topLeft = renderObject.localToGlobal(Offset.zero);
      final rect = topLeft & renderObject.size;
      expect(rect.left, greaterThanOrEqualTo(tileRect.left));
      expect(rect.right, lessThanOrEqualTo(tileRect.right));
    }
  }
}

Future<void> _pumpDashboard(
  WidgetTester tester, {
  required double width,
  ThemeData? theme,
}) async {
  tester.view.physicalSize = Size(width, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(theme: theme, home: const DashboardPage()),
  );
  await tester.pump();
}

DigestiveSummary _digestiveSummary({
  required List<int> amounts,
  bool hasExplicitNoMovement = false,
}) {
  return DigestiveSummary(
    eventCount: amounts.length,
    totalAmount: amounts.fold(0, (total, amount) => total + amount),
    latestShape: amounts.isEmpty ? null : 2,
    latestRelief: amounts.isEmpty ? null : 1,
    shapeTrend: [for (final _ in amounts) 2],
    reliefTrend: [for (final _ in amounts) 1],
    hasExplicitNoMovement: hasExplicitNoMovement,
  );
}

MorningFact _morning() {
  return MorningFact(
    date: DateTime(2026, 7, 28),
    weight: 90,
    bodyFat: 25,
    sleepDuration: const Duration(hours: 7),
    sleepScore: 80,
    workHours: 8,
    footPain: 1,
    medications: const [],
    freeNotes: null,
  );
}

MorningBriefRecord _brief(String date, {required String intent}) {
  final timestamp = DateTime.utc(2026, 7, 28);
  return MorningBriefRecord(
    localDate: date,
    requestId: 'request-$date',
    requestDigest:
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    responseDigest:
        'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
    generatedAt: timestamp,
    importedAt: timestamp,
    situationAnalysis: 'FORMAL SITUATION',
    operationStatus: MorningBriefOperationStatus.green,
    commanderIntent: intent,
    argoComment: 'MUST NOT DISPLAY',
    strategicResourceDecision: 'FORMAL RESOURCE',
    actions: const [],
    createdAt: timestamp,
    updatedAt: timestamp,
  );
}
