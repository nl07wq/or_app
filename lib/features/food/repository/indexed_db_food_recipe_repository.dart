import '../../../data/indexed_db/indexed_db_database_contract.dart';
import '../../../data/indexed_db/indexed_db_store_names.dart';
import '../../repositories/repository_exception.dart';
import '../models/recipe_models_v2.dart';
import '../services/food_v2_canonical_service.dart';
import 'food_recipe_repository.dart';

class IndexedDbFoodRecipeRepository implements FoodRecipeRepository {
  final IndexedDbDatabase _database;
  final DateTime Function() _now;

  IndexedDbFoodRecipeRepository(this._database, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  @override
  Future<void> create(FoodRecipeDefinition recipe) =>
      _write('foodRecipe.create', recipe.recipeId, (existing) {
        if (existing != null) throw StateError('FOOD recipe ID conflict.');
        return FoodRecipeDefinition.fromJson(recipe.toJson());
      });

  @override
  Future<void> update(FoodRecipeDefinition recipe) =>
      _write('foodRecipe.update', recipe.recipeId, (existing) {
        if (existing == null) throw StateError('FOOD recipe not found.');
        final current = FoodRecipeDefinition.fromJson(existing);
        return FoodRecipeDefinition.fromJson({
          ...recipe.toJson(),
          'createdAt': current.createdAt.toUtc().toIso8601String(),
          'updatedAt': _now().toUtc().toIso8601String(),
        });
      });

  @override
  Future<void> archive(String recipeId) =>
      _write('foodRecipe.archive', recipeId, (existing) {
        if (existing == null) throw StateError('FOOD recipe not found.');
        final current = FoodRecipeDefinition.fromJson(existing);
        return FoodRecipeDefinition.fromJson({
          ...current.toJson(),
          'isArchived': true,
          'updatedAt': _now().toUtc().toIso8601String(),
        });
      });

  @override
  Future<FoodRecipeDefinition?> readById(String recipeId) async {
    try {
      final value = await _database.findById(
        IndexedDbStoreNames.foodRecipeRecords,
        recipeId,
      );
      return value == null ? null : FoodRecipeDefinition.fromJson(value);
    } catch (error) {
      throw _exception('foodRecipe.readById', error);
    }
  }

  @override
  Future<List<FoodRecipeDefinition>> list() async {
    try {
      final values = await _database.findAll(
        IndexedDbStoreNames.foodRecipeRecords,
      );
      final result = values.map(FoodRecipeDefinition.fromJson).toList()
        ..sort((a, b) => a.recipeId.compareTo(b.recipeId));
      return List.unmodifiable(result);
    } catch (error) {
      throw _exception('foodRecipe.list', error);
    }
  }

  Future<void> _write(
    String operation,
    String id,
    FoodRecipeDefinition Function(Map<String, Object?>? existing) build,
  ) async {
    try {
      await _database.runTransaction<void>(
        storeNames: const [IndexedDbStoreNames.foodRecipeRecords],
        mode: IndexedDbTransactionMode.readWrite,
        action: (transaction) async {
          final existing = await transaction.findById(
            IndexedDbStoreNames.foodRecipeRecords,
            id,
          );
          final recipe = build(existing);
          final record = recipe.toJson();
          await transaction.put(IndexedDbStoreNames.foodRecipeRecords, record);
          final stored = await transaction.findById(
            IndexedDbStoreNames.foodRecipeRecords,
            id,
          );
          if (stored == null ||
              FoodV2CanonicalService.digest(stored) !=
                  FoodV2CanonicalService.digest(record) ||
              stored['createdAt'] != record['createdAt'] ||
              stored['updatedAt'] != record['updatedAt']) {
            throw const FormatException(
              'FOOD recipe read-back verification failed.',
            );
          }
          FoodRecipeDefinition.fromJson(stored);
        },
      );
    } catch (error) {
      throw _exception(operation, error);
    }
  }

  static RepositoryException _exception(String operation, Object error) =>
      error is RepositoryException
      ? error
      : RepositoryException(
          operation: operation,
          code: error is FormatException
              ? RepositoryErrorCode.verificationFailed
              : RepositoryErrorCode.transactionFailed,
          cause: error,
        );
}
