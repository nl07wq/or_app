import '../../../core/models/meal_data.dart';
import 'nutrition_summary.dart';

class NutritionSummaryEngine {
  const NutritionSummaryEngine();

  NutritionSummary generate(Iterable<MealData> records) {
    var calories = 0.0;
    var protein = 0.0;
    var fat = 0.0;
    var carbs = 0.0;

    for (final record in records) {
      calories += record.calories;
      protein += record.protein;
      fat += record.fat;
      carbs += record.carbohydrate;
    }

    return NutritionSummary(
      calories: calories,
      protein: protein,
      fat: fat,
      carbs: carbs,
    );
  }
}
