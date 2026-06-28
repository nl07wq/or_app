class FoodData {
  final String date;
  final String meal;
  final int calories;
  final double protein;
  final double fat;
  final double carbohydrate;
  final String memo;

  const FoodData({
    required this.date,
    required this.meal,
    required this.calories,
    required this.protein,
    required this.fat,
    required this.carbohydrate,
    required this.memo,
  });

  @override
  String toString() {
    return 'FoodData(date: $date, meal: $meal, calories: $calories)';
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date,
      'meal': meal,
      'calories': calories,
      'protein': protein,
      'fat': fat,
      'carbohydrate': carbohydrate,
      'memo': memo,
    };
  }

  Map<String, dynamic> toRecordJson() {
    return {'recordType': 'FoodData', 'version': '1.0', 'data': toJson()};
  }
}
