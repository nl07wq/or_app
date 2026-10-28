import 'package:flutter/material.dart';

import '../food_nutrition_formatter.dart';
import '../../../core/engine/food_summary.dart';

import '../../../core/widgets/operation_card.dart';
import '../../../core/widgets/section_header.dart';

class FoodSummaryCard extends StatelessWidget {
  final FoodSummary summary;

  const FoodSummaryCard({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    final titleStyle =
        ListTileTheme.of(context).titleTextStyle ??
        Theme.of(context).textTheme.titleMedium ??
        DefaultTextStyle.of(context).style;
    final numericFontSize = titleStyle.fontSize == null
        ? null
        : titleStyle.fontSize! - 1;
    return OperationCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            icon: Icons.calculate_outlined,
            title: "TODAY'S TOTAL",
          ),

          const SizedBox(height: 16),

          ListTile(
            leading: const Icon(Icons.local_fire_department_outlined),
            title: const Text("Calories"),
            trailing: _NutritionValue(
              key: const ValueKey('food-summary-calories-value'),
              value: FoodNutritionFormatter.calories(summary.calories),
              unit: 'kcal',
              numericFontSize: numericFontSize,
            ),
            contentPadding: EdgeInsets.zero,
          ),

          ListTile(
            leading: const Icon(Icons.fitness_center),
            title: const Text("Protein"),
            trailing: _NutritionValue(
              key: const ValueKey('food-summary-protein-value'),
              value: FoodNutritionFormatter.macro(summary.protein),
              unit: 'g',
              numericFontSize: numericFontSize,
            ),
            contentPadding: EdgeInsets.zero,
          ),

          ListTile(
            leading: const Icon(Icons.opacity),
            title: const Text("Fat"),
            trailing: _NutritionValue(
              key: const ValueKey('food-summary-fat-value'),
              value: FoodNutritionFormatter.macro(summary.fat),
              unit: 'g',
              numericFontSize: numericFontSize,
            ),
            contentPadding: EdgeInsets.zero,
          ),

          ListTile(
            leading: const Icon(Icons.rice_bowl_outlined),
            title: const Text("Carbohydrate"),
            trailing: _NutritionValue(
              key: const ValueKey('food-summary-carbohydrate-value'),
              value: FoodNutritionFormatter.macro(summary.carbohydrates),
              unit: 'g',
              numericFontSize: numericFontSize,
            ),
            contentPadding: EdgeInsets.zero,
          ),

          ListTile(
            leading: const Icon(Icons.water_drop_outlined),
            title: const Text("Water"),
            trailing: _NutritionValue(
              key: const ValueKey('food-summary-water-value'),
              value: summary.hydrationMl.toStringAsFixed(0),
              unit: 'ml',
              numericFontSize: numericFontSize,
            ),
            contentPadding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }
}

class _NutritionValue extends StatelessWidget {
  const _NutritionValue({
    super.key,
    required this.value,
    required this.unit,
    required this.numericFontSize,
  });

  final String value;
  final String unit;
  final double? numericFontSize;

  @override
  Widget build(BuildContext context) => Text.rich(
    TextSpan(
      children: [
        TextSpan(
          style: TextStyle(fontSize: numericFontSize),
          text: value,
        ),
        TextSpan(text: ' $unit'),
      ],
    ),
    textAlign: TextAlign.right,
  );
}
