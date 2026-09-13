enum DigestiveDayState { yes, confirmedNo, unknown }

enum DigestiveHistorySource {
  currentActivity,
  legacyActivity,
  dailyAggregate,
  none,
}

enum DigestiveDataQuality { full, partial, unknown, invalid }

class DigestiveEventSummary {
  const DigestiveEventSummary({
    this.sequence,
    required this.amount,
    this.shape,
    this.relief,
  });

  /// Present only when the formal source supplies a stable event sequence.
  final int? sequence;
  final int? amount;
  final int? shape;
  final int? relief;
}

class DigestiveDaySummary {
  const DigestiveDaySummary({
    required this.operationDate,
    required this.state,
    required this.source,
    required this.quality,
    required this.countKnown,
    this.exactCount,
    this.events = const [],
  });

  final String operationDate;
  final DigestiveDayState state;
  final DigestiveHistorySource source;
  final DigestiveDataQuality quality;
  final bool countKnown;
  final int? exactCount;
  final List<DigestiveEventSummary> events;

  bool get isKnown => state != DigestiveDayState.unknown;
}

class DigestiveDistribution {
  const DigestiveDistribution({
    required this.knownCounts,
    required this.missingCount,
  });

  final Map<int, int> knownCounts;
  final int missingCount;

  int get knownTotal => knownCounts.values.fold(0, (sum, value) => sum + value);
}

class DigestivePeriodSummary {
  const DigestivePeriodSummary({
    required this.days,
    required this.calendarDays,
    required this.knownDays,
    required this.yesDays,
    required this.confirmedNoDays,
    required this.unknownDays,
    required this.invalidDays,
    required this.exactCountDays,
    required this.totalExactEvents,
    required this.maximumDailyExactCount,
    required this.averagePerExactCountDay,
    required this.averagePerYesExactCountDay,
    required this.currentConfirmedNoStreak,
    required this.longestConfirmedNoStreak,
    required this.latestConfirmedBmDate,
    required this.daysSinceLatestConfirmedBmDate,
    required this.amountDistribution,
    required this.formDistribution,
    required this.reliefDistribution,
  });

  final List<DigestiveDaySummary> days;
  final int calendarDays;
  final int knownDays;
  final int yesDays;
  final int confirmedNoDays;
  final int unknownDays;
  final int invalidDays;
  final int exactCountDays;
  final int totalExactEvents;
  final int? maximumDailyExactCount;
  final double? averagePerExactCountDay;
  final double? averagePerYesExactCountDay;
  final int currentConfirmedNoStreak;
  final int longestConfirmedNoStreak;
  final String? latestConfirmedBmDate;
  final int? daysSinceLatestConfirmedBmDate;
  final DigestiveDistribution amountDistribution;
  final DigestiveDistribution formDistribution;
  final DigestiveDistribution reliefDistribution;

  double get recordingCoverage =>
      calendarDays == 0 ? 0 : knownDays / calendarDays;
}

class DigestiveHistoryBucket {
  const DigestiveHistoryBucket({
    required this.startDate,
    required this.endDate,
    required this.summary,
  });

  final String startDate;
  final String endDate;
  final DigestivePeriodSummary summary;
}
