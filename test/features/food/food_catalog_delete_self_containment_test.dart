import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/models/food_item.dart';
import 'package:or_app/core/models/meal_data.dart';
import 'package:or_app/core/models/meal_type.dart';
import 'package:or_app/features/food/models/food_catalog_models.dart';
import 'package:or_app/features/food/models/food_provenance_models.dart';
import 'package:or_app/features/food/models/food_quantity_models.dart';
import 'package:or_app/features/food/models/nutrition_models.dart';
import 'package:or_app/features/food/repository/food_meal_id_generator.dart';
import 'package:or_app/features/food/repository/indexed_db_daily_meal_v2_repository.dart';
import 'package:or_app/features/food/repository/indexed_db_food_catalog_repository.dart';
import 'package:or_app/features/food/services/food_catalog_meal_mapper.dart';

import '../../repositories/indexed_db/fake_indexed_db_database.dart';

void main() {
  test(
    'physical catalog delete leaves persisted meal snapshot unchanged',
    () async {
      final database = FakeIndexedDbDatabase();
      final catalogRepository = IndexedDbFoodCatalogRepository(database);
      final mealRepository = IndexedDbDailyMealV2Repository(database);
      final timestamp = DateTime.utc(2026, 8, 30, 10);
      final catalog = FoodCatalogEntry(
        foodId: '11111111-1111-4111-8111-111111111111',
        name: 'Snapshot Food',
        category: FoodCatalogCategory.packagedFood,
        brand: 'OR FOODS',
        baseQuantity: FoodQuantityDefinition(
          value: 100,
          unit: FoodQuantityUnit.gram,
        ),
        nutrition: NutritionSnapshot(
          calories: 200,
          protein: 10,
          fat: 5,
          carbohydrate: 30,
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
      await catalogRepository.create(catalog);

      var byte = 0;
      final meal = FoodCatalogMealMapper.map(
        meal: MealData(
          id: 'draft',
          date: '2026-08-30',
          mealType: MealType.breakfast.label,
          items: [
            FoodItem(
              name: catalog.name,
              calories: 200,
              protein: 10,
              fat: 5,
              carbohydrate: 30,
              amount: 0.5,
              baseAmount: 100,
              baseUnit: FoodBaseUnit.g,
              amountMode: FoodAmountMode.baseMultiplier,
            ),
          ],
          memo: '',
        ),
        catalogSources: [catalog],
        localDate: '2026-08-30',
        timestamp: timestamp,
        idGenerator: FoodMealIdGenerator(nextInt: (_) => byte++ & 0xff),
      );
      await mealRepository.create(meal);
      final before = (await mealRepository.readById(meal.mealId))!.toJson();

      await catalogRepository.delete(catalog.foodId);

      expect(await catalogRepository.readById(catalog.foodId), isNull);
      final restored = await mealRepository.readById(meal.mealId);
      expect(restored!.toJson(), before);
      final item = restored.items.single;
      expect(item.foodReferenceId, catalog.foodId);
      expect(item.nameSnapshot, 'Snapshot Food');
      expect(item.brandSnapshot, 'OR FOODS');
      expect(item.quantity.value, 50);
      expect(item.nutritionConsumed.calories, 100);
      expect(item.nutritionConsumed.protein, 5);
      expect(item.nutritionConsumed.fat, 2.5);
      expect(item.nutritionConsumed.carbohydrate, 15);
    },
  );
}
