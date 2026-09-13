import '../../../core/models/activity_data.dart';
import '../../../core/models/bowel_movement_record.dart';
import '../../activity/repository/activity_repository.dart';
import '../../daily_aggregate/models/daily_aggregate_v1.dart';
import '../../daily_aggregate/repository/daily_aggregate_repository.dart';
import '../models/digestive_history_models.dart';

/// Resolves exactly one formal Digestive source per operation date.
///
/// Activity event lists are authoritative. Legacy sources are fallbacks only;
/// their facts are never merged with an Activity date.
class DigestiveHistorySourceResolver {
  DigestiveHistorySourceResolver({
    required this.activityRepository,
    required this.dailyAggregateRepository,
  });

  final ActivityRepository activityRepository;
  final DailyAggregateRepository dailyAggregateRepository;

  Future<List<DigestiveDaySummary>> resolve({
    required String startDate,
    required String endDate,
  }) async {
    try {
      final results = await Future.wait<Object>([
        activityRepository.findAll(),
        dailyAggregateRepository.getRange(startDate, endDate),
      ]);
      final activities = results[0] as List<ActivityData>;
      final aggregates = results[1] as List<DailyAggregateV1>;
      return _resolveLoaded(startDate, endDate, activities, aggregates);
    } catch (_) {
      return List.unmodifiable([
        for (final date in _dates(startDate, endDate))
          DigestiveDaySummary(
            operationDate: date,
            state: DigestiveDayState.unknown,
            source: DigestiveHistorySource.none,
            quality: DigestiveDataQuality.invalid,
            countKnown: false,
          ),
      ]);
    }
  }

  /// Resolves from the first available formal Digestive date through [endDate].
  /// This avoids fabricating a multi-decade zero/unknown history for ALL.
  Future<List<DigestiveDaySummary>> resolveAvailableThrough(
    String endDate,
  ) async {
    try {
      final results = await Future.wait<Object>([
        activityRepository.findAll(),
        dailyAggregateRepository.getRange('0001-01-01', endDate),
      ]);
      final activities = results[0] as List<ActivityData>;
      final aggregates = results[1] as List<DailyAggregateV1>;
      final dates = <String>[
        for (final activity in activities) _date(activity.date),
        for (final aggregate in aggregates) aggregate.operationDate,
      ].where((date) => date.compareTo(endDate) <= 0).toList()
        ..sort();
      if (dates.isEmpty) return const [];
      return _resolveLoaded(dates.first, endDate, activities, aggregates);
    } catch (_) {
      return const [];
    }
  }

  List<DigestiveDaySummary> _resolveLoaded(
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
    return List.unmodifiable([
      for (final date in _dates(startDate, endDate))
        _resolveDate(date, activityByDate[date], aggregateByDate[date]),
    ]);
  }

  DigestiveDaySummary _resolveDate(
    String date,
    ActivityData? activity,
    DailyAggregateV1? aggregate,
  ) {
    if (activity?.digestiveEvents case final events?) {
      final movements = events.where((event) => event.amount > 0).toList();
      return DigestiveDaySummary(
        operationDate: date,
        state: movements.isEmpty
            ? DigestiveDayState.confirmedNo
            : DigestiveDayState.yes,
        source: DigestiveHistorySource.currentActivity,
        quality: DigestiveDataQuality.full,
        countKnown: true,
        exactCount: movements.length,
        events: List.unmodifiable([
          for (final event in movements)
            DigestiveEventSummary(
              sequence: event.sequence,
              amount: event.amount,
              shape: event.shape,
              relief: event.relief,
            ),
        ]),
      );
    }

    final legacyBowel = activity?.bowelMovement;
    if (legacyBowel?.status == BowelMovementStatus.none) {
      return DigestiveDaySummary(
        operationDate: date,
        state: DigestiveDayState.confirmedNo,
        source: DigestiveHistorySource.legacyActivity,
        quality: DigestiveDataQuality.partial,
        countKnown: false,
      );
    }
    if (legacyBowel?.status == BowelMovementStatus.recorded) {
      return DigestiveDaySummary(
        operationDate: date,
        state: DigestiveDayState.yes,
        source: DigestiveHistorySource.legacyActivity,
        quality: DigestiveDataQuality.partial,
        countKnown: false,
      );
    }

    if (aggregate != null &&
        (aggregate.digestiveCount != null ||
            aggregate.digestiveEvents.isNotEmpty)) {
      final movements = aggregate.digestiveEvents
          .where((event) => event.amount > 0)
          .toList();
      final count = aggregate.digestiveCount ?? movements.length;
      return DigestiveDaySummary(
        operationDate: date,
        state: count == 0
            ? DigestiveDayState.confirmedNo
            : DigestiveDayState.yes,
        source: DigestiveHistorySource.dailyAggregate,
        quality: DigestiveDataQuality.partial,
        countKnown: true,
        exactCount: count,
        events: List.unmodifiable([
          for (final event in movements)
            DigestiveEventSummary(
              amount: event.amount,
              shape: event.shape,
              relief: event.relief,
            ),
        ]),
      );
    }

    return DigestiveDaySummary(
      operationDate: date,
      state: DigestiveDayState.unknown,
      source: DigestiveHistorySource.none,
      quality: DigestiveDataQuality.unknown,
      countKnown: false,
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
