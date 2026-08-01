import 'food_v2_json.dart';

enum NutritionStatus {
  verified,
  declared,
  calculated,
  estimated,
  unknown;

  String get stableId => name;

  static NutritionStatus fromStableId(String value) {
    try {
      return values.byName(value);
    } on ArgumentError {
      throw FormatException('Unknown FOOD nutrition status: $value.');
    }
  }
}

class NutritionSnapshot {
  static const _fields = {'calories', 'protein', 'fat', 'carbohydrate'};

  final double? calories;
  final double? protein;
  final double? fat;
  final double? carbohydrate;

  NutritionSnapshot({
    this.calories,
    this.protein,
    this.fat,
    this.carbohydrate,
  }) {
    for (final entry in {
      'calories': calories,
      'protein': protein,
      'fat': fat,
      'carbohydrate': carbohydrate,
    }.entries) {
      final value = entry.value;
      if (value != null && (!value.isFinite || value < 0)) {
        throw ArgumentError.value(value, entry.key, 'Invalid nutrition value.');
      }
    }
  }

  bool get isEmpty =>
      calories == null &&
      protein == null &&
      fat == null &&
      carbohydrate == null;

  Map<String, Object?> toJson() => {
    'calories': calories,
    'protein': protein,
    'fat': fat,
    'carbohydrate': carbohydrate,
  };

  factory NutritionSnapshot.fromJson(Map<String, Object?> json) {
    rejectUnknownFields(json, _fields, 'FOOD nutrition');
    return NutritionSnapshot(
      calories: requireNullableNumber(json, 'calories', 'FOOD nutrition'),
      protein: requireNullableNumber(json, 'protein', 'FOOD nutrition'),
      fat: requireNullableNumber(json, 'fat', 'FOOD nutrition'),
      carbohydrate: requireNullableNumber(
        json,
        'carbohydrate',
        'FOOD nutrition',
      ),
    );
  }
}

void validateNutritionStatus(
  NutritionSnapshot nutrition,
  NutritionStatus status,
) {
  if (nutrition.isEmpty && status != NutritionStatus.unknown) {
    throw ArgumentError.value(
      status,
      'nutritionStatus',
      'Empty nutrition requires unknown status.',
    );
  }
}
