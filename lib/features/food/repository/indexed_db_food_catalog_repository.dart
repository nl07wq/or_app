import '../../../data/indexed_db/indexed_db_database_contract.dart';
import '../../../data/indexed_db/indexed_db_store_names.dart';
import '../../repositories/repository_exception.dart';
import '../models/food_catalog_models.dart';
import '../services/food_v2_canonical_service.dart';
import 'food_catalog_repository.dart';

class IndexedDbFoodCatalogRepository implements FoodCatalogRepository {
  final IndexedDbDatabase _database;
  final DateTime Function() _now;

  IndexedDbFoodCatalogRepository(this._database, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  @override
  Future<void> create(FoodCatalogEntry entry) =>
      _write('foodCatalog.create', entry.foodId, (existing) {
        if (existing != null) throw StateError('FOOD catalog ID conflict.');
        return _copy(entry);
      });

  @override
  Future<void> update(FoodCatalogEntry entry) => _write(
    'foodCatalog.update',
    entry.foodId,
    (existing) {
      if (existing == null) throw StateError('FOOD catalog record not found.');
      final current = FoodCatalogEntry.fromJson(existing);
      return FoodCatalogEntry.fromJson({
        ...entry.toJson(),
        'createdAt': current.createdAt.toUtc().toIso8601String(),
        'updatedAt': _now().toUtc().toIso8601String(),
      });
    },
  );

  @override
  Future<void> archive(String foodId) =>
      _write('foodCatalog.archive', foodId, (existing) {
        if (existing == null) {
          throw StateError('FOOD catalog record not found.');
        }
        final current = FoodCatalogEntry.fromJson(existing);
        return FoodCatalogEntry.fromJson({
          ...current.toJson(),
          'isArchived': true,
          'updatedAt': _now().toUtc().toIso8601String(),
        });
      });

  @override
  Future<FoodCatalogEntry?> readById(String foodId) => _read(foodId);

  @override
  Future<List<FoodCatalogEntry>> list() async {
    try {
      final values = await _database.findAll(
        IndexedDbStoreNames.foodCatalogRecords,
      );
      final result = values.map(FoodCatalogEntry.fromJson).toList()
        ..sort((a, b) => a.foodId.compareTo(b.foodId));
      return List.unmodifiable(result);
    } catch (error) {
      throw _exception('foodCatalog.list', error);
    }
  }

  Future<FoodCatalogEntry?> _read(String id) async {
    try {
      final value = await _database.findById(
        IndexedDbStoreNames.foodCatalogRecords,
        id,
      );
      return value == null ? null : FoodCatalogEntry.fromJson(value);
    } catch (error) {
      throw _exception('foodCatalog.readById', error);
    }
  }

  Future<void> _write(
    String operation,
    String id,
    FoodCatalogEntry Function(Map<String, Object?>? existing) build,
  ) async {
    try {
      await _database.runTransaction<void>(
        storeNames: const [IndexedDbStoreNames.foodCatalogRecords],
        mode: IndexedDbTransactionMode.readWrite,
        action: (transaction) async {
          final existing = await transaction.findById(
            IndexedDbStoreNames.foodCatalogRecords,
            id,
          );
          final entry = build(existing);
          final record = entry.toJson();
          await transaction.put(IndexedDbStoreNames.foodCatalogRecords, record);
          final stored = await transaction.findById(
            IndexedDbStoreNames.foodCatalogRecords,
            id,
          );
          if (stored == null ||
              FoodV2CanonicalService.digest(stored) !=
                  FoodV2CanonicalService.digest(record) ||
              stored['createdAt'] != record['createdAt'] ||
              stored['updatedAt'] != record['updatedAt']) {
            throw const FormatException(
              'FOOD catalog read-back verification failed.',
            );
          }
          FoodCatalogEntry.fromJson(stored);
        },
      );
    } catch (error) {
      throw _exception(operation, error);
    }
  }

  static FoodCatalogEntry _copy(FoodCatalogEntry value) =>
      FoodCatalogEntry.fromJson(value.toJson());

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
