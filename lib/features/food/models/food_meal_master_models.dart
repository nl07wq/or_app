import 'food_quantity_models.dart';
import 'food_v2_json.dart';

enum FoodMealMasterComponentType {
  food,
  recipe;

  String get stableId => name;

  static FoodMealMasterComponentType fromStableId(String value) {
    try {
      return values.byName(value);
    } on ArgumentError {
      throw FormatException('Unknown MEAL component type: $value.');
    }
  }
}

class FoodMealMasterComponent {
  static const _fields = {
    'componentId',
    'componentType',
    'foodReferenceId',
    'recipeReferenceId',
    'quantity',
    'sortOrder',
  };

  final String componentId;
  final FoodMealMasterComponentType componentType;
  final String? foodReferenceId;
  final String? recipeReferenceId;
  final FoodQuantityDefinition quantity;
  final int sortOrder;

  FoodMealMasterComponent({
    required this.componentId,
    required this.componentType,
    this.foodReferenceId,
    this.recipeReferenceId,
    required this.quantity,
    required this.sortOrder,
  }) {
    validateStableId(componentId, 'componentId');
    if (sortOrder < 0) throw ArgumentError.value(sortOrder, 'sortOrder');
    switch (componentType) {
      case FoodMealMasterComponentType.food:
        if (foodReferenceId == null || recipeReferenceId != null) {
          throw ArgumentError('FOOD component requires only foodReferenceId.');
        }
        validateStableId(foodReferenceId!, 'foodReferenceId');
      case FoodMealMasterComponentType.recipe:
        if (recipeReferenceId == null || foodReferenceId != null) {
          throw ArgumentError(
            'RECIPE component requires only recipeReferenceId.',
          );
        }
        validateStableId(recipeReferenceId!, 'recipeReferenceId');
    }
  }

  Map<String, Object?> toJson() => {
    'componentId': componentId,
    'componentType': componentType.stableId,
    'foodReferenceId': foodReferenceId,
    'recipeReferenceId': recipeReferenceId,
    'quantity': quantity.toJson(),
    'sortOrder': sortOrder,
  };

  factory FoodMealMasterComponent.fromJson(Map<String, Object?> json) {
    rejectUnknownFields(json, _fields, 'FOOD MEAL component');
    return FoodMealMasterComponent(
      componentId: requireString(json, 'componentId', 'FOOD MEAL component'),
      componentType: FoodMealMasterComponentType.fromStableId(
        requireString(json, 'componentType', 'FOOD MEAL component'),
      ),
      foodReferenceId: requireNullableString(
        json,
        'foodReferenceId',
        'FOOD MEAL component',
      ),
      recipeReferenceId: requireNullableString(
        json,
        'recipeReferenceId',
        'FOOD MEAL component',
      ),
      quantity: FoodQuantityDefinition.fromJson(
        requireMap(json, 'quantity', 'FOOD MEAL component'),
      ),
      sortOrder: requireInt(json, 'sortOrder', 'FOOD MEAL component'),
    );
  }
}

class FoodMealMaster {
  static const recordVersion1 = 1;
  static const _fields = {
    'mealMasterId',
    'recordVersion',
    'name',
    'memo',
    'components',
    'isArchived',
    'createdAt',
    'updatedAt',
  };

  final String mealMasterId;
  final int recordVersion;
  final String name;
  final String? memo;
  final List<FoodMealMasterComponent> components;
  final bool isArchived;
  final DateTime createdAt;
  final DateTime updatedAt;

  FoodMealMaster({
    required this.mealMasterId,
    this.recordVersion = recordVersion1,
    required this.name,
    this.memo,
    required List<FoodMealMasterComponent> components,
    required this.isArchived,
    required this.createdAt,
    required this.updatedAt,
  }) : components = List.unmodifiable(components) {
    validateStableId(mealMasterId, 'mealMasterId');
    if (recordVersion != recordVersion1) {
      throw ArgumentError.value(recordVersion, 'recordVersion');
    }
    validateRequiredText(name, 'name');
    if (this.components.isEmpty) {
      throw ArgumentError.value(components, 'components');
    }
    final ids = <String>{};
    final orders = <int>{};
    for (final component in this.components) {
      if (!ids.add(component.componentId)) {
        throw ArgumentError('componentId values must be unique.');
      }
      if (!orders.add(component.sortOrder)) {
        throw ArgumentError('sortOrder values must be unique.');
      }
    }
    validateTimestamps(createdAt, updatedAt);
  }

  Map<String, Object?> toJson() => {
    'mealMasterId': mealMasterId,
    'recordVersion': recordVersion,
    'name': name,
    'memo': memo,
    'components': components.map((value) => value.toJson()).toList(),
    'isArchived': isArchived,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory FoodMealMaster.fromJson(Map<String, Object?> json) {
    rejectUnknownFields(json, _fields, 'FOOD MEAL master');
    final raw = requireList(json, 'components', 'FOOD MEAL master');
    return FoodMealMaster(
      mealMasterId: requireString(json, 'mealMasterId', 'FOOD MEAL master'),
      recordVersion: requireInt(json, 'recordVersion', 'FOOD MEAL master'),
      name: requireString(json, 'name', 'FOOD MEAL master'),
      memo: requireNullableString(json, 'memo', 'FOOD MEAL master'),
      components: [
        for (final value in raw)
          if (value is Map)
            FoodMealMasterComponent.fromJson(Map<String, Object?>.from(value))
          else
            throw const FormatException('Invalid FOOD MEAL component.'),
      ],
      isArchived: requireBool(json, 'isArchived', 'FOOD MEAL master'),
      createdAt: requireUtcDateTime(json, 'createdAt', 'FOOD MEAL master'),
      updatedAt: requireUtcDateTime(json, 'updatedAt', 'FOOD MEAL master'),
    );
  }
}
