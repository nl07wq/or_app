import '../../../data/indexed_db/indexed_db_database_contract.dart';
import '../models/daily_aggregate_v1.dart';

abstract interface class DailyAggregateRepository {
  Future<DailyAggregateV1?> getByDate(String operationDate);

  Future<DailyAggregateV1> put(DailyAggregateV1 aggregate);

  Future<void> deleteByDate(String operationDate);

  Future<List<DailyAggregateV1>> getRange(String startDate, String endDate);

  Future<DailyAggregateV1> putInTransaction(
    IndexedDbTransaction transaction,
    DailyAggregateV1 aggregate,
  );

  Future<void> deleteByDateInTransaction(
    IndexedDbTransaction transaction,
    String operationDate,
  );
}
