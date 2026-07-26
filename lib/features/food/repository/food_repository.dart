import '../../../core/models/meal_data.dart';

abstract interface class FoodRepository {
  Future<void> save(MealData data);

  Future<void> update(MealData data);

  Future<MealData?> findById(String id);

  Future<List<MealData>> findByLocalDate(String localDate);

  Future<List<MealData>> findAll();

  Future<void> deleteById(String id);

  Future<void> clear();
}
