import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:or_app/core/engine/activity_summary.dart';
import 'package:or_app/core/engine/food_summary.dart';
import 'package:or_app/core/navigation/app_routes.dart';
import 'package:or_app/core/widgets/operation_flip_tile.dart';
import 'package:or_app/core/widgets/section_header.dart';
import 'package:or_app/data/indexed_db/indexed_db_store_names.dart';
import 'package:or_app/features/activity/models/activity_summary_state.dart';
import 'package:or_app/features/command_center/pages/command_center_page.dart';
import 'package:or_app/features/command_center/models/daily_command_read_model.dart';
import 'package:or_app/features/command_center/widgets/brief_debrief_page.dart';
import 'package:or_app/features/dashboard/widgets/daily_log_card.dart';
import 'package:or_app/features/food/models/food_summary_state.dart';
import 'package:or_app/features/morning/models/morning_fact.dart';
import 'package:or_app/features/morning/models/morning_fact_state.dart';
import 'package:or_app/features/operation_date/models/operation_active_attempt.dart';
import 'package:or_app/features/operation_date/models/operation_local_date.dart';
import 'package:or_app/features/operation_date/models/operation_state.dart';
import 'package:or_app/features/operation_date/widgets/operation_date_flip_calendar.dart';
import 'package:or_app/features/repositories/app_repository_container.dart';
import 'package:or_app/features/report_sync/models/daily_debrief_record.dart';
import 'package:or_app/features/report_sync/pages/report_sync_exchange_page.dart';
import 'package:or_app/features/report_sync/models/morning_brief_record.dart';
import 'package:or_app/features/training/models/training_summary_state.dart';

import '../../repositories/indexed_db/fake_indexed_db_database.dart';
import '../operation_date/operation_date_test_fixture.dart';

