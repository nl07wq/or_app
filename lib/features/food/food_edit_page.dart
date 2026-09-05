import 'package:flutter/material.dart';

import '../../core/models/meal_data.dart';
import '../../core/navigation/app_routes.dart';
import '../../core/services/daily_log_mutation_guard.dart';
import '../../core/widgets/confirmed_log_message.dart';

import 'services/food_submit_service.dart';
import 'services/daily_meal_v2_editor.dart';
import 'models/daily_meal_v2_models.dart';
import 'models/food_entry_sources.dart';
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

class DailyMealV2EditPage extends StatelessWidget {
  const DailyMealV2EditPage({super.key, required this.meal});

  final DailyMealV2 meal;

  Future<bool> _update(
    BuildContext context,
    MealData data,
    FoodEntrySources sources,
  ) async {
    try {
      final updated = DailyMealV2Editor.update(
        original: meal,
        data: data,
        sources: sources,
        timestamp: DateTime.now().toUtc(),
      );
      await FoodSubmitService.updateV2(updated);
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
    Navigator.pop(context, true);
    return true;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('EDIT MEAL')),
    body: Padding(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: FoodInputForm(
          initialMeal: DailyMealV2Editor.mealData(meal),
          initialSources: DailyMealV2Editor.sources(meal),
          onSave: (_) async => false,
          onSaveWithSources: (data, sources) => _update(context, data, sources),
        ),
      ),
    ),
  );
}
