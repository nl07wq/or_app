import 'package:flutter/material.dart';

import '../food_nutrition_formatter.dart';
import '../../../core/models/food_item.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/operation_card.dart';
import '../../../core/widgets/section_header.dart';

class FoodTotalCard extends StatelessWidget {
  final List<FoodItem> items;

  const FoodTotalCard({super.key, required this.items});

  int get totalCalories => items.fold(0, (sum, item) => sum + item.totalCalories);

  double get totalProtein => items.fold(0.0, (sum, item) => sum + item.totalProtein);

  double get totalFat => items.fold(0.0, (sum, item) => sum + item.totalFat);

  double get totalCarbohydrate =>
      items.fold(0.0, (sum, item) => sum + item.totalCarbohydrate);

  @override
  Widget build(BuildContext context) {
    return OperationCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            icon: Icons.calculate_outlined,
            title: "Meal Total",
          ),

          AppSpacing.gapMD,

          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.local_fire_department_outlined),
            title: const Text("Calories"),
            trailing: Text(
              "${FoodNutritionFormatter.calories(totalCalories)} kcal",
            ),
          ),

          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.fitness_center),
            title: const Text("Protein"),
            trailing: Text("${FoodNutritionFormatter.macro(totalProtein)} g"),
          ),

          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.opacity),
            title: const Text("Fat"),
            trailing: Text("${FoodNutritionFormatter.macro(totalFat)} g"),
          ),

          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.rice_bowl_outlined),
            title: const Text("Carbohydrate"),
            trailing: Text(
              "${FoodNutritionFormatter.macro(totalCarbohydrate)} g",
            ),
          ),
        ],
      ),
    );
  }
}
