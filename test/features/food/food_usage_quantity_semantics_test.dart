import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/models/food_item.dart';
import 'package:or_app/core/models/meal_data.dart';
import 'package:or_app/features/food/models/daily_meal_v2_models.dart';
import 'package:or_app/features/food/models/food_provenance_models.dart';
import 'package:or_app/features/food/models/food_quantity_models.dart';
import 'package:or_app/features/food/models/nutrition_models.dart';
import 'package:or_app/features/food/services/daily_meal_v2_editor.dart';

void main() {
  double calories({
    required double used,
    required double quantity,
    required double basis,
    required double registeredCalories,
  }) =>
      registeredCalories *
      FoodMealUsage.nutritionMultiplier(
        usedAmount: used,
        quantity: quantity,
        registeredBasisAmount: basis,
      );

  test('multiplicative one-piece and eight-piece fixtures scale nutrition', () {
    expect(
      calories(used: 1, quantity: 1, basis: 1, registeredCalories: 113),
      113,
    );
    expect(
      calories(used: 3, quantity: 1, basis: 1, registeredCalories: 113),
      339,
    );
    expect(
      calories(used: 1, quantity: 3, basis: 1, registeredCalories: 113),
      339,
    );
    expect(
      calories(used: 3, quantity: 2, basis: 1, registeredCalories: 113),
      678,
    );

    expect(
      calories(used: 8, quantity: 1, basis: 8, registeredCalories: 280),
      280,
    );
    expect(
      calories(used: 1, quantity: 1, basis: 8, registeredCalories: 280),
      35,
    );
    expect(
      calories(used: 1, quantity: 4, basis: 8, registeredCalories: 280),
      140,
    );
    expect(
      calories(used: 2, quantity: 3, basis: 8, registeredCalories: 280),
      210,
    );
  });

  test('equivalence and monotonicity are derived from total used units', () {
    final equivalent = [
      FoodMealUsage.totalUsedUnits(usedAmount: 1, quantity: 4),
      FoodMealUsage.totalUsedUnits(usedAmount: 2, quantity: 2),
      FoodMealUsage.totalUsedUnits(usedAmount: 4, quantity: 1),
    ];
    expect(equivalent.toSet(), {4.0});
    final quantities = [1.0, 2, 3, 4]
        .map(
          (value) => calories(
            used: 1,
            quantity: value.toDouble(),
            basis: 1,
            registeredCalories: 113,
          ),
        )
        .toList();
    expect(quantities, orderedEquals([113, 226, 339, 452]));
    expect(
      () => FoodMealUsage.totalUsedUnits(usedAmount: 0, quantity: 1),
      throwsArgumentError,
    );
    expect(
      () => FoodMealUsage.nutritionMultiplier(
        usedAmount: 1,
        quantity: 1,
        registeredBasisAmount: 0,
      ),
      throwsArgumentError,
    );
  });

  test(
    'V2.1 usage components persist while legacy snapshots remain unmarked',
    () {
      final timestamp = DateTime.utc(2026, 9, 26);
      final current = DailyMealItemSnapshot(
        mealItemId: '11111111-1111-4111-8111-111111111111',
        nameSnapshot: 'Donut',
        quantity: FoodQuantityDefinition(
          value: 4,
          unit: FoodQuantityUnit.piece,
        ),
        nutritionBasisQuantity: FoodQuantityDefinition(
          value: 8,
          unit: FoodQuantityUnit.piece,
        ),
        usageSetAmount: 1,
        usageSetQuantity: 4,
        quantitySemantics: FoodMealQuantitySemantics.multiplicativeV21,
        nutritionPerBase: NutritionSnapshot(
          calories: 280,
          protein: 23.2,
          fat: 7.2,
          carbohydrate: 31.2,
        ),
        nutritionConsumed: NutritionSnapshot(
          calories: 140,
          protein: 11.6,
          fat: 3.6,
          carbohydrate: 15.6,
        ),
        provenanceSnapshot: FoodDataProvenance(
          sourceType: FoodProvenanceSourceType.userInput,
          capturedAt: timestamp,
        ),
        nutritionStatusSnapshot: NutritionStatus.declared,
        sortOrder: 0,
      );
      final decoded = DailyMealItemSnapshot.fromJson(current.toJson());
      expect(decoded.usageSetAmount, 1);
      expect(decoded.usageSetQuantity, 4);
      expect(
        decoded.quantitySemantics,
        FoodMealQuantitySemantics.multiplicativeV21,
      );

      final legacyJson = current.toJson()
        ..remove('usageSetAmount')
        ..remove('usageSetQuantity')
        ..remove('quantitySemantics');
      final legacy = DailyMealItemSnapshot.fromJson(legacyJson);
      expect(legacy.quantitySemantics, isNull);
      expect(legacy.nutritionConsumed.calories, 140);
    },
  );

  test('V2.1 edit round trip retains components and calculated nutrition', () {
    final timestamp = DateTime.utc(2026, 9, 26);
    final original = DailyMealV2(
      mealId: '11111111-1111-4111-8111-111111111111',
      localDate: '2026-09-26',
      mealType: DailyMealTypeV2.snack,
      items: [
        DailyMealItemSnapshot(
          mealItemId: '22222222-2222-4222-8222-222222222222',
          nameSnapshot: 'Donut',
          quantity: FoodQuantityDefinition(
            value: 4,
            unit: FoodQuantityUnit.piece,
          ),
          nutritionBasisQuantity: FoodQuantityDefinition(
            value: 8,
            unit: FoodQuantityUnit.piece,
          ),
          usageSetAmount: 1,
          usageSetQuantity: 4,
          quantitySemantics: FoodMealQuantitySemantics.multiplicativeV21,
          nutritionPerBase: NutritionSnapshot(
            calories: 280,
            protein: 23.2,
            fat: 7.2,
            carbohydrate: 31.2,
          ),
          nutritionConsumed: NutritionSnapshot(
            calories: 140,
            protein: 11.6,
            fat: 3.6,
            carbohydrate: 15.6,
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
    final data = DailyMealV2Editor.mealData(original);
    final sources = DailyMealV2Editor.sources(original);
    expect(data.items.single.totalCalories, 140);
    expect(sources.usageSetAmounts.single, 1);
    expect(sources.usageSetQuantities.single, 4);

    final saved = DailyMealV2Editor.update(
      original: original,
      data: MealData(
        id: data.id,
        date: data.date,
        mealType: data.mealType,
        memo: data.memo,
        items: [
          const FoodItem(
            name: 'Donut',
            calories: 280,
            protein: 23.2,
            fat: 7.2,
            carbohydrate: 31.2,
            amount: 4,
            baseAmount: 8,
            baseUnit: FoodBaseUnit.g,
            amountMode: FoodAmountMode.physicalAmount,
          ),
        ],
      ),
      sources: sources,
      timestamp: timestamp.add(const Duration(minutes: 1)),
    );
    final item = saved.items.single;
    expect(item.usageSetAmount, 1);
    expect(item.usageSetQuantity, 4);
    expect(item.quantitySemantics, FoodMealQuantitySemantics.multiplicativeV21);
    expect(item.quantity.value, 4);
    expect(item.nutritionConsumed.calories, 140);
  });
}
