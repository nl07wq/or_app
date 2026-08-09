import 'dart:math' as math;

import '../../body_history/models/body_history_models.dart';
import '../../body_history/services/body_history_chart_engine.dart';
import '../models/nutrition_history_models.dart';

class NutritionHistoryChartEngine {
  static const double minimumDisplaySpanKcal = 500;

  const NutritionHistoryChartEngine();

  NutritionHistoryChartModel build({
    required List<NutritionHistoryDataPoint> source,
    required NutritionHistoryMetric metric,
    required BodyHistoryPeriod period,
    required String startDate,
    required String endDate,
    double availablePlotWidth =
        BodyHistoryChartEngine.maximumChartWidthCandidate,
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
      return NutritionHistoryChartModel(
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
    return NutritionHistoryChartModel(
      metric: metric,
      granularity: granularity,
      startDate: displayPoints.first.startDate,
      endDate: displayPoints.last.startDate,
      points: displayPoints,
      segments: _segments(displayPoints, granularity),
      summary: NutritionHistorySummary(
        maximum: values.reduce(math.max),
        minimum: values.reduce(math.min),
        average: values.reduce((a, b) => a + b) / values.length,
        measurementCount: values.length,
      ),
      axis: axisFor(metric, values),
    );
  }

  BodyHistoryAxisRange axisFor(
    NutritionHistoryMetric metric,
    List<double> values,
  ) {
    if (values.isEmpty) throw ArgumentError('values must not be empty.');
    var minimum = values.reduce(math.min);
    var maximum = values.reduce(math.max);
    if (metric == NutritionHistoryMetric.calorieBalance) {
      minimum = math.min(minimum, 0);
      maximum = math.max(maximum, 0);
    }
    if (maximum - minimum < minimumDisplaySpanKcal) {
      final center = (minimum + maximum) / 2;
      minimum = center - minimumDisplaySpanKcal / 2;
      maximum = center + minimumDisplaySpanKcal / 2;
      if (metric == NutritionHistoryMetric.calorieBalance) {
        minimum = math.min(minimum, 0);
        maximum = math.max(maximum, 0);
      }
    }
    final interval = _interval(maximum - minimum);
    return BodyHistoryAxisRange(
      minimum: (minimum / interval).floorToDouble() * interval - interval,
      maximum: (maximum / interval).ceilToDouble() * interval + interval,
      interval: interval,
    );
  }

  double chartWidth({
    required int pointCount,
    required double availableWidth,
  }) => const BodyHistoryChartEngine().chartWidth(
    pointCount: pointCount,
    availableWidth: availableWidth,
  );

  static double _interval(double span) {
    if (span <= 500) return 100;
    if (span <= 1000) return 250;
    if (span <= 2500) return 500;
    if (span <= 5000) return 1000;
    return 2000;
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
        item.date.subtract(Duration(days: item.date.weekday - 1)),
    }.length;
    if (_fitsDensity(weeks, availablePlotWidth)) {
      return BodyHistoryGranularity.weekly;
    }
    return BodyHistoryGranularity.monthly;
  }

  static bool _fitsDensity(int pointCount, double availablePlotWidth) =>
      pointCount * BodyHistoryChartEngine.pointSpacingCandidate <=
      math.max(
        availablePlotWidth,
        BodyHistoryChartEngine.maximumChartWidthCandidate,
      );

  static List<BodyHistoryDisplayPoint> _aggregate(
    List<({DateTime date, double value})> observations,
    BodyHistoryGranularity granularity,
  ) {
    final groups = <DateTime, List<({DateTime date, double value})>>{};
    for (final item in observations) {
      final start = switch (granularity) {
        BodyHistoryGranularity.daily => item.date,
        BodyHistoryGranularity.weekly => item.date.subtract(
          Duration(days: item.date.weekday - 1),
        ),
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
