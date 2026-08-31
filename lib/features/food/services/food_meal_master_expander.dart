import '../../../core/models/food_item.dart';
import '../models/food_catalog_models.dart';
import '../models/food_meal_master_models.dart';
import '../models/food_quantity_models.dart';
import '../models/recipe_models_v2.dart';
import '../repository/food_catalog_repository.dart';
import '../repository/food_recipe_repository.dart';
import 'food_recipe_nutrition.dart';

class FoodMealMasterExpansion {
  const FoodMealMasterExpansion({
    required this.items,
    required this.foodSources,
    required this.recipeSources,
    required this.quantityUnits,
  });

  final List<FoodItem> items;
  final List<FoodCatalogEntry?> foodSources;
  final List<FoodRecipeDefinition?> recipeSources;
  final List<FoodQuantityUnit> quantityUnits;
}

class FoodMealMasterExpansionException implements Exception {
  const FoodMealMasterExpansionException(this.componentLabel);

  final String componentLabel;

  @override
  String toString() => 'UNAVAILABLE MEAL ITEM: $componentLabel';
}

class FoodMealMasterExpander {
  const FoodMealMasterExpander({required this.foods, required this.recipes});

  final FoodCatalogRepository foods;
  final FoodRecipeRepository recipes;

  Future<FoodMealMasterExpansion> expand(FoodMealMaster meal) async {
    final components = meal.components.toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final items = <FoodItem>[];
    final foodSources = <FoodCatalogEntry?>[];
    final recipeSources = <FoodRecipeDefinition?>[];
    final units = <FoodQuantityUnit>[];
    for (var index = 0; index < components.length; index++) {
      final component = components[index];
      switch (component.componentType) {
        case FoodMealMasterComponentType.food:
          final food = await foods.readById(component.foodReferenceId!);
          if (food == null || food.isArchived) {
            throw FoodMealMasterExpansionException(
              '${index + 1} FOOD ${component.foodReferenceId}',
            );
          }
          if (food.baseQuantity.unit != component.quantity.unit) {
            throw FoodMealMasterExpansionException(
              '${index + 1} ${food.name} UNIT MISMATCH',
            );
          }
          items.add(_foodItem(food, component.quantity));
          foodSources.add(food);
          recipeSources.add(null);
          units.add(component.quantity.unit);
        case FoodMealMasterComponentType.recipe:
          final recipe = await recipes.readById(component.recipeReferenceId!);
          if (recipe == null || recipe.isArchived) {
            throw FoodMealMasterExpansionException(
              '${index + 1} RECIPE ${component.recipeReferenceId}',
            );
          }
          items.add(_recipeItem(recipe, component.quantity));
          foodSources.add(null);
          recipeSources.add(recipe);
          units.add(component.quantity.unit);
      }
    }
    return FoodMealMasterExpansion(
      items: List.unmodifiable(items),
      foodSources: List.unmodifiable(foodSources),
      recipeSources: List.unmodifiable(recipeSources),
      quantityUnits: List.unmodifiable(units),
    );
  }

  static FoodItem _foodItem(
    FoodCatalogEntry food,
    FoodQuantityDefinition quantity,
  ) {
    final nutrition = food.nutrition;
    final values = [
      nutrition.calories,
      nutrition.protein,
      nutrition.fat,
      nutrition.carbohydrate,
    ];
    if (values.any((value) => value == null)) {
      throw FoodMealMasterExpansionException('${food.name} NUTRITION');
    }
    return FoodItem(
      name: food.name,
      calories: nutrition.calories!,
      protein: nutrition.protein!,
      fat: nutrition.fat!,
      carbohydrate: nutrition.carbohydrate!,
      amount: quantity.value,
      baseAmount: food.baseQuantity.value,
      baseUnit: food.baseQuantity.unit == FoodQuantityUnit.milliliter
          ? FoodBaseUnit.ml
          : FoodBaseUnit.g,
      amountMode: FoodAmountMode.physicalAmount,
    );
  }

  static FoodItem _recipeItem(
    FoodRecipeDefinition recipe,
    FoodQuantityDefinition quantity,
  ) {
    final perServing = FoodRecipeNutrition.perServing(recipe);
    final values = [
      perServing.calories,
      perServing.protein,
      perServing.fat,
      perServing.carbohydrate,
    ];
    if (values.any((value) => value == null)) {
      throw FoodMealMasterExpansionException('${recipe.name} NUTRITION');
    }
    final multiplier = _recipeMultiplier(recipe, quantity);
    return FoodItem(
      name: recipe.name,
      calories: perServing.calories!,
      protein: perServing.protein!,
      fat: perServing.fat!,
      carbohydrate: perServing.carbohydrate!,
      amount: multiplier,
      baseAmount: 1,
      baseUnit: FoodBaseUnit.g,
      amountMode: FoodAmountMode.baseMultiplier,
    );
  }

  static double _recipeMultiplier(
    FoodRecipeDefinition recipe,
    FoodQuantityDefinition quantity,
  ) {
    if (quantity.unit == FoodQuantityUnit.serving) return quantity.value;
    if (quantity.unit != recipe.yieldQuantity.unit) {
      throw FoodMealMasterExpansionException('${recipe.name} UNIT MISMATCH');
    }
    final perServing = recipe.yieldQuantity.value / (recipe.servingCount ?? 1);
    return quantity.value / perServing;
  }
}
