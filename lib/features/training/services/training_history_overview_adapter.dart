import '../models/training_record_read_model.dart';
import 'training_history_domain_service.dart';

/// Presentation-level period choices for the Data Center training overview.
/// They deliberately operate on formal operation dates, not persistence dates.
enum TrainingHistoryOverviewPeriod {
  recent('RECENT'),
  oneMonth('1 MONTH'),
  threeMonths('3 MONTHS'),
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

  static const recentDays = 28;

  final TrainingHistoryDomainService domainService;

  TrainingHistoryOverview build(
    Iterable<TrainingRecordReadModel> records, {
    required TrainingHistoryOverviewPeriod period,
    DateTime? referenceDate,
  }) {
    final aggregates = [
      for (final record in records) domainService.sessionAggregate(record),
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
      frequencyPoints: List.unmodifiable(_frequency(selected)),
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
        TrainingHistoryOverviewPeriod.recent => end.subtract(
          const Duration(days: recentDays - 1),
        ),
        TrainingHistoryOverviewPeriod.oneMonth => end.subtract(
          const Duration(days: 29),
        ),
        TrainingHistoryOverviewPeriod.threeMonths => end.subtract(
          const Duration(days: 89),
        ),
        TrainingHistoryOverviewPeriod.all => null,
      };

  List<TrainingHistoryFrequencyPoint> _frequency(
    Iterable<TrainingSessionAggregate> aggregates,
  ) {
    final counts = <DateTime, int>{};
    for (final aggregate in aggregates) {
      final week = _mondayFor(_parseLocalDate(aggregate.operationDate));
      counts[week] = (counts[week] ?? 0) + 1;
    }
    final weeks = counts.keys.toList()..sort();
    return [
      for (final week in weeks)
        TrainingHistoryFrequencyPoint(weekStart: week, sessions: counts[week]!),
    ];
  }

  DateTime _mondayFor(DateTime date) =>
      date.subtract(Duration(days: date.weekday - DateTime.monday));

  DateTime _parseLocalDate(String value) {
    final parsed = DateTime.parse(value);
    return DateTime(parsed.year, parsed.month, parsed.day);
  }
}
