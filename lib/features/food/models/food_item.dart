enum FoodItemCategory { ingredient, preparedFood }

enum FoodUnit { g, ml, piece, pack, serving, halfSheet, teaspoonThird }

class FoodNutrition {
  final double calories;
  final double protein;
  final double fat;
  final double carbs;

  const FoodNutrition({
    required this.calories,
    required this.protein,
    required this.fat,
    required this.carbs,
  });

  FoodNutrition operator +(FoodNutrition other) {
    return FoodNutrition(
      calories: calories + other.calories,
      protein: protein + other.protein,
      fat: fat + other.fat,
      carbs: carbs + other.carbs,
    );
  }

  FoodNutrition scale(double multiplier) {
    if (!multiplier.isFinite || multiplier < 0) {
      throw ArgumentError.value(
        multiplier,
        'multiplier',
        'Multiplier must be finite and greater than or equal to zero.',
      );
    }

    return FoodNutrition(
      calories: calories * multiplier,
      protein: protein * multiplier,
      fat: fat * multiplier,
      carbs: carbs * multiplier,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is FoodNutrition &&
        other.calories == calories &&
        other.protein == protein &&
        other.fat == fat &&
        other.carbs == carbs;
  }

  @override
  int get hashCode => Object.hash(calories, protein, fat, carbs);
}

class FoodItem {
  final String id;
  final String name;
  final FoodItemCategory category;
  final double baseAmount;
  final FoodUnit baseUnit;
  final FoodNutrition nutritionAtBaseAmount;
  final DateTime createdAt;
  final DateTime updatedAt;

  FoodItem({
    required this.id,
    required this.name,
    required this.category,
    required this.baseAmount,
    required this.baseUnit,
    required this.nutritionAtBaseAmount,
    required this.createdAt,
    required this.updatedAt,
  }) {
    _validateNonEmpty(id, 'id');
    _validateNonEmpty(name, 'name');
    if (!baseAmount.isFinite || baseAmount <= 0) {
      throw ArgumentError.value(
        baseAmount,
        'baseAmount',
        'Base amount must be finite and greater than zero.',
      );
    }
  }

  FoodNutrition nutritionForAmount(double amount, FoodUnit unit) {
    if (unit != baseUnit) {
      throw ArgumentError.value(
        unit,
        'unit',
        'Amount unit must match the food item base unit.',
      );
    }
    if (!amount.isFinite || amount < 0) {
      throw ArgumentError.value(
        amount,
        'amount',
        'Amount must be finite and greater than or equal to zero.',
      );
    }

    return nutritionAtBaseAmount.scale(amount / baseAmount);
  }

  FoodItem copyWith({
    String? id,
    String? name,
    FoodItemCategory? category,
    double? baseAmount,
    FoodUnit? baseUnit,
    FoodNutrition? nutritionAtBaseAmount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FoodItem(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      baseAmount: baseAmount ?? this.baseAmount,
      baseUnit: baseUnit ?? this.baseUnit,
      nutritionAtBaseAmount:
          nutritionAtBaseAmount ?? this.nutritionAtBaseAmount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category': category.name,
      'baseAmount': baseAmount,
      'baseUnit': baseUnit.name,
      'nutritionAtBaseAmount': {
        'calories': nutritionAtBaseAmount.calories,
        'protein': nutritionAtBaseAmount.protein,
        'fat': nutritionAtBaseAmount.fat,
        'carbs': nutritionAtBaseAmount.carbs,
      },
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory FoodItem.fromJson(Map<String, dynamic> json) {
    final nutrition = Map<String, dynamic>.from(
      json['nutritionAtBaseAmount'] as Map,
    );

    return FoodItem(
      id: json['id'] as String,
      name: json['name'] as String,
      category: FoodItemCategory.values.byName(json['category'] as String),
      baseAmount: (json['baseAmount'] as num).toDouble(),
      baseUnit: FoodUnit.values.byName(json['baseUnit'] as String),
      nutritionAtBaseAmount: FoodNutrition(
        calories: (nutrition['calories'] as num).toDouble(),
        protein: (nutrition['protein'] as num).toDouble(),
        fat: (nutrition['fat'] as num).toDouble(),
        carbs: (nutrition['carbs'] as num).toDouble(),
      ),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is FoodItem &&
        other.id == id &&
        other.name == name &&
        other.category == category &&
        other.baseAmount == baseAmount &&
        other.baseUnit == baseUnit &&
        other.nutritionAtBaseAmount == nutritionAtBaseAmount &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    category,
    baseAmount,
    baseUnit,
    nutritionAtBaseAmount,
    createdAt,
    updatedAt,
  );

  static void _validateNonEmpty(String value, String name) {
    if (value.trim().isEmpty) {
      throw ArgumentError.value(value, name, 'Value must not be empty.');
    }
  }
}
