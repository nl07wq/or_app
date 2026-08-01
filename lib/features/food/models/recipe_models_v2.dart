import 'food_provenance_models.dart';
import 'food_quantity_models.dart';
import 'food_v2_json.dart';
import 'nutrition_models.dart';

class RecipeIngredientV2 {
  static const _fields = {
    'ingredientId',
    'foodReferenceId',
    'nameSnapshot',
    'quantity',
    'nutritionSnapshot',
    'nutritionStatus',
    'provenanceSnapshot',
    'sortOrder',
  };

  final String ingredientId;
  final String? foodReferenceId;
  final String nameSnapshot;
  final FoodQuantityDefinition quantity;
  final NutritionSnapshot nutritionSnapshot;
  final NutritionStatus nutritionStatus;
  final FoodDataProvenance provenanceSnapshot;
  final int sortOrder;

  RecipeIngredientV2({
    required this.ingredientId,
    this.foodReferenceId,
    required this.nameSnapshot,
    required this.quantity,
    required this.nutritionSnapshot,
    required this.nutritionStatus,
    required this.provenanceSnapshot,
    required this.sortOrder,
  }) {
    validateStableId(ingredientId, 'ingredientId');
    if (foodReferenceId != null) {
      validateStableId(foodReferenceId!, 'foodReferenceId');
    }
    validateRequiredText(nameSnapshot, 'nameSnapshot');
    validateNutritionStatus(nutritionSnapshot, nutritionStatus);
    if (sortOrder < 0) throw ArgumentError.value(sortOrder, 'sortOrder');
  }

  Map<String, Object?> toJson() => {
    'ingredientId': ingredientId,
    'foodReferenceId': foodReferenceId,
    'nameSnapshot': nameSnapshot,
    'quantity': quantity.toJson(),
    'nutritionSnapshot': nutritionSnapshot.toJson(),
    'nutritionStatus': nutritionStatus.stableId,
    'provenanceSnapshot': provenanceSnapshot.toJson(),
    'sortOrder': sortOrder,
  };

  factory RecipeIngredientV2.fromJson(Map<String, Object?> json) {
    rejectUnknownFields(json, _fields, 'FOOD recipe ingredient');
    final status = requireString(
      json,
      'nutritionStatus',
      'FOOD recipe ingredient',
    );
    return RecipeIngredientV2(
      ingredientId: requireString(
        json,
        'ingredientId',
        'FOOD recipe ingredient',
      ),
      foodReferenceId: requireNullableString(
        json,
        'foodReferenceId',
        'FOOD recipe ingredient',
      ),
      nameSnapshot: requireString(
        json,
        'nameSnapshot',
        'FOOD recipe ingredient',
      ),
      quantity: FoodQuantityDefinition.fromJson(
        requireMap(json, 'quantity', 'FOOD recipe ingredient'),
      ),
      nutritionSnapshot: NutritionSnapshot.fromJson(
        requireMap(json, 'nutritionSnapshot', 'FOOD recipe ingredient'),
      ),
      nutritionStatus: NutritionStatus.fromStableId(status),
      provenanceSnapshot: FoodDataProvenance.fromJson(
        requireMap(json, 'provenanceSnapshot', 'FOOD recipe ingredient'),
      ),
      sortOrder: requireInt(json, 'sortOrder', 'FOOD recipe ingredient'),
    );
  }
}

class FoodRecipeDefinition {
  static const recordVersion1 = 1;
  static const _fields = {
    'recipeId',
    'recordVersion',
    'name',
    'ingredients',
    'yieldQuantity',
    'servingCount',
    'nutrition',
    'nutritionStatus',
    'provenance',
    'memo',
    'isArchived',
    'createdAt',
    'updatedAt',
  };

  final String recipeId;
  final int recordVersion;
  final String name;
  final List<RecipeIngredientV2> ingredients;
  final FoodQuantityDefinition yieldQuantity;
  final double? servingCount;
  final NutritionSnapshot nutrition;
  final NutritionStatus nutritionStatus;
  final FoodDataProvenance provenance;
  final String? memo;
  final bool isArchived;
  final DateTime createdAt;
  final DateTime updatedAt;

