import 'food_catalog_models.dart';
import 'food_provenance_models.dart';
import 'food_quantity_models.dart';
import 'food_v2_json.dart';
import 'nutrition_models.dart';
import 'recipe_models_v2.dart';

enum DailyMealTypeV2 {
  breakfast,
  lunch,
  dinner,
  snack,
  training,
  water;

  String get stableId => name;

  static DailyMealTypeV2 fromStableId(String value) {
    try {
      return values.byName(value);
    } on ArgumentError {
      throw FormatException('Unknown FOOD meal type: $value.');
    }
  }
}

class DailyMealItemSnapshot {
  static const _fields = {
    'mealItemId',
    'foodReferenceId',
    'recipeReferenceId',
    'nameSnapshot',
    'brandSnapshot',
    'category',
    'quantity',
    'nutritionBasisQuantity',
    'usageSetAmount',
    'usageSetQuantity',
    'quantitySemantics',
    'recipeInstanceSnapshot',
    'nutritionPerBase',
    'nutritionConsumed',
    'provenanceSnapshot',
    'nutritionStatusSnapshot',
    'memo',
    'sortOrder',
  };

  final String mealItemId;
  final String? foodReferenceId;
  final String? recipeReferenceId;
  final String nameSnapshot;
  final String? brandSnapshot;
  final FoodCatalogCategory? category;
  final FoodQuantityDefinition quantity;

  /// The immutable amount against which [nutritionPerBase] was declared.
  /// Older records did not retain this separately and remain readable.
  final FoodQuantityDefinition? nutritionBasisQuantity;

  /// V2.1 preserves the two Meal-entry usage controls independently.  Missing
  /// values identify legacy records and must not be reinterpreted.
  final double? usageSetAmount;
  final double? usageSetQuantity;
  final FoodMealQuantitySemantics? quantitySemantics;

  /// A recipe is a reusable master.  This optional copy records the concrete
  /// ingredient instance used by this Meal, including any meal-only changes.
  final FoodRecipeDefinition? recipeInstanceSnapshot;
  final NutritionSnapshot nutritionPerBase;
  final NutritionSnapshot nutritionConsumed;
  final FoodDataProvenance provenanceSnapshot;
  final NutritionStatus nutritionStatusSnapshot;
  final String? memo;
  final int sortOrder;

  DailyMealItemSnapshot({
    required this.mealItemId,
    this.foodReferenceId,
    this.recipeReferenceId,
    required this.nameSnapshot,
    this.brandSnapshot,
    this.category,
    required this.quantity,
    this.nutritionBasisQuantity,
    this.usageSetAmount,
    this.usageSetQuantity,
    this.quantitySemantics,
    this.recipeInstanceSnapshot,
    required this.nutritionPerBase,
    required this.nutritionConsumed,
    required this.provenanceSnapshot,
    required this.nutritionStatusSnapshot,
    this.memo,
    required this.sortOrder,
  }) {
    validateStableId(mealItemId, 'mealItemId');
    if (foodReferenceId != null) {
      validateStableId(foodReferenceId!, 'foodReferenceId');
    }
    if (recipeReferenceId != null) {
      validateStableId(recipeReferenceId!, 'recipeReferenceId');
    }
    if (foodReferenceId != null && recipeReferenceId != null) {
      throw ArgumentError('FOOD item references are mutually exclusive.');
    }
    if (recipeInstanceSnapshot != null && recipeReferenceId == null) {
      throw ArgumentError(
        'Recipe instance snapshots require a recipe reference.',
      );
    }
    final usageFieldsPresent =
        usageSetAmount != null ||
        usageSetQuantity != null ||
        quantitySemantics != null;
    if (usageFieldsPresent &&
        (usageSetAmount == null ||
            usageSetQuantity == null ||
            quantitySemantics != FoodMealQuantitySemantics.multiplicativeV21)) {
      throw ArgumentError(
        'V2.1 FOOD usage fields must be complete and multiplicative.',
      );
    }
    if (usageSetAmount != null &&
        (!usageSetAmount!.isFinite ||
            usageSetAmount! <= 0 ||
            !usageSetQuantity!.isFinite ||
            usageSetQuantity! <= 0)) {
      throw ArgumentError('FOOD usage-set values must be positive and finite.');
    }
    validateRequiredText(nameSnapshot, 'nameSnapshot');
    validateNutritionStatus(nutritionPerBase, nutritionStatusSnapshot);
    validateNutritionStatus(nutritionConsumed, nutritionStatusSnapshot);
    if (sortOrder < 0) throw ArgumentError.value(sortOrder, 'sortOrder');
  }

