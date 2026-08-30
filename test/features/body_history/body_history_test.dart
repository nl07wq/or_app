import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/models/morning_data.dart';
import 'package:or_app/core/models/work_type.dart';
import 'package:or_app/features/body_history/models/body_history_models.dart';
import 'package:or_app/features/body_history/services/body_history_chart_engine.dart';
import 'package:or_app/features/body_history/services/body_history_source_resolver.dart';
import 'package:or_app/features/daily_aggregate/models/daily_aggregate_v1.dart';
import 'package:or_app/features/daily_aggregate/repository/daily_aggregate_repository.dart';
import 'package:or_app/features/status/models/persisted_status_record.dart';
import 'package:or_app/features/status/repositories/status_repository.dart';

void main() {
  const engine = BodyHistoryChartEngine();

  test(
    'STATUS wins when STATUS and aggregate exist on the same date',
    () async {
      final resolver = BodyHistorySourceResolver(
        statusRepository: _StatusRepository([_statusRecord('2026-08-08', 90)]),
        dailyAggregateRepository: _AggregateRepository([
          _aggregate('2026-08-08', weight: 100),
        ]),
      );

      final result = await resolver.resolve(
        startDate: '2026-08-08',
        endDate: '2026-08-08',
      );

      expect(result.single.weightKg, 90);
      expect(result.single.source, BodyHistorySource.status);
    },
  );

  test('aggregate is used only when STATUS is absent', () async {
    final resolver = BodyHistorySourceResolver(
      statusRepository: const _StatusRepository([]),
      dailyAggregateRepository: _AggregateRepository([
        _aggregate('2026-08-08', weight: 95.6),
      ]),
    );

    final result = await resolver.resolve(
      startDate: '2026-08-08',
      endDate: '2026-08-08',
    );

    expect(result.single.weightKg, 95.6);
    expect(result.single.source, BodyHistorySource.aggregateLegacyDns);
  });

  test('date is missing when neither source has a record', () async {
    final resolver = BodyHistorySourceResolver(
      statusRepository: const _StatusRepository([]),
      dailyAggregateRepository: const _AggregateRepository([]),
    );

    expect(
      await resolver.resolve(startDate: '2026-08-08', endDate: '2026-08-08'),
      isEmpty,
    );
  });

  test('long-range display compression keeps formal summary values', () {
    const points = [
      BodyHistoryDataPoint(
        operationDate: '2026-08-03',
        weightKg: 90,
        bodyFatPercent: null,
        source: BodyHistorySource.status,
      ),
      BodyHistoryDataPoint(
        operationDate: '2026-08-05',
        weightKg: 96,
        bodyFatPercent: null,
        source: BodyHistorySource.status,
      ),
    ];
    final weekly = engine.build(
      source: points,
      metric: BodyHistoryMetric.weight,
      period: BodyHistoryPeriod.oneYear,
      startDate: '2026-08-01',
      endDate: '2026-08-31',
    );
    final monthly = engine.build(
      source: points,
      metric: BodyHistoryMetric.weight,
      period: BodyHistoryPeriod.allTime,
      startDate: '2026-08-01',
      endDate: '2026-08-31',
    );

    expect(weekly.displayBucketDays, 15);
    expect(weekly.points.map((point) => point.value), [96]);
    expect(weekly.points.single.measurementCount, 2);
    expect(weekly.points.single.representativeDate, '2026-08-05');
    expect(weekly.summary?.first, 90);
    expect(weekly.summary?.latest, 96);
    expect(weekly.summary?.maximum, 96);
    expect(weekly.summary?.minimum, 90);
    expect(weekly.summary?.measurementCount, 2);
    expect(monthly.points.map((point) => point.value), [90, 96]);
    expect(
      monthly.points.every((point) => point.measurementCount == 1),
      isTrue,
    );
  });

  test(
    'small changes use the minimum display span instead of a narrow axis',
    () {
      final axis = engine.axisFor(BodyHistoryMetric.weight, const [96.8, 97.2]);

      expect(axis.maximum - axis.minimum, greaterThanOrEqualTo(5));
      expect(axis.minimum, greaterThan(0));
    },
  );

  test('large changes expand the axis range without changing values', () {
    final axis = engine.axisFor(BodyHistoryMetric.weight, const [80, 100]);

    expect(axis.minimum, lessThan(80));
    expect(axis.maximum, greaterThan(100));
    expect(axis.interval, 5);
  });
}

class _StatusRepository implements StatusRepository {
  final List<PersistedStatusRecord> records;

  const _StatusRepository(this.records);

  @override
  Future<StatusReadResult> getRange(String startDate, String endDate) async =>
      StatusReadResult(records: records);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _AggregateRepository implements DailyAggregateRepository {
  final List<DailyAggregateV1> records;

  const _AggregateRepository(this.records);

  @override
  Future<List<DailyAggregateV1>> getRange(
    String startDate,
    String endDate,
  ) async => records;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

PersistedStatusRecord _statusRecord(String date, double weight) =>
    PersistedStatusRecord(
      id: 'status:$date',
      localDate: date,
      createdAt: DateTime.utc(2026, 8, 8),
      updatedAt: DateTime.utc(2026, 8, 8),
      canonicalDate: date,
      recordKind: StatusRecordKind.canonical,
      data: MorningData(
        date: '${date}T07:00:00',
        weight: weight,
        bodyFat: 30,
        sleepHours: 7,
        sleepScore: 80,
        footPain: 0,
        workType: WorkType.holiday,
        workStart: '',
        workEnd: '',
        workBreak: '',
        workHours: 0,
        memo: '',
      ),
    );

DailyAggregateV1 _aggregate(String date, {required double weight}) =>
    DailyAggregateV1(
      operationDate: date,
      weightKg: weight,
      bodyFatPercent: 31,
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
      hydrationMl: 0,
      officialSteps: null,
      measuredSteps: null,
      trainingPerformed: false,
      digestiveCount: null,
      sourceType: DailyAggregateSourceType.legacyDns,
    );
