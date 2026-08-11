import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/engine/activity_summary.dart';
import 'package:or_app/core/engine/food_summary.dart';
import 'package:or_app/core/navigation/app_routes.dart';
import 'package:or_app/core/widgets/section_header.dart';
import 'package:or_app/data/indexed_db/indexed_db_store_names.dart';
import 'package:or_app/features/activity/models/activity_summary_state.dart';
import 'package:or_app/features/command_center/pages/command_center_page.dart';
import 'package:or_app/features/food/models/food_summary_state.dart';
import 'package:or_app/features/morning/models/morning_fact.dart';
import 'package:or_app/features/morning/models/morning_fact_state.dart';
import 'package:or_app/features/operation_date/models/operation_active_attempt.dart';
import 'package:or_app/features/operation_date/models/operation_local_date.dart';
import 'package:or_app/features/operation_date/models/operation_state.dart';
import 'package:or_app/features/repositories/app_repository_container.dart';
import 'package:or_app/features/report_sync/models/daily_debrief_record.dart';
import 'package:or_app/features/report_sync/pages/report_sync_exchange_page.dart';
import 'package:or_app/features/report_sync/models/morning_brief_record.dart';
import 'package:or_app/features/training/models/training_summary_state.dart';

import '../../repositories/indexed_db/fake_indexed_db_database.dart';
import '../operation_date/operation_date_test_fixture.dart';

