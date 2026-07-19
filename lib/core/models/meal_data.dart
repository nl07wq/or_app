import 'food_item.dart';

class MealData {
  final String date;
  final String mealType;
  final List<FoodItem> items;
  final String memo;
  final String id;

  const MealData({
    required this.date,
    required this.mealType,
    required this.items,
    required this.memo,
    required this.id,
  });

  int get calories => items.fold(0, (sum, item) => sum + item.calories);

  double get protein => items.fold(0.0, (sum, item) => sum + item.protein);

  double get fat => items.fold(0.0, (sum, item) => sum + item.fat);

  double get carbohydrate =>
      items.fold(0.0, (sum, item) => sum + item.carbohydrate);

  factory MealData.fromJson(Map<String, dynamic> json) {
    return MealData(
      date: json['date'] as String,
      mealType: json['mealType'] as String,
      memo: json['memo'] as String,
      items: (json['items'] as List).map((e) => FoodItem.fromJson(e)).toList(),
      id: json['id'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date,
      'mealType': mealType,
      'memo': memo,
      'items': items.map((e) => e.toJson()).toList(),
      'id': id,
    };
  }

  Map<String, dynamic> toRecordJson() {
    return {'recordType': 'MealData', 'version': '2.0', 'data': toJson()};
  }
}
