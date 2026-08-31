import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/food/models/food_quantity_models.dart';
import 'package:or_app/features/food/models/nutrition_models.dart';
import 'package:or_app/features/food/services/food_nutrition_recalculation.dart';

void main() {
  test('recalculates compatible gram nutrition without fabricating nulls', () {
    final preview = FoodNutritionRecalculation.preview(
      packageQuantity: 240,
      packageUnit: FoodQuantityUnit.gram,
      basisQuantity: 100,
      basisUnit: FoodQuantityUnit.gram,
      nutrition: NutritionSnapshot(
        calories: 271,
        protein: 45.7,
        fat: 7.9,
        carbohydrate: 0,
      ),
    );

    expect(preview.recalculated.calories, closeTo(112.9166667, 0.000001));
    expect(preview.recalculated.protein, closeTo(19.0416667, 0.000001));
    expect(preview.recalculated.fat, closeTo(3.2916667, 0.000001));
    expect(preview.recalculated.carbohydrate, 0);
  });

  test('supports milliliter and discrete same-unit ratios', () {
    final liquid = FoodNutritionRecalculation.preview(
      packageQuantity: 500,
      packageUnit: FoodQuantityUnit.milliliter,
      basisQuantity: 100,
      basisUnit: FoodQuantityUnit.milliliter,
      nutrition: NutritionSnapshot(calories: 250),
    );
    final pieces = FoodNutritionRecalculation.preview(
      packageQuantity: 6,
      packageUnit: FoodQuantityUnit.piece,
      basisQuantity: 1,
      basisUnit: FoodQuantityUnit.piece,
      nutrition: NutritionSnapshot(protein: 12),
    );

    expect(liquid.recalculated.calories, 50);
    expect(pieces.recalculated.protein, 2);
  });

  test('blocks incompatible units and preserves missing values', () {
    final nutrition = NutritionSnapshot(calories: 240, carbohydrate: 0);
    expect(
      FoodNutritionRecalculation.blockedReason(
        packageQuantity: 240,
        packageUnit: FoodQuantityUnit.gram,
        basisQuantity: 1,
        basisUnit: FoodQuantityUnit.serving,
        nutrition: nutrition,
      ),
      'PACKAGE AND NUTRITION BASIS UNITS MUST MATCH',
    );
    final preview = FoodNutritionRecalculation.preview(
      packageQuantity: 240,
      packageUnit: FoodQuantityUnit.gram,
      basisQuantity: 100,
      basisUnit: FoodQuantityUnit.gram,
      nutrition: nutrition,
    );
    expect(preview.recalculated.protein, isNull);
    expect(preview.recalculated.fat, isNull);
    expect(preview.recalculated.carbohydrate, 0);
  });
}
