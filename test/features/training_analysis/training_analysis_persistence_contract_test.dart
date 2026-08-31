import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/data/indexed_db/indexed_db_schema.dart';
import 'package:or_app/data/indexed_db/indexed_db_store_names.dart';
import 'package:or_app/features/import_export/models/backup_package.dart';
import 'package:or_app/features/import_export/services/backup_store_registry.dart';
import 'package:or_app/features/training_analysis/models/training_analysis_report.dart';

void main() {
  test('IndexedDB 13 adds the dedicated Training Analysis Report store', () {
    expect(IndexedDbSchema.databaseVersion, 15);
    final store = IndexedDbSchema.storeDefinitions.singleWhere(
      (definition) =>
          definition.name == IndexedDbStoreNames.trainingAnalysisReportRecords,
    );

    expect(store.keyPath, 'targetRecordId');
    expect(store.indexes.map((index) => index.name), [
      IndexedDbIndexNames.byOperationDate,
      IndexedDbIndexNames.byImportedAt,
    ]);
  });

  test('Backup schema 12 adds reports without changing schema 11', () {
    expect(BackupPackage.currentSchemaVersion, 15);
    expect(
      BackupSections.forSchema(11),
      isNot(contains(BackupSections.trainingAnalysisReportRecords)),
    );
    expect(
      BackupSections.forSchema(12),
      contains(BackupSections.trainingAnalysisReportRecords),
    );
    expect(
      BackupStoreRegistry.stores[BackupSections.trainingAnalysisReportRecords],
      IndexedDbStoreNames.trainingAnalysisReportRecords,
    );
  });

  test('Training Analysis Report record round-trips with revisions', () {
    final importedAt = DateTime.utc(2026, 8, 20, 12);
    final initial = TrainingAnalysisReport.initial(
      targetRecordId: 'training-v2:target',
      operationDate: '2026-08-20',
      sourceDigest: _digest('a'),
      responseDigest: _digest('b'),
      exchangeId: 'exchange-1',
      timestamp: importedAt,
      analysis: _analysis('first'),
    );
    final revised = initial.revise(
      sourceDigest: _digest('a'),
      responseDigest: _digest('c'),
      exchangeId: 'exchange-2',
      timestamp: importedAt.add(const Duration(hours: 1)),
      analysis: _analysis('second'),
    );

    final decoded = TrainingAnalysisReport.fromRecord(revised.toRecord());
    expect(decoded.targetRecordId, 'training-v2:target');
    expect(decoded.revision, 2);
    expect(decoded.analysis.sessionSummary, 'second summary');
    expect(decoded.previousRevisions, hasLength(1));
    expect(
      decoded.previousRevisions.single.analysis.sessionSummary,
      'first summary',
    );
  });
}

TrainingAnalysis _analysis(String prefix) => TrainingAnalysis(
  sessionSummary: '$prefix summary',
  performanceAnalysis: '$prefix performance',
  previousComparison: '$prefix comparison',
  progressAnalysis: '$prefix progress',
  recoveryFrequencyComment: '$prefix recovery',
  nextSessionProposal: '$prefix proposal',
  riskAttentionNotes: '$prefix risks',
  exerciseAnalyses: [
    TrainingExerciseAnalysis(
      exerciseIdentity: 'squat',
      exerciseName: 'Squat',
      assessment: '$prefix assessment',
      previousComparison: '$prefix comparison',
      progress: '$prefix progress',
      nextProposal: '$prefix proposal',
    ),
  ],
);

String _digest(String value) => value * 64;
