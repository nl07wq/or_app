class FoodItem {
  final String name;

  final int calories;

  final double protein;
  final double fat;
  final double carbohydrate;

  const FoodItem({
    required this.name,
    required this.calories,
    required this.protein,
    required this.fat,
    required this.carbohydrate,
  });

  factory FoodItem.fromJson(Map<String, dynamic> json) {
    return FoodItem(
      name: json['name'] as String,
      calories: json['calories'] as int,
      protein: (json['protein'] as num).toDouble(),
      fat: (json['fat'] as num).toDouble(),
      carbohydrate: (json['carbohydrate'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'calories': calories,
      'protein': protein,
      'fat': fat,
      'carbohydrate': carbohydrate,
    };
  }
}