  Map<String, Object?> toJson() => {
    'mealItemId': mealItemId,
    'foodReferenceId': foodReferenceId,
    'recipeReferenceId': recipeReferenceId,
    'nameSnapshot': nameSnapshot,
    'brandSnapshot': brandSnapshot,
    'category': category?.stableId,
    'quantity': quantity.toJson(),
    'nutritionBasisQuantity': nutritionBasisQuantity?.toJson(),
    'usageSetAmount': usageSetAmount,
    'usageSetQuantity': usageSetQuantity,
    'quantitySemantics': quantitySemantics?.stableId,
    'recipeInstanceSnapshot': recipeInstanceSnapshot?.toJson(),
    'nutritionPerBase': nutritionPerBase.toJson(),
    'nutritionConsumed': nutritionConsumed.toJson(),
    'provenanceSnapshot': provenanceSnapshot.toJson(),
    'nutritionStatusSnapshot': nutritionStatusSnapshot.stableId,
    'memo': memo,
    'sortOrder': sortOrder,
  };

  factory DailyMealItemSnapshot.fromJson(Map<String, Object?> json) {
    rejectUnknownFields(json, _fields, 'FOOD meal item');
    final category = requireNullableString(json, 'category', 'FOOD meal item');
    final status = requireString(
      json,
      'nutritionStatusSnapshot',
      'FOOD meal item',
    );
    return DailyMealItemSnapshot(
      mealItemId: requireString(json, 'mealItemId', 'FOOD meal item'),
      foodReferenceId: requireNullableString(
        json,
        'foodReferenceId',
        'FOOD meal item',
      ),
      recipeReferenceId: requireNullableString(
        json,
        'recipeReferenceId',
        'FOOD meal item',
      ),
      nameSnapshot: requireString(json, 'nameSnapshot', 'FOOD meal item'),
      brandSnapshot: requireNullableString(
        json,
        'brandSnapshot',
        'FOOD meal item',
      ),
      category: category == null
          ? null
          : FoodCatalogCategory.fromStableId(category),
      quantity: FoodQuantityDefinition.fromJson(
        requireMap(json, 'quantity', 'FOOD meal item'),
      ),
      nutritionBasisQuantity: json['nutritionBasisQuantity'] == null
          ? null
          : FoodQuantityDefinition.fromJson(
              requireMap(json, 'nutritionBasisQuantity', 'FOOD meal item'),
            ),
      // V2.1 fields are intentionally absent on historical snapshots.  Their
      // absence selects the preserved legacy interpretation rather than
      // changing a recorded Meal when it is read back.
      usageSetAmount: json['usageSetAmount'] == null
          ? null
          : requireNumber(json, 'usageSetAmount', 'FOOD meal item'),
      usageSetQuantity: json['usageSetQuantity'] == null
          ? null
          : requireNumber(json, 'usageSetQuantity', 'FOOD meal item'),
      quantitySemantics: json['quantitySemantics'] == null
          ? null
          : FoodMealQuantitySemantics.fromStableId(
              requireString(json, 'quantitySemantics', 'FOOD meal item'),
            ),
      recipeInstanceSnapshot: json['recipeInstanceSnapshot'] == null
          ? null
          : FoodRecipeDefinition.fromJson(
              requireMap(json, 'recipeInstanceSnapshot', 'FOOD meal item'),
            ),
      nutritionPerBase: NutritionSnapshot.fromJson(
        requireMap(json, 'nutritionPerBase', 'FOOD meal item'),
      ),
      nutritionConsumed: NutritionSnapshot.fromJson(
        requireMap(json, 'nutritionConsumed', 'FOOD meal item'),
      ),
      provenanceSnapshot: FoodDataProvenance.fromJson(
        requireMap(json, 'provenanceSnapshot', 'FOOD meal item'),
      ),
      nutritionStatusSnapshot: NutritionStatus.fromStableId(status),
      memo: requireNullableString(json, 'memo', 'FOOD meal item'),
      sortOrder: requireInt(json, 'sortOrder', 'FOOD meal item'),
    );
  }
}

