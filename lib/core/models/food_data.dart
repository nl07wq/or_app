class FoodData {
  final String date;
  final String meal;
  final int calories;
  final double protein;

  const FoodData({
    required this.date,
    required this.meal,
    required this.calories,
    required this.protein,
  });

  Map<String, dynamic> toJson() {
    return {
      'date': date,
      'meal': meal,
      'calories': calories,
      'protein': protein,
    };
  }
}
