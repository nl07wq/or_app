enum ActivityHistoryDayState {
  measured,
  measuredZero,
  notMeasured,
  outsideObservation,
}

enum ActivityHistorySource {
  currentActivity,
  aggregateRecords,
  aggregateLegacyDns,
  none,
}

enum ActivityHistoryQuality { full, partial, unknown, invalid }

class ActivityHistoryDaySummary {
  const ActivityHistoryDaySummary({
    required this.operationDate,
    required this.state,
    required this.source,
    required this.quality,
    required this.observationEligible,
    this.steps,
  });

  final String operationDate;
  final ActivityHistoryDayState state;
  final ActivityHistorySource source;
  final ActivityHistoryQuality quality;
  final bool observationEligible;
  final int? steps;

  bool get isMeasured =>
      state == ActivityHistoryDayState.measured ||
      state == ActivityHistoryDayState.measuredZero;
}

class ActivityHistoryPeriodSummary {
  const ActivityHistoryPeriodSummary({
    required this.days,
    required this.calendarDays,
    required this.observationDays,
    required this.outsideObservationDays,
    required this.measuredDays,
    required this.unmeasuredDays,
    required this.totalSteps,
    required this.averageMeasuredSteps,
    required this.maximumSteps,
    required this.minimumSteps,
    required this.latestMeasuredSteps,
  });

  final List<ActivityHistoryDaySummary> days;
  final int calendarDays;
  final int observationDays;
  final int outsideObservationDays;
  final int measuredDays;
  final int unmeasuredDays;
  final int totalSteps;
  final double? averageMeasuredSteps;
  final int? maximumSteps;
  final int? minimumSteps;
  final int? latestMeasuredSteps;

  double get measurementCoverage =>
      observationDays == 0 ? 0 : measuredDays / observationDays;
}

class ActivityHistoryBucket {
  const ActivityHistoryBucket({
    required this.startDate,
    required this.endDate,
    required this.summary,
  });

  final String startDate;
  final String endDate;
  final ActivityHistoryPeriodSummary summary;
}
