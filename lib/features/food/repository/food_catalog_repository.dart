import '../models/food_catalog_models.dart';

abstract interface class FoodCatalogRepository {
  Future<void> create(FoodCatalogEntry entry);
  Future<FoodCatalogEntry?> readById(String foodId);
  Future<List<FoodCatalogEntry>> list();
  Future<void> update(FoodCatalogEntry entry);
  Future<void> archive(String foodId);
}
