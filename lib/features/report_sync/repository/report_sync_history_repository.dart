import '../models/report_sync_history.dart';

abstract interface class ReportSyncHistoryRepository {
  Future<ReportSyncHistory> create(ReportSyncHistory history);
  Future<ReportSyncHistory?> readById(String exchangeId);
  Future<List<ReportSyncHistory>> list();
}
