import 'package:flutter/material.dart';

import '../../core/models/meal_data.dart';

import 'services/food_submit_service.dart';
import 'widgets/food_input_form.dart';

class FoodEditPage extends StatelessWidget {
  final MealData meal;

  const FoodEditPage({super.key, required this.meal});

  Future<void> _update(BuildContext context, MealData data) async {
    await FoodSubmitService.update(data);

    if (!context.mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Meal updated')));

    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('EDIT MEAL')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: FoodInputForm(
            initialMeal: meal,
            onSave: (data) => _update(context, data),
          ),
        ),
      ),
    );
  }
}
