import '../../../core/engine/food_summary.dart';
import '../../../core/models/meal_data.dart';
import '../../../modules/food/summary/nutrition_summary_engine.dart';

class FoodSummaryService {
  const FoodSummaryService._();

  static const _nutritionSummaryEngine = NutritionSummaryEngine();

  static FoodSummary today(Iterable<MealData> records) {
    final today = DateTime.now().toIso8601String().split('T').first;
    final dailyRecords = records.where((meal) => meal.date == today);
    final meals = dailyRecords.where((record) => !record.isWaterEntry);
    final waterEntries = dailyRecords.where((record) => record.isWaterEntry);
    final nutrition = _nutritionSummaryEngine.generate(meals);

    return FoodSummary(
      calories: nutrition.calories,
      protein: nutrition.protein,
      fat: nutrition.fat,
      carbohydrates: nutrition.carbs,
      hydrationMl: waterEntries.fold(0.0, (sum, entry) => sum + entry.waterMl!),
      mealCount: meals.length,
    );
  }
}
