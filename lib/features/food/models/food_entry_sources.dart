import 'food_catalog_models.dart';
import 'food_provenance_models.dart';
import 'food_quantity_models.dart';
import 'nutrition_models.dart';
import 'recipe_models_v2.dart';

/// Per-item source context carried by the editor.  It is intentionally
/// separate from a Meal snapshot: changing a Meal must never mutate a catalog
/// or recipe master record.
class FoodEntrySources {
  FoodEntrySources({
    required List<FoodCatalogEntry?> catalogSources,
    required List<FoodRecipeDefinition?> recipeSources,
    required List<FoodQuantityUnit> quantityUnits,
    List<String?>? foodReferenceIds,
    List<String?>? recipeReferenceIds,
    List<String?>? mealItemIds,
    List<FoodDataProvenance?>? provenanceSnapshots,
    List<NutritionStatus?>? nutritionStatuses,
    List<String?>? brandSnapshots,
    List<FoodCatalogCategory?>? categories,
    List<String?>? memos,
  }) : catalogSources = List.unmodifiable(catalogSources),
       recipeSources = List.unmodifiable(recipeSources),
       quantityUnits = List.unmodifiable(quantityUnits),
       foodReferenceIds = List.unmodifiable(
         foodReferenceIds ?? catalogSources.map((value) => value?.foodId),
       ),
       recipeReferenceIds = List.unmodifiable(
         recipeReferenceIds ?? recipeSources.map((value) => value?.recipeId),
       ),
       mealItemIds = List.unmodifiable(
         mealItemIds ?? List<String?>.filled(quantityUnits.length, null),
       ),
       provenanceSnapshots = List.unmodifiable(
         provenanceSnapshots ??
             List<FoodDataProvenance?>.filled(quantityUnits.length, null),
       ),
       nutritionStatuses = List.unmodifiable(
         nutritionStatuses ??
             List<NutritionStatus?>.filled(quantityUnits.length, null),
       ),
       brandSnapshots = List.unmodifiable(
         brandSnapshots ?? List<String?>.filled(quantityUnits.length, null),
       ),
       categories = List.unmodifiable(
         categories ??
             List<FoodCatalogCategory?>.filled(quantityUnits.length, null),
       ),
       memos = List.unmodifiable(
         memos ?? List<String?>.filled(quantityUnits.length, null),
       ) {
    final length = quantityUnits.length;
    if ([
      this.catalogSources.length,
      this.recipeSources.length,
      this.foodReferenceIds.length,
      this.recipeReferenceIds.length,
      this.mealItemIds.length,
      this.provenanceSnapshots.length,
      this.nutritionStatuses.length,
      this.brandSnapshots.length,
      this.categories.length,
      this.memos.length,
    ].any((value) => value != length)) {
      throw ArgumentError('FOOD entry source lists must have the same length.');
    }
  }

  final List<FoodCatalogEntry?> catalogSources;
  final List<FoodRecipeDefinition?> recipeSources;
  final List<FoodQuantityUnit> quantityUnits;
  final List<String?> foodReferenceIds;
  final List<String?> recipeReferenceIds;
  final List<String?> mealItemIds;
  final List<FoodDataProvenance?> provenanceSnapshots;
  final List<NutritionStatus?> nutritionStatuses;
  final List<String?> brandSnapshots;
  final List<FoodCatalogCategory?> categories;
  final List<String?> memos;
}
