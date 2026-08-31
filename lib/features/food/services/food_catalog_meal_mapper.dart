import '../../../core/models/meal_data.dart';
import '../../../core/models/meal_type.dart';
import '../models/daily_meal_v2_models.dart';
import '../models/food_catalog_models.dart';
import '../models/food_provenance_models.dart';
import '../models/food_quantity_models.dart';
import '../models/nutrition_models.dart';
import '../models/recipe_models_v2.dart';
import '../repository/food_meal_id_generator.dart';
import 'food_recipe_nutrition.dart';

class FoodCatalogMealMapper {
  const FoodCatalogMealMapper._();

  static DailyMealV2 map({
    required MealData meal,
    required List<FoodCatalogEntry?> catalogSources,
    List<FoodRecipeDefinition?>? recipeSources,
    required String localDate,
    required DateTime timestamp,
    required FoodMealIdGenerator idGenerator,
  }) {
    final recipes = recipeSources ?? List.filled(meal.items.length, null);
    if (catalogSources.length != meal.items.length ||
        recipes.length != meal.items.length) {
      throw ArgumentError('FOOD sources must match FOOD items.');
    }
    final items = <DailyMealItemSnapshot>[];
    for (var index = 0; index < meal.items.length; index++) {
      final item = meal.items[index];
      final catalog = catalogSources[index];
      final recipe = recipes[index];
      if (catalog != null && recipe != null) {
        throw ArgumentError('A FOOD item cannot reference food and recipe.');
      }
      if (recipe != null) {
        final perServing = FoodRecipeNutrition.perServing(recipe);
        items.add(
          DailyMealItemSnapshot(
            mealItemId: _id(idGenerator),
            recipeReferenceId: recipe.recipeId,
            nameSnapshot: recipe.name,
            quantity: FoodRecipeNutrition.consumptionQuantity(
              recipe,
              item.multiplier,
            ),
            nutritionPerBase: perServing,
            nutritionConsumed: FoodRecipeNutrition.scale(
              perServing,
              item.multiplier,
            ),
            provenanceSnapshot: recipe.provenance,
            nutritionStatusSnapshot: recipe.nutritionStatus,
            sortOrder: index,
          ),
        );
        continue;
      }
      final quantity = catalog == null
          ? FoodQuantityDefinition(
              value: item.physicalAmount ?? item.quantity.toDouble(),
              unit: item.baseUnit == null
                  ? FoodQuantityUnit.serving
                  : item.baseUnit!.label == 'mL'
                  ? FoodQuantityUnit.milliliter
                  : FoodQuantityUnit.gram,
            )
          : FoodQuantityDefinition(
              value: item.hasMeasuredAmount
                  ? item.physicalAmount!
                  : catalog.baseQuantity.value * item.quantity,
              unit: catalog.baseQuantity.unit,
            );
      final perBase = NutritionSnapshot(
        calories: item.calories.toDouble(),
        protein: item.protein,
        fat: item.fat,
        carbohydrate: item.carbohydrate,
      );
      items.add(
        DailyMealItemSnapshot(
          mealItemId: _id(idGenerator),
          foodReferenceId: catalog?.foodId,
          nameSnapshot: item.name,
          brandSnapshot: catalog?.brand,
          category: catalog?.category,
          quantity: quantity,
          nutritionPerBase: perBase,
          nutritionConsumed: NutritionSnapshot(
            calories: item.totalCalories,
            protein: item.totalProtein,
            fat: item.totalFat,
            carbohydrate: item.totalCarbohydrate,
          ),
          provenanceSnapshot:
              catalog?.provenance ??
              FoodDataProvenance(
                sourceType: FoodProvenanceSourceType.userInput,
                capturedAt: timestamp,
              ),
          nutritionStatusSnapshot:
              catalog?.nutritionStatus ?? NutritionStatus.declared,
          sortOrder: index,
        ),
      );
    }
    return DailyMealV2(
      mealId: _id(idGenerator),
      localDate: localDate,
      mealType: DailyMealTypeV2.values.byName(
        MealType.fromLabel(meal.mealType).name,
      ),
      items: items,
      memo: meal.memo.trim().isEmpty ? null : meal.memo.trim(),
      createdAt: timestamp,
      updatedAt: timestamp,
    );
  }

  static String _id(FoodMealIdGenerator generator) {
    final value = generator.generate();
    return value.startsWith('food:') ? value.substring(5) : value;
  }
}
