import '../../../core/models/food_item.dart';
import '../../../core/models/meal_data.dart';
import '../../../core/models/meal_type.dart';
import '../models/daily_meal_v2_models.dart';
import '../models/food_entry_sources.dart';
import '../models/food_provenance_models.dart';
import '../models/food_quantity_models.dart';
import '../models/nutrition_models.dart';
import '../repository/food_meal_id_generator.dart';

/// Projects a formal v2 Meal into the existing Food Entry editor and rebuilds
/// the same Meal identity from that editor's snapshot. Catalog masters are
/// deliberately only referenced, never updated here.
class DailyMealV2Editor {
  const DailyMealV2Editor._();

  static MealData mealData(DailyMealV2 meal) => MealData(
    id: meal.mealId,
    date: meal.localDate,
    mealType: _mealTypeLabel(meal.mealType),
    memo: meal.memo ?? '',
    items: [for (final item in meal.items) _foodItem(item)],
  );

  static FoodEntrySources sources(DailyMealV2 meal) => FoodEntrySources(
    catalogSources: List.filled(meal.items.length, null),
    recipeSources: List.filled(meal.items.length, null),
    quantityUnits: meal.items.map((item) => item.quantity.unit).toList(),
    foodReferenceIds: meal.items.map((item) => item.foodReferenceId).toList(),
    recipeReferenceIds: meal.items
        .map((item) => item.recipeReferenceId)
        .toList(),
    mealItemIds: meal.items.map((item) => item.mealItemId).toList(),
    provenanceSnapshots: meal.items
        .map((item) => item.provenanceSnapshot)
        .toList(),
    nutritionStatuses: meal.items
        .map((item) => item.nutritionStatusSnapshot)
        .toList(),
    brandSnapshots: meal.items.map((item) => item.brandSnapshot).toList(),
    categories: meal.items.map((item) => item.category).toList(),
    memos: meal.items.map((item) => item.memo).toList(),
  );

  static DailyMealV2 update({
    required DailyMealV2 original,
    required MealData data,
    required FoodEntrySources sources,
    required DateTime timestamp,
    FoodMealIdGenerator? idGenerator,
  }) {
    if (data.isWaterEntry || original.mealType == DailyMealTypeV2.water) {
      throw ArgumentError('Water records are not Meal editor records.');
    }
    if (data.items.length != sources.quantityUnits.length) {
      throw ArgumentError('FOOD editor sources must match Meal items.');
    }
    final generator = idGenerator ?? FoodMealIdGenerator();
    final items = <DailyMealItemSnapshot>[];
    for (var index = 0; index < data.items.length; index++) {
      final entry = data.items[index];
      final foodId = sources.foodReferenceIds[index];
      final recipeId = sources.recipeReferenceIds[index];
      if (foodId != null && recipeId != null) {
        throw ArgumentError('FOOD item references are mutually exclusive.');
      }
      final existingId = sources.mealItemIds[index];
      final consumed = NutritionSnapshot(
        calories: entry.totalCalories,
        protein: entry.totalProtein,
        fat: entry.totalFat,
        carbohydrate: entry.totalCarbohydrate,
      );
      items.add(
        DailyMealItemSnapshot(
          mealItemId: existingId ?? _id(generator),
          foodReferenceId: foodId,
          recipeReferenceId: recipeId,
          nameSnapshot: entry.name,
          brandSnapshot: sources.brandSnapshots[index],
          category: sources.categories[index],
          quantity: FoodQuantityDefinition(
            value: entry.physicalAmount ?? entry.quantity.toDouble(),
            unit: sources.quantityUnits[index],
          ),
          nutritionPerBase: NutritionSnapshot(
            calories: entry.calories.toDouble(),
            protein: entry.protein,
            fat: entry.fat,
            carbohydrate: entry.carbohydrate,
          ),
          nutritionConsumed: consumed,
          provenanceSnapshot:
              sources.provenanceSnapshots[index] ??
              FoodDataProvenance(
                sourceType: FoodProvenanceSourceType.userInput,
                capturedAt: timestamp.toUtc(),
              ),
          nutritionStatusSnapshot:
              sources.nutritionStatuses[index] ?? NutritionStatus.declared,
          memo: sources.memos[index],
          sortOrder: index,
        ),
      );
    }
    return DailyMealV2(
      mealId: original.mealId,
      localDate: original.localDate,
      mealType: DailyMealTypeV2.values.byName(
        MealType.fromLabel(data.mealType).name,
      ),
      items: items,
      memo: data.memo.trim().isEmpty ? null : data.memo.trim(),
      createdAt: original.createdAt,
      updatedAt: timestamp.toUtc(),
    );
  }

  static FoodItem _foodItem(DailyMealItemSnapshot item) {
    final quantity = item.quantity;
    final baseUnit = quantity.unit == FoodQuantityUnit.milliliter
        ? FoodBaseUnit.ml
        : FoodBaseUnit.g;
    return FoodItem(
      name: item.nameSnapshot,
      calories: item.nutritionPerBase.calories ?? 0,
      protein: item.nutritionPerBase.protein ?? 0,
      fat: item.nutritionPerBase.fat ?? 0,
      carbohydrate: item.nutritionPerBase.carbohydrate ?? 0,
      amount: 1,
      baseAmount: quantity.value,
      baseUnit: baseUnit,
      amountMode: FoodAmountMode.baseMultiplier,
    );
  }

  static String _mealTypeLabel(DailyMealTypeV2 type) => switch (type) {
    DailyMealTypeV2.breakfast => MealType.breakfast.label,
    DailyMealTypeV2.lunch => MealType.lunch.label,
    DailyMealTypeV2.dinner => MealType.dinner.label,
    DailyMealTypeV2.snack => MealType.snack.label,
    DailyMealTypeV2.training => MealType.training.label,
    DailyMealTypeV2.water => 'Water',
  };

  static String _id(FoodMealIdGenerator generator) {
    final value = generator.generate();
    return value.startsWith('food:') ? value.substring(5) : value;
  }
}