class DailyMealV2 {
  static const recordVersion2 = 2;
  static const _fields = {
    'mealId',
    'recordVersion',
    'localDate',
    'mealType',
    'items',
    'memo',
    'waterMl',
    'createdAt',
    'updatedAt',
  };

  final String mealId;
  final int recordVersion;
  final String localDate;
  final DailyMealTypeV2 mealType;
  final List<DailyMealItemSnapshot> items;
  final String? memo;
  final double? waterMl;
  final DateTime createdAt;
  final DateTime updatedAt;

  DailyMealV2({
    required this.mealId,
    this.recordVersion = recordVersion2,
    required this.localDate,
    required this.mealType,
    required List<DailyMealItemSnapshot> items,
    this.memo,
    this.waterMl,
    required this.createdAt,
    required this.updatedAt,
  }) : items = List.unmodifiable(items) {
    validateStableId(mealId, 'mealId');
    if (recordVersion != recordVersion2) {
      throw ArgumentError.value(recordVersion, 'recordVersion');
    }
    validateLocalDate(localDate);
    if (waterMl != null && (!waterMl!.isFinite || waterMl! <= 0)) {
      throw ArgumentError.value(waterMl, 'waterMl');
    }
    if (mealType == DailyMealTypeV2.water) {
      if (this.items.isNotEmpty || waterMl == null) {
        throw ArgumentError(
          'Water meals require empty items and positive waterMl.',
        );
      }
    } else if (this.items.isEmpty) {
      throw ArgumentError.value(
        items,
        'items',
        'Non-water meals require items.',
      );
    }
    _validateUnique(this.items.map((value) => value.mealItemId), 'mealItemId');
    _validateUnique(this.items.map((value) => value.sortOrder), 'sortOrder');
    validateTimestamps(createdAt, updatedAt);
  }

  Map<String, Object?> toJson() => {
    'mealId': mealId,
    'recordVersion': recordVersion,
    'localDate': localDate,
    'mealType': mealType.stableId,
    'items': items.map((value) => value.toJson()).toList(),
    'memo': memo,
    'waterMl': waterMl,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory DailyMealV2.fromJson(Map<String, Object?> json) {
    rejectUnknownFields(json, _fields, 'FOOD daily meal');
    final mealType = requireString(json, 'mealType', 'FOOD daily meal');
    final rawItems = requireList(json, 'items', 'FOOD daily meal');
    final items = rawItems.map((value) {
      if (value is! Map) throw const FormatException('Invalid FOOD meal item.');
      return DailyMealItemSnapshot.fromJson(Map<String, Object?>.from(value));
    }).toList();
    return DailyMealV2(
      mealId: requireString(json, 'mealId', 'FOOD daily meal'),
      recordVersion: requireInt(json, 'recordVersion', 'FOOD daily meal'),
      localDate: requireString(json, 'localDate', 'FOOD daily meal'),
      mealType: DailyMealTypeV2.fromStableId(mealType),
      items: items,
      memo: requireNullableString(json, 'memo', 'FOOD daily meal'),
      waterMl: requireNullableNumber(json, 'waterMl', 'FOOD daily meal'),
      createdAt: requireUtcDateTime(json, 'createdAt', 'FOOD daily meal'),
      updatedAt: requireUtcDateTime(json, 'updatedAt', 'FOOD daily meal'),
    );
  }

  static void _validateUnique(Iterable<Object> values, String name) {
    final seen = <Object>{};
    if (values.any((value) => !seen.add(value))) {
      throw ArgumentError('$name values must be unique.');
    }
  }
}
