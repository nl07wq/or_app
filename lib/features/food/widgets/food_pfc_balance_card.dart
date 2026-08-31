import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/operation_card.dart';
import '../../../core/widgets/section_header.dart';
import '../food_nutrition_formatter.dart';
import '../models/nutrition_models.dart';

const double foodDetailPfcRingWidth = 12;
const Color foodDetailProteinColor = Color(0xFFE08AAA);
const Color foodDetailFatColor = Color(0xFFE9A052);
const Color foodDetailCarbohydrateColor = Color(0xFF62BFE3);

class FoodPfcBalanceCard extends StatelessWidget {
  const FoodPfcBalanceCard({
    super.key,
    required this.nutrition,
    this.title = 'PFC BALANCE',
    this.keyPrefix = 'food-detail-pfc',
  });

  final NutritionSnapshot nutrition;
  final String title;
  final String keyPrefix;

  static bool hasBalance(NutritionSnapshot nutrition) =>
      nutrition.protein != null &&
      nutrition.fat != null &&
      nutrition.carbohydrate != null &&
      nutrition.protein! * 4 +
              nutrition.fat! * 9 +
              nutrition.carbohydrate! * 4 >
          0;

  @override
  Widget build(BuildContext context) {
    final grams = [nutrition.protein!, nutrition.fat!, nutrition.carbohydrate!];
    final values = [grams[0] * 4, grams[1] * 9, grams[2] * 4];
    final total = values.reduce((a, b) => a + b);
    const colors = [
      foodDetailProteinColor,
      foodDetailFatColor,
      foodDetailCarbohydrateColor,
    ];
    return OperationCard(
      key: ValueKey('$keyPrefix-card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(icon: Icons.donut_large, title: title),
          AppSpacing.gapSM,
          Row(
            key: ValueKey('$keyPrefix-horizontal'),
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                key: ValueKey('$keyPrefix-donut'),
                width: 104,
                height: 104,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CustomPaint(painter: _PfcPainter(values, colors)),
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                nutrition.calories == null
                                    ? 'N/A'
                                    : FoodNutritionFormatter.calories(
                                        nutrition.calories!,
                                      ),
                                key: ValueKey('$keyPrefix-center-calories'),
                                maxLines: 1,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  height: 1,
                                ),
                              ),
                            ),
                            if (nutrition.calories != null)
                              const Text(
                                'kcal',
                                style: TextStyle(fontSize: 10, height: 1.1),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  children: [
                    for (var index = 0; index < values.length; index++) ...[
                      _PfcMetricRow(
                        key: ValueKey(
                          '$keyPrefix-${const ['PROTEIN', 'FAT', 'CARBOHYDRATE'][index]}',
                        ),
                        label: const ['PROTEIN', 'FAT', 'CARBOHYDRATE'][index],
                        grams: grams[index],
                        percent: (values[index] / total * 100).round(),
                        color: colors[index],
                      ),
                      if (index < values.length - 1) AppSpacing.gapSM,
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PfcMetricRow extends StatelessWidget {
  const _PfcMetricRow({
    super.key,
    required this.label,
    required this.grams,
    required this.percent,
    required this.color,
  });

  final String label;
  final double grams;
  final int percent;
  final Color color;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final style = TextStyle(color: color, fontWeight: FontWeight.bold);
      final compact = constraints.maxWidth < 190;
      return Row(
        children: [
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(label, maxLines: 1, style: style),
            ),
          ),
          SizedBox(
            width: compact ? 50 : 72,
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                '${FoodNutritionFormatter.macro(grams)} g',
                maxLines: 1,
                style: style,
              ),
            ),
          ),
          SizedBox(
            width: compact ? 36 : 48,
            child: Align(
              alignment: Alignment.centerRight,
              child: Text('$percent%', maxLines: 1, style: style),
            ),
          ),
        ],
      );
    },
  );
}

class _PfcPainter extends CustomPainter {
  const _PfcPainter(this.values, this.colors);

  final List<double> values;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final total = values.reduce((a, b) => a + b);
    final rect = Offset.zero & size;
    var start = -math.pi / 2;
    for (var index = 0; index < values.length; index++) {
      final sweep = math.pi * 2 * values[index] / total;
      canvas.drawArc(
        rect.deflate(10),
        start,
        sweep,
        false,
        Paint()
          ..color = colors[index]
          ..style = PaintingStyle.stroke
          ..strokeWidth = foodDetailPfcRingWidth
          ..strokeCap = StrokeCap.butt,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _PfcPainter oldDelegate) =>
      oldDelegate.values != values || oldDelegate.colors != colors;
}
