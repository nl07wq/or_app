import 'food_v2_json.dart';

enum FoodQuantityUnit {
  gram,
  milliliter,
  piece,
  pack,
  serving;

  String get stableId => name;

  bool get isPhysical => this == gram || this == milliliter;

  static FoodQuantityUnit fromStableId(String value) {
    try {
      return values.byName(value);
    } on ArgumentError {
      throw FormatException('Unknown FOOD quantity unit: $value.');
    }
  }
}

/// Versioned Meal-entry interpretation for the two usage controls.  Older
/// formal records have no marker and retain their stored consumed nutrition.
enum FoodMealQuantitySemantics {
  legacyDivision,
  multiplicativeV21;

  String get stableId => name;

  static FoodMealQuantitySemantics fromStableId(String value) {
    try {
      return values.byName(value);
    } on ArgumentError {
      throw FormatException('Unknown FOOD quantity semantics: $value.');
    }
  }
}

/// Shared V2.1 Meal usage calculation.  Registered basis remains immutable;
/// both editor controls contribute positively to the consumed total.
abstract final class FoodMealUsage {
  static double totalUsedUnits({
    required double usedAmount,
    required double quantity,
  }) {
    _validatePositive(usedAmount, 'usedAmount');
    _validatePositive(quantity, 'quantity');
    return usedAmount * quantity;
  }

  static double nutritionMultiplier({
    required double usedAmount,
    required double quantity,
    required double registeredBasisAmount,
  }) {
    _validatePositive(registeredBasisAmount, 'registeredBasisAmount');
    return totalUsedUnits(usedAmount: usedAmount, quantity: quantity) /
        registeredBasisAmount;
  }

  static void _validatePositive(double value, String name) {
    if (!value.isFinite || value <= 0) {
      throw ArgumentError.value(value, name, 'Must be positive and finite.');
    }
  }
}

class FoodQuantityDefinition {
  static const _fields = {'value', 'unit', 'basisValue', 'basisUnit'};

  final double value;
  final FoodQuantityUnit unit;
  final double? basisValue;
  final FoodQuantityUnit? basisUnit;

  FoodQuantityDefinition({
    required this.value,
    required this.unit,
    this.basisValue,
    this.basisUnit,
  }) {
    if (!value.isFinite || value <= 0) {
      throw ArgumentError.value(value, 'value', 'Quantity must be positive.');
    }
    if (unit.isPhysical && (basisValue != null || basisUnit != null)) {
      throw ArgumentError.value(unit, 'unit', 'Physical units have no basis.');
    }
    if ((basisValue == null) != (basisUnit == null)) {
      throw ArgumentError(
        'basisValue and basisUnit must be provided together.',
      );
    }
    if (basisValue != null && (!basisValue!.isFinite || basisValue! <= 0)) {
      throw ArgumentError.value(basisValue, 'basisValue');
    }
    if (basisUnit != null && !basisUnit!.isPhysical) {
      throw ArgumentError.value(basisUnit, 'basisUnit');
    }
  }

  Map<String, Object?> toJson() => {
    'value': value,
    'unit': unit.stableId,
    'basisValue': basisValue,
    'basisUnit': basisUnit?.stableId,
  };

  factory FoodQuantityDefinition.fromJson(Map<String, Object?> json) {
    rejectUnknownFields(json, _fields, 'FOOD quantity');
    final unit = requireString(json, 'unit', 'FOOD quantity');
    final basisUnit = requireNullableString(json, 'basisUnit', 'FOOD quantity');
    return FoodQuantityDefinition(
      value: requireNumber(json, 'value', 'FOOD quantity'),
      unit: FoodQuantityUnit.fromStableId(unit),
      basisValue: requireNullableNumber(json, 'basisValue', 'FOOD quantity'),
      basisUnit: basisUnit == null
          ? null
          : FoodQuantityUnit.fromStableId(basisUnit),
    );
  }
}
