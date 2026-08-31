import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/models/food_item.dart';
import 'package:or_app/core/models/meal_data.dart';
import 'package:or_app/core/models/meal_type.dart';
import 'package:or_app/features/food/models/food_catalog_models.dart';
import 'package:or_app/features/food/models/food_provenance_models.dart';
import 'package:or_app/features/food/models/food_quantity_models.dart';
import 'package:or_app/features/food/models/nutrition_models.dart';
import 'package:or_app/features/food/repository/food_meal_id_generator.dart';
import 'package:or_app/features/food/services/food_catalog_meal_mapper.dart';

void main() {
  test(
    'catalog selection creates immutable reference and nutrition snapshot',
    () {
      var byte = 0;
      final timestamp = DateTime.utc(2026, 8, 29, 10);
      final catalog = FoodCatalogEntry(
        foodId: '11111111-1111-4111-8111-111111111111',
        name: 'Rice',
        category: FoodCatalogCategory.packagedFood,
        brand: 'OR Foods',
        baseQuantity: FoodQuantityDefinition(
          value: 100,
          unit: FoodQuantityUnit.gram,
        ),
        nutrition: NutritionSnapshot(
          calories: 200,
          protein: 4,
          fat: 2,
          carbohydrate: 40,
        ),
        nutritionStatus: NutritionStatus.declared,
        provenance: FoodDataProvenance(
          sourceType: FoodProvenanceSourceType.userInput,
          capturedAt: timestamp,
        ),
        isArchived: false,
        createdAt: timestamp,
        updatedAt: timestamp,
      );
      final mapped = FoodCatalogMealMapper.map(
        meal: MealData(
          date: '2026-08-29',
          mealType: MealType.breakfast.label,
          items: [
            FoodItem(
              name: 'Rice',
              calories: 200,
              protein: 4,
              fat: 2,
              carbohydrate: 40,
              amount: 0.5,
              baseAmount: 100,
              baseUnit: FoodBaseUnit.g,
              amountMode: FoodAmountMode.baseMultiplier,
            ),
          ],
          memo: '',
          id: 'legacy-draft',
        ),
        catalogSources: [catalog],
        localDate: '2026-08-29',
        timestamp: timestamp,
        idGenerator: FoodMealIdGenerator(nextInt: (_) => byte++ & 0xff),
      );

      final item = mapped.items.single;
      expect(item.foodReferenceId, catalog.foodId);
      expect(item.nameSnapshot, 'Rice');
      expect(item.brandSnapshot, 'OR Foods');
      expect(item.nutritionPerBase.calories, 200);
      expect(item.nutritionConsumed.calories, 100);
      expect(item.quantity.value, 50);
      expect(item.quantity.unit, FoodQuantityUnit.gram);
      expect(
        item.provenanceSnapshot.sourceType,
        FoodProvenanceSourceType.userInput,
      );

      final editedCatalog = FoodCatalogEntry.fromJson({
        ...catalog.toJson(),
        'name': 'Changed Later',
        'nutrition': {
          'calories': 999,
          'protein': 4.0,
          'fat': 2.0,
          'carbohydrate': 40.0,
        },
      });
      expect(editedCatalog.name, 'Changed Later');
      expect(item.nameSnapshot, 'Rice');
      expect(item.nutritionConsumed.calories, 100);
    },
  );

  for (final unit in [FoodQuantityUnit.piece, FoodQuantityUnit.pack]) {
    test('unlinked ${unit.name} input preserves its Formal unit', () {
      var byte = 0;
      final timestamp = DateTime.utc(2026, 9, 1, 10);
      final mapped = FoodCatalogMealMapper.map(
        meal: MealData(
          date: '2026-09-01',
          mealType: MealType.breakfast.label,
          items: const [
            FoodItem(
              name: 'Discrete Food',
              calories: 80,
              protein: 7.6,
              fat: 6.2,
              carbohydrate: 0.2,
              amount: 2,
              baseAmount: 1,
              baseUnit: FoodBaseUnit.g,
              amountMode: FoodAmountMode.baseMultiplier,
            ),
          ],
          memo: '',
          id: 'discrete-draft',
        ),
        catalogSources: const [null],
        quantityUnits: [unit],
        localDate: '2026-09-01',
        timestamp: timestamp,
        idGenerator: FoodMealIdGenerator(nextInt: (_) => byte++ & 0xff),
      );

      expect(mapped.items.single.quantity.value, 2);
      expect(mapped.items.single.quantity.unit, unit);
      expect(mapped.items.single.nutritionConsumed.calories, 160);
      expect(mapped.items.single.foodReferenceId, isNull);
      expect(mapped.items.single.recipeReferenceId, isNull);
    });
  }
}
