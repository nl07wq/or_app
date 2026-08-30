import 'dart:math' as math;

import '../models/body_history_models.dart';
import 'history_display_point_compressor.dart';

class BodyHistoryChartEngine {
  static const int maximumDisplayPointsCandidate = 120;
  static const double maximumChartWidthCandidate = 3600;
  static const double pointSpacingCandidate =
      HistoryDisplayPointCompressor.minimumReadablePointSpacing;
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
      return BodyHistoryChartModel(
        metric: metric,
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
      startDate: _format(observations.first.date),
      endDate: _format(observations.last.date),
      points: displayPoints,
      segments: compression.segments,
      displayBucketDays: compression.bucketDays,
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

  static DateTime _parse(String value) => DateTime.parse('${value}T00:00:00Z');

  static String _format(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}
