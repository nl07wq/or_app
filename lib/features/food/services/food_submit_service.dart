import '../../../core/models/meal_data.dart';
import '../../../core/repositories/food_repository.dart';

class FoodSubmitService {
  const FoodSubmitService._();

  static Future<void> save(MealData data) async {
    await FoodRepository.save(data);
  }

  static Future<void> update(MealData data) async {
    await FoodRepository.update(data);
  }
}
