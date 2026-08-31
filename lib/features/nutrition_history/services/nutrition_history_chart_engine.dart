import 'dart:math' as math;

import '../../body_history/models/body_history_models.dart';
import '../../body_history/services/body_history_chart_engine.dart';
import '../../body_history/services/history_display_point_compressor.dart';
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
    final observations = <HistoryDisplayObservation>[
      for (final point in source)
        if (point.valueFor(metric) case final value?)
          if (value.isFinite)
            HistoryDisplayObservation(
              date: _parse(point.operationDate),
              value: value,
            ),
    ]..sort((a, b) => a.date.compareTo(b.date));
    const granularity = BodyHistoryGranularity.daily;
    if (observations.isEmpty) {
      return NutritionHistoryChartModel(
        metric: metric,
        period: period,
        granularity: granularity,
        startDate: startDate,
        endDate: endDate,
        points: const [],
        segments: const [],
        displayBucketDays: 1,
        summary: null,
        axis: null,
      );
    }
    final compression = const HistoryDisplayPointCompressor().compress(
      observations: observations,
      period: period,
      rangeStartDate: startDate,
      rangeEndDate: endDate,
      availablePlotWidth: availablePlotWidth,
    );
    final displayPoints = compression.points;
    final values = observations.map((item) => item.value).toList();
    return NutritionHistoryChartModel(
      metric: metric,
      period: period,
      granularity: granularity,
      startDate: _format(observations.first.date),
      endDate: _format(observations.last.date),
      points: displayPoints,
      segments: compression.segments,
      displayBucketDays: compression.bucketDays,
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
    final minimumSpan = metric.unit == 'kcal' ? minimumDisplaySpanKcal : 25.0;
    if (maximum - minimum < minimumSpan) {
      final center = (minimum + maximum) / 2;
      minimum = center - minimumSpan / 2;
      maximum = center + minimumSpan / 2;
      if (metric == NutritionHistoryMetric.calorieBalance) {
        minimum = math.min(minimum, 0);
        maximum = math.max(maximum, 0);
      }
    }
    final interval = metric.unit == 'kcal'
        ? _interval(maximum - minimum)
        : _gramInterval(maximum - minimum);
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

  static double _gramInterval(double span) {
    if (span <= 10) return 2;
    if (span <= 25) return 5;
    if (span <= 60) return 10;
    return 20;
  }

  static DateTime _parse(String value) => DateTime.parse('${value}T00:00:00Z');

  static String _format(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}
