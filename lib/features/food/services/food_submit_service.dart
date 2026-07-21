import '../../../core/models/meal_data.dart';
import '../../../core/repositories/food_repository.dart';
import '../../../core/services/daily_log_mutation_guard.dart';

import '../models/food_summary_state.dart';

class FoodSubmitService {
  const FoodSubmitService._();

  static Future<void> save(MealData data) async {
    await DailyLogMutationGuard.assertDateMutable(DateTime.parse(data.date));
    await FoodRepository.save(data);
    await refreshFoodSummary();
  }

  static Future<void> update(MealData data) async {
    await DailyLogMutationGuard.assertDateMutable(DateTime.parse(data.date));
    await FoodRepository.update(data);
    await refreshFoodSummary();
  }

  static Future<void> delete(MealData data) async {
    await DailyLogMutationGuard.assertDateMutable(DateTime.parse(data.date));
    await FoodRepository.remove(data);
    await refreshFoodSummary();
  }
}