void main() {
  late FakeIndexedDbDatabase database;

  test('maps debrief lifecycle statuses to distinct formal symbols', () {
    final lifecycleIcons = {
      dailyDebriefLifecycleIconForStatus(DailyDebriefLifecycleStatus.active),
      dailyDebriefLifecycleIconForStatus(DailyDebriefLifecycleStatus.stale),
      dailyDebriefLifecycleIconForStatus(
        DailyDebriefLifecycleStatus.invalidated,
      ),
    };

    expect(
      dailyDebriefLifecycleIconForStatus(DailyDebriefLifecycleStatus.active),
      Icons.verified_outlined,
    );
    expect(
      dailyDebriefLifecycleIconForStatus(DailyDebriefLifecycleStatus.stale),
      Icons.history,
    );
    expect(
      dailyDebriefLifecycleIconForStatus(
        DailyDebriefLifecycleStatus.invalidated,
      ),
      Icons.block,
    );
    expect(lifecycleIcons, hasLength(3));
    expect(
      lifecycleIcons.intersection({
        Icons.check_circle,
        Icons.adjust,
        Icons.cancel,
        Icons.help_outline,
      }),
      isEmpty,
    );
  });

  test('omits only the first revision suffix from debrief presentation', () {
    expect(dailyDebriefPresentationIdentity('2026-08-14', 1), 'DD-2026-08-14');
    expect(
      dailyDebriefPresentationIdentity('2026-08-14', 2),
      'DD-2026-08-14-Rev2',
    );
    expect(
      dailyDebriefPresentationIdentity('2026-08-14', 7),
      'DD-2026-08-14-Rev7',
    );
  });

  test('maps every cycle state to its formal Material Symbol', () {
    expect(
      cycleStateIconFor(DailyCommandCycleState.standby),
      Icons.radio_button_unchecked,
    );
    expect(
      cycleStateIconFor(DailyCommandCycleState.active),
      Icons.change_circle,
    );
    expect(
      cycleStateIconFor(DailyCommandCycleState.reviewReady),
      Icons.task_alt,
    );
    expect(
      cycleStateIconFor(DailyCommandCycleState.awaitingDebrief),
      Icons.pending_actions,
    );
    expect(
      cycleStateIconFor(DailyCommandCycleState.finalizing),
      Icons.autorenew,
    );
    expect(
      cycleStateIconFor(DailyCommandCycleState.recoveryRequired),
      Icons.build_circle,
    );
  });

  setUp(() {
    morningFactNotifier.value = null;
    foodSummaryNotifier.value = null;
    trainingSummaryNotifier.value = null;
    activitySummaryNotifier.value = const ActivitySummary.empty();
    database = FakeIndexedDbDatabase();
    seedOperationState(database, '2026-08-01');
    AppRepositoryRegistry.install(AppRepositoryContainer.indexedDb(database));
  });

  tearDown(AppRepositoryRegistry.resetForTesting);

  testWidgets('shows Current Operation and STANDBY without invented command', (
    tester,
  ) async {
    await _pump(tester, width: 390);

    expect(find.byType(OperationDateFlipCalendar), findsOneWidget);
    expect(find.text('AUG'), findsOneWidget);
    expect(find.text('01'), findsOneWidget);
    expect(find.text('SAT'), findsOneWidget);
    expect(find.text('OPERATION DATE'), findsOneWidget);
    expect(find.text('CYCLE STATE'), findsOneWidget);
    expect(find.text('DAILY ASSESSMENT'), findsOneWidget);
    expect(find.text('NOT AVAILABLE'), findsWidgets);
    expect(find.textContaining('STATUSを入力'), findsNothing);
    expect(find.text('COMMANDER INTENT'), findsNothing);
    expect(find.text('ARGO COMMENT'), findsNothing);
    expect(find.text('OPERATION MODULES'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('DAILY LOG'),
      300,
      scrollable: _dailyCommandScrollable(),
    );
    expect(find.text('DAILY REVIEW'), findsOneWidget);
    expect(find.text('FINALIZE BLOCKED'), findsOneWidget);
    expect(find.text('STATUS, FOOD, ACTIVITY'), findsOneWidget);
    expect(find.text('VIEW DAILY REVIEW'), findsNothing);
    expect(find.text('FINALIZE DAY'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('CURRENT OPERATION shared calendar fits at 320px', (
    tester,
  ) async {
    await _pump(tester, width: 320);

    final row = find.byKey(const ValueKey('operation-date-flip-row'));
    final dateGroup = find.byKey(
      const ValueKey('current-operation-date-group'),
    );
    final cycleGroup = find.byKey(
      const ValueKey('current-operation-cycle-group'),
    );
    final cycleValue = find.byKey(
      const ValueKey('current-operation-cycle-value'),
    );
    expect(find.byType(OperationDateFlipCalendar), findsOneWidget);
    expect(find.text('OPERATION DATE'), findsOneWidget);
    expect(find.text('CYCLE STATE'), findsOneWidget);
    expect(find.text('IDLE'), findsOneWidget);
    expect(find.byIcon(Icons.radio_button_unchecked), findsOneWidget);
    expect(tester.getSize(row).width, 168);
    for (var index = 0; index < 3; index++) {
      expect(
        tester.getSize(find.byKey(ValueKey('operation-date-tile-$index'))),
        const Size(52, 36),
      );
    }
    expect(tester.getTopLeft(dateGroup).dy, tester.getTopLeft(cycleGroup).dy);
    expect(tester.getTopLeft(row).dy, tester.getTopLeft(cycleValue).dy);
    expect(tester.getSize(cycleValue).height, 36);
    expect(
      tester.getTopLeft(cycleGroup).dx,
      greaterThanOrEqualTo(tester.getTopRight(dateGroup).dx),
    );
    expect(
      find.byKey(const ValueKey('dashboard-live-flip-clock')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  test('cycle state short labels preserve every internal state mapping', () {
    expect(cycleStateShortLabelFor(DailyCommandCycleState.standby), 'IDLE');
    expect(cycleStateShortLabelFor(DailyCommandCycleState.active), 'RUN');
    expect(
      cycleStateShortLabelFor(DailyCommandCycleState.awaitingDebrief),
      'WAIT',
    );
    expect(cycleStateShortLabelFor(DailyCommandCycleState.reviewReady), 'DONE');
    expect(cycleStateShortLabelFor(DailyCommandCycleState.finalizing), 'LOAD');
    expect(
      cycleStateShortLabelFor(DailyCommandCycleState.recoveryRequired),
      'ERROR',
    );
  });

  testWidgets('keeps assessment while retiring operation hub sections', (
    tester,
  ) async {
    morningFactNotifier.value = _status();
    foodSummaryNotifier.value = const FoodSummary(
      calories: 1800,
      protein: 100,
      fat: 60,
      carbohydrates: 200,
      hydrationMl: 2000,
      mealCount: 3,
    );
    activitySummaryNotifier.value = const ActivitySummary(
      steps: 5000,
      measuredSteps: 5000,
      isRecorded: true,
      calculationBasis: ActivityCalculationBasis(
        rawSteps: 5000,
        currentCarryOver: 0,
        previousCarryOverDeduction: 0,
        officialSteps: 5000,
      ),
    );
    await _pump(tester, width: 900);

    expect(find.text('DAILY ASSESSMENT'), findsOneWidget);
    expect(find.text('OPERATION STATUS'), findsNothing);
    expect(find.text('COMMANDER INTENT'), findsNothing);
    expect(find.text('ARGO COMMENT'), findsNothing);
    expect(find.text('PRIMARY CONSTRAINT'), findsOneWidget);
    expect(find.text('AVAILABLE RESOURCE'), findsOneWidget);
    expect(find.text('OPERATION MODULES'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('DAILY LOG'),
      300,
      scrollable: _dailyCommandScrollable(),
    );
    expect(find.byIcon(Icons.chevron_right), findsNWidgets(4));
    expect(find.text('DAILY REVIEW'), findsOneWidget);
    expect(find.text('FINALIZE READY'), findsOneWidget);
    expect(find.text('VIEW DAILY REVIEW'), findsNothing);
    expect(find.text('FINALIZE DAY'), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('daily-command-list')),
        matching: find.text('DATA CENTER'),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('daily-command-list')),
        matching: find.text('BACKUP & RESTORE'),
      ),
      findsNothing,
    );
  });

  testWidgets('shared DAILY LOG opens the existing routes', (tester) async {
    morningFactNotifier.value = _status();
    foodSummaryNotifier.value = const FoodSummary(
      calories: 1800,
      protein: 100,
      fat: 60,
      carbohydrates: 200,
      hydrationMl: 2000,
      mealCount: 3,
    );
    activitySummaryNotifier.value = const ActivitySummary(
      steps: 5000,
      measuredSteps: 5000,
      isRecorded: true,
      calculationBasis: ActivityCalculationBasis(
        rawSteps: 5000,
        currentCarryOver: 0,
        previousCarryOverDeduction: 0,
        officialSteps: 5000,
      ),
    );
    await _pump(tester, width: 900);
    await tester.scrollUntilVisible(
      find.text('DAILY LOG'),
      300,
      scrollable: _dailyCommandScrollable(),
    );

    for (final entry in const [
      ('STATUS completed', 'STATUS ROUTE'),
      ('FOOD completed', 'FOOD ROUTE'),
      ('TRAINING not recorded optional', 'TRAINING ROUTE'),
      ('ACTIVITY completed', 'ACTIVITY ROUTE'),
    ]) {
      await tester.tap(find.bySemanticsLabel(entry.$1));
      await tester.pumpAndSettle();
      expect(find.text(entry.$2), findsOneWidget);
      Navigator.of(tester.element(find.text(entry.$2))).pop();
      await tester.pumpAndSettle();
    }

    await tester.tap(find.text('DAILY REVIEW'));
    await tester.pumpAndSettle();
    expect(find.text('DAILY REVIEW ROUTE'), findsOneWidget);
  });

  testWidgets(
    'Command Center finalize returns to top and flips its shared calendar once',
    (tester) async {
      seedOperationState(database, '2026-08-11');
      await _pump(tester, width: 390);

      await tester.scrollUntilVisible(
        find.byType(DailyLogSection),
        300,
        scrollable: _dailyCommandScrollable(),
      );
      await tester.pump();
      expect(_dailyCommandScrollPosition(tester).pixels, greaterThan(0));
      final owner = tester.widget<DailyLogSection>(
        find.byType(DailyLogSection),
      );
      seedOperationState(database, '2026-08-12');
      final transition = owner.onReviewCompleted!(
        OperationLocalDate.parse('2026-08-11'),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(_dailyCommandScrollPosition(tester).pixels, 0);
      expect(find.widgetWithText(AppBar, 'COMMAND CENTER'), findsOneWidget);
      expect(find.widgetWithText(AppBar, 'O.R.L.O.'), findsNothing);
      expect(find.text('AUG'), findsOneWidget);
      final dayTile = find.byKey(const ValueKey('operation-date-tile-1'));
      final weekdayTile = find.byKey(const ValueKey('operation-date-tile-2'));
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
      final tiles = [
        for (var index = 0; index < 3; index++)
          tester.widget<OperationMechanicalFlipTile>(
            find.byKey(ValueKey('operation-date-tile-$index')),
          ),
      ];
      expect(tiles[0].animationDuration, const Duration(milliseconds: 320));
      expect(tiles[1].animationDuration, const Duration(milliseconds: 360));
      expect(tiles[2].animationDuration, const Duration(milliseconds: 320));
      expect(tiles[1].firstPhaseRatio, closeTo(200 / 360, 0.0001));
      expect(tiles[1].startDelay, Duration.zero);
      expect(tiles[2].startDelay, const Duration(milliseconds: 60));

      await tester.pump(const Duration(milliseconds: 60));
      await tester.pump();
      expect(
        find.descendant(
          of: weekdayTile,
          matching: find.byKey(const ValueKey('mechanical-flip-old-upper')),
        ),
        findsOneWidget,
      );
      await tester.pumpAndSettle();
      await transition;
      expect(find.text('12'), findsOneWidget);
      expect(find.text('WED'), findsOneWidget);
      expect(
        find.descendant(
          of: dayTile,
          matching: find.byKey(const ValueKey('mechanical-flip-static')),
        ),
        findsOneWidget,
      );

      morningFactNotifier.value = _status();
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: dayTile,
          matching: find.byKey(const ValueKey('mechanical-flip-static')),
        ),
        findsOneWidget,
      );
      expect(find.text('12'), findsOneWidget);

      await _tapCommandCenterTab(tester, 'BRIEF / DEBRIEF');
      await _tapCommandCenterTab(tester, 'DAILY COMMAND');
      expect(find.text('12'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('mechanical-flip-old-upper')),
        findsNothing,
      );
    },
  );

  testWidgets('Command Center cancelled review preserves scroll and date', (
    tester,
  ) async {
    seedOperationState(database, '2026-08-11');
    await _pump(
      tester,
      width: 390,
      reviewPageBuilder: (context) => Scaffold(
        body: TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('CANCEL CC FINALIZE'),
        ),
      ),
    );
    await tester.scrollUntilVisible(
      find.text('DAILY REVIEW'),
      300,
      scrollable: _dailyCommandScrollable(),
    );
    await Scrollable.ensureVisible(
      tester.element(find.text('DAILY REVIEW')),
      alignment: 0.5,
    );
    await tester.pump();
    final previousOffset = _dailyCommandScrollPosition(tester).pixels;
    expect(previousOffset, greaterThan(0));
    await tester.tap(find.text('DAILY REVIEW'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CANCEL CC FINALIZE'));
    await tester.pumpAndSettle();

    expect(_dailyCommandScrollPosition(tester).pixels, greaterThan(0));
    expect(
      (await AppRepositoryRegistry.container.operationState.requireCurrent())
          .operationDate
          .value,
      '2026-08-11',
    );
    expect(
      find.byKey(const ValueKey('mechanical-flip-old-upper')),
      findsNothing,
    );
  });

  testWidgets('separates BRIEF DEBRIEF content from report sync pages', (
    tester,
  ) async {
    await _pump(tester, width: 390);

    expect(find.text('BRIEF / DEBRIEF'), findsWidgets);
    expect(find.text('PERIODIC REPORT'), findsOneWidget);
    expect(find.text('WEEKLY REPORT'), findsNothing);
    expect(find.text('MONTHLY REPORT'), findsNothing);
    expect(find.text('YEARLY REPORT'), findsNothing);
    expect(find.text('DAILY COMMAND'), findsWidgets);
    expect(find.text('DATA CENTER'), findsWidgets);
    await tester.tap(find.text('BRIEF / DEBRIEF').first);
    await tester.pumpAndSettle();
    final selectedBriefTab = tester.widget<AnimatedContainer>(
      find.byKey(const ValueKey('command-center-tab-0')),
    );
    final unselectedCommandTab = tester.widget<AnimatedContainer>(
      find.byKey(const ValueKey('command-center-tab-1')),
    );
    expect(
      ((selectedBriefTab.decoration as BoxDecoration).border as Border)
          .bottom
          .color,
      isNot(Colors.transparent),
    );
    expect(
      ((unselectedCommandTab.decoration as BoxDecoration).border as Border)
          .bottom
          .color,
      Colors.transparent,
    );
    expect(find.text('DAILY BRIEF'), findsWidgets);
    expect(find.text('DAILY DEBRIEF'), findsWidgets);
    expect(find.text('WEEKLY'), findsNothing);
    expect(find.text('MONTHLY'), findsNothing);
    expect(find.text('YEARLY'), findsNothing);
    expect(find.byType(ReportSyncExchangePanel), findsNothing);
    expect(find.text('MORNING BRIEF'), findsNothing);
    expect(find.text('DAILY BRIEFはまだありません。'), findsOneWidget);
    expect(find.text('DAILY BRIEF BACK NUMBER'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('view-all-morning-brief-back-numbers')),
      findsNothing,
    );
    expect(find.text('CREATE DAILY BRIEF'), findsOneWidget);
    expect(find.text('REPORT SYNC'), findsNothing);
    final briefHeaders = tester
        .widgetList<SectionHeader>(find.byType(SectionHeader))
        .toList();
    expect(
      briefHeaders.singleWhere((value) => value.title == 'DAILY BRIEF').icon,
      Icons.light_mode_outlined,
    );
    expect(
      briefHeaders
          .singleWhere((value) => value.title == 'DAILY BRIEF BACK NUMBER')
          .icon,
      Icons.auto_stories_outlined,
    );
    expect(
      find.byKey(const ValueKey('open-morning-brief-report-sync')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('open-morning-brief-report-sync')),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ReportSyncExchangePage), findsOneWidget);
    expect(find.text('EXPORT TO CHATGPT'), findsOneWidget);
    Navigator.of(tester.element(find.byType(ReportSyncExchangePage))).pop();
    await tester.pumpAndSettle();

    await _openDailyDebrief(tester);
    await tester.pumpAndSettle();
    expect(find.byType(ReportSyncExchangePanel), findsNothing);
    expect(find.text('DAILY DEBRIEFはまだありません。'), findsOneWidget);
    expect(find.text('NO DAILY DEBRIEF BACK NUMBER'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('view-all-daily-debrief-back-numbers')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('open-daily-debrief-report-sync')),
      findsOneWidget,
    );
    expect(find.text('CREATE DAILY DEBRIEF'), findsOneWidget);
    final debriefHeaders = tester
        .widgetList<SectionHeader>(find.byType(SectionHeader))
        .toList();
    expect(
      debriefHeaders
          .singleWhere((value) => value.title == 'DAILY DEBRIEF BACK NUMBER')
          .icon,
      Icons.auto_stories_outlined,
    );
    await tester.tap(
      find.byKey(const ValueKey('open-daily-debrief-report-sync')),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ReportSyncExchangePage), findsOneWidget);
    expect(find.byType(ReportSyncExchangePanel), findsOneWidget);
    expect(
      find.byKey(const ValueKey('report-sync-target-date')),
      findsOneWidget,
    );
    expect(find.text('COPY CHATGPT PROMPT'), findsOneWidget);
    Navigator.of(tester.element(find.byType(ReportSyncExchangePage))).pop();
    await tester.pumpAndSettle();
    expect(find.text('CREATE DAILY DEBRIEF'), findsOneWidget);
    expect(find.textContaining('施設'), findsNothing);
  });

  testWidgets('marks the selected Command Center top tab with an underline', (
    tester,
  ) async {
    await _pump(tester, width: 390);
    await tester.tap(find.text('BRIEF / DEBRIEF').first);
    await tester.pumpAndSettle();

    BorderSide bottomBorder(int index) {
      final tab = tester.widget<AnimatedContainer>(
        find.byKey(ValueKey('command-center-tab-$index')),
      );
      return ((tab.decoration as BoxDecoration).border as Border).bottom;
    }

    expect(bottomBorder(0).color, isNot(Colors.transparent));
    expect(bottomBorder(1).color, Colors.transparent);
    expect(find.text('DAILY BRIEF'), findsWidgets);

    await _tapCommandCenterTab(tester, 'DAILY COMMAND');
    expect(bottomBorder(0).color, Colors.transparent);
    expect(bottomBorder(1).color, isNot(Colors.transparent));
    expect(find.byKey(const ValueKey('daily-command-list')), findsOneWidget);
  });

  testWidgets('opens periodic reports under one independent top tab', (
    tester,
  ) async {
    await _pump(tester, width: 390);

    await _tapCommandCenterTab(tester, 'PERIODIC REPORT');
    final tab = tester.widget<AnimatedContainer>(
      find.byKey(const ValueKey('command-center-tab-2')),
    );
    expect(
      ((tab.decoration as BoxDecoration).border as Border).bottom.color,
      isNot(Colors.transparent),
    );
    expect(find.text('WEEKLY'), findsOneWidget);
    expect(find.text('MONTHLY'), findsOneWidget);
    expect(find.text('YEARLY'), findsOneWidget);
    expect(find.text('WEEKLY REPORT'), findsOneWidget);

    await tester.tap(find.text('MONTHLY'));
    await tester.pumpAndSettle();
    expect(find.text('MONTHLY REPORT'), findsOneWidget);

    await tester.tap(find.text('YEARLY'));
    await tester.pumpAndSettle();
    expect(find.text('YEARLY REPORT'), findsOneWidget);

    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps Data Center inside Command Center tabs', (tester) async {
    await _pump(tester, width: 900);

    await _tapCommandCenterTab(tester, 'DATA CENTER');

    expect(find.byKey(const ValueKey('data-center-content')), findsOneWidget);
    expect(find.text('HISTORY'), findsNWidgets(2));
    expect(find.text('OPEN HISTORY'), findsOneWidget);
    expect(find.text('DAILY AGGREGATE RECORDS'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows imported brief and debrief content with history', (
    tester,
  ) async {
    const digest =
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
    final timestamp = DateTime.utc(2026, 8, 1, 9);
    await AppRepositoryRegistry.container.morningBriefs.create(
      MorningBriefRecord(
        localDate: '2026-08-01',
        requestId: 'legacy-request',
        requestDigest: digest,
        responseDigest: digest,
        generatedAt: timestamp,
        importedAt: timestamp,
        situationAnalysis: 'Morning situation',
        operationStatus: MorningBriefOperationStatus.green,
        commanderIntent: 'Morning intent',
        argoComment: 'Morning comment',
        strategicResourceDecision: 'Morning resources',
        actions: const [
          MorningBriefAction(
            actionId: 'action-1',
            text: 'Morning action',
            priority: 'high',
          ),
        ],
        createdAt: timestamp,
        updatedAt: timestamp,
      ),
    );
    await _pump(tester, width: 390);
    await tester.tap(find.widgetWithText(TextButton, 'BRIEF / DEBRIEF'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Morning situation'), findsOneWidget);
    expect(find.textContaining('Morning intent'), findsOneWidget);
    expect(find.text('MB-2026-08-01-Rev1'), findsOneWidget);
    expect(find.text('DAILY BRIEF BACK NUMBER'), findsOneWidget);

    await _openDailyDebrief(tester);
    await tester.pumpAndSettle();
    expect(find.byType(ReportSyncExchangePanel), findsNothing);
    expect(find.text('CREATE DAILY DEBRIEF'), findsOneWidget);
    expect(find.text('NO DAILY DEBRIEF BACK NUMBER'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('open-daily-debrief-report-sync')),
      findsOneWidget,
    );
  });

  testWidgets('successful brief import return resets its main scroll', (
    tester,
  ) async {
    for (final date in const [
      '2026-08-01',
      '2026-07-31',
      '2026-07-30',
      '2026-07-29',
      '2026-07-28',
      '2026-07-27',
    ]) {
      await AppRepositoryRegistry.container.morningBriefs.create(
        _morningBriefV2(date),
      );
    }
    await _pump(tester, width: 390);
    await tester.tap(find.widgetWithText(TextButton, 'BRIEF / DEBRIEF'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('CREATE DAILY BRIEF'));
    await tester.pumpAndSettle();
    expect(_morningBriefScrollPosition(tester).pixels, greaterThan(0));
    await tester.tap(find.text('CREATE DAILY BRIEF'));
    await tester.pumpAndSettle();

    final page = tester.widget<ReportSyncExchangePage>(
      find.byType(ReportSyncExchangePage),
    );
    page.onApplied!();
    Navigator.of(tester.element(find.byType(ReportSyncExchangePage))).pop();
    await tester.pumpAndSettle();

    expect(_morningBriefScrollPosition(tester).pixels, 0);
    expect(find.text('DAILY BRIEF'), findsWidgets);
    expect(find.text('MB-2026-08-01-Rev1'), findsOneWidget);
  });

  testWidgets('shows the latest Morning Brief and preserves prior revisions', (
    tester,
  ) async {
    final first = _morningBriefV2(
      '2026-08-01',
      intent: 'ORIGINAL MORNING INTENT',
    ).asInitialRevision();
    final revised = first.reviseWith(
      _morningBriefV2('2026-08-01', intent: 'REVISED MORNING INTENT'),
      timestamp: first.updatedAt.add(const Duration(minutes: 1)),
    );
    await AppRepositoryRegistry.container.morningBriefs.create(revised);

    await _pump(tester, width: 390);
    await tester.tap(find.widgetWithText(TextButton, 'BRIEF / DEBRIEF'));
    await tester.pumpAndSettle();

    expect(find.text('MB-2026-08-01-Rev2'), findsOneWidget);
    expect(find.text('REVISED MORNING INTENT'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('morning-brief-previous-revisions')),
      findsOneWidget,
    );
    expect(find.text('REV 1'), findsOneWidget);
    await tester.ensureVisible(find.text('REV 1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('REV 1'));
    await tester.pumpAndSettle();
    expect(find.text('MB-2026-08-01-Rev1'), findsOneWidget);
    expect(find.text('ORIGINAL MORNING INTENT'), findsOneWidget);
  });

  testWidgets('normal back preserves daily brief scroll position', (
    tester,
  ) async {
    for (final date in const [
      '2026-08-01',
      '2026-07-31',
      '2026-07-30',
      '2026-07-29',
      '2026-07-28',
      '2026-07-27',
    ]) {
      await AppRepositoryRegistry.container.morningBriefs.create(
        _morningBriefV2(date),
      );
    }
    await _pump(tester, width: 390);
    await tester.tap(find.widgetWithText(TextButton, 'BRIEF / DEBRIEF'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('CREATE DAILY BRIEF'));
    await tester.pumpAndSettle();
    final before = _morningBriefScrollPosition(tester).pixels;
    expect(before, greaterThan(0));
    await tester.tap(find.text('CREATE DAILY BRIEF'));
    await tester.pumpAndSettle();
    Navigator.of(tester.element(find.byType(ReportSyncExchangePage))).pop();
    await tester.pumpAndSettle();

    expect(_morningBriefScrollPosition(tester).pixels, before);
  });

  testWidgets('keeps existing debrief visible with creation action', (
    tester,
  ) async {
    final timestamp = DateTime.utc(2026, 8, 1, 23);
    final record = _dailyDebriefRecord(
      localDate: '2026-08-01',
      bodyEvaluation: 'LATEST BODY REVIEW',
      conditionEvaluation: 'FOOT CONDITION REVIEW',
      timestamp: timestamp.add(const Duration(days: 1)),
      revision: 7,
    );
    final olderRecord = _dailyDebriefRecord(
      localDate: '2026-07-31',
      bodyEvaluation: 'OLDER BODY REVIEW',
      rationale: 'OLDER COMMANDER RATIONALE',
      timestamp: timestamp,
    );
    database.seed(
      IndexedDbStoreNames.dailyDebriefRecords,
      record.localDate,
      record.toRecord(),
    );
    database.seed(
      IndexedDbStoreNames.dailyDebriefRecords,
      olderRecord.localDate,
      olderRecord.toRecord(),
    );

    await _pump(tester, width: 390);
    await tester.tap(find.widgetWithText(TextButton, 'BRIEF / DEBRIEF'));
    await tester.pumpAndSettle();
    await _openDailyDebrief(tester);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('current-daily-debrief')), findsOneWidget);
    expect(find.text('DD-2026-08-01-Rev7'), findsOneWidget);
    expect(find.textContaining('LATEST BODY REVIEW'), findsOneWidget);
    expect(find.text('DAILY DEBRIEF'), findsWidgets);
    expect(find.textContaining('REVISION'), findsNothing);
    expect(find.text('ACTIVE'), findsNothing);
    expect(find.text('STALE'), findsNothing);
    expect(find.text('INVALIDATED'), findsNothing);
    expect(
      find.byKey(const ValueKey('daily-debrief-lifecycle-invalidated')),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.block), findsOneWidget);
    expect(find.text('COMMANDER INTENT EVALUATION'), findsOneWidget);
    expect(find.text('OUTCOME'), findsNothing);
    expect(find.text('PARTIALLY ACHIEVED'), findsNothing);
    expect(find.text('partiallyAchieved'), findsNothing);
    expect(
      find.byKey(const ValueKey('daily-debrief-outcome-partiallyAchieved')),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey('daily-debrief-header-outcome-partiallyAchieved'),
      ),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.adjust), findsNWidgets(2));
    expect(find.text('YELLOW'), findsNWidgets(2));
    expect(find.text('評価理由'), findsOneWidget);
    expect(find.text('判定根拠'), findsOneWidget);
    expect(find.text('RATIONALE'), findsNothing);
    expect(find.text('EVIDENCE'), findsNothing);
    expect(find.text('EVIDENCE ITEM'), findsOneWidget);
    expect(find.text('EXECUTION EVALUATION'), findsOneWidget);
    expect(find.text('SUCCESSES'), findsOneWidget);
    expect(find.text('SUCCESS ITEM'), findsOneWidget);
    expect(find.text('ADJUSTMENTS'), findsOneWidget);
    expect(find.text('ADJUSTMENT ITEM'), findsOneWidget);
    expect(find.text('CROSS ANALYSIS'), findsOneWidget);
    expect(find.text('KEY FACTORS'), findsOneWidget);
    expect(find.text('INTERACTIONS'), findsOneWidget);
    expect(find.text('CONSTRAINTS'), findsOneWidget);
    expect(find.text('RESOURCES'), findsOneWidget);
    expect(find.text('DOMAIN EVALUATIONS'), findsOneWidget);
    expect(find.text('BODY'), findsOneWidget);
    expect(find.text('RECOVERY'), findsNothing);
    expect(find.text('TRAINING'), findsNothing);
    expect(find.byIcon(Icons.monitor_weight_outlined), findsOneWidget);
    expect(find.text('NEXT-DAY HANDOFF'), findsOneWidget);
    expect(find.text('WATCH POINTS'), findsOneWidget);
    expect(find.text('WATCH ITEM'), findsOneWidget);
    for (final panel in const [
      'daily-debrief-panel-commander-intent',
      'daily-debrief-panel-execution-evaluation',
      'daily-debrief-panel-cross-analysis',
      'daily-debrief-panel-next-day-handoff',
    ]) {
      expect(find.byKey(ValueKey(panel)), findsOneWidget);
    }
    expect(
      find.byKey(const ValueKey('daily-debrief-domain-body')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('daily-debrief-panel-domain-body')),
      findsNothing,
    );
    final scheme = Theme.of(
      tester.element(
        find.byKey(const ValueKey('daily-debrief-panel-commander-intent')),
      ),
    ).colorScheme;
    expect(
      _panelColor(tester, 'daily-debrief-panel-commander-intent'),
      scheme.primaryContainer,
    );
    expect(
      _panelColor(tester, 'daily-debrief-panel-execution-evaluation'),
      scheme.secondaryContainer.withValues(alpha: 0.55),
    );
    expect(
      _panelColor(tester, 'daily-debrief-panel-cross-analysis'),
      scheme.surfaceContainerLow,
    );
    expect(
      _panelColor(tester, 'daily-debrief-panel-next-day-handoff'),
      scheme.surfaceContainerHighest,
    );
    final executionPanel = find.byKey(
      const ValueKey('daily-debrief-panel-execution-evaluation'),
    );
    expect(
      find.descendant(
        of: executionPanel,
        matching: find.byKey(const ValueKey('daily-debrief-group-successes')),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: executionPanel,
        matching: find.byKey(const ValueKey('daily-debrief-group-adjustments')),
      ),
      findsOneWidget,
    );
    expect(find.byIcon(Symbols.barefoot), findsOneWidget);
    expect(find.byIcon(Icons.health_and_safety_outlined), findsNothing);
    expect(find.textContaining('CURRENT REVISION'), findsNothing);
    expect(find.textContaining('STATUS ACTIVE'), findsNothing);
    _expectDailyDebriefReadingOrder(tester);
    expect(
      find.byKey(const ValueKey('daily-debrief-history-2026-08-01')),
      findsNothing,
    );
    await tester.scrollUntilVisible(
      find.text('CREATE DAILY DEBRIEF'),
      500,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('daily-debrief-content')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text('CREATE DAILY DEBRIEF'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('daily-debrief-history-2026-07-31')),
      500,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('daily-debrief-content')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('daily-debrief-history-2026-07-31')),
    );
    await tester.pump();
    final historyRow = find.byKey(
      const ValueKey('daily-debrief-history-2026-07-31'),
    );
    expect(
      find.descendant(
        of: historyRow,
        matching: find.byIcon(Icons.description_outlined),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: historyRow,
        matching: find.text('OLDER COMMANDER RATIONALE'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: historyRow,
        matching: find.byIcon(Icons.chevron_right),
      ),
      findsOneWidget,
    );
    expect(find.textContaining('OPERATION DATE  '), findsNothing);
    expect(find.textContaining('STATUS  '), findsNothing);
    expect(find.textContaining('IMPORTED AT  '), findsNothing);

    await tester.tap(
      find.byKey(const ValueKey('daily-debrief-history-2026-07-31')),
    );
    await tester.pumpAndSettle();
    expect(find.text('DD-2026-07-31'), findsOneWidget);
    expect(find.textContaining('OLDER BODY REVIEW'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('daily-debrief-outcome-partiallyAchieved')),
      findsOneWidget,
    );
    expect(find.text('評価理由'), findsOneWidget);
    expect(find.text('判定根拠'), findsOneWidget);
    expect(find.text('SOURCE REFERENCES'), findsNothing);
    expect(find.textContaining('aaaaaaaaaaaaaaaa'), findsNothing);
    expect(olderRecord.sources.dailyAggregate.recordDigest, isNotEmpty);
    expect(find.text('PREVIOUS REVISIONS'), findsOneWidget);
    _expectDailyDebriefReadingOrder(tester);
  });

  testWidgets('does not use a historical debrief as the current-day report', (
    tester,
  ) async {
    final historical = _dailyDebriefRecord(
      localDate: '2026-07-31',
      bodyEvaluation: 'HISTORICAL BODY REVIEW',
      timestamp: DateTime.utc(2026, 7, 31, 23),
    );
    database.seed(
      IndexedDbStoreNames.dailyDebriefRecords,
      historical.localDate,
      historical.toRecord(),
    );

    await _pump(tester, width: 390);
    await tester.tap(find.widgetWithText(TextButton, 'BRIEF / DEBRIEF'));
    await tester.pumpAndSettle();
    await _openDailyDebrief(tester);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('current-daily-debrief')), findsNothing);
    expect(find.text('DAILY DEBRIEFはまだありません。'), findsOneWidget);
    expect(find.textContaining('HISTORICAL BODY REVIEW'), findsNothing);
    expect(
      find.byKey(const ValueKey('daily-debrief-history-2026-07-31')),
      findsOneWidget,
    );
  });

  testWidgets('debrief back numbers match brief rows and outcome colors', (
    tester,
  ) async {
    final timestamp = DateTime.utc(2026, 8, 1, 23);
    final current = _dailyDebriefRecord(
      localDate: '2026-08-01',
      bodyEvaluation: 'CURRENT BODY',
      timestamp: timestamp,
    );
    database.seed(
      IndexedDbStoreNames.dailyDebriefRecords,
      current.localDate,
      current.toRecord(),
    );
    final cases = [
      (
        '2026-07-31',
        DailyDebriefCommanderIntentOutcome.achieved,
        'GREEN RATIONALE',
      ),
      (
        '2026-07-30',
        DailyDebriefCommanderIntentOutcome.partiallyAchieved,
        'YELLOW RATIONALE',
      ),
      (
        '2026-07-29',
        DailyDebriefCommanderIntentOutcome.notAchieved,
        'RED RATIONALE',
      ),
      (
        '2026-07-28',
        DailyDebriefCommanderIntentOutcome.notAssessable,
        'GRAY RATIONALE',
      ),
    ];
    for (var index = 0; index < cases.length; index++) {
      final value = cases[index];
      final record = _dailyDebriefRecord(
        localDate: value.$1,
        bodyEvaluation: 'BODY ${value.$1}',
        rationale: value.$3,
        outcome: value.$2,
        revision: index + 2,
        timestamp: timestamp.subtract(Duration(days: index + 1)),
      );
      database.seed(
        IndexedDbStoreNames.dailyDebriefRecords,
        record.localDate,
        record.toRecord(),
      );
      expect(record.revision, index + 2);
    }
    final noEvaluation = _dailyDebriefRecord(
      localDate: '2026-07-27',
      bodyEvaluation: 'NO EVALUATION BODY',
      commanderIntentRecorded: false,
      timestamp: timestamp.subtract(const Duration(days: 5)),
    );
    database.seed(
      IndexedDbStoreNames.dailyDebriefRecords,
      noEvaluation.localDate,
      noEvaluation.toRecord(),
    );

    await _pump(tester, width: 390);
    await tester.tap(find.widgetWithText(TextButton, 'BRIEF / DEBRIEF'));
    await tester.pumpAndSettle();
    await _openDailyDebrief(tester);
    await tester.pumpAndSettle();

    final colors = Theme.of(
      tester.element(find.byKey(const ValueKey('daily-debrief-content'))),
    ).colorScheme;
    for (final value in cases.take(3)) {
      final row = find.byKey(ValueKey('daily-debrief-history-${value.$1}'));
      await tester.scrollUntilVisible(
        row,
        400,
        scrollable: find
            .descendant(
              of: find.byKey(const ValueKey('daily-debrief-content')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(row, findsOneWidget);
    }
    expect(
      find.byKey(const ValueKey('daily-debrief-history-2026-07-28')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('daily-debrief-history-2026-07-27')),
      findsNothing,
    );
    final viewAll = find.byKey(
      const ValueKey('view-all-daily-debrief-back-numbers'),
    );
    await tester.scrollUntilVisible(
      viewAll,
      400,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('daily-debrief-content')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(viewAll);
    await tester.pumpAndSettle();
    for (final value in cases) {
      final row = find.byKey(
        ValueKey('all-daily-debrief-back-number-${value.$1}'),
      );
      await tester.scrollUntilVisible(row, 300);
      final expectedColor = switch (value.$2) {
        DailyDebriefCommanderIntentOutcome.achieved => Colors.green,
        DailyDebriefCommanderIntentOutcome.partiallyAchieved => Colors.amber,
        DailyDebriefCommanderIntentOutcome.notAchieved => colors.error,
        DailyDebriefCommanderIntentOutcome.notAssessable => colors.outline,
      };
      final dot = tester.widget<Container>(
        find.descendant(
          of: row,
          matching: find.byKey(const ValueKey('back-number-outcome-dot')),
        ),
      );
      expect((dot.decoration! as BoxDecoration).color, expectedColor);
      expect(
        find.descendant(
          of: row,
          matching: find.byIcon(Icons.description_outlined),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: row, matching: find.text(value.$1)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: row, matching: find.text(value.$3)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: row, matching: find.byIcon(Icons.chevron_right)),
        findsOneWidget,
      );
    }
    expect(find.textContaining('OPERATION DATE  '), findsNothing);
    expect(find.textContaining('STATUS  '), findsNothing);
    expect(find.textContaining('IMPORTED AT  '), findsNothing);
    final noEvaluationRow = find.byKey(
      const ValueKey('all-daily-debrief-back-number-2026-07-27'),
    );
    await tester.scrollUntilVisible(noEvaluationRow, 300);
    final noEvaluationTile = tester.widget<ListTile>(
      find.descendant(of: noEvaluationRow, matching: find.byType(ListTile)),
    );
    expect(noEvaluationTile.subtitle, isNull);
    expect(
      find.descendant(
        of: noEvaluationRow,
        matching: find.byKey(const ValueKey('back-number-outcome-dot')),
      ),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'does not show view all when brief and debrief have three back numbers',
    (tester) async {
      final timestamp = DateTime.utc(2026, 8, 1, 23);
      for (final date in const [
        '2026-08-01',
        '2026-07-31',
        '2026-07-30',
        '2026-07-29',
      ]) {
        await AppRepositoryRegistry.container.morningBriefs.create(
          _morningBriefV2(date),
        );
        final debrief = _dailyDebriefRecord(
          localDate: date,
          bodyEvaluation: 'BODY $date',
          timestamp: timestamp,
        );
        database.seed(
          IndexedDbStoreNames.dailyDebriefRecords,
          debrief.localDate,
          debrief.toRecord(),
        );
      }

      await _pump(tester, width: 390);
      await tester.tap(find.widgetWithText(TextButton, 'BRIEF / DEBRIEF'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('morning-brief-back-number-2026-07-29')),
      );
      expect(
        find.byKey(const ValueKey('view-all-morning-brief-back-numbers')),
        findsNothing,
      );

      await _openDailyDebrief(tester);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('daily-debrief-history-2026-07-29')),
        400,
        scrollable: find
            .descendant(
              of: find.byKey(const ValueKey('daily-debrief-content')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(
        find.byKey(const ValueKey('view-all-daily-debrief-back-numbers')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('hides empty debrief subsections in current and detail views', (
    tester,
  ) async {
    final current = _dailyDebriefRecord(
      localDate: '2026-08-01',
      bodyEvaluation: 'CURRENT BODY REVIEW',
      timestamp: DateTime.utc(2026, 8, 1, 23),
      evidence: const [],
      successes: const [],
      adjustments: const [],
      keyFactors: const [],
      interactions: const [],
      constraints: const [],
      resources: const [],
      watchPoints: const [],
    );
    final historical = _dailyDebriefRecord(
      localDate: '2026-07-31',
      bodyEvaluation: 'HISTORICAL BODY REVIEW',
      timestamp: DateTime.utc(2026, 7, 31, 23),
      evidence: const [],
      successes: const [],
      adjustments: const [],
      keyFactors: const [],
      interactions: const [],
      constraints: const [],
      resources: const [],
      watchPoints: const [],
    );
    for (final record in [current, historical]) {
      database.seed(
        IndexedDbStoreNames.dailyDebriefRecords,
        record.localDate,
        record.toRecord(),
      );
    }

    await _pump(tester, width: 390);
    await tester.tap(find.widgetWithText(TextButton, 'BRIEF / DEBRIEF'));
    await tester.pumpAndSettle();
    await _openDailyDebrief(tester);
    await tester.pumpAndSettle();

    _expectEmptyDebriefSubsectionsHidden(tester);
    final currentDetail = find.byKey(const ValueKey('current-daily-debrief'));
    expect(
      find.descendant(of: currentDetail, matching: find.byType(Divider)),
      findsNothing,
    );
    expect(current.analysis.executionEvaluation.successes, isEmpty);
    expect(current.analysis.crossAnalysis.constraints, isEmpty);
    expect(current.analysis.nextDayHandoff.watchPoints, isEmpty);

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('daily-debrief-history-2026-07-31')),
      500,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('daily-debrief-content')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(
      find.byKey(const ValueKey('daily-debrief-history-2026-07-31')),
    );
    await tester.pumpAndSettle();

    _expectEmptyDebriefSubsectionsHidden(tester);
    expect(find.textContaining('HISTORICAL BODY REVIEW'), findsOneWidget);
  });

  testWidgets('debrief panels and barefoot icon fit supported widths', (
    tester,
  ) async {
    final record = _dailyDebriefRecord(
      localDate: '2026-08-01',
      bodyEvaluation: '長い日本語のBODY評価文をそのまま表示します。',
      recoveryEvaluation: '回復状態を記録した評価文です。',
      conditionEvaluation: '足底筋膜炎の状態を評価した文章です。',
      timestamp: DateTime.utc(2026, 8, 1, 23),
    );
    database.seed(
      IndexedDbStoreNames.dailyDebriefRecords,
      record.localDate,
      record.toRecord(),
    );
    final historical = _dailyDebriefRecord(
      localDate: '2026-07-31',
      bodyEvaluation: '過去日のBODY評価文です。',
      rationale: List.filled(4, '長い日本語のCommander Intent評価理由を一覧で表示します。').join(),
      timestamp: DateTime.utc(2026, 7, 31, 23),
    );
    database.seed(
      IndexedDbStoreNames.dailyDebriefRecords,
      historical.localDate,
      historical.toRecord(),
    );

    for (final width in [320.0, 390.0, 900.0, 1280.0]) {
      await _pump(tester, width: width);
      await tester.tap(find.widgetWithText(TextButton, 'BRIEF / DEBRIEF'));
      await tester.pumpAndSettle();
      while (tester.takeException() != null) {}
      await _openDailyDebrief(tester);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('daily-debrief-domain-body')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('daily-debrief-domain-condition')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('daily-debrief-panel-domain-body')),
        findsNothing,
      );
      expect(find.byIcon(Symbols.barefoot), findsOneWidget);
      expect(find.byIcon(Icons.health_and_safety_outlined), findsNothing);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('daily-debrief-history-2026-07-31')),
        500,
        scrollable: find
            .descendant(
              of: find.byKey(const ValueKey('daily-debrief-content')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      final preview = tester.widget<Text>(
        find.textContaining('長い日本語のCommander Intent評価理由').last,
      );
      expect(preview.maxLines, 2);
      expect(preview.overflow, TextOverflow.ellipsis);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('brief and debrief use dedicated holiday work presentation', (
    tester,
  ) async {
    final brief = _morningBriefV2('2026-08-01', work: '公休日で実働だった。');
    final debrief = _dailyDebriefRecord(
      localDate: '2026-08-01',
      bodyEvaluation: 'BODY',
      workEvaluation: '公休日で実働だった。',
      timestamp: DateTime.utc(2026, 8, 1, 23),
    );
    database.seed(
      IndexedDbStoreNames.morningBriefRecords,
      brief.localDate,
      brief.toRecord(),
    );
    database.seed(
      IndexedDbStoreNames.dailyDebriefRecords,
      debrief.localDate,
      debrief.toRecord(),
    );

    await _pump(tester, width: 390);
    await tester.tap(find.widgetWithText(TextButton, 'BRIEF / DEBRIEF'));
    await tester.pumpAndSettle();
    expect(find.text('公休日'), findsOneWidget);
    expect(find.textContaining('実働'), findsNothing);

    await _openDailyDebrief(tester);
    await tester.pumpAndSettle();
    expect(find.text('公休日'), findsOneWidget);
    expect(find.textContaining('実働'), findsNothing);
  });

  for (final outcomeCase in const [
    (
      DailyDebriefCommanderIntentOutcome.achieved,
      Icons.check_circle,
      'green',
      'GREEN',
    ),
    (
      DailyDebriefCommanderIntentOutcome.partiallyAchieved,
      Icons.adjust,
      'amber',
      'YELLOW',
    ),
    (
      DailyDebriefCommanderIntentOutcome.notAchieved,
      Icons.cancel,
      'error',
      'RED',
    ),
    (
      DailyDebriefCommanderIntentOutcome.notAssessable,
      Icons.help_outline,
      'outline',
      'GRAY',
    ),
  ]) {
    testWidgets('maps ${outcomeCase.$1.name} to its semantic outcome visual', (
      tester,
    ) async {
      final record = _dailyDebriefRecord(
        localDate: '2026-08-01',
        bodyEvaluation: 'BODY REVIEW',
        recoveryEvaluation: 'RECOVERY REVIEW',
        outcome: outcomeCase.$1,
        timestamp: DateTime.utc(2026, 8, 1, 23),
      );
      database.seed(
        IndexedDbStoreNames.dailyDebriefRecords,
        record.localDate,
        record.toRecord(),
      );

      await _pump(tester, width: 390);
      await tester.tap(find.widgetWithText(TextButton, 'BRIEF / DEBRIEF'));
      await tester.pumpAndSettle();
      await _openDailyDebrief(tester);
      await tester.pumpAndSettle();

      final sectionIndicator = find.byKey(
        ValueKey('daily-debrief-outcome-${outcomeCase.$1.name}'),
      );
      final headerIndicator = find.byKey(
        ValueKey('daily-debrief-header-outcome-${outcomeCase.$1.name}'),
      );
      final sectionIcon = tester.widget<Icon>(sectionIndicator);
      final headerIcon = tester.widget<Icon>(headerIndicator);
      final colorScheme = Theme.of(
        tester.element(sectionIndicator),
      ).colorScheme;
      final expectedColor = switch (outcomeCase.$3) {
        'green' => Colors.green,
        'amber' => Colors.amber,
        'error' => colorScheme.error,
        _ => colorScheme.outline,
      };
      expect(sectionIcon.icon, outcomeCase.$2);
      expect(sectionIcon.color, expectedColor);
      expect(headerIcon.icon, outcomeCase.$2);
      expect(headerIcon.color, expectedColor);
      expect(find.text(outcomeCase.$4), findsNWidgets(2));
      expect(find.text(outcomeCase.$1.name), findsNothing);
      expect(find.text('OUTCOME'), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('current-daily-debrief')),
          matching: find.byType(Divider),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });
  }

  testWidgets(
    'separates current Morning Brief and exposes three back numbers with detail',
    (tester) async {
      for (final date in const [
        '2026-08-01',
        '2026-07-31',
        '2026-07-30',
        '2026-07-29',
        '2026-07-28',
        '2026-07-27',
        '2026-07-26',
      ]) {
        await AppRepositoryRegistry.container.morningBriefs.create(
          _morningBriefV2(date),
        );
      }

      await _pump(tester, width: 390);
      await tester.tap(find.widgetWithText(TextButton, 'BRIEF / DEBRIEF'));
      await tester.pumpAndSettle();

      expect(find.text('CURRENT INTENT 2026-08-01'), findsOneWidget);
      expect(find.text('CARRYOVER MUST STAY HIDDEN'), findsNothing);
      expect(find.text('OVERALL'), findsNothing);
      expect(find.text('HIGH'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('morning-brief-status-lamp-yellow')),
        findsNWidgets(2),
      );
      expect(find.byIcon(Icons.assignment_outlined), findsNothing);
      expect(find.byIcon(Icons.light_mode_outlined), findsNWidgets(2));
      expect(find.byIcon(Icons.analytics_outlined), findsOneWidget);
      expect(find.byIcon(Icons.monitor_weight_outlined), findsOneWidget);
      expect(find.byIcon(Icons.bedtime_outlined), findsOneWidget);
      expect(find.byIcon(Symbols.barefoot), findsOneWidget);
      expect(find.byIcon(Icons.health_and_safety_outlined), findsNothing);
      expect(find.byIcon(Icons.work_outline), findsOneWidget);
      expect(find.byIcon(Icons.route_outlined), findsOneWidget);
      expect(find.byIcon(Icons.track_changes_outlined), findsOneWidget);
      expect(find.byIcon(Icons.flag_outlined), findsOneWidget);
      expect(find.byIcon(Icons.checklist_outlined), findsOneWidget);
      expect(find.text('判断'), findsOneWidget);
      expect(find.text('重点資源'), findsOneWidget);
      expect(find.text('理由'), findsOneWidget);
      expect(find.text('実行方針'), findsOneWidget);

      await tester.ensureVisible(
        find.byKey(const ValueKey('morning-brief-back-number-2026-07-31')),
      );
      await tester.pumpAndSettle();
      expect(find.text('DAILY BRIEF BACK NUMBER'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('morning-brief-back-number-2026-07-31')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('morning-brief-back-number-2026-07-28')),
        findsNothing,
      );

      await tester.tap(
        find.byKey(const ValueKey('morning-brief-back-number-2026-07-31')),
      );
      await tester.pumpAndSettle();
      expect(find.text('CURRENT INTENT 2026-07-31'), findsOneWidget);
      Navigator.of(
        tester.element(find.text('CURRENT INTENT 2026-07-31')),
      ).pop();
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(const ValueKey('view-all-morning-brief-back-numbers')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('view-all-morning-brief-back-numbers')),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('all-morning-brief-back-number-2026-07-26')),
        250,
      );
      expect(
        find.byKey(const ValueKey('all-morning-brief-back-number-2026-07-26')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final statusCase in [
    (hours: 8, name: 'green'),
    (hours: 6, name: 'yellow'),
    (hours: 4, name: 'red'),
  ]) {
    testWidgets('shows ${statusCase.name} status lamp', (tester) async {
      morningFactNotifier.value = _status().copyWith(
        sleepDuration: Duration(hours: statusCase.hours),
      );
      await _pump(tester, width: 390);
      await _scrollDailyCommand(tester, -350);

      expect(
        find.byKey(ValueKey('daily-command-status-lamp-${statusCase.name}')),
        findsOneWidget,
      );
      final lamp = tester.widget<Icon>(
        find.byKey(ValueKey('daily-command-status-lamp-${statusCase.name}')),
      );
      expect(lamp.size, 18);
      expect(find.text(statusCase.name.toUpperCase()), findsOneWidget);
    });
  }

  testWidgets('keeps recovery cycle state without review actions', (
    tester,
  ) async {
    final date = OperationLocalDate.parse('2026-08-01');
    final now = DateTime.utc(2026, 8, 1);
    database.seed(
      'operation_state',
      OperationState.canonicalId,
      OperationState(
        operationDate: date,
        phase: OperationPhase.finalizedPendingBackup,
        activeAttempt: OperationActiveAttempt(
          idempotencyKey: 'daily-finalize:${date.value}',
          targetLocalDate: date,
          startedAt: now,
          confirmationId: 'confirmation-1',
          confirmationDigest: 'digest-1',
        ),
        createdAt: now,
        updatedAt: now,
      ).toRecord(),
    );

    await _pump(tester, width: 390);
    expect(find.textContaining('RECOVERY REQUIRED'), findsNothing);
    expect(find.byIcon(Icons.build_circle), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('DAILY LOG'),
      300,
      scrollable: _dailyCommandScrollable(),
    );
    expect(find.text('DAILY REVIEW'), findsOneWidget);
    expect(find.text('RESUME FINALIZE'), findsNothing);
    expect(find.text('FINALIZE DAY'), findsNothing);
  });

  for (final width in [320.0, 390.0, 900.0, 1280.0]) {
    testWidgets('has no overflow at ${width.toInt()}px in light and dark', (
      tester,
    ) async {
      for (final theme in [ThemeData.light(), ThemeData.dark()]) {
        await _pump(tester, width: width, theme: theme);
        expect(tester.takeException(), isNull);
        await tester.tap(
          find.widgetWithText(TextButton, 'BRIEF / DEBRIEF').first,
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.descendant(
            of: find.byType(TabBar),
            matching: find.text('DAILY BRIEF'),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(
          find.byKey(const ValueKey('morning-brief-content')),
          findsOneWidget,
        );
        await _openDailyDebrief(tester);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(
          find.byKey(const ValueKey('daily-debrief-content')),
          findsOneWidget,
        );
      }
    });
  }
}

Finder _dailyCommandScrollable() => find.descendant(
  of: find.byKey(const ValueKey('daily-command-list')),
  matching: find.byType(Scrollable),
);

Finder _morningBriefScrollable() => find.descendant(
  of: find.byKey(const ValueKey('morning-brief-content')),
  matching: find.byType(Scrollable),
);

ScrollPosition _morningBriefScrollPosition(WidgetTester tester) =>
    tester.state<ScrollableState>(_morningBriefScrollable()).position;

Color? _panelColor(WidgetTester tester, String key) {
  final container = tester.widget<Container>(
    find
        .descendant(
          of: find.byKey(ValueKey(key)),
          matching: find.byType(Container),
        )
        .first,
  );
  return (container.decoration! as BoxDecoration).color;
}

void _expectDailyDebriefReadingOrder(WidgetTester tester) {
  final positions = [
    'DOMAIN EVALUATIONS',
    'COMMANDER INTENT EVALUATION',
    'EXECUTION EVALUATION',
    'CROSS ANALYSIS',
    'NEXT-DAY HANDOFF',
  ].map((title) => tester.getTopLeft(find.text(title)).dy).toList();
  expect(positions, orderedEquals(positions.toList()..sort()));
}

void _expectEmptyDebriefSubsectionsHidden(WidgetTester tester) {
  for (final subsection in const [
    'SUCCESSES',
    'ADJUSTMENTS',
    'KEY FACTORS',
    'INTERACTIONS',
    'CONSTRAINTS',
    'RESOURCES',
    'WATCH POINTS',
  ]) {
    expect(find.text(subsection), findsNothing);
  }
  for (final section in const [
    'DOMAIN EVALUATIONS',
    'COMMANDER INTENT EVALUATION',
  ]) {
    expect(find.text(section), findsOneWidget);
  }
  for (final emptySection in const [
    'EXECUTION EVALUATION',
    'CROSS ANALYSIS',
    'NEXT-DAY HANDOFF',
  ]) {
    expect(find.text(emptySection), findsNothing);
  }
  expect(
    find.byKey(const ValueKey('daily-debrief-panel-commander-intent')),
    findsOneWidget,
  );
  expect(
    find.byKey(const ValueKey('daily-debrief-panel-execution-evaluation')),
    findsNothing,
  );
  expect(
    find.byKey(const ValueKey('daily-debrief-panel-next-day-handoff')),
    findsNothing,
  );
}

ScrollPosition _dailyCommandScrollPosition(WidgetTester tester) =>
    tester.state<ScrollableState>(_dailyCommandScrollable()).position;

DailyDebriefRecord _dailyDebriefRecord({
  required String localDate,
  required String bodyEvaluation,
  required DateTime timestamp,
  String? recoveryEvaluation,
  String? conditionEvaluation,
  String? workEvaluation,
  String rationale = 'RATIONALE BODY',
  bool commanderIntentRecorded = true,
  int revision = 1,
  DailyDebriefCommanderIntentOutcome outcome =
      DailyDebriefCommanderIntentOutcome.partiallyAchieved,
  List<String> evidence = const ['EVIDENCE ITEM'],
  List<String> successes = const ['SUCCESS ITEM'],
  List<String> adjustments = const ['ADJUSTMENT ITEM'],
  List<String> keyFactors = const ['KEY FACTOR ITEM'],
  List<String> interactions = const ['INTERACTION ITEM'],
  List<String> constraints = const ['CONSTRAINT ITEM'],
  List<String> resources = const ['RESOURCE ITEM'],
  List<String> watchPoints = const ['WATCH ITEM'],
}) {
  final sources = DailyDebriefSources(
    dailyAggregate: DailyDebriefDailyAggregateReference(
      operationDate: localDate,
      sourceType: 'records',
      recordDigest:
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    ),
    confirmation: DailyDebriefConfirmationReference(
      recordId: 'confirmation:$localDate',
      recordVersion: 2,
      revision: 1,
      snapshotDigest: '1234abcd',
      recordDigest:
          'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
    ),
    morningBrief: DailyDebriefMorningBriefReference(
      localDate: localDate,
      recordVersion: 2,
      responseDigest:
          'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd',
      recordDigest:
          'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee',
    ),
  );
  final analysis = DailyDebriefAnalysis(
    commanderIntentEvaluation: commanderIntentRecorded
        ? DailyDebriefCommanderIntentEvaluation(
            outcome: outcome,
            rationale: rationale,
            evidence: evidence,
          )
        : null,
    domainEvaluations: DailyDebriefDomainEvaluations(
      body: bodyEvaluation,
      recovery: recoveryEvaluation,
      condition: conditionEvaluation,
      work: workEvaluation,
      nutrition: null,
      hydration: null,
      activity: null,
      training: null,
    ),
    crossAnalysis: DailyDebriefCrossAnalysis(
      keyFactors: keyFactors,
      interactions: interactions,
      constraints: constraints,
      resources: resources,
    ),
    executionEvaluation: DailyDebriefExecutionEvaluation(
      successes: successes,
      adjustments: adjustments,
    ),
    nextDayHandoff: DailyDebriefNextDayHandoff(watchPoints: watchPoints),
  );
  const responseDigest =
      'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
  var record = DailyDebriefRecord.initial(
    localDate: localDate,
    sources: sources,
    analysis: analysis,
    responseDigest: responseDigest,
    timestamp: timestamp,
  );
  for (var nextRevision = 2; nextRevision <= revision; nextRevision++) {
    record = record.revise(
      sources: sources,
      analysis: analysis,
      responseDigest: responseDigest,
      timestamp: timestamp.add(Duration(seconds: nextRevision - 1)),
    );
  }
  return record;
}

MorningBriefRecord _morningBriefV2(
  String date, {
  String? intent,
  String work = 'WORK STATUS',
}) {
  const digest =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  final timestamp = DateTime.utc(2026, 8, 1, 9);
  return MorningBriefRecord.v2(
    localDate: date,
    sourceType: 'status',
    sourceOperationDate: date,
    sourceRecordId: 'status:$date',
    sourceDigest: digest,
    responseDigest: digest,
    exchangeId: 'exchange:$date',
    generatedAt: timestamp,
    importedAt: timestamp,
    situationAnalysisV2: MorningBriefSituationAnalysis(
      body: 'BODY STATUS',
      recovery: 'RECOVERY STATUS',
      condition: 'CONDITION STATUS',
      work: work,
      carryover: 'CARRYOVER MUST STAY HIDDEN',
      overall: 'Integrated overall assessment',
      workDisplay: MorningBriefSectionDisplay(
        primaryText: work,
        supportingText: work,
      ),
    ),
    operatingPolicy: 'Operating policy',
    strategicResourceDecisionV2: const MorningBriefStrategicResourceDecision(
      decision: 'Decision',
      targetResource: 'Resource',
      rationale: 'Rationale',
      execution: 'Execution',
    ),
    operationStatus: MorningBriefOperationStatus.yellow,
    commanderIntent: intent ?? 'CURRENT INTENT $date',
    actions: const [
      MorningBriefAction(
        actionId: 'action-1',
        text: 'Priority action',
        priority: 'high',
      ),
    ],
    createdAt: timestamp,
    updatedAt: timestamp,
  );
}

Future<void> _scrollDailyCommand(WidgetTester tester, double dy) async {
  await tester.drag(
    find.byKey(const ValueKey('daily-command-list')),
    Offset(0, dy),
  );
  await tester.pumpAndSettle();
}

Future<void> _openDailyDebrief(WidgetTester tester) async {
  final tab = find.text('DAILY DEBRIEF').first;
  await tester.ensureVisible(tab);
  await tester.pumpAndSettle();
  await tester.tap(tab);
}

Future<void> _tapCommandCenterTab(WidgetTester tester, String label) async {
  final tab = find.widgetWithText(TextButton, label).first;
  await tester.ensureVisible(tab);
  await tester.pumpAndSettle();
  await tester.tap(tab);
  await tester.pumpAndSettle();
}

Future<void> _pump(
  WidgetTester tester, {
  required double width,
  ThemeData? theme,
  WidgetBuilder? reviewPageBuilder,
}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: const CommandCenterPage(),
      onGenerateRoute: reviewPageBuilder == null
          ? null
          : (settings) => settings.name == AppRoutes.logConfirmationReview
                ? PageRouteBuilder<Object?>(
                    settings: settings,
                    transitionDuration: Duration.zero,
                    reverseTransitionDuration: Duration.zero,
                    pageBuilder: (context, _, _) => reviewPageBuilder(context),
                  )
                : null,
      routes: {
        AppRoutes.morning: (_) => const Scaffold(body: Text('STATUS ROUTE')),
        AppRoutes.food: (_) => const Scaffold(body: Text('FOOD ROUTE')),
        AppRoutes.training: (_) => const Scaffold(body: Text('TRAINING ROUTE')),
        AppRoutes.activity: (_) => const Scaffold(body: Text('ACTIVITY ROUTE')),
        if (reviewPageBuilder == null)
          AppRoutes.logConfirmationReview: (_) =>
              const Scaffold(body: Text('DAILY REVIEW ROUTE')),
        AppRoutes.backupRestore: (_) =>
            const Scaffold(body: Text('BACKUP ROUTE')),
      },
    ),
  );
  await tester.pumpAndSettle();
}

MorningFact _status() => MorningFact(
  date: DateTime(2026, 8, 1),
  weight: 80,
  bodyFat: 20,
  sleepDuration: const Duration(hours: 8),
  sleepScore: 80,
  workHours: 0,
  footPain: 0,
  medications: const [],
  freeNotes: null,
);
