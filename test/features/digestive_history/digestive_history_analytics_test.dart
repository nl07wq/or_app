import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/models/activity_data.dart';
import 'package:or_app/core/models/bowel_movement_record.dart';
import 'package:or_app/core/models/digestive_event.dart';
import 'package:or_app/features/activity/repository/activity_repository.dart';
import 'package:or_app/features/daily_aggregate/models/daily_aggregate_v1.dart';
import 'package:or_app/features/daily_aggregate/repository/daily_aggregate_repository.dart';
import 'package:or_app/features/digestive_history/models/digestive_history_models.dart';
import 'package:or_app/features/digestive_history/services/digestive_history_analytics.dart';
import 'package:or_app/features/digestive_history/services/digestive_history_source_resolver.dart';

void main() {
  const analytics = DigestiveHistoryAnalytics();

  test('multiple events remain individual distribution observations', () {
    final summary = analytics.summarize([
      _day(
        '2026-09-01',
        DigestiveDayState.yes,
        3,
        events: const [
          DigestiveEventSummary(sequence: 1, amount: 1, shape: 1, relief: 0),
          DigestiveEventSummary(sequence: 2, amount: 2, shape: 2, relief: 1),
          DigestiveEventSummary(sequence: 3, amount: 3, shape: 3, relief: 2),
        ],
      ),
    ]);

    expect(summary.totalExactEvents, 3);
    expect(summary.amountDistribution.knownCounts, {1: 1, 2: 1, 3: 1});
    expect(summary.formDistribution.knownCounts, {1: 1, 2: 1, 3: 1});
    expect(summary.reliefDistribution.knownCounts, {0: 1, 1: 1, 2: 1});
  });

  test('unknown breaks confirmed-no streak and is never zero', () {
    final summary = analytics.summarize([
      _day('2026-09-01', DigestiveDayState.confirmedNo, 0),
      _day('2026-09-02', DigestiveDayState.confirmedNo, 0),
      _day(
        '2026-09-03',
        DigestiveDayState.unknown,
        null,
        known: false,
        quality: DigestiveDataQuality.unknown,
      ),
      _day('2026-09-04', DigestiveDayState.confirmedNo, 0),
    ]);

    expect(summary.longestConfirmedNoStreak, 2);
    expect(summary.currentConfirmedNoStreak, 1);
    expect(summary.unknownDays, 1);
    expect(summary.totalExactEvents, 0);
  });

  test('uses exact-count denominator and preserves missing attributes', () {
    final summary = analytics.summarize([
      _day(
        '2026-09-01',
        DigestiveDayState.yes,
        2,
        events: const [
          DigestiveEventSummary(amount: 1),
          DigestiveEventSummary(amount: 2, shape: 2),
        ],
      ),
      _day(
        '2026-09-02',
        DigestiveDayState.yes,
        null,
        known: false,
        quality: DigestiveDataQuality.partial,
      ),
    ]);

    expect(summary.exactCountDays, 1);
    expect(summary.averagePerExactCountDay, 2);
    expect(summary.amountDistribution.knownTotal, 2);
    expect(summary.formDistribution.knownTotal, 1);
    expect(summary.formDistribution.missingCount, 1);
    expect(summary.reliefDistribution.missingCount, 2);
  });

  test(
    'resolver prefers current activity events over aggregate fallback',
    () async {
      final resolver = DigestiveHistorySourceResolver(
        activityRepository: _ActivityRepository([
          ActivityData(
            date: DateTime(2026, 9, 1),
            measuredSteps: 1,
            digestiveEvents: [_event(amount: 2, sequence: 1)],
          ),
          ActivityData(
            date: DateTime(2026, 9, 2),
            measuredSteps: 1,
            bowelMovement: const BowelMovementRecord.none(),
          ),
        ]),
        dailyAggregateRepository: _AggregateRepository([
          _aggregate('2026-09-01', count: 9),
          _aggregate('2026-09-03', count: 2),
        ]),
      );

      final days = await resolver.resolve(
        startDate: '2026-09-01',
        endDate: '2026-09-03',
      );
      expect(days[0].source, DigestiveHistorySource.currentActivity);
      expect(days[0].exactCount, 1);
      expect(days[1].source, DigestiveHistorySource.legacyActivity);
      expect(days[1].state, DigestiveDayState.confirmedNo);
      expect(days[2].source, DigestiveHistorySource.dailyAggregate);
      expect(days[2].exactCount, 2);
    },
  );

  test('unreadable source is invalid, never confirmed no', () async {
    final resolver = DigestiveHistorySourceResolver(
      activityRepository: _ThrowingActivityRepository(),
      dailyAggregateRepository: _AggregateRepository(const []),
    );
    final day = (await resolver.resolve(
      startDate: '2026-09-01',
      endDate: '2026-09-01',
    )).single;
    expect(day.quality, DigestiveDataQuality.invalid);
    expect(day.state, DigestiveDayState.unknown);
  });
}

DigestiveDaySummary _day(
  String date,
  DigestiveDayState state,
  int? count, {
  bool known = true,
  DigestiveDataQuality quality = DigestiveDataQuality.full,
  List<DigestiveEventSummary> events = const [],
}) => DigestiveDaySummary(
  operationDate: date,
  state: state,
  source: DigestiveHistorySource.currentActivity,
  quality: quality,
  countKnown: known,
  exactCount: count,
  events: events,
);

DigestiveEvent _event({required int amount, required int sequence}) =>
    DigestiveEvent(
      id: 'event-$sequence',
      sequence: sequence,
      amount: amount,
      shape: 2,
      relief: 1,
      recordedAt: DateTime.utc(2026, 9, 1),
    );

DailyAggregateV1 _aggregate(String date, {required int count}) =>
    DailyAggregateV1(
      operationDate: date,
      weightKg: null,
      bodyFatPercent: null,
      sleepDurationMinutes: null,
      sleepScore: null,
      sleepType: null,
      plantarFasciitisLevel: null,
      workStartTime: null,
      workEndTime: null,
      workBreakMinutes: null,
      actualWorkMinutes: null,
      intakeCaloriesKcal: null,
      proteinG: null,
      fatG: null,
      carbsG: null,
      hydrationMl: null,
      officialSteps: null,
      measuredSteps: null,
      trainingPerformed: null,
      digestiveCount: count,
      sourceType: DailyAggregateSourceType.legacyDns,
    );

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
  _AggregateRepository(this.values);
  final List<DailyAggregateV1> values;
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
  ) async => values;
  @override
  Future<DailyAggregateV1> put(DailyAggregateV1 aggregate) async => aggregate;
  @override
  Future<DailyAggregateV1> putInTransaction(
    dynamic transaction,
    DailyAggregateV1 aggregate,
  ) async => aggregate;
}

class _ThrowingActivityRepository extends _ActivityRepository {
  _ThrowingActivityRepository() : super(const []);

  @override
  Future<List<ActivityData>> findAll() async => throw const FormatException();
}
