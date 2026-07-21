import 'food_item.dart';

class RecipeIngredient {
  final String foodItemId;
  final double amount;
  final FoodUnit unit;

  RecipeIngredient({
    required this.foodItemId,
    required this.amount,
    required this.unit,
  }) {
    if (foodItemId.trim().isEmpty) {
      throw ArgumentError.value(
        foodItemId,
        'foodItemId',
        'Food item ID must not be empty.',
      );
    }
    if (!amount.isFinite || amount <= 0) {
      throw ArgumentError.value(
        amount,
        'amount',
        'Amount must be finite and greater than zero.',
      );
    }
  }

  RecipeIngredient copyWith({
    String? foodItemId,
    double? amount,
    FoodUnit? unit,
  }) {
    return RecipeIngredient(
      foodItemId: foodItemId ?? this.foodItemId,
      amount: amount ?? this.amount,
      unit: unit ?? this.unit,
    );
  }

  Map<String, dynamic> toJson() {
    return {'foodItemId': foodItemId, 'amount': amount, 'unit': unit.name};
  }

  factory RecipeIngredient.fromJson(Map<String, dynamic> json) {
    return RecipeIngredient(
      foodItemId: json['foodItemId'] as String,
      amount: (json['amount'] as num).toDouble(),
      unit: FoodUnit.values.byName(json['unit'] as String),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is RecipeIngredient &&
        other.foodItemId == foodItemId &&
        other.amount == amount &&
        other.unit == unit;
  }

  @override
  int get hashCode => Object.hash(foodItemId, amount, unit);
}

class Recipe {
  final String id;
  final String name;
  final double baseAmount;
  final FoodUnit baseUnit;
  final List<RecipeIngredient> ingredients;
  final DateTime createdAt;
  final DateTime updatedAt;

  Recipe({
    required this.id,
    required this.name,
    required this.baseAmount,
    required this.baseUnit,
    required List<RecipeIngredient> ingredients,
    required this.createdAt,
    required this.updatedAt,
  }) : ingredients = List.unmodifiable(ingredients) {
    if (id.trim().isEmpty) {
      throw ArgumentError.value(id, 'id', 'ID must not be empty.');
    }
    if (name.trim().isEmpty) {
      throw ArgumentError.value(name, 'name', 'Name must not be empty.');
    }
    if (!baseAmount.isFinite || baseAmount <= 0) {
      throw ArgumentError.value(
        baseAmount,
        'baseAmount',
        'Base amount must be finite and greater than zero.',
      );
    }
  }

  FoodNutrition nutritionForItemsById(Map<String, FoodItem> itemsById) {
    return ingredients.fold(
      const FoodNutrition(calories: 0, protein: 0, fat: 0, carbs: 0),
      (total, ingredient) {
        final item = itemsById[ingredient.foodItemId];
        if (item == null) {
          throw StateError(
            'Food item ${ingredient.foodItemId} is required to calculate recipe nutrition.',
          );
        }
        return total +
            item.nutritionForAmount(ingredient.amount, ingredient.unit);
      },
    );
  }

  FoodNutrition nutritionForAmount(
    Map<String, FoodItem> itemsById,
    double amount,
    FoodUnit unit,
  ) {
    if (unit != baseUnit) {
      throw ArgumentError.value(
        unit,
        'unit',
        'Amount unit must match the recipe base unit.',
      );
    }
    if (!amount.isFinite || amount < 0) {
      throw ArgumentError.value(
        amount,
        'amount',
        'Amount must be finite and greater than or equal to zero.',
      );
    }

    return nutritionForItemsById(itemsById).scale(amount / baseAmount);
  }

  Recipe copyWith({
    String? id,
    String? name,
    double? baseAmount,
    FoodUnit? baseUnit,
    List<RecipeIngredient>? ingredients,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Recipe(
      id: id ?? this.id,
      name: name ?? this.name,
      baseAmount: baseAmount ?? this.baseAmount,
      baseUnit: baseUnit ?? this.baseUnit,
      ingredients: ingredients ?? this.ingredients,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'baseAmount': baseAmount,
      'baseUnit': baseUnit.name,
      'ingredients': ingredients
          .map((ingredient) => ingredient.toJson())
          .toList(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Recipe.fromJson(Map<String, dynamic> json) {
    return Recipe(
      id: json['id'] as String,
      name: json['name'] as String,
      baseAmount: (json['baseAmount'] as num).toDouble(),
      baseUnit: FoodUnit.values.byName(json['baseUnit'] as String),
      ingredients: (json['ingredients'] as List)
          .map(
            (ingredient) => RecipeIngredient.fromJson(
              Map<String, dynamic>.from(ingredient as Map),
            ),
          )
          .toList(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is Recipe &&
        other.id == id &&
        other.name == name &&
        other.baseAmount == baseAmount &&
        other.baseUnit == baseUnit &&
        _listEquals(other.ingredients, ingredients) &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    baseAmount,
    baseUnit,
    Object.hashAll(ingredients),
    createdAt,
    updatedAt,
  );

  static bool _listEquals<T>(List<T> first, List<T> second) {
    if (identical(first, second)) return true;
    if (first.length != second.length) return false;

    for (var index = 0; index < first.length; index++) {
      if (first[index] != second[index]) return false;
    }
    return true;
  }
}
