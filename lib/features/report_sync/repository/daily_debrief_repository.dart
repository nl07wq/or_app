import '../models/daily_debrief_record.dart';

abstract interface class DailyDebriefRepository {
  Future<DailyDebriefRecord> create(DailyDebriefRecord record);
  Future<DailyDebriefRecord?> readByLocalDate(String localDate);
  Future<List<DailyDebriefRecord>> list();
}
