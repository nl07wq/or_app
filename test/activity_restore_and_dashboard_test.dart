import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/engine/activity_summary.dart';
import 'package:or_app/core/models/activity_data.dart';
import 'package:or_app/core/services/daily_state_restore_service.dart';
import 'package:or_app/features/activity/models/activity_summary_state.dart';
import 'package:or_app/features/dashboard/dashboard_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    DailyStateRestoreService.resetForTesting();
    activitySummaryNotifier.value = const ActivitySummary.empty();
  });

  test('startup restore publishes today activity summary', () async {
    final today = DateTime.now();
    final record = ActivityData(date: today, steps: 0);
    SharedPreferences.setMockInitialValues({
      'activity_records': [jsonEncode(record.toJson())],
    });

    await DailyStateRestoreService.restore();

    expect(activitySummaryNotifier.value.isRecorded, isTrue);
    expect(activitySummaryNotifier.value.steps, 0);
  });

  test('startup restore publishes empty summary when today has no record', () async {
    SharedPreferences.setMockInitialValues({});

    await DailyStateRestoreService.restore();

    expect(activitySummaryNotifier.value.isRecorded, isFalse);
    expect(activitySummaryNotifier.value.steps, 0);
  });

  testWidgets('Dashboard formats recorded and empty Activity states', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: DashboardPage()));
    expect(find.text('Not recorded'), findsOneWidget);

    activitySummaryNotifier.value = const ActivitySummary(steps: 8420, isRecorded: true);
    await tester.pump();
    expect(find.text('8,420 steps'), findsOneWidget);

    activitySummaryNotifier.value = const ActivitySummary(steps: 0, isRecorded: true);
    await tester.pump();
    expect(find.text('0 steps'), findsOneWidget);
  });
}
