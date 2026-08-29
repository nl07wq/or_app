import '../food_nutrition_formatter.dart';
import '../models/food_quantity_models.dart';
import 'food_input_capture_gateway.dart';
import 'japanese_nutrition_ocr_parser.dart';

FoodNutritionLiveCandidate describeNutritionCandidate(String rawText) {
  final draft = const JapaneseNutritionOcrParser().parse(rawText);
  if (draft.isEmpty) {
    return const FoodNutritionLiveCandidate(state: 'SCANNING...');
  }
  final hasMajorValues =
      draft.calories != null &&
      draft.protein != null &&
      draft.fat != null &&
      draft.carbohydrate != null;
  return FoodNutritionLiveCandidate(
    state: hasMajorValues ? 'DETECTED' : 'PARTIAL',
    calories: draft.calories == null
        ? null
        : '${FoodNutritionFormatter.calories(draft.calories!)} kcal',
    protein: draft.protein == null
        ? null
        : '${FoodNutritionFormatter.macro(draft.protein!)} g',
    fat: draft.fat == null
        ? null
        : '${FoodNutritionFormatter.macro(draft.fat!)} g',
    carbohydrate: draft.carbohydrate == null
        ? null
        : '${FoodNutritionFormatter.macro(draft.carbohydrate!)} g',
    basis: _quantity(draft.basisQuantity, draft.basisUnit),
    package: _quantity(draft.packageQuantity, draft.packageUnit),
  );
}

String? _quantity(double? value, FoodQuantityUnit? unit) {
  if (value == null || unit == null) return null;
  final number = value == value.roundToDouble()
      ? value.round().toString()
      : FoodNutritionFormatter.macro(value);
  return '$number ${switch (unit) {
    FoodQuantityUnit.gram => 'g',
    FoodQuantityUnit.milliliter => 'mL',
    FoodQuantityUnit.piece => 'piece',
    FoodQuantityUnit.pack => 'pack',
    FoodQuantityUnit.serving => 'serving',
  }}';
}
