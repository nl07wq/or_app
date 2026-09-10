import '../models/training_record_read_model.dart';
import 'training_history_domain_service.dart';

/// Presentation-level period choices for the Data Center training overview.
/// They deliberately operate on formal operation dates, not persistence dates.
enum TrainingHistoryOverviewPeriod {
  oneWeek('1 WEEK'),
  oneMonth('1 MONTH'),
  threeMonths('3 MONTHS'),
  sixMonths('6 MONTHS'),
  oneYear('1 YEAR'),
  all('ALL');

  const TrainingHistoryOverviewPeriod(this.label);

  final String label;
}

class TrainingHistoryOverviewPoint {
  const TrainingHistoryOverviewPoint({
    required this.date,
    required this.recordedVolume,
    required this.recordedReps,
    required this.recordedSetCount,
  });

  final DateTime date;
  final double recordedVolume;
  final int recordedReps;
  final int recordedSetCount;
}

class TrainingHistoryFrequencyPoint {
  const TrainingHistoryFrequencyPoint({
    required this.weekStart,
    required this.sessions,
  });

  final DateTime weekStart;
  final int sessions;
}

class TrainingHistoryOverview {
  const TrainingHistoryOverview({
    required this.points,
    required this.frequencyPoints,
    required this.sessionCount,
    required this.trainingDays,
    required this.recordedVolume,
    required this.recordedReps,
  });

  final List<TrainingHistoryOverviewPoint> points;
  final List<TrainingHistoryFrequencyPoint> frequencyPoints;
  final int sessionCount;
  final int trainingDays;
  final double recordedVolume;
  final int recordedReps;

  bool get isEmpty => points.isEmpty;
}

/// Converts shared domain aggregates into chronological, period-aware UI data.
/// It contains no training metric formulas; those remain in
/// [TrainingHistoryDomainService].
class TrainingHistoryOverviewAdapter {
  const TrainingHistoryOverviewAdapter({
    this.domainService = const TrainingHistoryDomainService(),
  });

  final TrainingHistoryDomainService domainService;

  bool includesOperationDate(
    String operationDate, {
    required TrainingHistoryOverviewPeriod period,
    DateTime? referenceDate,
  }) {
    final now = referenceDate ?? DateTime.now();
    final end = DateTime(now.year, now.month, now.day);
    final start = _startFor(period, end);
    return start == null || !_parseLocalDate(operationDate).isBefore(start);
  }

  TrainingHistoryOverview build(
    Iterable<TrainingRecordReadModel> records, {
    required TrainingHistoryOverviewPeriod period,
    DateTime? referenceDate,
  }) {
    final aggregates = [
      for (final record in records)
        if (record.strengthTrainingPerformed)
          domainService.sessionAggregate(record),
    ]..sort((a, b) => a.operationDate.compareTo(b.operationDate));
    if (aggregates.isEmpty) return _empty();

    final now = referenceDate ?? DateTime.now();
    final end = DateTime(now.year, now.month, now.day);
    final start = _startFor(period, end);
    final selected = [
      for (final aggregate in aggregates)
        if (start == null ||
            !_parseLocalDate(aggregate.operationDate).isBefore(start))
          aggregate,
    ];
    if (selected.isEmpty) return _empty();
    final points = [
      for (final aggregate in selected)
        TrainingHistoryOverviewPoint(
          date: _parseLocalDate(aggregate.operationDate),
          recordedVolume: aggregate.recordedVolume,
          recordedReps: aggregate.recordedReps,
          recordedSetCount: aggregate.recordedSetCount,
        ),
    ];
    final days = <String>{
      for (final aggregate in selected) aggregate.operationDate,
    };
    return TrainingHistoryOverview(
      points: List.unmodifiable(points),
      frequencyPoints: List.unmodifiable(
        _frequency(
          selected,
          rangeStart: start ?? _parseLocalDate(selected.first.operationDate),
          rangeEnd: period == TrainingHistoryOverviewPeriod.all
              ? _parseLocalDate(selected.last.operationDate)
              : end,
        ),
      ),
      sessionCount: selected.length,
      trainingDays: days.length,
      recordedVolume: selected.fold<double>(
        0,
        (sum, aggregate) => sum + aggregate.recordedVolume,
      ),
      recordedReps: selected.fold<int>(
        0,
        (sum, aggregate) => sum + aggregate.recordedReps,
      ),
    );
  }

  TrainingHistoryOverview _empty() => const TrainingHistoryOverview(
    points: [],
    frequencyPoints: [],
    sessionCount: 0,
    trainingDays: 0,
    recordedVolume: 0,
    recordedReps: 0,
  );

  DateTime? _startFor(TrainingHistoryOverviewPeriod period, DateTime end) =>
      switch (period) {
        TrainingHistoryOverviewPeriod.oneWeek => end.subtract(
          const Duration(days: 6),
        ),
        TrainingHistoryOverviewPeriod.oneMonth => _monthsBefore(end, 1),
        TrainingHistoryOverviewPeriod.threeMonths => _monthsBefore(end, 3),
        TrainingHistoryOverviewPeriod.sixMonths => _monthsBefore(end, 6),
        TrainingHistoryOverviewPeriod.oneYear => _yearsBefore(end, 1),
        TrainingHistoryOverviewPeriod.all => null,
      };

  List<TrainingHistoryFrequencyPoint> _frequency(
    Iterable<TrainingSessionAggregate> aggregates, {
    required DateTime rangeStart,
    required DateTime rangeEnd,
  }) {
    final counts = <DateTime, int>{};
    for (final aggregate in aggregates) {
      final week = _mondayFor(_parseLocalDate(aggregate.operationDate));
      counts[week] = (counts[week] ?? 0) + 1;
    }
    final firstWeek = _mondayFor(rangeStart);
    final finalWeek = _mondayFor(rangeEnd);
    final weeks = <DateTime>[];
    for (
      var week = firstWeek;
      !week.isAfter(finalWeek);
      week = week.add(const Duration(days: 7))
    ) {
      weeks.add(week);
    }
    return [
      for (final week in weeks)
        TrainingHistoryFrequencyPoint(
          weekStart: week,
          sessions: counts[week] ?? 0,
        ),
    ];
  }

  DateTime _mondayFor(DateTime date) =>
      date.subtract(Duration(days: date.weekday - DateTime.monday));

  DateTime _monthsBefore(DateTime date, int months) {
    final firstOfFollowingMonth = DateTime(date.year, date.month - months + 1);
    final lastDay = firstOfFollowingMonth.subtract(const Duration(days: 1)).day;
    return DateTime(date.year, date.month - months, date.day.clamp(1, lastDay));
  }

  DateTime _yearsBefore(DateTime date, int years) {
    final year = date.year - years;
    final lastDay = DateTime(year, date.month + 1, 0).day;
    return DateTime(year, date.month, date.day.clamp(1, lastDay));
  }

  DateTime _parseLocalDate(String value) {
    final parsed = DateTime.parse(value);
    return DateTime(parsed.year, parsed.month, parsed.day);
  }
}
