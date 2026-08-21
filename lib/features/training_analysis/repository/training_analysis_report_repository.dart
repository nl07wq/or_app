import '../../../data/indexed_db/indexed_db_database_contract.dart';
import '../../../data/indexed_db/indexed_db_store_names.dart';
import '../../report_sync/services/report_sync_canonical_service.dart';
import '../models/training_analysis_report.dart';

abstract interface class TrainingAnalysisReportRepository {
  Future<TrainingAnalysisReport?> read(String targetRecordId);
  Future<List<TrainingAnalysisReport>> list();
  Future<TrainingAnalysisReport> putInTransaction(
    IndexedDbTransaction transaction,
    TrainingAnalysisReport report,
  );
}

class IndexedDbTrainingAnalysisReportRepository
    implements TrainingAnalysisReportRepository {
  const IndexedDbTrainingAnalysisReportRepository(this._database);

  final IndexedDbDatabase _database;

  @override
  Future<TrainingAnalysisReport?> read(String targetRecordId) async {
    final value = await _database.findById(
      IndexedDbStoreNames.trainingAnalysisReportRecords,
      targetRecordId,
    );
    return value == null ? null : TrainingAnalysisReport.fromRecord(value);
  }

  @override
  Future<List<TrainingAnalysisReport>> list() async {
    final values = [
      for (final value in await _database.findAll(
        IndexedDbStoreNames.trainingAnalysisReportRecords,
      ))
        TrainingAnalysisReport.fromRecord(value),
    ];
    values.sort((a, b) => b.operationDate.compareTo(a.operationDate));
    return List.unmodifiable(values);
  }

  @override
  Future<TrainingAnalysisReport> putInTransaction(
    IndexedDbTransaction transaction,
    TrainingAnalysisReport report,
  ) async {
    final encoded = report.toRecord();
    await transaction.put(
      IndexedDbStoreNames.trainingAnalysisReportRecords,
      encoded,
    );
    final readBack = await transaction.findById(
      IndexedDbStoreNames.trainingAnalysisReportRecords,
      report.targetRecordId,
    );
    if (readBack == null ||
        ReportSyncCanonicalService.encode(readBack) !=
            ReportSyncCanonicalService.encode(encoded)) {
      throw StateError('Training Analysis Report read-back failed.');
    }
    return TrainingAnalysisReport.fromRecord(readBack);
  }
}
