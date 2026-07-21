class FoodNutritionFormatter {
  const FoodNutritionFormatter._();

  static String calories(num value) => value.round().toString();

  static String macro(num value) => value.toStringAsFixed(1);
}
