import 'dart:math' as math;

import '../../../core/models/operation_calendar_period.dart';

import '../models/body_history_models.dart';

class BodyHistoryChartEngine {
  static const int maximumDisplayPointsCandidate = 120;
  static const double maximumChartWidthCandidate = 3600;
  static const double pointSpacingCandidate = 24;
  static const double minimumWeightDisplaySpanCandidate = 5;
  static const double minimumBodyFatDisplaySpanCandidate = 5;

  const BodyHistoryChartEngine();

  BodyHistoryChartModel build({
    required List<BodyHistoryDataPoint> source,
    required BodyHistoryMetric metric,
    required BodyHistoryPeriod period,
    required String startDate,
    required String endDate,
    double availablePlotWidth = maximumChartWidthCandidate,
  }) {
    final observations = [
      for (final point in source)
        if (point.valueFor(metric) case final value?)
          if (value.isFinite) (date: _parse(point.operationDate), value: value),
    ]..sort((a, b) => a.date.compareTo(b.date));
    final granularity = _selectGranularity(
      observations: observations,
      availablePlotWidth: availablePlotWidth,
    );
    if (observations.isEmpty) {
      return BodyHistoryChartModel(
        metric: metric,
        granularity: granularity,
        startDate: startDate,
        endDate: endDate,
        points: const [],
        segments: const [],
        summary: null,
        axis: null,
      );
    }
    final displayPoints = _aggregate(observations, granularity);
    final values = observations.map((item) => item.value).toList();
    final summary = BodyHistorySummary(
      first: values.first,
      latest: values.last,
      change: values.last - values.first,
      maximum: values.reduce(math.max),
      minimum: values.reduce(math.min),
      measurementCount: values.length,
    );
    return BodyHistoryChartModel(
      metric: metric,
      granularity: granularity,
      startDate: displayPoints.first.startDate,
      endDate: displayPoints.last.startDate,
      points: displayPoints,
      segments: _segments(displayPoints, granularity),
      summary: summary,
      axis: axisFor(metric, values),
    );
  }

  BodyHistoryAxisRange axisFor(BodyHistoryMetric metric, List<double> values) {
    if (values.isEmpty) throw ArgumentError('values must not be empty.');
    var minimum = values.reduce(math.min);
    var maximum = values.reduce(math.max);
    final minimumSpan = metric == BodyHistoryMetric.weight
        ? minimumWeightDisplaySpanCandidate
        : minimumBodyFatDisplaySpanCandidate;
    if (maximum - minimum < minimumSpan) {
      final center = (minimum + maximum) / 2;
      minimum = center - minimumSpan / 2;
      maximum = center + minimumSpan / 2;
    }
    final interval = metric == BodyHistoryMetric.weight
        ? _weightInterval(maximum - minimum)
        : _bodyFatInterval(maximum - minimum);
    final lower = (minimum / interval).floorToDouble() * interval - interval;
    final upper = (maximum / interval).ceilToDouble() * interval + interval;
    return BodyHistoryAxisRange(
      minimum: lower,
      maximum: upper,
      interval: interval,
    );
  }

  double chartWidth({
    required int pointCount,
    required double availableWidth,
  }) => math.max(
    availableWidth,
    math.min(maximumChartWidthCandidate, pointCount * pointSpacingCandidate),
  );

  static double _weightInterval(double span) {
    if (span <= 2) return 0.5;
    if (span <= 5) return 1;
    if (span <= 15) return 2.5;
    if (span <= 30) return 5;
    return 10;
  }

  static double _bodyFatInterval(double span) {
    if (span <= 2) return 0.5;
    if (span <= 5) return 1;
    if (span <= 10) return 2;
    return 5;
  }

  static BodyHistoryGranularity _selectGranularity({
    required List<({DateTime date, double value})> observations,
    required double availablePlotWidth,
  }) {
    if (_fitsDensity(observations.length, availablePlotWidth)) {
      return BodyHistoryGranularity.daily;
    }
    final weeks = {
      for (final item in observations)
        OperationCalendarPeriod.week(item.date).start,
    }.length;
    if (_fitsDensity(weeks, availablePlotWidth)) {
      return BodyHistoryGranularity.weekly;
    }
    return BodyHistoryGranularity.monthly;
  }

  static bool _fitsDensity(int pointCount, double availablePlotWidth) =>
      pointCount * pointSpacingCandidate <=
      math.max(availablePlotWidth, maximumChartWidthCandidate);

  static List<BodyHistoryDisplayPoint> _aggregate(
    List<({DateTime date, double value})> observations,
    BodyHistoryGranularity granularity,
  ) {
    final groups = <DateTime, List<({DateTime date, double value})>>{};
    for (final item in observations) {
      final start = switch (granularity) {
        BodyHistoryGranularity.daily => item.date,
        BodyHistoryGranularity.weekly => OperationCalendarPeriod.week(
          item.date,
        ).start,
        BodyHistoryGranularity.monthly => DateTime.utc(
          item.date.year,
          item.date.month,
        ),
      };
      groups.putIfAbsent(start, () => []).add(item);
    }
    final starts = groups.keys.toList()..sort();
    final viewportStart = starts.first;
    return [
      for (final start in starts)
        BodyHistoryDisplayPoint(
          x: start.difference(viewportStart).inDays.toDouble(),
          value:
              groups[start]!.map((item) => item.value).reduce((a, b) => a + b) /
              groups[start]!.length,
          startDate: _format(start),
          endDate: _format(switch (granularity) {
            BodyHistoryGranularity.daily => start,
            BodyHistoryGranularity.weekly => start.add(const Duration(days: 6)),
            BodyHistoryGranularity.monthly => DateTime.utc(
              start.year,
              start.month + 1,
              0,
            ),
          }),
          measurementCount: groups[start]!.length,
        ),
    ];
  }

  static List<List<BodyHistoryDisplayPoint>> _segments(
    List<BodyHistoryDisplayPoint> points,
    BodyHistoryGranularity granularity,
  ) {
    if (points.isEmpty) return const [];
    final result = <List<BodyHistoryDisplayPoint>>[];
    var current = <BodyHistoryDisplayPoint>[points.first];
    for (var index = 1; index < points.length; index++) {
      final previous = _parse(points[index - 1].startDate);
      final expected = switch (granularity) {
        BodyHistoryGranularity.daily => previous.add(const Duration(days: 1)),
        BodyHistoryGranularity.weekly => previous.add(const Duration(days: 7)),
        BodyHistoryGranularity.monthly => DateTime.utc(
          previous.year,
          previous.month + 1,
        ),
      };
      final next = _parse(points[index].startDate);
      if (next != expected) {
        result.add(current);
        current = <BodyHistoryDisplayPoint>[];
      }
      current.add(points[index]);
    }
    result.add(current);
    return result;
  }

  static DateTime _parse(String value) => DateTime.parse('${value}T00:00:00Z');

  static String _format(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}
