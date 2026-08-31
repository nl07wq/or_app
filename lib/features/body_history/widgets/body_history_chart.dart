import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../models/body_history_models.dart';
import '../services/body_history_chart_engine.dart';
import '../services/body_history_x_axis.dart';
import '../services/history_y_axis_width.dart';
import '../theme/history_metric_color_registry.dart';

class BodyHistoryChart extends StatelessWidget {
  static const double _height = 300;
  static const double yAxisWidth = 52;
  static const double _chartTopPadding = 16;
  static const double _bottomTitlesHeight = 38;

  final BodyHistoryChartModel model;

  const BodyHistoryChart({super.key, required this.model});

  @override
  Widget build(BuildContext context) {
    if (model.points.isEmpty || model.axis == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
        child: Center(child: Text('この期間には記録がありません。')),
      );
    }
    final engine = const BodyHistoryChartEngine();
    return LayoutBuilder(
      builder: (context, constraints) {
        final yAxisWidth = _yAxisWidth(context);
        final availableChartWidth = math.max(
          0.0,
          constraints.maxWidth - yAxisWidth,
        );
        final totalDays =
            DateTime.parse(
              model.endDate,
            ).difference(DateTime.parse(model.startDate)).inDays +
            1;
        final chartWidth = totalDays <= 370
            ? availableChartWidth
            : engine.chartWidth(
                pointCount: model.points.length,
                availableWidth: availableChartWidth,
              );
        final ticks = const BodyHistoryXAxis().ticks(
          startDate: model.startDate,
          endDate: model.endDate,
          period: model.period,
          granularity: model.granularity,
          availablePlotWidth: availableChartWidth,
        );
        return SizedBox(
          height: _height,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: yAxisWidth,
                child: _FixedYAxis(axis: model.axis!, unit: model.metric.unit),
              ),
              Expanded(
                child: totalDays <= 370
                    ? SizedBox(
                        width: chartWidth,
                        child: _ChartPlot(
                          chart: LineChart(_chartData(context)),
                          ticks: ticks,
                          maximumX: _maximumX,
                        ),
                      )
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(
                          width: chartWidth,
                          child: _ChartPlot(
                            chart: LineChart(_chartData(context)),
                            ticks: ticks,
                            maximumX: _maximumX,
                          ),
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  double _yAxisWidth(BuildContext context) {
    final axis = model.axis!;
    return HistoryYAxisWidth.calculate(
      labels: [
        for (
          var value = axis.maximum;
          value >= axis.minimum - axis.interval / 2;
          value -= axis.interval
        )
          '${_number(value)}${model.metric.unit}',
      ],
      style: Theme.of(context).textTheme.labelSmall ?? const TextStyle(),
      textDirection: Directionality.of(context),
    );
  }

  LineChartData _chartData(BuildContext context) {
    final axis = model.axis!;
    final minX = model.points.length == 1 ? -0.5 : 0.0;
    final maxX = _maximumX;
    final color = HistoryMetricColorRegistry.resolve(
      context,
      switch (model.metric) {
        BodyHistoryMetric.weight => HistoryMetricColorKey.weight,
        BodyHistoryMetric.bodyFat => HistoryMetricColorKey.bodyFat,
      },
    );
    final gridColor = Theme.of(context).colorScheme.outlineVariant;
    return LineChartData(
      minX: minX,
      maxX: maxX,
      minY: axis.minimum,
      maxY: axis.maximum,
      clipData: const FlClipData(
        top: true,
        bottom: true,
        left: false,
        right: false,
      ),
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: axis.interval,
        getDrawingHorizontalLine: (_) =>
            FlLine(color: gridColor.withValues(alpha: 0.55), strokeWidth: 1),
      ),
      borderData: FlBorderData(
        show: true,
        border: Border(bottom: BorderSide(color: gridColor)),
      ),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        leftTitles: AxisTitles(sideTitles: const SideTitles(showTitles: false)),
        bottomTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
      ),
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          fitInsideHorizontally: true,
          fitInsideVertically: true,
          getTooltipColor: (_) => Theme.of(context).colorScheme.inverseSurface,
          getTooltipItems: (spots) => [
            for (final spot in spots)
              LineTooltipItem(
                bodyHistoryTooltipText(model, _pointAt(spot.x)),
                TextStyle(
                  color: Theme.of(context).colorScheme.onInverseSurface,
                ),
              ),
          ],
        ),
      ),
      lineBarsData: [
        for (final segment in model.segments)
          LineChartBarData(
            spots: [for (final point in segment) FlSpot(point.x, point.value)],
            isCurved: false,
            color: color,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (_, _, _, _) => FlDotCirclePainter(
                radius: 4,
                color: color,
                strokeWidth: 1.5,
                strokeColor: Theme.of(context).colorScheme.surface,
              ),
            ),
            belowBarData: BarAreaData(show: false),
          ),
      ],
    );
  }

  BodyHistoryDisplayPoint _pointAt(double x) => model.points.reduce(
    (first, second) =>
        (first.x - x).abs() <= (second.x - x).abs() ? first : second,
  );

  double get _maximumX {
    if (model.points.length == 1) return 0.5;
    return DateTime.parse('${model.endDate}T00:00:00Z')
        .difference(DateTime.parse('${model.startDate}T00:00:00Z'))
        .inDays
        .toDouble();
  }

  static String _number(double value) {
    final rounded = value.roundToDouble();
    return (value - rounded).abs() < 0.001
        ? rounded.toStringAsFixed(0)
        : value.toStringAsFixed(1);
  }
}

