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

enum FoodVisualKey {
  meat,
  fish,
  egg,
  dairy,
  grain,
  vegetable,
  fruit,
  snack,
  drink,
  condiment,
  protein;

  String get stableId => name;

  static FoodVisualKey fromStableId(String value) {
    try {
      return values.byName(value);
    } on ArgumentError {
      throw FormatException('Unknown FOOD visual key: $value.');
    }
  }
}

enum FoodBarcodeFormat {
  ean13,
  ean8,
  upc,
  unknown;

  String get stableId => name;

  static FoodBarcodeFormat fromStableId(String value) {
    try {
      return values.byName(value);
    } on ArgumentError {
      throw FormatException('Unknown FOOD barcode format: $value.');
    }
  }
}

class FoodCatalogEntry {
  static const recordVersion1 = 1;
  static const recordVersion2 = 2;
  static const currentRecordVersion = recordVersion2;
  static const _version1Fields = {
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
  static const _version2Fields = {
    ..._version1Fields,
    'barcodeValue',
    'barcodeFormat',
    'packageQuantity',
    'packageUnit',
    'visualKey',
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
  final String? barcodeValue;
  final FoodBarcodeFormat? barcodeFormat;
  final double? packageQuantity;
  final FoodQuantityUnit? packageUnit;
  final FoodVisualKey? visualKey;
  final DateTime createdAt;
  final DateTime updatedAt;

  FoodCatalogEntry({
    required this.foodId,
    this.recordVersion = currentRecordVersion,
    required this.name,
    required this.category,
    this.brand,
    required this.baseQuantity,
    required this.nutrition,
    required this.nutritionStatus,
    required this.provenance,
    required this.isArchived,
    this.memo,
    this.barcodeValue,
    this.barcodeFormat,
    this.packageQuantity,
    this.packageUnit,
    this.visualKey,
    required this.createdAt,
    required this.updatedAt,
  }) {
    validateStableId(foodId, 'foodId');
    if (recordVersion != recordVersion1 && recordVersion != recordVersion2) {
      throw ArgumentError.value(recordVersion, 'recordVersion');
    }
    if (recordVersion == recordVersion1 &&
        (barcodeValue != null ||
            barcodeFormat != null ||
            packageQuantity != null ||
            packageUnit != null ||
            visualKey != null)) {
      throw ArgumentError('FOOD catalog v1 cannot contain v2 fields.');
    }
    if (barcodeValue != null &&
        (barcodeValue!.trim() != barcodeValue || barcodeValue!.isEmpty)) {
      throw ArgumentError.value(barcodeValue, 'barcodeValue');
    }
    if (barcodeValue == null && barcodeFormat != null) {
      throw ArgumentError('barcodeFormat requires barcodeValue.');
    }
    if ((packageQuantity == null) != (packageUnit == null)) {
      throw ArgumentError(
        'packageQuantity and packageUnit must be provided together.',
      );
    }
    if (packageQuantity != null &&
        (!packageQuantity!.isFinite || packageQuantity! <= 0)) {
      throw ArgumentError.value(packageQuantity, 'packageQuantity');
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
    if (recordVersion >= recordVersion2) ...{
      'barcodeValue': barcodeValue,
      'barcodeFormat': barcodeFormat?.stableId,
      'packageQuantity': packageQuantity,
      'packageUnit': packageUnit?.stableId,
      'visualKey': visualKey?.stableId,
    },
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory FoodCatalogEntry.fromJson(Map<String, Object?> json) {
    final version = requireInt(json, 'recordVersion', 'FOOD catalog');
    final fields = switch (version) {
      recordVersion1 => _version1Fields,
      recordVersion2 => _version2Fields,
      _ => throw FormatException(
        'Unsupported FOOD catalog recordVersion: $version.',
      ),
    };
    rejectUnknownFields(json, fields, 'FOOD catalog');
    final category = requireString(json, 'category', 'FOOD catalog');
    final status = requireString(json, 'nutritionStatus', 'FOOD catalog');
    return FoodCatalogEntry(
      foodId: requireString(json, 'foodId', 'FOOD catalog'),
      recordVersion: version,
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
      barcodeValue: version == recordVersion1
          ? null
          : requireNullableString(json, 'barcodeValue', 'FOOD catalog'),
      barcodeFormat: version == recordVersion1
          ? null
          : switch (requireNullableString(
              json,
              'barcodeFormat',
              'FOOD catalog',
            )) {
              final value? => FoodBarcodeFormat.fromStableId(value),
              null => null,
            },
      packageQuantity: version == recordVersion1
          ? null
          : requireNullableNumber(json, 'packageQuantity', 'FOOD catalog'),
      packageUnit: version == recordVersion1
          ? null
          : switch (requireNullableString(
              json,
              'packageUnit',
              'FOOD catalog',
            )) {
              final value? => FoodQuantityUnit.fromStableId(value),
              null => null,
            },
      visualKey: version == recordVersion1 || !json.containsKey('visualKey')
          ? null
          : switch (requireNullableString(json, 'visualKey', 'FOOD catalog')) {
              final value? => FoodVisualKey.fromStableId(value),
              null => null,
            },
      createdAt: requireUtcDateTime(json, 'createdAt', 'FOOD catalog'),
      updatedAt: requireUtcDateTime(json, 'updatedAt', 'FOOD catalog'),
    );
  }
}
