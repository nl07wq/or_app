import '../../../core/models/meal_data.dart';
import '../../../data/indexed_db/indexed_db_database_contract.dart';
import '../../../data/indexed_db/indexed_db_store_names.dart';
import '../../repositories/repository_exception.dart';
import '../models/persisted_food_record.dart';
import 'food_repository.dart';

class FoodReadIssue {
  final String? recordId;
  final String code;
  final String message;

  const FoodReadIssue({
    required this.recordId,
    required this.code,
    required this.message,
  });
}

class FoodReadResult {
  final List<PersistedFoodRecord> records;
  final List<FoodReadIssue> issues;

  FoodReadResult({
    required Iterable<PersistedFoodRecord> records,
    Iterable<FoodReadIssue> issues = const [],
  }) : records = List.unmodifiable(records),
       issues = List.unmodifiable(issues);

  List<MealData> get values =>
      List.unmodifiable(records.map((record) => record.data));

  bool get hasIssues => issues.isNotEmpty;
}

abstract interface class FoodAuditRepository {
  Future<FoodReadResult> findAllWithIssues();
}

class IndexedDbFoodRepository implements FoodRepository, FoodAuditRepository {
  final IndexedDbDatabase _database;
  final DateTime Function() _now;

  IndexedDbFoodRepository(this._database, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  @override
  Future<void> save(MealData data) => _put(data, operation: 'food.save');

  @override
  Future<void> update(MealData data) => _put(data, operation: 'food.update');

  Future<void> _put(MealData data, {required String operation}) async {
    final id = PersistedFoodRecord.envelopeId(data.id);
    final localDate = PersistedFoodRecord.localDateFromMealDate(data.date);
    try {
      await _database.runTransaction<void>(
        storeNames: const [IndexedDbStoreNames.foodRecords],
        mode: IndexedDbTransactionMode.readWrite,
        action: (transaction) async {
          final existingValue = await transaction.findById(
            IndexedDbStoreNames.foodRecords,
            id,
          );
          final existing = existingValue == null
              ? null
              : PersistedFoodRecord.fromRecord(existingValue);
          final timestamp = _now().toUtc();
          await transaction.put(
            IndexedDbStoreNames.foodRecords,
            PersistedFoodRecord(
              id: id,
              localDate: localDate,
              createdAt: existing?.createdAt ?? timestamp,
              updatedAt: timestamp,
              migrationSource: existing?.migrationSource,
              data: _copy(data),
            ).toRecord(),
          );
        },
      );
    } on RepositoryException {
      rethrow;
    } on FormatException catch (error) {
      throw RepositoryException(
        operation: operation,
        code: RepositoryErrorCode.invalidRecord,
        cause: error,
      );
    } catch (error) {
      throw RepositoryException(
        operation: operation,
        code: RepositoryErrorCode.transactionFailed,
        cause: error,
      );
    }
  }

  @override
  Future<MealData?> findById(String id) async {
    try {
      final envelopeId = id.startsWith('food:')
          ? id
          : PersistedFoodRecord.envelopeId(id);
      final value = await _database.findById(
        IndexedDbStoreNames.foodRecords,
        envelopeId,
      );
      if (value == null) return null;
      return PersistedFoodRecord.fromRecord(value).data;
    } on FormatException catch (error) {
      throw RepositoryException(
        operation: 'food.findById',
        code: RepositoryErrorCode.invalidRecord,
        cause: error,
      );
    } catch (error) {
      throw RepositoryException(operation: 'food.findById', cause: error);
    }
  }

  @override
  Future<List<MealData>> findByLocalDate(String localDate) async {
    try {
      PersistedFoodRecord.validateLocalDate(localDate);
      final result = await findAllWithIssues();
      if (result.hasIssues) {
        throw RepositoryException(
          operation: 'food.findByLocalDate',
          code: RepositoryErrorCode.partialCorruption,
          cause: result.issues,
        );
      }
      return List.unmodifiable(
        result.records
            .where((record) => record.localDate == localDate)
            .map((record) => record.data),
      );
    } on RepositoryException {
      rethrow;
    } on FormatException catch (error) {
      throw RepositoryException(
        operation: 'food.findByLocalDate',
        code: RepositoryErrorCode.invalidRecord,
        cause: error,
      );
    }
  }

  @override
  Future<List<MealData>> findAll() async {
    final result = await findAllWithIssues();
    if (result.hasIssues) {
      throw RepositoryException(
        operation: 'food.findAll',
        code: RepositoryErrorCode.partialCorruption,
        cause: result.issues,
      );
    }
    return result.values;
  }

  @override
  Future<FoodReadResult> findAllWithIssues() async {
    try {
      final stored = await _database.findAll(IndexedDbStoreNames.foodRecords);
      final records = <PersistedFoodRecord>[];
      final issues = <FoodReadIssue>[];
      for (final value in stored) {
        try {
          records.add(PersistedFoodRecord.fromRecord(value));
        } catch (error) {
          issues.add(
            FoodReadIssue(
              recordId: value['id'] is String ? value['id'] as String : null,
              code: 'invalidRecord',
              message: error.toString(),
            ),
          );
        }
      }
      records.sort((first, second) {
        final byCreatedAt = first.createdAt.compareTo(second.createdAt);
        return byCreatedAt != 0
            ? byCreatedAt
            : first.data.id.compareTo(second.data.id);
      });
      return FoodReadResult(records: records, issues: issues);
    } catch (error) {
      throw RepositoryException(operation: 'food.findAll', cause: error);
    }
  }

  @override
  Future<void> deleteById(String id) async {
    try {
      final envelopeId = id.startsWith('food:')
          ? id
          : PersistedFoodRecord.envelopeId(id);
      await _database.deleteById(IndexedDbStoreNames.foodRecords, envelopeId);
    } catch (error) {
      throw RepositoryException(operation: 'food.deleteById', cause: error);
    }
  }

  @override
  Future<void> clear() async {
    try {
      await _database.clear(IndexedDbStoreNames.foodRecords);
    } catch (error) {
      throw RepositoryException(operation: 'food.clear', cause: error);
    }
  }

  static MealData _copy(MealData data) {
    return MealData.fromJson(Map<String, dynamic>.from(data.toJson()));
  }
}
