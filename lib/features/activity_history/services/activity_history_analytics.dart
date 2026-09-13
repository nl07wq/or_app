import '../models/activity_history_models.dart';

class ActivityHistoryAnalytics {
  const ActivityHistoryAnalytics();

  ActivityHistoryPeriodSummary summarize(List<ActivityHistoryDaySummary> days) {
    final ordered = [...days]
      ..sort((a, b) => a.operationDate.compareTo(b.operationDate));
    final eligible = ordered.where((day) => day.observationEligible).toList();
    final measured = eligible
        .where((day) => day.isMeasured && day.steps != null)
        .toList();
    final values = measured.map((day) => day.steps!).toList();
    return ActivityHistoryPeriodSummary(
      days: List.unmodifiable(ordered),
      calendarDays: ordered.length,
      observationDays: eligible.length,
      outsideObservationDays: ordered.length - eligible.length,
      measuredDays: measured.length,
      unmeasuredDays: eligible.where((day) => !day.isMeasured).length,
      totalSteps: values.fold(0, (sum, value) => sum + value),
      averageMeasuredSteps: values.isEmpty
          ? null
          : values.fold(0, (sum, value) => sum + value) / values.length,
      maximumSteps: values.isEmpty
          ? null
          : values.reduce((a, b) => a > b ? a : b),
      minimumSteps: values.isEmpty
          ? null
          : values.reduce((a, b) => a < b ? a : b),
      latestMeasuredSteps: values.isEmpty ? null : values.last,
    );
  }
}
