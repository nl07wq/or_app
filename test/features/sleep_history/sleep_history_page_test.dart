import 'dart:convert';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/models/morning_data.dart';
import 'package:or_app/core/models/work_type.dart';
import 'package:or_app/features/body_history/services/data_center_history_range_preference.dart';
import 'package:or_app/features/daily_aggregate/models/daily_aggregate_v1.dart';
import 'package:or_app/features/daily_aggregate/repository/daily_aggregate_repository.dart';
import 'package:or_app/features/sleep_history/pages/sleep_history_page.dart';
import 'package:or_app/features/sleep_history/services/sleep_history_source_resolver.dart';
import 'package:or_app/features/status/models/persisted_status_record.dart';
import 'package:or_app/features/status/repositories/status_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../operation_date/operation_date_test_fixture.dart';

void main() {
  testWidgets('Sleep overview presents distinct duration and score extrema', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view
      ..physicalSize = const Size(390, 3000)
      ..devicePixelRatio = 1;
    SharedPreferences.setMockInitialValues({
      DataCenterHistoryRangePreference.storageKey: jsonEncode({
        'version': 1,
        'period': 'oneWeek',
      }),
    });
    await tester.pumpWidget(await _page());
    await tester.pumpAndSettle();

    expect(find.text('記録日数'), findsOneWidget);
    expect(find.text('平均睡眠'), findsOneWidget);
    expect(find.text('平均スコア'), findsOneWidget);
    expect(find.text('最長睡眠'), findsOneWidget);
    expect(find.text('最短睡眠'), findsOneWidget);
    expect(find.text('最高/最低スコア'), findsOneWidget);
    expect(find.text('睡眠またはスコア'), findsNothing);
    expect(find.text('13:21'), findsOneWidget);
    expect(find.text('3:42'), findsOneWidget);
    expect(find.text('91 / 47'), findsOneWidget);
    expect(find.text('記録 3日'), findsNWidgets(2));
  });

  testWidgets('Sleep bucket chart tooltips expose only the selected value', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view
      ..physicalSize = const Size(390, 3000)
      ..devicePixelRatio = 1;
    SharedPreferences.setMockInitialValues({
      DataCenterHistoryRangePreference.storageKey: jsonEncode({
        'version': 1,
        'period': 'oneMonth',
      }),
    });
    await tester.pumpWidget(await _page());
    await tester.pumpAndSettle();

    final durationCharts = tester
        .widgetList<BarChart>(find.byType(BarChart))
        .toList();
    expect(durationCharts, hasLength(2));
    for (final chart in durationCharts) {
      expect(chart.data.barTouchData.enabled, isTrue);
      expect(_tooltipText(chart), '7:42');
      expect(_tooltipText(chart), isNot(contains('9/7')));
      expect(_tooltipText(chart), isNot(contains('2026年')));
    }

    await tester.tap(find.text('スコア'));
    await tester.pump();
    final scoreCharts = tester
        .widgetList<BarChart>(find.byType(BarChart))
        .toList();
    expect(scoreCharts, hasLength(2));
    for (final chart in scoreCharts) {
      expect(chart.data.barTouchData.enabled, isTrue);
      expect(_tooltipText(chart), '73');
      expect(_tooltipText(chart), isNot(contains('9/7')));
      expect(_tooltipText(chart), isNot(contains('2026年')));
    }
  });
}

String _tooltipText(BarChart chart) {
  final group = chart.data.barGroups.first;
  final tooltip = chart.data.barTouchData.touchTooltipData.getTooltipItem(
    group,
    0,
    group.barRods.first,
    0,
  );
  if (tooltip == null) fail('Expected a tooltip item for the rendered bar.');
  return tooltip.text;
}

Future<Widget> _page() async => MaterialApp(
  home: SleepHistoryPage(
    resolver: SleepHistorySourceResolver(
      statusRepository: _StatusRepository([
        _status('2026-09-07', hours: 13.35, score: 91),
        _status('2026-09-08', hours: 3.7, score: 47),
        _status('2026-09-13', hours: 6.05, score: 81),
      ]),
      dailyAggregateRepository: const _AggregateRepository(),
    ),
    operationDateService: await operationDateServiceFor('2026-09-13'),
  ),
);

class _StatusRepository implements StatusRepository {
  const _StatusRepository(this.records);
  final List<PersistedStatusRecord> records;

  @override
  Future<StatusReadResult> getRange(String startDate, String endDate) async =>
      StatusReadResult(
        records: records
            .where(
              (record) =>
                  record.localDate.compareTo(startDate) >= 0 &&
                  record.localDate.compareTo(endDate) <= 0,
            )
            .toList(),
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _AggregateRepository implements DailyAggregateRepository {
  const _AggregateRepository();

  @override
  Future<List<DailyAggregateV1>> getRange(
    String startDate,
    String endDate,
  ) async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

PersistedStatusRecord _status(
  String date, {
  required double hours,
  required int score,
}) => PersistedStatusRecord(
  id: 'status:$date',
  localDate: date,
  createdAt: DateTime.utc(2026, 9, 13),
  updatedAt: DateTime.utc(2026, 9, 13),
  canonicalDate: date,
  recordKind: StatusRecordKind.canonical,
  data: MorningData(
    date: '${date}T07:00:00',
    weight: null,
    bodyFat: null,
    sleepHours: hours,
    sleepScore: score,
    footPain: 0,
    workType: WorkType.holiday,
    workStart: '',
    workEnd: '',
    workBreak: '',
    workHours: 0,
    memo: '',
  ),
);
