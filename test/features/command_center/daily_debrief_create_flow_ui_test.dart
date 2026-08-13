import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/engine/activity_summary.dart';
import 'package:or_app/core/engine/food_summary.dart';
import 'package:or_app/core/models/bowel_movement_record.dart';
import 'package:or_app/core/services/daily_log_confirmation_service.dart';
import 'package:or_app/core/services/daily_log_confirmation_validation.dart';
import 'package:or_app/features/command_center/widgets/brief_debrief_page.dart';
import 'package:or_app/features/morning/models/morning_fact.dart';
import 'package:or_app/features/operation_date/models/operation_local_date.dart';
import 'package:or_app/features/report_sync/pages/report_sync_exchange_page.dart';
import 'package:or_app/features/repositories/app_repository_container.dart';

import '../../repositories/indexed_db/fake_indexed_db_database.dart';

void main() {
  tearDown(AppRepositoryRegistry.resetForTesting);

  testWidgets(
    'current eligible date prepares once and opens report sync directly',
    (tester) async {
      final database = FakeIndexedDbDatabase();
      final container = AppRepositoryContainer.indexedDb(database);
      await container.operationState.createInitial(
        OperationLocalDate.parse('2026-08-12'),
      );
      AppRepositoryRegistry.install(container);
      final snapshot = _snapshot();
      var preparationCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BriefDebriefPage(
              dailyLogSourceLoader: (_) async => snapshot,
              prepareDailyDebrief: (date, _) async {
                expect(date, '2026-08-12');
                preparationCount++;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('DAILY DEBRIEF').first);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('daily-debrief-target-date')),
        findsNothing,
      );
      expect(find.text('CREATE DAILY DEBRIEF'), findsOneWidget);
      await tester.tap(find.text('CREATE DAILY DEBRIEF'));
      await tester.pumpAndSettle();

      expect(preparationCount, 1);
      expect(find.byType(ReportSyncExchangePage), findsOneWidget);
      expect(
        tester
            .widget<ReportSyncExchangePage>(find.byType(ReportSyncExchangePage))
            .initialTargetDate,
        '2026-08-12',
      );
      expect(find.widgetWithText(AppBar, 'DAILY REVIEW'), findsNothing);
      expect(find.text('CONFIRM'), findsNothing);
    },
  );

  testWidgets('successful import returns daily debrief content to top', (
    tester,
  ) async {
    final container = await _installEligibleContainer();
    final snapshot = _snapshot();
    tester.view.physicalSize = const Size(390, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BriefDebriefPage(
            dailyLogSourceLoader: (_) async => snapshot,
            prepareDailyDebrief: (_, _) async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('DAILY DEBRIEF').first);
    await tester.pumpAndSettle();
    final position = _dailyDebriefScrollPosition(tester);
    position.jumpTo(position.maxScrollExtent / 2);
    await tester.pump();
    expect(_dailyDebriefScrollPosition(tester).pixels, greaterThan(0));
    await tester.tap(find.text('CREATE DAILY DEBRIEF'));
    await tester.pumpAndSettle();

    final page = tester.widget<ReportSyncExchangePage>(
      find.byType(ReportSyncExchangePage),
    );
    page.onApplied!();
    Navigator.of(tester.element(find.byType(ReportSyncExchangePage))).pop();
    await tester.pumpAndSettle();

    expect(_dailyDebriefScrollPosition(tester).pixels, 0);
    expect(find.text('DAILY DEBRIEF'), findsWidgets);
    expect(container, same(AppRepositoryRegistry.container));
  });

  testWidgets('normal back preserves daily debrief scroll position', (
    tester,
  ) async {
    await _installEligibleContainer();
    tester.view.physicalSize = const Size(390, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BriefDebriefPage(
            dailyLogSourceLoader: (_) async => _snapshot(),
            prepareDailyDebrief: (_, _) async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('DAILY DEBRIEF').first);
    await tester.pumpAndSettle();
    final position = _dailyDebriefScrollPosition(tester);
    position.jumpTo(position.maxScrollExtent / 2);
    await tester.pump();
    final before = _dailyDebriefScrollPosition(tester).pixels;
    expect(before, greaterThan(0));
    await tester.tap(find.text('CREATE DAILY DEBRIEF'));
    await tester.pumpAndSettle();
    Navigator.of(tester.element(find.byType(ReportSyncExchangePage))).pop();
    await tester.pumpAndSettle();

    expect(_dailyDebriefScrollPosition(tester).pixels, before);
  });
}

Future<AppRepositoryContainer> _installEligibleContainer() async {
  final container = AppRepositoryContainer.indexedDb(FakeIndexedDbDatabase());
  await container.operationState.createInitial(
    OperationLocalDate.parse('2026-08-12'),
  );
  AppRepositoryRegistry.install(container);
  return container;
}

Finder _dailyDebriefScrollable() => find.descendant(
  of: find.byKey(const ValueKey('daily-debrief-content')),
  matching: find.byType(Scrollable),
);

ScrollPosition _dailyDebriefScrollPosition(WidgetTester tester) =>
    tester.state<ScrollableState>(_dailyDebriefScrollable()).position;

DailyLogSourceSnapshot _snapshot() {
  final morning = MorningFact(
    date: DateTime(2026, 8, 12),
    weight: 80,
    bodyFat: 20,
    sleepDuration: const Duration(hours: 8),
    sleepScore: 80,
    workHours: 8,
    footPain: 0,
    medications: const [],
    freeNotes: null,
  );
  const food = FoodSummary(
    calories: 1800,
    protein: 100,
    fat: 60,
    carbohydrates: 200,
    hydrationMl: 2000,
    mealCount: 3,
  );
  final activity = ActivitySummary(
    steps: 5000,
    measuredSteps: 5000,
    isRecorded: true,
    bowelMovement: BowelMovementRecord.recorded(amount: 1, shape: 2),
    calculationBasis: const ActivityCalculationBasis(
      rawSteps: 5000,
      currentCarryOver: 0,
      previousCarryOverDeduction: 0,
      officialSteps: 5000,
    ),
  );
  final validation = DailyLogConfirmationValidation.validate(
    morning: morning,
    food: food,
    activity: activity,
    training: null,
  );
  return DailyLogSourceSnapshot(
    morning: morning,
    food: food,
    activity: activity,
    training: null,
    validation: validation,
  );
}
