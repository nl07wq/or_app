import '../../../data/indexed_db/indexed_db_database_contract.dart';
import '../models/daily_debrief_record.dart';

abstract interface class DailyDebriefRepository {
  Future<DailyDebriefRecord?> readByLocalDate(String localDate);

  Future<List<DailyDebriefRecord>> list();

  Future<DailyDebriefRecord> putInTransaction(
    IndexedDbTransaction transaction,
    DailyDebriefRecord record,
  );
}
