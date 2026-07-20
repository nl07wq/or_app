import '../../../core/engine/food_summary.dart';
import '../../../core/models/meal_data.dart';

class FoodSummaryService {
  const FoodSummaryService._();

  static FoodSummary today(Iterable<MealData> records) {
    final today = DateTime.now().toIso8601String().split('T').first;
    final dailyRecords = records.where((meal) => meal.date == today);

    return FoodSummary(
      calories: dailyRecords.fold(0.0, (sum, meal) => sum + meal.calories),
      protein: dailyRecords.fold(0.0, (sum, meal) => sum + meal.protein),
      fat: dailyRecords.fold(0.0, (sum, meal) => sum + meal.fat),
      carbohydrates: dailyRecords.fold(
        0.0,
        (sum, meal) => sum + meal.carbohydrate,
      ),
      hydrationMl: 0,
      mealCount: dailyRecords.length,
    );
  }
}
