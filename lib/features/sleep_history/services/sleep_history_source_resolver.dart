import '../../daily_aggregate/models/daily_aggregate_v1.dart';
import '../../daily_aggregate/repository/daily_aggregate_repository.dart';
import '../../status/repositories/status_repository.dart';
import '../models/sleep_history_models.dart';

/// Resolves each Sleep fact independently: current canonical STATUS wins for
/// the fact it contains; Aggregate/DNS fills only a missing compatible fact.
class SleepHistorySourceResolver {
  const SleepHistorySourceResolver({
    required this.statusRepository,
    required this.dailyAggregateRepository,
  });

  final StatusRepository statusRepository;
  final DailyAggregateRepository dailyAggregateRepository;

  Future<List<SleepHistoryDay>> resolve({
    required String startDate,
    required String endDate,
  }) async {
    final statuses = await statusRepository.getRange(startDate, endDate);
    final aggregates = await dailyAggregateRepository.getRange(
      startDate,
      endDate,
    );
    final statusByDate = {
      for (final record in statuses.records) record.localDate: record,
    };
    final aggregateByDate = {
      for (final record in aggregates) record.operationDate: record,
    };
    final values = <SleepHistoryDay>[];
    for (
      var date = DateTime.parse(startDate);
      !date.isAfter(DateTime.parse(endDate));
      date = date.add(const Duration(days: 1))
    ) {
      final key = _date(date);
      final status = statusByDate[key];
      final aggregate = aggregateByDate[key];
      final statusDuration = _durationFromHours(status?.data.sleepHours);
      final aggregateDuration = _durationFromAggregate(aggregate);
      final statusScore = _score(status?.data.sleepScore);
      final aggregateScore = _score(aggregate?.sleepScore);
      values.add(
        SleepHistoryDay(
          operationDate: key,
          durationMinutes: statusDuration ?? aggregateDuration,
          score: statusScore ?? aggregateScore,
          durationSource: statusDuration != null
              ? SleepHistorySource.currentStatus
              : aggregateDuration != null
              ? _aggregateSource(aggregate)
              : SleepHistorySource.none,
          scoreSource: statusScore != null
              ? SleepHistorySource.currentStatus
              : aggregateScore != null
              ? _aggregateSource(aggregate)
              : SleepHistorySource.none,
        ),
      );
    }
    return List.unmodifiable(values);
  }

  static int? _durationFromHours(double? value) {
    if (value == null || value <= 0) return null;
    return (value * 60).round();
  }

  static int? _durationFromAggregate(DailyAggregateV1? value) {
    final minutes = value?.sleepDurationMinutes;
    return minutes == null || minutes <= 0 ? null : minutes;
  }

  static int? _score(int? value) =>
      value != null && value >= 0 && value <= 100 ? value : null;

  static SleepHistorySource _aggregateSource(DailyAggregateV1? value) =>
      value?.sourceType == DailyAggregateSourceType.legacyDns
      ? SleepHistorySource.aggregateLegacyDns
      : SleepHistorySource.aggregateRecords;

  static String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}
