import '../../../data/indexed_db/indexed_db_database_contract.dart';
import '../../../data/indexed_db/indexed_db_store_names.dart';
import '../../report_sync/services/report_sync_canonical_service.dart';
import '../models/periodic_report.dart';

abstract interface class PeriodicReportRepository {
  Future<PeriodicReportRecord?> read(String id);
  Future<List<PeriodicReportRecord>> list({PeriodicReportType? type});
  Future<PeriodicReportRecord> putInTransaction(
    IndexedDbTransaction transaction,
    PeriodicReportRecord report,
  );
}

class IndexedDbPeriodicReportRepository implements PeriodicReportRepository {
  const IndexedDbPeriodicReportRepository(this._database);

  final IndexedDbDatabase _database;

  @override
  Future<PeriodicReportRecord?> read(String id) async {
    final value = await _database.findById(
      IndexedDbStoreNames.periodicReportRecords,
      id,
    );
    return value == null ? null : PeriodicReportRecord.fromRecord(value);
  }

  @override
  Future<List<PeriodicReportRecord>> list({PeriodicReportType? type}) async {
    final records = [
      for (final value in await _database.findAll(
        IndexedDbStoreNames.periodicReportRecords,
      ))
        PeriodicReportRecord.fromRecord(value),
    ].where((record) => type == null || record.reportType == type).toList();
    records.sort((a, b) => b.periodStart.compareTo(a.periodStart));
    return List.unmodifiable(records);
  }

  @override
  Future<PeriodicReportRecord> putInTransaction(
    IndexedDbTransaction transaction,
    PeriodicReportRecord report,
  ) async {
    final encoded = report.toRecord();
    await transaction.put(IndexedDbStoreNames.periodicReportRecords, encoded);
    final readBack = await transaction.findById(
      IndexedDbStoreNames.periodicReportRecords,
      report.id,
    );
    if (readBack == null ||
        ReportSyncCanonicalService.encode(readBack) !=
            ReportSyncCanonicalService.encode(encoded)) {
      throw StateError('Periodic Report read-back failed.');
    }
    return PeriodicReportRecord.fromRecord(readBack);
  }
}
