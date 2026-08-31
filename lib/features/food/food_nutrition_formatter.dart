import 'models/food_quantity_models.dart';
import 'models/nutrition_models.dart';

class FoodNutritionFormatter {
  const FoodNutritionFormatter._();

  static String calories(num value) => value.round().toString();

  static String macro(num value) {
    final decimal = value.toDouble();
    return decimal == decimal.roundToDouble()
        ? decimal.round().toString()
        : decimal.toStringAsFixed(1);
  }

  static String amount(num value) {
    final decimal = value.toDouble();
    return decimal == decimal.roundToDouble()
        ? decimal.round().toString()
        : decimal.toString();
  }

  static String displayNumber(num value) => macro(value);

  static String quantityUnit(FoodQuantityUnit unit) => switch (unit) {
    FoodQuantityUnit.gram => 'g',
    FoodQuantityUnit.milliliter => 'ml',
    FoodQuantityUnit.piece => 'piece',
    FoodQuantityUnit.pack => 'pack',
    FoodQuantityUnit.serving => 'serving',
  };

  static String quantity(FoodQuantityDefinition value) =>
      '${displayNumber(value.value)} ${quantityUnit(value.unit)}';

  static String compactQuantity(FoodQuantityDefinition value) =>
      '${displayNumber(value.value)}${quantityUnit(value.unit)}';

  static String nutrition(NutritionSnapshot value) => [
    _nutritionValue(value.calories, 'kcal'),
    'P ${_nutritionValue(value.protein, 'g')}',
    'F ${_nutritionValue(value.fat, 'g')}',
    'C ${_nutritionValue(value.carbohydrate, 'g')}',
  ].join(' · ');

  static String compactNutrition(NutritionSnapshot value) => [
    _compactNutritionValue(value.calories, 'kcal'),
    'P ${_compactNutritionValue(value.protein, 'g')}',
    'F ${_compactNutritionValue(value.fat, 'g')}',
    'C ${_compactNutritionValue(value.carbohydrate, 'g')}',
  ].join('  ');

  static String servings(num value) =>
      '${displayNumber(value)} ${value > 1 ? 'SERVINGS' : 'SERVING'}';

  static String _nutritionValue(num? value, String unit) =>
      value == null ? '—' : '${displayNumber(value)} $unit';

  static String _compactNutritionValue(num? value, String unit) =>
      value == null ? '—' : '${displayNumber(value)}$unit';
}
