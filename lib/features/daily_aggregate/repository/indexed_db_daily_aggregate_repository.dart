import '../../../data/indexed_db/indexed_db_database_contract.dart';
import '../../../data/indexed_db/indexed_db_store_names.dart';
import '../models/daily_aggregate_v1.dart';
import 'daily_aggregate_repository.dart';

class IndexedDbDailyAggregateRepository implements DailyAggregateRepository {
  final IndexedDbDatabase _database;

  const IndexedDbDailyAggregateRepository(this._database);

  @override
  Future<DailyAggregateV1?> getByDate(String operationDate) async {
    final value = await _database.findById(
      IndexedDbStoreNames.dailyAggregateRecords,
      operationDate,
    );
    return value == null ? null : DailyAggregateV1.fromJson(value);
  }

  @override
  Future<DailyAggregateV1> put(DailyAggregateV1 aggregate) =>
      _database.runTransaction(
        storeNames: const [IndexedDbStoreNames.dailyAggregateRecords],
        mode: IndexedDbTransactionMode.readWrite,
        action: (transaction) => putInTransaction(transaction, aggregate),
      );

  @override
  Future<DailyAggregateV1> putInTransaction(
    IndexedDbTransaction transaction,
    DailyAggregateV1 aggregate,
  ) async {
    final encoded = aggregate.toJson();
    await transaction.put(IndexedDbStoreNames.dailyAggregateRecords, encoded);
    final readBack = await transaction.findById(
      IndexedDbStoreNames.dailyAggregateRecords,
      aggregate.operationDate,
    );
    if (readBack == null) {
      throw StateError('Daily Aggregate read-back is missing.');
    }
    final restored = DailyAggregateV1.fromJson(readBack);
    if (!_equal(restored, aggregate)) {
      throw StateError('Daily Aggregate read-back mismatch.');
    }
    return restored;
  }

  @override
  Future<void> deleteByDate(String operationDate) => _database.runTransaction(
    storeNames: const [IndexedDbStoreNames.dailyAggregateRecords],
    mode: IndexedDbTransactionMode.readWrite,
    action: (transaction) =>
        deleteByDateInTransaction(transaction, operationDate),
  );

  @override
  Future<void> deleteByDateInTransaction(
    IndexedDbTransaction transaction,
    String operationDate,
  ) async {
    await transaction.deleteById(
      IndexedDbStoreNames.dailyAggregateRecords,
      operationDate,
    );
    if (await transaction.findById(
          IndexedDbStoreNames.dailyAggregateRecords,
          operationDate,
        ) !=
        null) {
      throw StateError('Daily Aggregate deletion read-back failed.');
    }
  }

  @override
  Future<List<DailyAggregateV1>> getRange(
    String startDate,
    String endDate,
  ) async {
    if (startDate.compareTo(endDate) > 0) {
      throw ArgumentError('startDate must not be after endDate.');
    }
    final values =
        [
              for (final record in await _database.findAll(
                IndexedDbStoreNames.dailyAggregateRecords,
              ))
                DailyAggregateV1.fromJson(record),
            ]
            .where(
              (value) =>
                  value.operationDate.compareTo(startDate) >= 0 &&
                  value.operationDate.compareTo(endDate) <= 0,
            )
            .toList();
    values.sort((a, b) => a.operationDate.compareTo(b.operationDate));
    return List.unmodifiable(values);
  }

  static bool _equal(DailyAggregateV1 first, DailyAggregateV1 second) {
    final left = first.toJson();
    final right = second.toJson();
    return left.length == right.length &&
        left.entries.every((entry) => right[entry.key] == entry.value);
  }
}
