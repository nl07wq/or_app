class FoodNutritionFormatter {
  const FoodNutritionFormatter._();

  static String calories(num value) => value.round().toString();

  static String macro(num value) => value.toStringAsFixed(1);

  static String amount(num value) {
    final decimal = value.toDouble();
    return decimal == decimal.roundToDouble()
        ? decimal.round().toString()
        : decimal.toString();
  }
}
