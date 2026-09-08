import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/activity/activity_page.dart';
import 'package:or_app/core/state/app_initialization_state.dart';
import 'package:or_app/features/food/food_catalog_page.dart';
import 'package:or_app/features/food/food_page.dart';
import 'package:or_app/features/food/food_entry_page.dart';
import 'package:or_app/features/morning/morning_page.dart';
import 'package:or_app/features/report_sync/pages/report_sync_exchange_page.dart';
import 'package:or_app/features/repositories/app_repository_container.dart';
import 'package:or_app/features/training/training_page.dart';
import 'package:or_app/features/training/training_plan_import_page.dart';

import '../../repositories/indexed_db/fake_indexed_db_database.dart';
import '../operation_date/operation_date_test_fixture.dart';

void main() {
  late FakeIndexedDbDatabase database;
  late AppInitializationController controller;

  setUp(() {
    database = FakeIndexedDbDatabase();
    controller = AppInitializationController()..markReady();
    AppRepositoryRegistry.beginStartup(controller: controller);
    AppRepositoryRegistry.install(AppRepositoryContainer.indexedDb(database));
    seedOperationState(database, '2026-07-26');
  });

  tearDown(AppRepositoryRegistry.resetForTesting);

  testWidgets('FOOD orders daily actions before the report sync section', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: FoodPage()));

    expect(find.text('REPORT SYNC'), findsOneWidget);
    expect(find.text('FOOD REPORT SYNC'), findsOneWidget);
    expect(find.text('COMING LATER'), findsNothing);
    expect(find.text('FOOD DATABASE'), findsOneWidget);
    expect(find.text('RECIPE DATABASE'), findsNothing);
    expect(find.text('FOOD ENTRY'), findsOneWidget);
    expect(find.text('RECORD'), findsWidgets);

    final manual = tester.getTopLeft(find.text('MANUAL ENTRY')).dy;
    final record = tester.getTopLeft(find.text('RECORD').first).dy;
    final database = tester.getTopLeft(find.text('FOOD DATABASE')).dy;
    final sync = tester.getTopLeft(find.text('REPORT SYNC')).dy;
    expect(manual, lessThan(record));
    expect(record, lessThan(database));
    expect(database, lessThan(sync));

    await tester.ensureVisible(find.text('OPEN FOOD DATABASE'));
    await tester.tap(find.text('OPEN FOOD DATABASE'));
    await tester.pumpAndSettle();
    expect(find.byType(FoodCatalogPage), findsOneWidget);

    Navigator.of(tester.element(find.byType(FoodCatalogPage))).pop();
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('SYNC FOOD'));
    await tester.tap(find.text('SYNC FOOD'));
    await tester.pumpAndSettle();
    expect(find.byType(ReportSyncExchangePage), findsOneWidget);
    expect(find.text('FOOD REPORT SYNC'), findsWidgets);

    Navigator.of(tester.element(find.byType(ReportSyncExchangePage))).pop();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('FOOD ENTRY'));
    await tester.tap(find.text('FOOD ENTRY'));
    await tester.pumpAndSettle();
    expect(find.byType(FoodEntryPage), findsOneWidget);
  });

  testWidgets('TRAINING orders daily actions before the report sync section', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: TrainingPage()));

    expect(find.text('REPORT SYNC'), findsOneWidget);
    expect(find.text('SYNC TRAINING'), findsOneWidget);
    expect(find.text('MANUAL ENTRY'), findsOneWidget);
    expect(find.text('RECORD'), findsWidgets);

    final manual = tester.getTopLeft(find.text('MANUAL ENTRY')).dy;
    final plan = tester.getTopLeft(find.text('PLAN')).dy;
    final record = tester.getTopLeft(find.text('RECORD').first).dy;
    final analysis = tester.getTopLeft(find.text('ANALYSIS REPORT')).dy;
    final sync = tester.getTopLeft(find.text('REPORT SYNC')).dy;
    expect(manual, lessThan(plan));
    expect(plan, lessThan(record));
    expect(record, lessThan(analysis));
    expect(analysis, lessThan(sync));

    await tester.ensureVisible(find.text('TRAINING PLAN'));
    await tester.tap(find.text('TRAINING PLAN'));
    await tester.pumpAndSettle();
    expect(find.byType(TrainingPlanImportPage), findsOneWidget);

    Navigator.of(tester.element(find.byType(TrainingPlanImportPage))).pop();
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('SYNC TRAINING'));
    await tester.tap(find.text('SYNC TRAINING'));
    await tester.pumpAndSettle();
    expect(find.byType(ReportSyncExchangePage), findsOneWidget);
    expect(find.text('TRAINING REPORT SYNC'), findsWidgets);
    expect(find.text('OPEN ORLO SYNC'), findsNothing);
  });

  testWidgets('STATUS has no report sync and keeps daily actions', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: MorningPage()));

    expect(find.text('REPORT SYNC'), findsNothing);
    expect(find.text('MANUAL ENTRY'), findsNothing);
    expect(find.text('STATUS ENTRY'), findsWidgets);
    expect(find.text('RECORD'), findsWidgets);
  });

  testWidgets('ACTIVITY has no report sync and keeps daily actions', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: ActivityPage()));
    await tester.pumpAndSettle();

    expect(find.text('REPORT SYNC'), findsNothing);
    expect(find.text('ACTIVITY ENTRY'), findsWidgets);
    expect(find.text('RECORD'), findsWidgets);
  });

  for (final pageCase in const <({String name, Widget page})>[
    (name: 'FOOD', page: FoodPage()),
    (name: 'TRAINING', page: TrainingPage()),
    (name: 'STATUS', page: MorningPage()),
    (name: 'ACTIVITY', page: ActivityPage()),
  ]) {
    for (final width in [320.0, 390.0, 900.0, 1280.0]) {
      testWidgets(
        '${pageCase.name} remains overflow-free at ${width.toInt()}px',
        (tester) async {
          tester.view.physicalSize = Size(width, 1000);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          for (final theme in [ThemeData.light(), ThemeData.dark()]) {
            await tester.pumpWidget(
              MaterialApp(theme: theme, home: pageCase.page),
            );
            await tester.pump();
            expect(tester.takeException(), isNull);
          }
        },
      );
    }
  }
}
