import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/activity/activity_page.dart';
import 'package:or_app/features/food/food_page.dart';
import 'package:or_app/features/food/food_entry_page.dart';
import 'package:or_app/features/morning/morning_page.dart';
import 'package:or_app/features/sync/pages/orlo_sync_page.dart';
import 'package:or_app/features/training/training_page.dart';

void main() {
  testWidgets('FOOD keeps v1 entry and reports sync as coming later', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: FoodPage()));

    expect(find.text('REPORT SYNC'), findsOneWidget);
    expect(find.text('FOOD SYNC'), findsOneWidget);
    expect(find.text('COMING LATER'), findsOneWidget);
    expect(find.text('FOOD DATABASE'), findsNothing);
    expect(find.text('RECIPE DATABASE'), findsNothing);
    expect(find.text('FOOD ENTRY'), findsOneWidget);
    expect(find.text('RECORD'), findsWidgets);

    await tester.tap(find.text('SYNC FOOD'));
    await tester.pump();
    expect(find.text('FOOD SYNC COMING LATER'), findsOneWidget);
    expect(find.byType(OrloSyncPage), findsNothing);

    await tester.tap(find.text('FOOD ENTRY'));
    await tester.pumpAndSettle();
    expect(find.byType(FoodEntryPage), findsOneWidget);
  });

  testWidgets('TRAINING opens a locked training sync experience', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: TrainingPage()));

    expect(find.text('REPORT SYNC'), findsOneWidget);
    expect(find.text('SYNC TRAINING'), findsOneWidget);
    expect(find.text('MANUAL ENTRY'), findsOneWidget);
    expect(find.text('RECORD'), findsWidgets);

    await tester.tap(find.text('SYNC TRAINING'));
    await tester.pumpAndSettle();
    expect(find.byType(OrloSyncPage), findsOneWidget);
    expect(find.text('TRAINING SYNC'), findsOneWidget);
    expect(find.text('TRAINING'), findsOneWidget);
    expect(find.text('Data Type'), findsNothing);
    expect(find.text('OPEN ORLO SYNC'), findsNothing);
  });

  testWidgets('STATUS has no report sync and keeps daily actions', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: MorningPage()));

    expect(find.text('REPORT SYNC'), findsNothing);
    expect(find.text('MANUAL ENTRY'), findsOneWidget);
    expect(find.text('RECORD'), findsWidgets);
  });

  testWidgets('ACTIVITY has no report sync and keeps daily actions', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: ActivityPage()));
    await tester.pump();

    expect(find.text('REPORT SYNC'), findsNothing);
    expect(find.text('MANUAL ENTRY'), findsOneWidget);
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
