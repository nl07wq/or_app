import '../models/daily_meal_v2_models.dart';

abstract interface class DailyMealV2Repository {
  Future<void> create(DailyMealV2 meal);
  Future<DailyMealV2?> readById(String mealId);
  Future<List<DailyMealV2>> readForLocalDate(String localDate);
  Future<List<DailyMealV2>> findAll();
  Future<void> update(DailyMealV2 meal);
}
