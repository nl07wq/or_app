import '../../../core/engine/food_summary.dart';
import '../../../core/models/meal_data.dart';

class FoodSummaryService {
  const FoodSummaryService._();

  static FoodSummary today(Iterable<MealData> records) {
    final today = DateTime.now().toIso8601String().split('T').first;
    final dailyRecords = records.where((meal) => meal.date == today);
    final meals = dailyRecords.where((record) => !record.isWaterEntry);
    final waterEntries = dailyRecords.where((record) => record.isWaterEntry);

    return FoodSummary(
      calories: meals.fold(0.0, (sum, meal) => sum + meal.calories),
      protein: meals.fold(0.0, (sum, meal) => sum + meal.protein),
      fat: meals.fold(0.0, (sum, meal) => sum + meal.fat),
      carbohydrates: meals.fold(
        0.0,
        (sum, meal) => sum + meal.carbohydrate,
      ),
      hydrationMl: waterEntries.fold(
        0.0,
        (sum, entry) => sum + entry.waterMl!,
      ),
      mealCount: meals.length,
    );
  }
}
