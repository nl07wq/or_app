import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/models/morning_data.dart';
import 'package:or_app/core/models/work_type.dart';
import 'package:or_app/features/daily_aggregate/models/daily_aggregate_v1.dart';
import 'package:or_app/features/daily_aggregate/repository/daily_aggregate_repository.dart';
import 'package:or_app/features/sleep_history/models/sleep_history_models.dart';
import 'package:or_app/features/sleep_history/services/sleep_history_source_resolver.dart';
import 'package:or_app/features/status/models/persisted_status_record.dart';
import 'package:or_app/features/status/repositories/status_repository.dart';

void main() {
  test(
    'current Status wins while aggregate fills only an absent Sleep fact',
    () async {
      final resolver = SleepHistorySourceResolver(
        statusRepository: _StatusRepository([
          _status('2026-09-12', hours: 7.5, score: null),
        ]),
        dailyAggregateRepository: _AggregateRepository([
          _aggregate('2026-09-12', 480, 84),
        ]),
      );
      final day = (await resolver.resolve(
        startDate: '2026-09-12',
        endDate: '2026-09-12',
      )).single;
      expect(day.durationMinutes, 450);
      expect(day.durationSource, SleepHistorySource.currentStatus);
      expect(day.score, 84);
      expect(day.scoreSource, SleepHistorySource.aggregateLegacyDns);
    },
  );

  test(
    'zero duration is unavailable while zero score remains a valid Formal score',
    () async {
      final resolver = SleepHistorySourceResolver(
        statusRepository: _StatusRepository([
          _status('2026-09-12', hours: 0, score: 0),
        ]),
        dailyAggregateRepository: const _AggregateRepository([]),
      );
      final day = (await resolver.resolve(
        startDate: '2026-09-12',
        endDate: '2026-09-12',
      )).single;
      expect(day.durationMinutes, isNull);
      expect(day.score, 0);
      expect(day.scoreSource, SleepHistorySource.currentStatus);
    },
  );
}

class _StatusRepository implements StatusRepository {
  const _StatusRepository(this.records);
  final List<PersistedStatusRecord> records;
  @override
  Future<StatusReadResult> getRange(String startDate, String endDate) async =>
      StatusReadResult(records: records);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _AggregateRepository implements DailyAggregateRepository {
  const _AggregateRepository(this.records);
  final List<DailyAggregateV1> records;
  @override
  Future<List<DailyAggregateV1>> getRange(
    String startDate,
    String endDate,
  ) async => records;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

PersistedStatusRecord _status(
  String date, {
  required double hours,
  required int? score,
}) => PersistedStatusRecord(
  id: 'status:$date',
  localDate: date,
  createdAt: DateTime.utc(2026, 9, 12),
  updatedAt: DateTime.utc(2026, 9, 12),
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

DailyAggregateV1 _aggregate(String date, int duration, int score) =>
    DailyAggregateV1(
      operationDate: date,
      weightKg: null,
      bodyFatPercent: null,
      sleepDurationMinutes: duration,
      sleepScore: score,
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
      digestiveCount: null,
      sourceType: DailyAggregateSourceType.legacyDns,
    );
