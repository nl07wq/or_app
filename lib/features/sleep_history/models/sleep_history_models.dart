enum SleepHistorySource {
  currentStatus,
  aggregateRecords,
  aggregateLegacyDns,
  none,
}

class SleepHistoryDay {
  const SleepHistoryDay({
    required this.operationDate,
    required this.durationMinutes,
    required this.score,
    required this.durationSource,
    required this.scoreSource,
  });

  final String operationDate;
  final int? durationMinutes;
  final int? score;
  final SleepHistorySource durationSource;
  final SleepHistorySource scoreSource;

  bool get hasDuration => durationMinutes != null;
  bool get hasScore => score != null;
  bool get observed => hasDuration || hasScore;
}

enum SleepHistoryMetric {
  duration('睡眠時間'),
  score('スコア');

  const SleepHistoryMetric(this.label);
  final String label;
}

class SleepHistorySummary {
  const SleepHistorySummary({
    required this.days,
    required this.durationDays,
    required this.scoreDays,
    required this.averageDurationMinutes,
    required this.averageScore,
    required this.longestDurationMinutes,
    required this.highestScore,
    required this.latestDurationMinutes,
    required this.latestScore,
  });

  final List<SleepHistoryDay> days;
  final int durationDays;
  final int scoreDays;
  final double? averageDurationMinutes;
  final double? averageScore;
  final int? longestDurationMinutes;
  final int? highestScore;
  final int? latestDurationMinutes;
  final int? latestScore;

  int get observedDays => days.where((day) => day.observed).length;
}