String bodyHistoryTooltipText(
  BodyHistoryChartModel model,
  BodyHistoryDisplayPoint point,
) {
  final value = '${BodyHistoryChart._number(point.value)}${model.metric.unit}';
  if (point.isCompressed) {
    return '${point.startDate} – ${point.endDate}\n'
        'Representative: ${point.representativeDate}\n'
        '${model.metric.label}: $value\n'
        'Records: ${point.measurementCount}';
  }
  return switch (model.granularity) {
    BodyHistoryGranularity.daily => '${point.representativeDate}\n$value',
    BodyHistoryGranularity.weekly =>
      '${point.startDate} – ${point.endDate}\n'
          '週平均: $value\n記録日数: ${point.measurementCount}日',
    BodyHistoryGranularity.monthly =>
      '${point.startDate.substring(0, 7)}\n'
          '月平均: $value\n記録日数: ${point.measurementCount}日',
  };
}

class _ChartPlot extends StatelessWidget {
  const _ChartPlot({
    required this.chart,
    required this.ticks,
    required this.maximumX,
  });
  final Widget chart;
  final List<BodyHistoryXAxisTick> ticks;
  final double maximumX;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Expanded(
        child: Padding(
          padding: const EdgeInsets.only(
            top: BodyHistoryChart._chartTopPadding,
            left: 6,
            right: 6,
          ),
          child: chart,
        ),
      ),
      SizedBox(
        height: BodyHistoryChart._bottomTitlesHeight,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: _XAxisLabels(ticks: ticks, maximumX: maximumX),
        ),
      ),
    ],
  );
}

class _XAxisLabels extends StatelessWidget {
  static const double _labelWidth = BodyHistoryXAxis.minimumLabelWidthCandidate;

  final List<BodyHistoryXAxisTick> ticks;
  final double maximumX;

  const _XAxisLabels({required this.ticks, required this.maximumX});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final maximumLeft = math.max(0.0, constraints.maxWidth - _labelWidth);
      return Stack(
        clipBehavior: Clip.none,
        children: [
          for (final tick in ticks)
            Positioned(
              left:
                  ((ticks.length == 1
                                  ? 0.5
                                  : maximumX == 0
                                  ? 0
                                  : tick.x / maximumX) *
                              constraints.maxWidth -
                          _labelWidth / 2)
                      .clamp(0.0, maximumLeft),
              width: _labelWidth,
              child: Text(
                tick.label,
                textAlign: ticks.length == 1
                    ? TextAlign.center
                    : tick.x == 0
                    ? TextAlign.left
                    : tick.x == maximumX
                    ? TextAlign.right
                    : TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
        ],
      );
    },
  );
}

class _FixedYAxis extends StatelessWidget {
  final BodyHistoryAxisRange axis;
  final String unit;

  const _FixedYAxis({required this.axis, required this.unit});

  @override
  Widget build(BuildContext context) {
    final gridColor = Theme.of(context).colorScheme.outlineVariant;
    final values = <double>[];
    for (
      var value = axis.maximum;
      value >= axis.minimum - axis.interval / 2;
      value -= axis.interval
    ) {
      values.add(value);
    }
    return Padding(
      padding: const EdgeInsets.only(
        top: BodyHistoryChart._chartTopPadding,
        bottom: BodyHistoryChart._bottomTitlesHeight,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(right: BorderSide(color: gridColor)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final value in values)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Text(
                  '${BodyHistoryChart._number(value)}$unit',
                  textAlign: TextAlign.right,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
