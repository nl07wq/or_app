import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/models/food_item.dart';
import 'package:or_app/core/models/meal_data.dart';
import 'package:or_app/features/food/models/daily_meal_v2_models.dart';
import 'package:or_app/features/food/models/food_entry_sources.dart';
import 'package:or_app/features/food/models/food_provenance_models.dart';
import 'package:or_app/features/food/models/food_quantity_models.dart';
import 'package:or_app/features/food/models/nutrition_models.dart';
import 'package:or_app/features/food/services/daily_meal_v2_editor.dart';

void main() {
  final timestamp = DateTime.utc(2026, 9, 5);
  final original = DailyMealV2(
    mealId: '11111111-1111-4111-8111-111111111111',
    localDate: '2026-09-05',
    mealType: DailyMealTypeV2.lunch,
    items: [
      DailyMealItemSnapshot(
        mealItemId: '22222222-2222-4222-8222-222222222222',
        foodReferenceId: '33333333-3333-4333-8333-333333333333',
        nameSnapshot: 'Chicken',
        quantity: FoodQuantityDefinition(
          value: 100,
          unit: FoodQuantityUnit.gram,
        ),
        nutritionPerBase: NutritionSnapshot(
          calories: 120,
          protein: 25,
          fat: 2,
          carbohydrate: 0,
        ),
        nutritionConsumed: NutritionSnapshot(
          calories: 120,
          protein: 25,
          fat: 2,
          carbohydrate: 0,
        ),
        provenanceSnapshot: FoodDataProvenance(
          sourceType: FoodProvenanceSourceType.userInput,
          capturedAt: timestamp,
        ),
        nutritionStatusSnapshot: NutritionStatus.declared,
        sortOrder: 0,
      ),
    ],
    createdAt: timestamp,
    updatedAt: timestamp,
  );

  test(
    'editing retains Meal identity, item identity, and Food DB reference',
    () {
      final meal = DailyMealV2Editor.mealData(original);
      final sources = DailyMealV2Editor.sources(original);
      final updated = DailyMealV2Editor.update(
        original: original,
        data: MealData(
          id: meal.id,
          date: meal.date,
          mealType: meal.mealType,
          memo: 'corrected',
          items: [
            const FoodItem(
              name: 'Chicken',
              calories: 120,
              protein: 25,
              fat: 2,
              carbohydrate: 0,
              amount: 1.2,
              baseAmount: 100,
              baseUnit: FoodBaseUnit.g,
              amountMode: FoodAmountMode.baseMultiplier,
            ),
          ],
        ),
        sources: sources,
        timestamp: DateTime.utc(2026, 9, 6),
      );

      expect(updated.mealId, original.mealId);
      expect(updated.items.single.mealItemId, original.items.single.mealItemId);
      expect(
        updated.items.single.foodReferenceId,
        original.items.single.foodReferenceId,
      );
      expect(updated.items.single.nutritionConsumed.protein, 30);
      expect(updated.memo, 'corrected');
    },
  );

  test('a newly added item has no accidental master reference', () {
    final sources = FoodEntrySources(
      catalogSources: const [null],
      recipeSources: const [null],
      quantityUnits: const [FoodQuantityUnit.gram],
    );
    final updated = DailyMealV2Editor.update(
      original: original,
      data: const MealData(
        id: 'ignored',
        date: '2026-09-05',
        mealType: '昼食',
        memo: '',
        items: [
          FoodItem(
            name: 'Rice',
            calories: 150,
            protein: 3,
            fat: 1,
            carbohydrate: 34,
            amount: 1,
            baseAmount: 100,
            baseUnit: FoodBaseUnit.g,
            amountMode: FoodAmountMode.baseMultiplier,
          ),
        ],
      ),
      sources: sources,
      timestamp: DateTime.utc(2026, 9, 6),
    );
    expect(updated.items.single.foodReferenceId, isNull);
    expect(updated.items.single.recipeReferenceId, isNull);
  });

  test('incomplete formal nutrition stays unavailable to the numeric editor', () {
    final incomplete = DailyMealV2(
      mealId: '44444444-4444-4444-8444-444444444444',
      localDate: original.localDate,
      mealType: DailyMealTypeV2.lunch,
      items: [
        DailyMealItemSnapshot(
          mealItemId: '55555555-5555-4555-8555-555555555555',
          nameSnapshot: 'Unknown',
          quantity: FoodQuantityDefinition(value: 1, unit: FoodQuantityUnit.serving),
          nutritionPerBase: NutritionSnapshot(),
          nutritionConsumed: NutritionSnapshot(),
          provenanceSnapshot: FoodDataProvenance(
            sourceType: FoodProvenanceSourceType.userInput,
            capturedAt: timestamp,
          ),
          nutritionStatusSnapshot: NutritionStatus.unknown,
          sortOrder: 0,
        ),
      ],
      createdAt: timestamp,
      updatedAt: timestamp,
    );
    expect(DailyMealV2Editor.canEdit(incomplete), isFalse);
  });
}
