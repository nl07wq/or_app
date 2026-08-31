import '../../../data/indexed_db/indexed_db_database_contract.dart';
import '../../../data/indexed_db/indexed_db_store_names.dart';
import '../../repositories/repository_exception.dart';
import '../models/food_meal_master_models.dart';
import '../services/food_v2_canonical_service.dart';
import 'food_meal_master_repository.dart';

class IndexedDbFoodMealMasterRepository implements FoodMealMasterRepository {
  IndexedDbFoodMealMasterRepository(this._database, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final IndexedDbDatabase _database;
  final DateTime Function() _now;

  @override
  Future<void> create(FoodMealMaster meal) =>
      _write('foodMealMaster.create', meal.mealMasterId, (existing) {
        if (existing != null) throw StateError('FOOD MEAL ID conflict.');
        return FoodMealMaster.fromJson(meal.toJson());
      });

  @override
  Future<void> update(FoodMealMaster meal) =>
      _write('foodMealMaster.update', meal.mealMasterId, (existing) {
        if (existing == null) throw StateError('FOOD MEAL not found.');
        final current = FoodMealMaster.fromJson(existing);
        return FoodMealMaster.fromJson({
          ...meal.toJson(),
          'createdAt': current.createdAt.toUtc().toIso8601String(),
          'updatedAt': _now().toUtc().toIso8601String(),
        });
      });

  @override
  Future<void> archive(String mealMasterId) =>
      _write('foodMealMaster.archive', mealMasterId, (existing) {
        if (existing == null) throw StateError('FOOD MEAL not found.');
        final current = FoodMealMaster.fromJson(existing);
        return FoodMealMaster.fromJson({
          ...current.toJson(),
          'isArchived': true,
          'updatedAt': _now().toUtc().toIso8601String(),
        });
      });

  @override
  Future<FoodMealMaster?> readById(String mealMasterId) async {
    try {
      final value = await _database.findById(
        IndexedDbStoreNames.foodMealMasterRecords,
        mealMasterId,
      );
      return value == null ? null : FoodMealMaster.fromJson(value);
    } catch (error) {
      throw _exception('foodMealMaster.readById', error);
    }
  }

  @override
  Future<List<FoodMealMaster>> list() async {
    try {
      final values = await _database.findAll(
        IndexedDbStoreNames.foodMealMasterRecords,
      );
      final result = values.map(FoodMealMaster.fromJson).toList()
        ..sort((a, b) => a.mealMasterId.compareTo(b.mealMasterId));
      return List.unmodifiable(result);
    } catch (error) {
      throw _exception('foodMealMaster.list', error);
    }
  }

  Future<void> _write(
    String operation,
    String id,
    FoodMealMaster Function(Map<String, Object?>? existing) build,
  ) async {
    try {
      await _database.runTransaction<void>(
        storeNames: const [IndexedDbStoreNames.foodMealMasterRecords],
        mode: IndexedDbTransactionMode.readWrite,
        action: (transaction) async {
          final existing = await transaction.findById(
            IndexedDbStoreNames.foodMealMasterRecords,
            id,
          );
          final meal = build(existing);
          final record = meal.toJson();
          await transaction.put(
            IndexedDbStoreNames.foodMealMasterRecords,
            record,
          );
          final stored = await transaction.findById(
            IndexedDbStoreNames.foodMealMasterRecords,
            id,
          );
          if (stored == null ||
              FoodV2CanonicalService.digest(stored) !=
                  FoodV2CanonicalService.digest(record)) {
            throw const FormatException('FOOD MEAL read-back failed.');
          }
          FoodMealMaster.fromJson(stored);
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
