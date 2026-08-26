import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';

class PeriodicReportChartPoint {
  const PeriodicReportChartPoint({
    required this.x,
    required this.label,
    required this.value,
  });

  final int x;
  final String label;
  final double value;
}

class PeriodicReportChart extends StatelessWidget {
  const PeriodicReportChart({
    super.key,
    required this.title,
    required this.unit,
    required this.points,
    required this.maximumIndex,
  });

  final String title;
  final String unit;
  final List<PeriodicReportChartPoint> points;
  final int maximumIndex;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) return const SizedBox.shrink();
    final values = points.map((point) => point.value).toList();
    final minimum = values.reduce(math.min);
    final maximum = values.reduce(math.max);
    final span = maximum - minimum;
    final padding = span == 0
        ? math.max(maximum.abs() * 0.08, 1.0)
        : span * 0.12;
    final labels = {for (final point in points) point.x: point.label};
    final segments = _segments(points);
    final color = Theme.of(context).colorScheme.primary;
    final gridColor = Theme.of(context).colorScheme.outlineVariant;

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
          AppSpacing.gapSM,
          LayoutBuilder(
            builder: (context, constraints) {
              final chartWidth = math.max(
                constraints.maxWidth,
                (maximumIndex + 1) * (maximumIndex > 12 ? 34.0 : 42.0),
              );
              return SizedBox(
                height: 190,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: chartWidth,
                    child: LineChart(
                      LineChartData(
                        minX: 0,
                        maxX: math.max(1, maximumIndex).toDouble(),
                        minY: minimum - padding,
                        maxY: maximum + padding,
                        clipData: const FlClipData.all(),
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          getDrawingHorizontalLine: (_) => FlLine(
                            color: gridColor.withValues(alpha: 0.55),
                            strokeWidth: 1,
                          ),
                        ),
                        borderData: FlBorderData(
                          show: true,
                          border: Border(bottom: BorderSide(color: gridColor)),
                        ),
                        titlesData: FlTitlesData(
                          topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 48,
                              getTitlesWidget: (value, meta) => SideTitleWidget(
                                meta: meta,
                                child: Text(
                                  _number(value),
                                  style: Theme.of(context).textTheme.labelSmall,
                                ),
                              ),
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 32,
                              interval: 1,
                              getTitlesWidget: (value, meta) {
                                final x = value.round();
                                final label = labels[x];
                                if (label == null || !_showLabel(x)) {
                                  return const SizedBox.shrink();
                                }
                                return SideTitleWidget(
                                  meta: meta,
                                  child: Text(
                                    label,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.labelSmall,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        lineTouchData: LineTouchData(
                          touchTooltipData: LineTouchTooltipData(
                            fitInsideHorizontally: true,
                            fitInsideVertically: true,
                            getTooltipColor: (_) =>
                                Theme.of(context).colorScheme.inverseSurface,
                            getTooltipItems: (spots) => [
                              for (final spot in spots)
                                LineTooltipItem(
                                  '${labels[spot.x.round()] ?? ''}\n'
                                  '${_number(spot.y)} $unit',
                                  TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onInverseSurface,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        lineBarsData: [
                          for (final segment in segments)
                            LineChartBarData(
                              spots: [
                                for (final point in segment)
                                  FlSpot(point.x.toDouble(), point.value),
                              ],
                              isCurved: false,
                              color: color,
                              barWidth: 3,
                              isStrokeCapRound: true,
                              dotData: FlDotData(
                                show: true,
                                getDotPainter: (_, _, _, _) =>
                                    FlDotCirclePainter(
                                      radius: 4,
                                      color: color,
                                      strokeWidth: 1.5,
                                      strokeColor: Theme.of(
                                        context,
                                      ).colorScheme.surface,
                                    ),
                              ),
                              belowBarData: BarAreaData(show: false),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  bool _showLabel(int x) {
    if (maximumIndex <= 12) return true;
    return x == 0 || x == maximumIndex || (x + 1) % 5 == 0;
  }

  static List<List<PeriodicReportChartPoint>> _segments(
    List<PeriodicReportChartPoint> source,
  ) {
    final sorted = [...source]..sort((a, b) => a.x.compareTo(b.x));
    final result = <List<PeriodicReportChartPoint>>[];
    for (final point in sorted) {
      if (result.isEmpty || point.x - result.last.last.x > 1) {
        result.add([point]);
      } else {
        result.last.add(point);
      }
    }
    return result;
  }

  static String _number(double value) {
    final rounded = value.roundToDouble();
    return (value - rounded).abs() < 0.0001
        ? rounded.toStringAsFixed(0)
        : value.toStringAsFixed(1);
  }
}
