import '../models/food_data.dart';

class FoodRepository {
  static final List<FoodData> _records = [];

  static void add(FoodData data) {
    _records.add(data);
  }

  static List<FoodData> getAll() {
    return List.unmodifiable(_records);
  }

  static void clear() {
    _records.clear();
  }
}
