class FoodSummary {
  final double calories;
  final double protein;
  final double fat;
  final double carbohydrates;
  final double hydrationMl;
  final int mealCount;

  const FoodSummary({
    required this.calories,
    required this.protein,
    required this.fat,
    required this.carbohydrates,
    required this.hydrationMl,
    required this.mealCount,
  });

  Map<String, dynamic> toJson() => {
    'calories': calories,
    'protein': protein,
    'fat': fat,
    'carbohydrates': carbohydrates,
    'hydrationMl': hydrationMl,
    'mealCount': mealCount,
  };

  factory FoodSummary.fromJson(Map<String, dynamic> json) => FoodSummary(
    calories: (json['calories'] as num).toDouble(),
    protein: (json['protein'] as num).toDouble(),
    fat: (json['fat'] as num).toDouble(),
    carbohydrates: (json['carbohydrates'] as num).toDouble(),
    hydrationMl: (json['hydrationMl'] as num).toDouble(),
    mealCount: json['mealCount'] as int,
  );
}
