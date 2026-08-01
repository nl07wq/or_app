import 'food_provenance_models.dart';
import 'food_quantity_models.dart';
import 'food_v2_json.dart';
import 'nutrition_models.dart';

enum FoodCatalogCategory {
  ingredient,
  preparedFood,
  packagedFood,
  beverage;

  String get stableId => name;

  static FoodCatalogCategory fromStableId(String value) {
    try {
      return values.byName(value);
    } on ArgumentError {
      throw FormatException('Unknown FOOD catalog category: $value.');
    }
  }
}

class FoodCatalogEntry {
  static const recordVersion1 = 1;
  static const _fields = {
    'foodId',
    'recordVersion',
    'name',
    'category',
    'brand',
    'baseQuantity',
    'nutrition',
    'nutritionStatus',
    'provenance',
    'isArchived',
    'memo',
    'createdAt',
    'updatedAt',
  };

  final String foodId;
  final int recordVersion;
  final String name;
  final FoodCatalogCategory category;
  final String? brand;
  final FoodQuantityDefinition baseQuantity;
  final NutritionSnapshot nutrition;
  final NutritionStatus nutritionStatus;
  final FoodDataProvenance provenance;
  final bool isArchived;
  final String? memo;
  final DateTime createdAt;
  final DateTime updatedAt;

  FoodCatalogEntry({
    required this.foodId,
    this.recordVersion = recordVersion1,
    required this.name,
    required this.category,
    this.brand,
    required this.baseQuantity,
    required this.nutrition,
    required this.nutritionStatus,
    required this.provenance,
    required this.isArchived,
    this.memo,
    required this.createdAt,
    required this.updatedAt,
  }) {
    validateStableId(foodId, 'foodId');
    if (recordVersion != recordVersion1) {
      throw ArgumentError.value(recordVersion, 'recordVersion');
    }
    validateRequiredText(name, 'name');
    validateNutritionStatus(nutrition, nutritionStatus);
    validateTimestamps(createdAt, updatedAt);
  }

  Map<String, Object?> toJson() => {
    'foodId': foodId,
    'recordVersion': recordVersion,
    'name': name,
    'category': category.stableId,
    'brand': brand,
    'baseQuantity': baseQuantity.toJson(),
    'nutrition': nutrition.toJson(),
    'nutritionStatus': nutritionStatus.stableId,
    'provenance': provenance.toJson(),
    'isArchived': isArchived,
    'memo': memo,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory FoodCatalogEntry.fromJson(Map<String, Object?> json) {
    rejectUnknownFields(json, _fields, 'FOOD catalog');
    final category = requireString(json, 'category', 'FOOD catalog');
    final status = requireString(json, 'nutritionStatus', 'FOOD catalog');
    return FoodCatalogEntry(
      foodId: requireString(json, 'foodId', 'FOOD catalog'),
      recordVersion: requireInt(json, 'recordVersion', 'FOOD catalog'),
      name: requireString(json, 'name', 'FOOD catalog'),
      category: FoodCatalogCategory.fromStableId(category),
      brand: requireNullableString(json, 'brand', 'FOOD catalog'),
      baseQuantity: FoodQuantityDefinition.fromJson(
        requireMap(json, 'baseQuantity', 'FOOD catalog'),
      ),
      nutrition: NutritionSnapshot.fromJson(
        requireMap(json, 'nutrition', 'FOOD catalog'),
      ),
      nutritionStatus: NutritionStatus.fromStableId(status),
      provenance: FoodDataProvenance.fromJson(
        requireMap(json, 'provenance', 'FOOD catalog'),
      ),
      isArchived: requireBool(json, 'isArchived', 'FOOD catalog'),
      memo: requireNullableString(json, 'memo', 'FOOD catalog'),
      createdAt: requireUtcDateTime(json, 'createdAt', 'FOOD catalog'),
      updatedAt: requireUtcDateTime(json, 'updatedAt', 'FOOD catalog'),
    );
  }
}
