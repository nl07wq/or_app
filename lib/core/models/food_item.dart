class FoodItem {
  final String name;

  final int calories;

  final double protein;
  final double fat;
  final double carbohydrate;
  final int quantity;

  const FoodItem({
    required this.name,
    required this.calories,
    required this.protein,
    required this.fat,
    required this.carbohydrate,
    int quantity = 1,
  }) : quantity = quantity < 1 ? 1 : quantity;

  int get totalCalories => calories * quantity;
  double get totalProtein => protein * quantity;
  double get totalFat => fat * quantity;
  double get totalCarbohydrate => carbohydrate * quantity;

  factory FoodItem.fromJson(Map<String, dynamic> json) {
    final quantity = (json['quantity'] as num?)?.toInt() ?? 1;

    return FoodItem(
      name: json['name'] as String,
      calories: json['calories'] as int,
      protein: (json['protein'] as num).toDouble(),
      fat: (json['fat'] as num).toDouble(),
      carbohydrate: (json['carbohydrate'] as num).toDouble(),
      quantity: quantity < 1 ? 1 : quantity,
    );
  }

  FoodItem copyWith({
    String? name,
    int? calories,
    double? protein,
    double? fat,
    double? carbohydrate,
    int? quantity,
  }) {
    return FoodItem(
      name: name ?? this.name,
      calories: calories ?? this.calories,
      protein: protein ?? this.protein,
      fat: fat ?? this.fat,
      carbohydrate: carbohydrate ?? this.carbohydrate,
      quantity: quantity ?? this.quantity,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'calories': calories,
      'protein': protein,
      'fat': fat,
      'carbohydrate': carbohydrate,
      'quantity': quantity,
    };
  }

  @override
  bool operator ==(Object other) {
    return other is FoodItem &&
        other.name == name &&
        other.calories == calories &&
        other.protein == protein &&
        other.fat == fat &&
        other.carbohydrate == carbohydrate &&
        other.quantity == quantity;
  }

  @override
  int get hashCode => Object.hash(
    name,
    calories,
    protein,
    fat,
    carbohydrate,
    quantity,
  );
}
