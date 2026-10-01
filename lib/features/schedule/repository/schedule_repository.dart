import '../models/schedule_record.dart';

abstract interface class ScheduleRepository {
  Future<List<ScheduleRecord>> findAll();
  Future<List<ScheduleRecord>> findForDate(String localDate);
  Future<List<ScheduleRecord>> findForMonth(DateTime month);
  Future<ScheduleRecord?> findWorkForDate(String localDate);
  Future<void> save(ScheduleRecord record);
  Future<void> delete(String id);
}
