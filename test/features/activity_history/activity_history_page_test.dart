import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/models/activity_data.dart';
import 'package:or_app/features/activity/repository/activity_repository.dart';
import 'package:or_app/features/activity_history/pages/activity_history_page.dart';
import 'package:or_app/features/activity_history/services/activity_history_source_resolver.dart';
import 'package:or_app/features/body_history/services/data_center_history_range_preference.dart';
import 'package:or_app/features/daily_aggregate/models/daily_aggregate_v1.dart';
import 'package:or_app/features/daily_aggregate/repository/daily_aggregate_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../operation_date/operation_date_test_fixture.dart';

void main() {
  testWidgets(
    'Activity Trend uses seven latest rows and expands without a target',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view
        ..physicalSize = const Size(900, 3000)
        ..devicePixelRatio = 1;
      SharedPreferences.setMockInitialValues({
        DataCenterHistoryRangePreference.storageKey: jsonEncode({
          'version': 1,
          'period': 'fifteenDays',
        }),
      });
      final records = [
        for (var day = 1; day <= 15; day++)
          ActivityData(
            date: DateTime(2026, 9, day),
            measuredSteps: day * 1000,
            stepsEntered: day != 15,
          ),
      ];
      await tester.pumpWidget(
        MaterialApp(
          home: ActivityHistoryPage(
            resolver: ActivityHistorySourceResolver(
              activityRepository: _ActivityRepository(records),
              dailyAggregateRepository: const _AggregateRepository(),
            ),
            operationDateService: await operationDateServiceFor('2026-09-15'),
          ),
        ),
      );
      for (var index = 0; index < 5; index += 1) {
        await tester.pump(const Duration(milliseconds: 16));
      }

      expect(find.text('TREND'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('歩数の推移')).dy,
        lessThan(tester.getTopLeft(find.text('TREND')).dy),
      );
      expect(
        tester.getTopLeft(find.text('TREND')).dy,
        lessThan(tester.getTopLeft(find.text('WEEKLY')).dy),
      );
      expect(
        find.byKey(const ValueKey('activity-trend-bar-2026-09-09')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('activity-trend-bar-2026-09-08')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('activity-trend-toggle')),
        findsOneWidget,
      );
      expect(find.text('MONTHLY'), findsNothing);
      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byKey(const ValueKey('activity-trend-bar-2026-09-15')),
            )
            .value,
        isNull,
      );

      await tester.tap(find.byKey(const ValueKey('activity-trend-toggle')));
      await tester.pump();
      expect(
        find.byKey(const ValueKey('activity-trend-bar-2026-09-01')),
        findsOneWidget,
      );
      expect(find.text('折りたたむ'), findsOneWidget);
      expect(
        tester
            .getTopLeft(
              find.byKey(const ValueKey('activity-daily-history-2026-09-09')),
            )
            .dy,
        lessThan(
          tester
              .getTopLeft(
                find.byKey(const ValueKey('activity-daily-history-2026-09-15')),
              )
              .dy,
        ),
      );
    },
  );
}

class _ActivityRepository implements ActivityRepository {
  _ActivityRepository(this.records);
  final List<ActivityData> records;

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
  Future<List<ActivityData>> findAll() async => records;
  @override
  Future<List<ActivityData>> getAll() async => records;
  @override
  Future<void> save(ActivityData data) async {}
}

class _AggregateRepository implements DailyAggregateRepository {
  const _AggregateRepository();

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
