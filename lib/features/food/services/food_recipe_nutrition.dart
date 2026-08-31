import '../models/nutrition_models.dart';
import '../models/recipe_models_v2.dart';

abstract final class FoodRecipeNutrition {
  static NutritionSnapshot total(Iterable<RecipeIngredientV2> ingredients) {
    final values = ingredients
        .map((ingredient) => ingredient.nutritionSnapshot)
        .toList(growable: false);
    return NutritionSnapshot(
      calories: _sum(values.map((value) => value.calories)),
      protein: _sum(values.map((value) => value.protein)),
      fat: _sum(values.map((value) => value.fat)),
      carbohydrate: _sum(values.map((value) => value.carbohydrate)),
    );
  }

  static NutritionSnapshot scale(NutritionSnapshot source, double factor) {
    if (!factor.isFinite || factor <= 0) {
      throw ArgumentError.value(factor, 'factor');
    }
    double? scaled(double? value) => value == null ? null : value * factor;
    return NutritionSnapshot(
      calories: scaled(source.calories),
      protein: scaled(source.protein),
      fat: scaled(source.fat),
      carbohydrate: scaled(source.carbohydrate),
    );
  }

  static NutritionSnapshot perServing(FoodRecipeDefinition recipe) =>
      scale(recipe.nutrition, 1 / (recipe.servingCount ?? 1));

  static double? _sum(Iterable<double?> values) {
    var found = false;
    var total = 0.0;
    for (final value in values) {
      if (value == null) continue;
      found = true;
      total += value;
    }
    return found ? total : null;
  }
}
