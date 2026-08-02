import 'dart:math';

import '../../../core/services/daily_log_mutation_guard.dart';
import '../../repositories/app_repository_container.dart';
import '../models/daily_meal_v2_models.dart';
import '../models/food_catalog_models.dart';
import '../models/food_provenance_models.dart';
import '../models/food_quantity_models.dart';
import '../models/nutrition_models.dart';
import '../models/recipe_models_v2.dart';

class FoodApplicationService {
  FoodApplicationService._();

  static String newId() {
    final bytes = List<int>.generate(16, (_) => Random.secure().nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes
        .map((value) => value.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }

  static FoodDataProvenance provenance(
    FoodProvenanceSourceType sourceType, {
    String? sourceName,
    String? sourceReference,
    DateTime? sourceUpdatedAt,
    String? notes,
  }) => FoodDataProvenance(
    sourceType: sourceType,
    sourceName: _nullable(sourceName),
    sourceReference: _nullable(sourceReference),
    capturedAt: DateTime.now().toUtc(),
    sourceUpdatedAt: sourceUpdatedAt?.toUtc(),
    notes: _nullable(notes),
  );

  static NutritionSnapshot recipeNutrition(
    Iterable<RecipeIngredientV2> ingredients,
  ) {
    final values = ingredients.map((value) => value.nutritionSnapshot).toList();
    double? sum(double? Function(NutritionSnapshot value) select) {
      final known = values.map(select).whereType<double>().toList();
      return known.isEmpty
          ? null
          : known.fold<double>(0, (sum, value) => sum + value);
    }

    return NutritionSnapshot(
      calories: sum((value) => value.calories),
      protein: sum((value) => value.protein),
      fat: sum((value) => value.fat),
      carbohydrate: sum((value) => value.carbohydrate),
    );
  }

  static FoodNutritionCalculation calculateConsumed({
    required FoodQuantityDefinition base,
    required FoodQuantityDefinition consumed,
    required NutritionSnapshot nutritionPerBase,
  }) {
    final multiplier = _multiplier(base, consumed);
    if (multiplier == null) {
      return const FoodNutritionCalculation(multiplier: null, nutrition: null);
    }
    double? scale(double? value) => value == null ? null : value * multiplier;
    return FoodNutritionCalculation(
      multiplier: multiplier,
      nutrition: NutritionSnapshot(
        calories: scale(nutritionPerBase.calories),
        protein: scale(nutritionPerBase.protein),
        fat: scale(nutritionPerBase.fat),
        carbohydrate: scale(nutritionPerBase.carbohydrate),
      ),
    );
  }

  static double? _multiplier(
    FoodQuantityDefinition base,
    FoodQuantityDefinition consumed,
  ) {
    if (base.unit == consumed.unit) return consumed.value / base.value;
    final consumedPhysical = consumed.basisValue == null
        ? null
        : consumed.value * consumed.basisValue!;
    if (consumedPhysical != null && consumed.basisUnit == base.unit) {
      return consumedPhysical / base.value;
    }
    if (base.unit == FoodQuantityUnit.serving &&
        consumed.unit == FoodQuantityUnit.serving) {
      return consumed.value / base.value;
    }
    return null;
  }

  static DailyMealItemSnapshot itemFromCatalog(
    FoodCatalogEntry catalog,
    FoodQuantityDefinition quantity,
    int sortOrder,
  ) {
    final calculated = calculateConsumed(
      base: catalog.baseQuantity,
      consumed: quantity,
      nutritionPerBase: catalog.nutrition,
    );
    return DailyMealItemSnapshot(
      mealItemId: newId(),
      foodReferenceId: catalog.foodId,
      nameSnapshot: catalog.name,
      brandSnapshot: catalog.brand,
      category: catalog.category,
      quantity: quantity,
      nutritionPerBase: catalog.nutrition,
      nutritionConsumed: calculated.nutrition ?? NutritionSnapshot(),
      provenanceSnapshot: catalog.provenance,
      nutritionStatusSnapshot: calculated.nutrition == null
          ? NutritionStatus.unknown
          : catalog.nutritionStatus,
      sortOrder: sortOrder,
    );
  }

  static DailyMealItemSnapshot itemFromRecipe(
    FoodRecipeDefinition recipe,
    FoodQuantityDefinition quantity,
    int sortOrder,
  ) {
    final calculated = calculateConsumed(
      base: recipe.yieldQuantity,
      consumed: quantity,
      nutritionPerBase: recipe.nutrition,
    );
    return DailyMealItemSnapshot(
      mealItemId: newId(),
      recipeReferenceId: recipe.recipeId,
      nameSnapshot: recipe.name,
      quantity: quantity,
      nutritionPerBase: recipe.nutrition,
      nutritionConsumed: calculated.nutrition ?? NutritionSnapshot(),
      provenanceSnapshot: recipe.provenance,
      nutritionStatusSnapshot: calculated.nutrition == null
          ? NutritionStatus.unknown
          : recipe.nutritionStatus,
      sortOrder: sortOrder,
    );
  }

  static Future<void> createMeal(DailyMealV2 meal) async {
    await DailyLogMutationGuard.assertDateMutable(
      DateTime.parse(meal.localDate),
    );
    await AppRepositoryRegistry.container.dailyMealsV2.create(meal);
    final stored = await AppRepositoryRegistry.container.dailyMealsV2.readById(
      meal.mealId,
    );
    if (stored == null) throw StateError('Daily Meal v2 read-back failed.');
  }

  static Future<void> updateMeal(DailyMealV2 meal) async {
    await DailyLogMutationGuard.assertDateMutable(
      DateTime.parse(meal.localDate),
    );
    await AppRepositoryRegistry.container.dailyMealsV2.update(meal);
    final stored = await AppRepositoryRegistry.container.dailyMealsV2.readById(
      meal.mealId,
    );
    if (stored == null) throw StateError('Daily Meal v2 read-back failed.');
  }

  static String? _nullable(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}

class FoodNutritionCalculation {
  final double? multiplier;
  final NutritionSnapshot? nutrition;

  const FoodNutritionCalculation({
    required this.multiplier,
    required this.nutrition,
  });
}
