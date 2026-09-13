import '../../../core/models/activity_data.dart';
import '../../activity/repository/activity_repository.dart';
import '../../daily_aggregate/models/daily_aggregate_v1.dart';
import '../../daily_aggregate/repository/daily_aggregate_repository.dart';
import '../models/activity_history_models.dart';

/// Read-only, one-source-per-date resolver for historical official Steps.
/// Activity is canonical; Daily Aggregate is a compatibility fallback only.
class ActivityHistorySourceResolver {
  ActivityHistorySourceResolver({
    required this.activityRepository,
    required this.dailyAggregateRepository,
  });

  final ActivityRepository activityRepository;
  final DailyAggregateRepository dailyAggregateRepository;

  Future<List<ActivityHistoryDaySummary>> resolve({
    required String startDate,
    required String endDate,
  }) async {
    try {
      final loaded = await Future.wait<Object>([
        activityRepository.findAll(),
        dailyAggregateRepository.getRange(startDate, endDate),
      ]);
      return _resolveLoaded(
        startDate,
        endDate,
        loaded[0] as List<ActivityData>,
        loaded[1] as List<DailyAggregateV1>,
      );
    } catch (_) {
      return List.unmodifiable([
        for (final date in _dates(startDate, endDate))
          ActivityHistoryDaySummary(
            operationDate: date,
            state: ActivityHistoryDayState.outsideObservation,
            source: ActivityHistorySource.none,
            quality: ActivityHistoryQuality.invalid,
            observationEligible: false,
          ),
      ]);
    }
  }

  Future<List<ActivityHistoryDaySummary>> resolveAvailableThrough(
    String endDate,
  ) async {
    try {
      final loaded = await Future.wait<Object>([
        activityRepository.findAll(),
        dailyAggregateRepository.getRange('0001-01-01', endDate),
      ]);
      final activities = loaded[0] as List<ActivityData>;
      final aggregates = loaded[1] as List<DailyAggregateV1>;
      final candidates = <String>[
        for (final activity in activities) _date(activity.date),
        for (final aggregate in aggregates)
          if (aggregate.officialSteps != null) aggregate.operationDate,
      ].where((date) => date.compareTo(endDate) <= 0).toList()..sort();
      if (candidates.isEmpty) return const [];
      return _resolveLoaded(candidates.first, endDate, activities, aggregates);
    } catch (_) {
      return const [];
    }
  }

  List<ActivityHistoryDaySummary> _resolveLoaded(
    String startDate,
    String endDate,
    List<ActivityData> activities,
    List<DailyAggregateV1> aggregates,
  ) {
    final activityByDate = <String, ActivityData>{
      for (final activity in activities) _date(activity.date): activity,
    };
    final aggregateByDate = <String, DailyAggregateV1>{
      for (final aggregate in aggregates) aggregate.operationDate: aggregate,
    };
    // stepsEntered is the current Formal recording contract. Its first
    // available Activity record establishes when continuous measurement can
    // legitimately be evaluated. Historical DNS aggregates are direct,
    // date-specific formal facts: they are eligible on their own dates, but
    // do not turn unrepresented dates between sparse imports into misses.
    final observationStarts = activityByDate.keys.toList()..sort();
    final observationStart = observationStarts.isEmpty
        ? null
        : observationStarts.first;
    return List.unmodifiable([
      for (final date in _dates(startDate, endDate))
        _resolveDate(
          date,
          activity: activityByDate[date],
          previousActivity:
              activityByDate[_date(
                DateTime.parse(date).subtract(const Duration(days: 1)),
              )],
          aggregate: aggregateByDate[date],
          observationEligible:
              (observationStart != null &&
                  date.compareTo(observationStart) >= 0) ||
              aggregateByDate[date]?.officialSteps != null,
        ),
    ]);
  }

  ActivityHistoryDaySummary _resolveDate(
    String date, {
    required ActivityData? activity,
    required ActivityData? previousActivity,
    required DailyAggregateV1? aggregate,
    required bool observationEligible,
  }) {
    if (activity?.stepsEntered == true) {
      try {
        final steps =
            activity!.officialSteps ??
            activity.officialStepsFor(
              previousActivity?.carryOverEntered == true
                  ? previousActivity!.carryOver
                  : 0,
            );
        return ActivityHistoryDaySummary(
          operationDate: date,
          state: steps == 0
              ? ActivityHistoryDayState.measuredZero
              : ActivityHistoryDayState.measured,
          source: ActivityHistorySource.currentActivity,
          quality: ActivityHistoryQuality.full,
          observationEligible: observationEligible,
          steps: steps,
        );
      } catch (_) {
        return ActivityHistoryDaySummary(
          operationDate: date,
          state: observationEligible
              ? ActivityHistoryDayState.notMeasured
              : ActivityHistoryDayState.outsideObservation,
          source: ActivityHistorySource.currentActivity,
          quality: ActivityHistoryQuality.invalid,
          observationEligible: observationEligible,
        );
      }
    }
    if (aggregate?.officialSteps case final steps?) {
      return ActivityHistoryDaySummary(
        operationDate: date,
        state: steps == 0
            ? ActivityHistoryDayState.measuredZero
            : ActivityHistoryDayState.measured,
        source: aggregate!.sourceType == DailyAggregateSourceType.legacyDns
            ? ActivityHistorySource.aggregateLegacyDns
            : ActivityHistorySource.aggregateRecords,
        quality: ActivityHistoryQuality.partial,
        observationEligible: observationEligible,
        steps: steps,
      );
    }
    return ActivityHistoryDaySummary(
      operationDate: date,
      state: observationEligible
          ? ActivityHistoryDayState.notMeasured
          : ActivityHistoryDayState.outsideObservation,
      source: activity == null
          ? ActivityHistorySource.none
          : ActivityHistorySource.currentActivity,
      quality: ActivityHistoryQuality.unknown,
      observationEligible: observationEligible,
    );
  }

  static Iterable<String> _dates(String startDate, String endDate) sync* {
    var value = DateTime.parse(startDate);
    final end = DateTime.parse(endDate);
    while (!value.isAfter(end)) {
      yield _date(value);
      value = DateTime(value.year, value.month, value.day + 1);
    }
  }

  static String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}
