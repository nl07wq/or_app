import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/models/activity_data.dart';
import 'package:or_app/features/activity/repository/activity_repository.dart';
import 'package:or_app/features/activity_history/models/activity_history_models.dart';
import 'package:or_app/features/activity_history/services/activity_history_analytics.dart';
import 'package:or_app/features/activity_history/services/activity_history_source_resolver.dart';
import 'package:or_app/features/daily_aggregate/models/daily_aggregate_v1.dart';
import 'package:or_app/features/daily_aggregate/repository/daily_aggregate_repository.dart';

void main() {
  group('ActivityHistorySourceResolver', () {
    test(
      'keeps measured zero, missing, and outside observation distinct',
      () async {
        final resolver = ActivityHistorySourceResolver(
          activityRepository: _ActivityRepository([
            ActivityData(
              date: DateTime(2026, 9, 10),
              measuredSteps: 0,
              stepsEntered: true,
            ),
            ActivityData(
              date: DateTime(2026, 9, 12),
              measuredSteps: 1200,
              stepsEntered: true,
            ),
          ]),
          dailyAggregateRepository: const _AggregateRepository(),
        );

        final days = await resolver.resolve(
          startDate: '2026-09-09',
          endDate: '2026-09-12',
        );

        expect(days[0].state, ActivityHistoryDayState.outsideObservation);
        expect(days[1].state, ActivityHistoryDayState.measuredZero);
        expect(days[1].steps, 0);
        expect(days[2].state, ActivityHistoryDayState.notMeasured);
        expect(days[2].steps, isNull);
        expect(days[3].state, ActivityHistoryDayState.measured);
        expect(days[3].steps, 1200);
      },
    );

    test(
      'Activity is authoritative over a same-date aggregate fallback',
      () async {
        final resolver = ActivityHistorySourceResolver(
          activityRepository: _ActivityRepository([
            ActivityData(
              date: DateTime(2026, 9, 12),
              measuredSteps: 1200,
              stepsEntered: true,
            ),
          ]),
          dailyAggregateRepository: const _AggregateRepository(),
        );
        final day = (await resolver.resolve(
          startDate: '2026-09-12',
          endDate: '2026-09-12',
        )).single;
        expect(day.source, ActivityHistorySource.currentActivity);
        expect(day.steps, 1200);
      },
    );
  });

  test(
    'analytics excludes outside observation and missing from Steps averages',
    () {
      final summary = const ActivityHistoryAnalytics().summarize([
        const ActivityHistoryDaySummary(
          operationDate: '2026-09-09',
          state: ActivityHistoryDayState.outsideObservation,
          source: ActivityHistorySource.none,
          quality: ActivityHistoryQuality.unknown,
          observationEligible: false,
        ),
        const ActivityHistoryDaySummary(
          operationDate: '2026-09-10',
          state: ActivityHistoryDayState.measuredZero,
          source: ActivityHistorySource.currentActivity,
          quality: ActivityHistoryQuality.full,
          observationEligible: true,
          steps: 0,
        ),
        const ActivityHistoryDaySummary(
          operationDate: '2026-09-11',
          state: ActivityHistoryDayState.notMeasured,
          source: ActivityHistorySource.none,
          quality: ActivityHistoryQuality.unknown,
          observationEligible: true,
        ),
        const ActivityHistoryDaySummary(
          operationDate: '2026-09-12',
          state: ActivityHistoryDayState.measured,
          source: ActivityHistorySource.currentActivity,
          quality: ActivityHistoryQuality.full,
          observationEligible: true,
          steps: 1200,
        ),
      ]);
      expect(summary.observationDays, 3);
      expect(summary.measuredDays, 2);
      expect(summary.unmeasuredDays, 1);
      expect(summary.measurementCoverage, closeTo(2 / 3, 0.0001));
      expect(summary.totalSteps, 1200);
      expect(summary.averageMeasuredSteps, 600);
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
  Future<List<ActivityData>> findAll() async => records;
  @override
  Future<ActivityData?> findByDate(DateTime date) async => records
      .where((value) => value.date == date)
      .cast<ActivityData?>()
      .firstOrNull;
  @override
  Future<ActivityData?> findById(String id) async => records
      .where((value) => value.id == id)
      .cast<ActivityData?>()
      .firstOrNull;
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
  @override
  Future<void> deleteByDateInTransaction(
    dynamic transaction,
    String operationDate,
  ) async {}
}