void main() {
  late FakeIndexedDbDatabase database;

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

    expect(find.textContaining('2026-08-01'), findsOneWidget);
    expect(find.text('DAILY ASSESSMENT'), findsOneWidget);
    expect(find.text('NOT AVAILABLE'), findsWidgets);
    expect(find.textContaining('STATUSを入力'), findsNothing);
    expect(find.text('COMMANDER INTENT'), findsNothing);
    expect(find.text('ARGO COMMENT'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('FINALIZE BLOCKED'),
      500,
      scrollable: _dailyCommandScrollable(),
    );
    await tester.pumpAndSettle();
    expect(find.text('FINALIZE BLOCKED'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('daily-review-finalize-blocked')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('daily-review-blockers')), findsOneWidget);
    expect(find.text('STATUS, FOOD, ACTIVITY'), findsOneWidget);
    expect(find.textContaining('不足:'), findsNothing);
    expect(find.text('FINALIZE DAY'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('uses shared state and approved Daily Command order', (
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
    await tester.scrollUntilVisible(
      find.text('OPERATION MODULES'),
      500,
      scrollable: _dailyCommandScrollable(),
    );
    await tester.pumpAndSettle();
    expect(find.text('Recorded'), findsNWidgets(3));
    expect(find.text('Optional'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('FINALIZE READY'),
      500,
      scrollable: _dailyCommandScrollable(),
    );
    await tester.pumpAndSettle();
    expect(find.text('FINALIZE READY'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('daily-review-finalize-ready')),
      findsOneWidget,
    );
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

  testWidgets('separates BRIEF DEBRIEF content from report sync pages', (
    tester,
  ) async {
    await _pump(tester, width: 390);

    expect(find.text('BRIEF / DEBRIEF'), findsWidgets);
    expect(find.text('DAILY COMMAND'), findsWidgets);
    expect(find.text('DATA CENTER'), findsWidgets);
    await tester.tap(find.text('BRIEF / DEBRIEF').first);
    await tester.pumpAndSettle();
    expect(find.text('DAILY BRIEF'), findsWidgets);
    expect(find.text('DAILY DEBRIEF'), findsWidgets);
    expect(find.byType(ReportSyncExchangePanel), findsNothing);
    expect(find.text('MORNING BRIEF'), findsNothing);
    expect(find.text('DAILY BRIEFはまだありません。'), findsOneWidget);
    expect(find.text('DAILY BRIEF BACK NUMBER'), findsOneWidget);
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

    await tester.tap(find.text('DAILY DEBRIEF').first);
    await tester.pumpAndSettle();
    expect(find.byType(ReportSyncExchangePanel), findsNothing);
    expect(find.text('DAILY DEBRIEFはまだありません。'), findsOneWidget);
    expect(find.text('NO DAILY DEBRIEF HISTORY'), findsOneWidget);
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

  testWidgets('keeps Data Center inside Command Center tabs', (tester) async {
    await _pump(tester, width: 390);

    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(-250, 0),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('DATA CENTER').first);
    await tester.pumpAndSettle();

    expect(find.text('SYSTEM STATE'), findsOneWidget);
    expect(find.text('2026-08-01'), findsOneWidget);
    expect(find.text('BACKUP SCHEMA 3.0'), findsOneWidget);
    await tester.drag(
      find.byKey(const ValueKey('data-center-content')),
      const Offset(0, -1000),
    );
    await tester.pumpAndSettle();
    expect(find.text('NORMAL SYNC'), findsNothing);
    expect(find.text('OPEN ORLO SYNC'), findsNothing);
    expect(find.text('SYSTEM MONITORING'), findsOneWidget);
    expect(find.textContaining('OPERATION SYNC'), findsNothing);
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
    expect(find.text('MB-2026-08-01'), findsOneWidget);
    expect(find.text('DAILY BRIEF BACK NUMBER'), findsOneWidget);

    await tester.tap(find.text('DAILY DEBRIEF').first);
    await tester.pumpAndSettle();
    expect(find.byType(ReportSyncExchangePanel), findsNothing);
    expect(find.text('CREATE DAILY DEBRIEF'), findsOneWidget);
    expect(find.text('NO DAILY DEBRIEF HISTORY'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('open-daily-debrief-report-sync')),
      findsOneWidget,
    );
  });

  testWidgets('keeps existing debrief visible with creation action', (
    tester,
  ) async {
    final timestamp = DateTime.utc(2026, 8, 1, 23);
    final record = DailyDebriefRecord.initial(
      localDate: '2026-08-01',
      sources: const DailyDebriefSources(
        dailyAggregate: DailyDebriefDailyAggregateReference(
          operationDate: '2026-08-01',
          sourceType: 'records',
          recordDigest:
              'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        ),
        confirmation: DailyDebriefConfirmationReference(
          recordId: 'confirmation:2026-08-01',
          recordVersion: 2,
          revision: 1,
          snapshotDigest: '1234abcd',
          recordDigest:
              'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
        ),
        morningBrief: null,
      ),
      analysis: DailyDebriefAnalysis(
        commanderIntentEvaluation: null,
        domainEvaluations: DailyDebriefDomainEvaluations(
          body: 'BODY REVIEW',
          recovery: null,
          condition: null,
          work: null,
          nutrition: null,
          hydration: null,
          activity: null,
          training: null,
        ),
        crossAnalysis: DailyDebriefCrossAnalysis(
          keyFactors: [],
          interactions: [],
          constraints: [],
          resources: [],
        ),
        executionEvaluation: DailyDebriefExecutionEvaluation(
          successes: [],
          adjustments: [],
        ),
        nextDayHandoff: DailyDebriefNextDayHandoff(watchPoints: []),
      ),
      responseDigest:
          'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
      timestamp: timestamp,
    );
    database.seed(
      IndexedDbStoreNames.dailyDebriefRecords,
      record.localDate,
      record.toRecord(),
    );

    await _pump(tester, width: 390);
    await tester.tap(find.widgetWithText(TextButton, 'BRIEF / DEBRIEF'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('DAILY DEBRIEF').first);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('current-daily-debrief')), findsOneWidget);
    expect(find.text('CREATE DAILY DEBRIEF'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('daily-debrief-history-2026-08-01')),
      findsOneWidget,
    );
  });

  testWidgets(
    'separates current Morning Brief and exposes five back numbers with detail',
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
      expect(find.byIcon(Icons.health_and_safety_outlined), findsOneWidget);
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
        find.byKey(const ValueKey('morning-brief-back-number-2026-07-26')),
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

  testWidgets('shows recovery action instead of normal finalize', (
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
    await _scrollDailyCommand(tester, -900);

    expect(find.text('RECOVERY REQUIRED'), findsOneWidget);
    expect(find.text('RESUME FINALIZE'), findsOneWidget);
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
        await tester.tap(find.text('DAILY DEBRIEF').first);
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

MorningBriefRecord _morningBriefV2(String date) {
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
    situationAnalysisV2: const MorningBriefSituationAnalysis(
      body: 'BODY STATUS',
      recovery: 'RECOVERY STATUS',
      condition: 'CONDITION STATUS',
      work: 'WORK STATUS',
      carryover: 'CARRYOVER MUST STAY HIDDEN',
      overall: 'Integrated overall assessment',
    ),
    operatingPolicy: 'Operating policy',
    strategicResourceDecisionV2: const MorningBriefStrategicResourceDecision(
      decision: 'Decision',
      targetResource: 'Resource',
      rationale: 'Rationale',
      execution: 'Execution',
    ),
    operationStatus: MorningBriefOperationStatus.yellow,
    commanderIntent: 'CURRENT INTENT $date',
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

Future<void> _pump(
  WidgetTester tester, {
  required double width,
  ThemeData? theme,
}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: const CommandCenterPage(),
      routes: {
        AppRoutes.morning: (_) => const Scaffold(body: Text('STATUS ROUTE')),
        AppRoutes.food: (_) => const Scaffold(body: Text('FOOD ROUTE')),
        AppRoutes.training: (_) => const Scaffold(body: Text('TRAINING ROUTE')),
        AppRoutes.activity: (_) => const Scaffold(body: Text('ACTIVITY ROUTE')),
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
