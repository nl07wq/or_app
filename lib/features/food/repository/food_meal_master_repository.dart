import '../models/food_meal_master_models.dart';

abstract interface class FoodMealMasterRepository {
  Future<void> create(FoodMealMaster meal);
  Future<FoodMealMaster?> readById(String mealMasterId);
  Future<List<FoodMealMaster>> list();
  Future<void> update(FoodMealMaster meal);
  Future<void> archive(String mealMasterId);
}
