import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/engine/activity_summary.dart';
import 'package:or_app/core/engine/food_summary.dart';
import 'package:or_app/core/navigation/app_routes.dart';
import 'package:or_app/features/activity/models/activity_summary_state.dart';
import 'package:or_app/features/command_center/pages/command_center_page.dart';
import 'package:or_app/features/food/models/food_summary_state.dart';
import 'package:or_app/features/morning/models/morning_fact.dart';
import 'package:or_app/features/morning/models/morning_fact_state.dart';
import 'package:or_app/features/operation_date/models/operation_active_attempt.dart';
import 'package:or_app/features/operation_date/models/operation_local_date.dart';
import 'package:or_app/features/operation_date/models/operation_state.dart';
import 'package:or_app/features/repositories/app_repository_container.dart';
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
    expect(find.textContaining('STANDBY'), findsWidgets);
    expect(find.textContaining('STATUSを入力'), findsOneWidget);
    expect(find.text('COMMANDER INTENT'), findsNothing);
    expect(find.text('ARGO COMMENT'), findsNothing);
    await _scrollDailyCommand(tester, -900);
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

    await _scrollDailyCommand(tester, -350);
    expect(find.textContaining('OPERATION STATUS'), findsOneWidget);
    expect(find.textContaining('COMMANDER INTENT'), findsOneWidget);
    expect(find.text('ARGO COMMENT'), findsOneWidget);
    expect(find.byIcon(Icons.flag_outlined), findsOneWidget);
    expect(find.byIcon(Icons.lightbulb_outline), findsOneWidget);
    final labels = tester
        .widgetList<Text>(find.byType(Text))
        .map((widget) => widget.data)
        .whereType<String>()
        .toList();
    final statusIndex = labels.indexWhere(
      (value) => value.startsWith('OPERATION STATUS'),
    );
    final intentIndex = labels.indexWhere(
      (value) => value.startsWith('COMMANDER INTENT'),
    );
    final briefIndex = labels.indexOf('ARGO COMMENT');
    expect(statusIndex, lessThan(intentIndex));
    expect(intentIndex, lessThan(briefIndex));
    await _scrollDailyCommand(tester, -900);
    expect(find.text('Recorded'), findsNWidgets(3));
    expect(find.text('Optional'), findsOneWidget);
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

  testWidgets('uses uppercase tabs and formal BRIEF DEBRIEF exchange', (
    tester,
  ) async {
    await _pump(tester, width: 390);

    expect(find.text('BRIEF / DEBRIEF'), findsWidgets);
    expect(find.text('DAILY COMMAND'), findsWidgets);
    expect(find.text('DATA CENTER'), findsWidgets);
    await tester.tap(find.text('BRIEF / DEBRIEF').first);
    await tester.pumpAndSettle();
    expect(find.text('MORNING BRIEF'), findsWidgets);
    expect(find.text('DAILY DEBRIEF'), findsWidgets);
    expect(find.text('COPY CHATGPT PROMPT'), findsWidgets);
    expect(find.text('COPY REQUEST DATA'), findsWidgets);
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
      }
    });
  }
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
