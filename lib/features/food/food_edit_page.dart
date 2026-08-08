import 'package:flutter/material.dart';

import '../../core/models/meal_data.dart';
import '../../core/navigation/app_routes.dart';
import '../../core/services/daily_log_mutation_guard.dart';
import '../../core/widgets/confirmed_log_message.dart';

import 'services/food_submit_service.dart';
import 'widgets/food_input_form.dart';

class FoodEditPage extends StatelessWidget {
  final MealData meal;
  final bool returnAfterSave;

  const FoodEditPage({
    super.key,
    required this.meal,
    this.returnAfterSave = false,
  });

  Future<bool> _update(BuildContext context, MealData data) async {
    try {
      await FoodSubmitService.update(data);
    } on ConfirmedDailyLogException catch (error) {
      if (context.mounted) showConfirmedLogMessage(context, error);
      return false;
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('MEALの更新に失敗しました')));
      }
      return false;
    }

    if (!context.mounted) return true;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('MEALを更新しました')));

    if (returnAfterSave || data.isWaterEntry) {
      Navigator.pop(context, true);
    } else {
      Navigator.popUntil(context, ModalRoute.withName(AppRoutes.food));
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('FOOD')),
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
