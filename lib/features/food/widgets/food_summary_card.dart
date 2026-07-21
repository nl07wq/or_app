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
            trailing: Text(
              "${FoodNutritionFormatter.calories(summary.calories)} kcal",
            ),
            contentPadding: EdgeInsets.zero,
          ),

          ListTile(
            leading: const Icon(Icons.fitness_center),
            title: const Text("Protein"),
            trailing: Text(
              "${FoodNutritionFormatter.macro(summary.protein)} g",
            ),
            contentPadding: EdgeInsets.zero,
          ),

          ListTile(
            leading: const Icon(Icons.opacity),
            title: const Text("Fat"),
            trailing: Text("${FoodNutritionFormatter.macro(summary.fat)} g"),
            contentPadding: EdgeInsets.zero,
          ),

          ListTile(
            leading: const Icon(Icons.rice_bowl_outlined),
            title: const Text("Carbohydrate"),
            trailing: Text(
              "${FoodNutritionFormatter.macro(summary.carbohydrates)} g",
            ),
            contentPadding: EdgeInsets.zero,
          ),

          ListTile(
            leading: const Icon(Icons.water_drop_outlined),
            title: const Text("Water"),
            trailing: Text("${summary.hydrationMl.toStringAsFixed(0)} ml"),
            contentPadding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }
}
