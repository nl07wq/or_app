import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/operation_card.dart';
import '../food_nutrition_formatter.dart';

enum NutritionVisualMetric { calories, protein, fat, carbohydrate }

abstract final class NutritionVisualColors {
  static const calories = Color(0xFFF2C14E);
  static const protein = Color(0xFFE08AAA);
  static const fat = Color(0xFFE9A052);
  static const carbohydrate = Color(0xFF62BFE3);
  static const onTrack = Color(0xFF63C692);
  static const low = Color(0xFFE9A052);
  static const high = Color(0xFFE08A6A);

  static Color forMetric(NutritionVisualMetric metric) => switch (metric) {
    NutritionVisualMetric.calories => calories,
    NutritionVisualMetric.protein => protein,
    NutritionVisualMetric.fat => fat,
    NutritionVisualMetric.carbohydrate => carbohydrate,
  };
}

class NutritionDonut extends StatelessWidget {
  const NutritionDonut({
    super.key,
    required this.values,
    required this.colors,
    required this.centerTop,
    required this.centerBottom,
    this.size = 92,
  });
  final List<double> values;
  final List<Color> colors;
  final String centerTop;
  final String centerBottom;
  final double size;

  @override
  Widget build(BuildContext context) {
    final total = values.fold<double>(0, (sum, value) => sum + value);
    if (total <= 0) return const Text('—');
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(painter: _DonutPainter(values, colors)),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  centerTop,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  centerBottom,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class NutritionStatusBadge extends StatelessWidget {
  const NutritionStatusBadge({super.key, required this.status});
  final String status;
  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'ON TRACK' => NutritionVisualColors.onTrack,
      'LOW' => NutritionVisualColors.low,
      'HIGH' || 'OVER' => NutritionVisualColors.high,
      _ => Theme.of(context).colorScheme.outline,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class NutritionContributorCard extends StatelessWidget {
  const NutritionContributorCard({
    super.key,
    required this.metric,
    required this.foodName,
    required this.value,
    required this.unit,
    this.sharePercent,
    this.mealType,
  });
  final NutritionVisualMetric metric;
  final String foodName;
  final double? value;
  final String unit;
  final int? sharePercent;
  final String? mealType;
  @override
  Widget build(BuildContext context) => OperationCard(
    child: Container(
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: NutritionVisualColors.forMetric(metric),
            width: 4,
          ),
        ),
      ),
      padding: const EdgeInsets.only(left: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TOP ${metric.name.toUpperCase()}',
            style: TextStyle(
              color: NutritionVisualColors.forMetric(metric),
              fontWeight: FontWeight.bold,
            ),
          ),
          AppSpacing.gapSM,
          Text(foodName, maxLines: 2, overflow: TextOverflow.ellipsis),
          Text(
            value == null
                ? '—'
                : '${FoodNutritionFormatter.macro(value!)}$unit',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (sharePercent != null)
            Text('$sharePercent% OF ${metric.name.toUpperCase()}'),
          if (mealType != null)
            Text(
              mealType!.toUpperCase(),
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ),
    ),
  );
}

class _DonutPainter extends CustomPainter {
  const _DonutPainter(this.values, this.colors);
  final List<double> values;
  final List<Color> colors;
  @override
  void paint(Canvas canvas, Size size) {
    final total = values.fold<double>(0, (sum, value) => sum + value);
    var start = -math.pi / 2;
    for (var i = 0; i < values.length; i++) {
      final sweep = math.pi * 2 * values[i] / total;
      canvas.drawArc(
        (Offset.zero & size).deflate(7),
        start,
        sweep,
        false,
        Paint()
          ..color = colors[i]
          ..style = PaintingStyle.stroke
          ..strokeWidth = 10,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) =>
      oldDelegate.values != values || oldDelegate.colors != colors;
}
