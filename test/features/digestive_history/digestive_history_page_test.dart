import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:or_app/core/models/activity_data.dart';
import 'package:or_app/core/models/digestive_event.dart';
import 'package:or_app/features/activity/repository/activity_repository.dart';
import 'package:or_app/features/body_history/services/data_center_history_range_preference.dart';
import 'package:or_app/features/daily_aggregate/models/daily_aggregate_v1.dart';
import 'package:or_app/features/daily_aggregate/repository/daily_aggregate_repository.dart';
import 'package:or_app/features/digestive_history/pages/digestive_history_page.dart';
import 'package:or_app/features/digestive_history/services/digestive_history_source_resolver.dart';

import '../operation_date/operation_date_test_fixture.dart';

void main() {
  testWidgets(
    'anchors Digestive Trend to Operation Date and aligns event detail',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view
        ..physicalSize = const Size(390, 844)
        ..devicePixelRatio = 1;
      SharedPreferences.setMockInitialValues({
        DataCenterHistoryRangePreference.storageKey: jsonEncode({
          'version': 1,
          'period': 'oneWeek',
        }),
      });

      final resolver = DigestiveHistorySourceResolver(
        activityRepository: _ActivityRepository([
          ActivityData(
            date: DateTime(2026, 9, 10),
            digestiveEvents: [
              DigestiveEvent(
                id: 'event-1',
                sequence: 1,
                amount: 3,
                shape: 2,
                relief: 2,
                recordedAt: DateTime(2026, 9, 10, 8),
              ),
            ],
          ),
          ActivityData(date: DateTime(2026, 9, 12), digestiveEvents: const []),
        ]),
        dailyAggregateRepository: _AggregateRepository(),
      );

      final operationDateService = await operationDateServiceFor('2026-09-12');
      await tester.pumpWidget(
        MaterialApp(
          home: DigestiveHistoryPage(
            resolver: resolver,
            operationDateService: operationDateService,
          ),
        ),
      );
      for (var index = 0; index < 5; index += 1) {
        await tester.pump(const Duration(milliseconds: 16));
      }

      expect(find.textContaining('検索期間:'), findsOneWidget);
      tester.view.physicalSize = const Size(390, 3000);
      await tester.pump();
      expect(
        tester.getTopLeft(find.text('OVERVIEW')).dy,
        lessThan(tester.getTopLeft(find.text('排便回数の推移')).dy),
      );
      expect(
        tester.getTopLeft(find.text('排便回数の推移')).dy,
        lessThan(tester.getTopLeft(find.text('TREND')).dy),
      );
      expect(
        tester.getTopLeft(find.text('TREND')).dy,
        lessThan(tester.getTopLeft(find.text('DISTRIBUTION')).dy),
      );
      final chart = find.byKey(const ValueKey('digestive-daily-count-chart'));
      expect(
        find.descendant(of: chart, matching: find.text('9/12')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: chart, matching: find.text('9/13')),
        findsNothing,
      );
      expect(find.textContaining('集計対象 7日 ・ 排便あり'), findsNothing);
      for (final date in const ['2026-09-10', '2026-09-11', '2026-09-12']) {
        expect(find.byKey(ValueKey('digestive-trend-$date')), findsOneWidget);
      }
      expect(
        find.byKey(const ValueKey('digestive-trend-2026-09-13')),
        findsNothing,
      );

      final outside = tester.widget<LinearProgressIndicator>(
        find.byKey(const ValueKey('digestive-trend-bar-2026-09-06')),
      );
      final unresolved = tester.widget<LinearProgressIndicator>(
        find.byKey(const ValueKey('digestive-trend-bar-2026-09-11')),
      );
      final confirmedZero = tester.widget<LinearProgressIndicator>(
        find.byKey(const ValueKey('digestive-trend-bar-2026-09-12')),
      );
      expect(outside.value, 0);
      expect(unresolved.value, isNull);
      expect(confirmedZero.value, 0);
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);

      tester.view.physicalSize = const Size(390, 3000);
      await tester.pump();
      final status = find.byKey(
        const ValueKey('digestive-daily-status-2026-09-10'),
      );
      await tester.tap(status);
      await tester.pump();
      final event = find.byKey(
        const ValueKey('digestive-daily-event-2026-09-10-1'),
      );
      expect(event, findsOneWidget);
      expect(tester.getTopLeft(event).dx, tester.getTopLeft(status).dx);
      expect(find.textContaining('残便感:スッキリ'), findsOneWidget);
      expect(find.textContaining('残便:'), findsNothing);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await tester.pumpWidget(
        MaterialApp(
          home: DigestiveHistoryPage(
            key: const ValueKey('operation-date-advanced'),
            resolver: resolver,
            operationDateService: await operationDateServiceFor('2026-09-13'),
          ),
        ),
      );
      for (var index = 0; index < 5; index += 1) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(
        find.byKey(const ValueKey('digestive-trend-2026-09-13')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byKey(const ValueKey('digestive-trend-bar-2026-09-13')),
            )
            .value,
        isNull,
      );
    },
  );
}

class _ActivityRepository implements ActivityRepository {
  _ActivityRepository(this.values);

  final List<ActivityData> values;

  @override
  Future<void> clear() async {}

  @override
  Future<void> delete(String id) async {}

  @override
  Future<void> deleteByDate(DateTime date) async {}

  @override
  Future<ActivityData?> findByDate(DateTime date) async => null;

  @override
  Future<ActivityData?> findById(String id) async => null;

  @override
  Future<List<ActivityData>> findAll() async => values;

  @override
  Future<List<ActivityData>> getAll() async => values;

  @override
  Future<void> save(ActivityData data) async {}
}

class _AggregateRepository implements DailyAggregateRepository {
  @override
  Future<void> deleteByDate(String operationDate) async {}

  @override
  Future<void> deleteByDateInTransaction(
    dynamic transaction,
    String operationDate,
  ) async {}

  @override
  Future<DailyAggregateV1?> getByDate(String operationDate) async => null;

  @override
  Future<List<DailyAggregateV1>> getRange(
    String startDate,
    String endDate,
  ) async => const [];

  @override
  Future<DailyAggregateV1> put(DailyAggregateV1 aggregate) async => aggregate;

  @override
  Future<DailyAggregateV1> putInTransaction(
    dynamic transaction,
    DailyAggregateV1 aggregate,
  ) async => aggregate;
}
