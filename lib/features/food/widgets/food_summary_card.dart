import 'package:flutter/material.dart';

import '../../../core/models/meal_data.dart';

import '../../../core/widgets/operation_card.dart';
import '../../../core/widgets/section_header.dart';

class FoodSummaryCard extends StatelessWidget {
  final List<MealData> records;

  const FoodSummaryCard({super.key, required this.records});

  int get totalCalories => records.fold(0, (sum, meal) => sum + meal.calories);

  double get totalProtein =>
      records.fold(0.0, (sum, meal) => sum + meal.protein);

  double get totalFat => records.fold(0.0, (sum, meal) => sum + meal.fat);

  double get totalCarbohydrate =>
      records.fold(0.0, (sum, meal) => sum + meal.carbohydrate);

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
            trailing: Text("$totalCalories kcal"),
            contentPadding: EdgeInsets.zero,
          ),

          ListTile(
            leading: const Icon(Icons.fitness_center),
            title: const Text("Protein"),
            trailing: Text("${totalProtein.toStringAsFixed(1)} g"),
            contentPadding: EdgeInsets.zero,
          ),

          ListTile(
            leading: const Icon(Icons.opacity),
            title: const Text("Fat"),
            trailing: Text("${totalFat.toStringAsFixed(1)} g"),
            contentPadding: EdgeInsets.zero,
          ),

          ListTile(
            leading: const Icon(Icons.rice_bowl_outlined),
            title: const Text("Carbohydrate"),
            trailing: Text("${totalCarbohydrate.toStringAsFixed(1)} g"),
            contentPadding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }
}
