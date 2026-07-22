import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/engine/activity_summary.dart';
import 'package:or_app/core/models/activity_data.dart';
import 'package:or_app/core/services/app_clock.dart';
import 'package:or_app/features/activity/activity_page.dart';
import 'package:or_app/features/activity/repository/activity_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppClock.resetForTesting();
  });

  tearDown(AppClock.resetForTesting);

  ActivitySummary summaryFor({
    required int measuredSteps,
    required int carryOver,
    required int previousCarryOver,
  }) {
    return ActivitySummary.fromActivityData(
      ActivityData(
        date: DateTime(2026, 7, 21),
        measuredSteps: measuredSteps,
        carryOver: carryOver,
      ),
      previousCarryOver: previousCarryOver,
    );
  }

  test('adds the current date Carry Over to official steps', () {
    final summary = summaryFor(
      measuredSteps: 8000,
      carryOver: 2000,
      previousCarryOver: 0,
    );

    expect(summary.officialSteps, 10000);
    expect(summary.steps, 10000);
  });

  test('deducts the prior date Carry Over from official steps', () {
    final summary = summaryFor(
      measuredSteps: 12000,
      carryOver: 0,
      previousCarryOver: 2000,
    );

    expect(summary.officialSteps, 10000);
  });

  test('uses the prior calendar day Carry Over as the next day deduction', () {
    final summary = summaryFor(
      measuredSteps: 12000,
      carryOver: 0,
      previousCarryOver: 5000,
    );

    expect(summary.previousCarryOverDeduction, 5000);
    expect(summary.officialSteps, 7000);
  });

  test('adds the current Carry Over and deducts the prior Carry Over', () {
    final summary = summaryFor(
      measuredSteps: 12000,
      carryOver: 1000,
      previousCarryOver: 2000,
    );

    expect(summary.officialSteps, 11000);
  });

  test('keeps a zero Activity record valid', () {
    final summary = summaryFor(
      measuredSteps: 0,
      carryOver: 0,
      previousCarryOver: 0,
    );

    expect(summary.officialSteps, 0);
  });

  test(
    'legacy steps-only JSON reads as measured steps with zero Carry Over',
    () {
      final data = ActivityData.fromJson({
        'date': '2026-07-21T00:00:00.000',
        'steps': 5886,
      });

      expect(data.measuredSteps, 5886);
      expect(data.carryOver, 0);
    },
  );

  test(
    'does not infer current Carry Over from the former temporary fields',
    () {
      final data = ActivityData.fromJson({
        'date': '2026-07-21T00:00:00.000',
        'steps': 8206,
        'measuredSteps': 2320,
        'carryOverApplied': 5886,
        'carryOverRecorded': 500,
      });

      expect(data.measuredSteps, 8206);
      expect(data.carryOver, 0);
    },
  );

  test('rejects persisting an official step result below zero', () async {
    const repository = LocalActivityRepository();
    await repository.save(
      ActivityData(
        date: DateTime(2026, 7, 20),
        measuredSteps: 100,
        carryOver: 101,
      ),
    );

    await expectLater(
      repository.save(
        ActivityData(
          date: DateTime(2026, 7, 21),
          measuredSteps: 100,
          carryOver: 0,
        ),
      ),
      throwsArgumentError,
    );
    expect(await repository.findByDate(DateTime(2026, 7, 21)), isNull);
  });

  testWidgets('new entry uses the current Debug Date and prior Carry Over', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final previous = ActivityData(
      date: DateTime(2026, 7, 22),
      measuredSteps: 10000,
      carryOver: 5000,
    );
    SharedPreferences.setMockInitialValues({
      'activity_records': [jsonEncode(previous.toJson())],
    });
    AppClock.setDebugDate(DateTime(2026, 7, 23));

    await tester.pumpWidget(const MaterialApp(home: ActivityPage()));
    await tester.tap(find.text('Log Activity'));
    await tester.pumpAndSettle();

    expect(find.text('Activity Entry'), findsOneWidget);
    expect(find.text('2026-07-23'), findsOneWidget);
    expect(find.text('-5,000 steps'), findsOneWidget);
  });

  testWidgets('existing target-date record opens in Edit mode', (tester) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final previous = ActivityData(
      date: DateTime(2026, 7, 22),
      measuredSteps: 10000,
      carryOver: 5000,
    );
    final existing = ActivityData(
      date: DateTime(2026, 7, 23),
      measuredSteps: 12000,
      carryOver: 0,
    );
    SharedPreferences.setMockInitialValues({
      'activity_records': [
        jsonEncode(previous.toJson()),
        jsonEncode(existing.toJson()),
      ],
    });
    AppClock.setDebugDate(DateTime(2026, 7, 23));

    await tester.pumpWidget(const MaterialApp(home: ActivityPage()));
    await tester.tap(find.text('Log Activity'));
    await tester.pumpAndSettle();

    expect(find.text('Edit Activity'), findsOneWidget);
    expect(find.text('2026-07-23'), findsOneWidget);
    expect(find.widgetWithText(TextField, '12000'), findsOneWidget);
    expect(find.text('-5,000 steps'), findsOneWidget);
    expect(find.text('7,000 steps'), findsOneWidget);
  });
}