  FoodRecipeDefinition({
    required this.recipeId,
    this.recordVersion = recordVersion1,
    required this.name,
    required List<RecipeIngredientV2> ingredients,
    required this.yieldQuantity,
    this.servingCount,
    required this.nutrition,
    required this.nutritionStatus,
    required this.provenance,
    this.memo,
    required this.isArchived,
    required this.createdAt,
    required this.updatedAt,
  }) : ingredients = List.unmodifiable(ingredients) {
    validateStableId(recipeId, 'recipeId');
    if (recordVersion != recordVersion1) {
      throw ArgumentError.value(recordVersion, 'recordVersion');
    }
    validateRequiredText(name, 'name');
    if (this.ingredients.isEmpty) {
      throw ArgumentError.value(ingredients, 'ingredients');
    }
    _validateUnique(
      this.ingredients.map((value) => value.ingredientId),
      'ingredientId',
    );
    _validateUnique(
      this.ingredients.map((value) => value.sortOrder),
      'sortOrder',
    );
    if (servingCount != null &&
        (!servingCount!.isFinite || servingCount! <= 0)) {
      throw ArgumentError.value(servingCount, 'servingCount');
    }
    validateNutritionStatus(nutrition, nutritionStatus);
    validateTimestamps(createdAt, updatedAt);
  }

  Map<String, Object?> toJson() => {
    'recipeId': recipeId,
    'recordVersion': recordVersion,
    'name': name,
    'ingredients': ingredients.map((value) => value.toJson()).toList(),
    'yieldQuantity': yieldQuantity.toJson(),
    'servingCount': servingCount,
    'nutrition': nutrition.toJson(),
    'nutritionStatus': nutritionStatus.stableId,
    'provenance': provenance.toJson(),
    'memo': memo,
    'isArchived': isArchived,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory FoodRecipeDefinition.fromJson(Map<String, Object?> json) {
    rejectUnknownFields(json, _fields, 'FOOD recipe');
    final rawIngredients = requireList(json, 'ingredients', 'FOOD recipe');
    final ingredients = rawIngredients.map((value) {
      if (value is! Map) {
        throw const FormatException('Invalid FOOD recipe ingredient.');
      }
      return RecipeIngredientV2.fromJson(Map<String, Object?>.from(value));
    }).toList();
    final status = requireString(json, 'nutritionStatus', 'FOOD recipe');
    return FoodRecipeDefinition(
      recipeId: requireString(json, 'recipeId', 'FOOD recipe'),
      recordVersion: requireInt(json, 'recordVersion', 'FOOD recipe'),
      name: requireString(json, 'name', 'FOOD recipe'),
      ingredients: ingredients,
      yieldQuantity: FoodQuantityDefinition.fromJson(
        requireMap(json, 'yieldQuantity', 'FOOD recipe'),
      ),
      servingCount: requireNullableNumber(json, 'servingCount', 'FOOD recipe'),
      nutrition: NutritionSnapshot.fromJson(
        requireMap(json, 'nutrition', 'FOOD recipe'),
      ),
      nutritionStatus: NutritionStatus.fromStableId(status),
      provenance: FoodDataProvenance.fromJson(
        requireMap(json, 'provenance', 'FOOD recipe'),
      ),
      memo: requireNullableString(json, 'memo', 'FOOD recipe'),
      isArchived: requireBool(json, 'isArchived', 'FOOD recipe'),
      createdAt: requireUtcDateTime(json, 'createdAt', 'FOOD recipe'),
      updatedAt: requireUtcDateTime(json, 'updatedAt', 'FOOD recipe'),
    );
  }

  static void _validateUnique(Iterable<Object> values, String name) {
    final seen = <Object>{};
    if (values.any((value) => !seen.add(value))) {
      throw ArgumentError('$name values must be unique.');
    }
  }
}
