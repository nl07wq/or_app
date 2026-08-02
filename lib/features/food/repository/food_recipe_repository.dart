import '../models/recipe_models_v2.dart';

abstract interface class FoodRecipeRepository {
  Future<void> create(FoodRecipeDefinition recipe);
  Future<FoodRecipeDefinition?> readById(String recipeId);
  Future<List<FoodRecipeDefinition>> list();
  Future<void> update(FoodRecipeDefinition recipe);
  Future<void> archive(String recipeId);
}
