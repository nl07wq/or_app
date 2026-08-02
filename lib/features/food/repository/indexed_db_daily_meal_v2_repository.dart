import '../../../data/indexed_db/indexed_db_database_contract.dart';
import '../../../data/indexed_db/indexed_db_store_names.dart';
import '../../repositories/repository_exception.dart';
import '../models/daily_meal_v2_models.dart';
import '../models/persisted_daily_meal_v2_record.dart';
import '../services/food_v2_canonical_service.dart';
import 'daily_meal_v2_repository.dart';

class IndexedDbDailyMealV2Repository implements DailyMealV2Repository {
  final IndexedDbDatabase _database;
  final DateTime Function() _now;

  IndexedDbDailyMealV2Repository(this._database, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  @override
  Future<void> create(DailyMealV2 meal) =>
      _write('dailyMealV2.create', meal, false);

  @override
  Future<void> update(DailyMealV2 meal) =>
      _write('dailyMealV2.update', meal, true);

  @override
  Future<DailyMealV2?> readById(String mealId) async {
    try {
      final value = await _database.findById(
        IndexedDbStoreNames.foodRecords,
        PersistedDailyMealV2Record.envelopeId(mealId),
      );
      if (value == null ||
          value['recordVersion'] != DailyMealV2.recordVersion2) {
        return null;
      }
      return PersistedDailyMealV2Record.fromRecord(value).data;
    } catch (error) {
      throw _exception('dailyMealV2.readById', error);
    }
  }

  @override
  Future<List<DailyMealV2>> readForLocalDate(String localDate) async {
    try {
      final values = await _database.findAll(IndexedDbStoreNames.foodRecords);
      final result =
          values
              .where(
                (value) => value['recordVersion'] == DailyMealV2.recordVersion2,
              )
              .map(PersistedDailyMealV2Record.fromRecord)
              .where((value) => value.localDate == localDate)
              .map((value) => value.data)
              .toList()
            ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      return List.unmodifiable(result);
    } catch (error) {
      throw _exception('dailyMealV2.readForLocalDate', error);
    }
  }

  Future<void> _write(
    String operation,
    DailyMealV2 input,
    bool updating,
  ) async {
    final id = PersistedDailyMealV2Record.envelopeId(input.mealId);
    try {
      await _database.runTransaction<void>(
        storeNames: const [IndexedDbStoreNames.foodRecords],
        mode: IndexedDbTransactionMode.readWrite,
        action: (transaction) async {
          final existingValue = await transaction.findById(
            IndexedDbStoreNames.foodRecords,
            id,
          );
          if (updating != (existingValue != null)) {
            throw StateError(
              updating ? 'Daily Meal v2 not found.' : 'Daily Meal ID conflict.',
            );
          }
          final existing = existingValue == null
              ? null
              : PersistedDailyMealV2Record.fromRecord(existingValue);
          final meal = updating
              ? DailyMealV2.fromJson({
                  ...input.toJson(),
                  'createdAt': existing!.createdAt.toUtc().toIso8601String(),
                  'updatedAt': _now().toUtc().toIso8601String(),
                })
              : DailyMealV2.fromJson(input.toJson());
          final record = PersistedDailyMealV2Record.fromMeal(meal).toRecord();
          await transaction.put(IndexedDbStoreNames.foodRecords, record);
          final stored = await transaction.findById(
            IndexedDbStoreNames.foodRecords,
            id,
          );
          if (stored == null ||
              FoodV2CanonicalService.digest(
                    Map<String, Object?>.from(stored['data'] as Map),
                  ) !=
                  FoodV2CanonicalService.digest(meal.toJson()) ||
              stored['createdAt'] != record['createdAt'] ||
              stored['updatedAt'] != record['updatedAt']) {
            throw const FormatException(
              'Daily Meal v2 read-back verification failed.',
            );
          }
          PersistedDailyMealV2Record.fromRecord(stored);
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
