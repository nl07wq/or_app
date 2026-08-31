import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/models/operation_calendar_period.dart';
import 'package:or_app/data/indexed_db/indexed_db_schema.dart';
import 'package:or_app/data/indexed_db/indexed_db_database_contract.dart';
import 'package:or_app/data/indexed_db/indexed_db_store_names.dart';
import 'package:or_app/features/daily_aggregate/models/daily_aggregate_v1.dart';
import 'package:or_app/features/daily_aggregate/repository/indexed_db_daily_aggregate_repository.dart';
import 'package:or_app/features/import_export/models/backup_package.dart';
import 'package:or_app/features/import_export/services/backup_store_registry.dart';
import 'package:or_app/features/periodic_report/models/periodic_report.dart';
import 'package:or_app/features/periodic_report/repository/periodic_report_repository.dart';
import 'package:or_app/features/periodic_report/services/periodic_report_fact_service.dart';
import 'package:or_app/features/training/repository/indexed_db_training_repository.dart';

import '../../repositories/indexed_db/fake_indexed_db_database.dart';

void main() {
  test('IndexedDB 14 and Backup schema 13 add one periodic report store', () {
    expect(IndexedDbSchema.databaseVersion, 15);
    final store = IndexedDbSchema.storeDefinitions.singleWhere(
      (value) => value.name == IndexedDbStoreNames.periodicReportRecords,
    );
    expect(store.keyPath, 'id');
    expect(store.indexes.map((value) => value.name), [
      IndexedDbIndexNames.byReportType,
      IndexedDbIndexNames.byImportedAt,
    ]);
    expect(BackupPackage.currentSchemaVersion, 15);
    expect(
      BackupSections.forSchema(12),
      isNot(contains(BackupSections.periodicReportRecords)),
    );
    expect(
      BackupSections.forSchema(13),
      contains(BackupSections.periodicReportRecords),
    );
    expect(
      BackupStoreRegistry.stores[BackupSections.periodicReportRecords],
      IndexedDbStoreNames.periodicReportRecords,
    );
  });

  test(
    'common week contract uses Monday through Sunday and stable identity',
    () {
      final period = OperationCalendarPeriod.week(DateTime(2026, 8, 27));
      expect(period.id, 'weekly:2026-08-24');
      expect(period.start, DateTime(2026, 8, 24));
      expect(period.end, DateTime(2026, 8, 30));
      expect(period.isCompleteAt(DateTime(2026, 8, 30)), isFalse);
      expect(period.isCompleteAt(DateTime(2026, 8, 31)), isTrue);
    },
  );

  test(
    'weekly facts preserve missing days and use formal calorie balance',
    () async {
      final database = FakeIndexedDbDatabase();
      final aggregates = IndexedDbDailyAggregateRepository(database);
      await aggregates.put(_daily('2026-08-24', weight: 80, balance: -770));
      await aggregates.put(_daily('2026-08-30', weight: 79.5, balance: -770));
      final service = PeriodicReportFactService(
        dailyAggregates: aggregates,
        training: IndexedDbTrainingSessionRepository(database),
        reports: IndexedDbPeriodicReportRepository(database),
      );

      final facts = await service.generate(
        reportType: PeriodicReportType.weekly,
        anchor: DateTime(2026, 8, 27),
        currentOperationDate: DateTime(2026, 8, 31),
      );

      expect(facts.periodId, 'weekly:2026-08-24');
      expect(facts.expectedDailyCount, 7);
      expect(facts.availableDailyCount, 2);
      expect(facts.missingDailyDates, hasLength(5));
      expect(facts.metrics['calorieBalanceKcal']!.total, -1540);
      expect(facts.theoreticalWeightChangeKg, closeTo(-0.2, 0.000001));
      expect(facts.actualWeightChangeKg, -0.5);
    },
  );

  test('partial periods are rejected', () async {
    final database = FakeIndexedDbDatabase();
    final service = PeriodicReportFactService(
      dailyAggregates: IndexedDbDailyAggregateRepository(database),
      training: IndexedDbTrainingSessionRepository(database),
      reports: IndexedDbPeriodicReportRepository(database),
    );
    expect(
      () => service.generate(
        reportType: PeriodicReportType.monthly,
        anchor: DateTime(2026, 8, 1),
        currentOperationDate: DateTime(2026, 8, 31),
      ),
      throwsStateError,
    );
  });

  test(
    'yearly facts consume saved monthly facts and preserve missing months',
    () async {
      final database = FakeIndexedDbDatabase();
      final reports = IndexedDbPeriodicReportRepository(database);
      final monthly = _record(_monthlyFacts('2025-01', 31, 30, -7700));
      await database.runTransaction(
        storeNames: const [IndexedDbStoreNames.periodicReportRecords],
        mode: IndexedDbTransactionMode.readWrite,
        action: (transaction) => reports.putInTransaction(transaction, monthly),
      );
      final facts =
          await PeriodicReportFactService(
            dailyAggregates: IndexedDbDailyAggregateRepository(database),
            training: IndexedDbTrainingSessionRepository(database),
            reports: reports,
          ).generate(
            reportType: PeriodicReportType.yearly,
            anchor: DateTime(2025, 6, 1),
            currentOperationDate: DateTime(2026, 1, 1),
          );

      expect(facts.sourceMonthlyFactIds, ['monthly:2025-01']);
      expect(facts.missingMonthlyFactIds, hasLength(11));
      expect(facts.availableDailyCount, 30);
      expect(facts.theoreticalWeightChangeKg, -1);
    },
  );

  test('record revisions retain previous immutable facts and analysis', () {
    final firstFacts = _monthlyFacts('2025-01', 31, 30, -7700);
    final first = _record(firstFacts);
    final revised = first.revise(
      facts: firstFacts,
      analysis: _analysis('second'),
      sourceDigest: _digest('c'),
      responseDigest: _digest('d'),
      exchangeId: 'response-2',
      timestamp: DateTime.utc(2026, 2, 2),
    );
    final decoded = PeriodicReportRecord.fromRecord(revised.toRecord());

    expect(decoded.revision, 2);
    expect(decoded.previousRevisions, hasLength(1));
    expect(decoded.previousRevisions.single.analysis.overallSummary, 'first');
    expect(decoded.analysis.overallSummary, 'second');
  });
}

DailyAggregateV1 _daily(
  String date, {
  required double weight,
  required double balance,
}) => DailyAggregateV1(
  operationDate: date,
  weightKg: weight,
  bodyFatPercent: null,
  sleepDurationMinutes: null,
  sleepScore: null,
  sleepType: null,
  plantarFasciitisLevel: null,
  workStartTime: null,
  workEndTime: null,
  workBreakMinutes: null,
  actualWorkMinutes: null,
  intakeCaloriesKcal: null,
  estimatedCalorieBalanceKcal: balance,
  proteinG: null,
  fatG: null,
  carbsG: null,
  hydrationMl: null,
  officialSteps: null,
  measuredSteps: null,
  trainingPerformed: null,
  digestiveCount: null,
  sourceType: DailyAggregateSourceType.records,
);

PeriodicReportFacts _monthlyFacts(
  String month,
  int expected,
  int available,
  double balance,
) => PeriodicReportFacts(
  reportType: PeriodicReportType.monthly,
  periodId: 'monthly:$month',
  startDate: '$month-01',
  endDate: '$month-$expected',
  expectedDailyCount: expected,
  availableDailyCount: available,
  missingDailyDates: const [],
  sourceMonthlyFactIds: const [],
  missingMonthlyFactIds: const [],
  metrics: {
    'calorieBalanceKcal': PeriodicMetricFact(
      sampleCount: available,
      total: balance,
      average: balance / available,
      minimum: balance / available,
      maximum: balance / available,
    ),
  },
  previousPeriodComparisons: const {},
  operationStatusCounts: const {},
  trainingSessionCount: 0,
  trainingDays: 0,
  exercisesPerformed: const [],
  theoreticalWeightChangeKg: balance / 7700,
  actualWeightChangeKg: null,
);

PeriodicReportRecord _record(PeriodicReportFacts facts) =>
    PeriodicReportRecord.initial(
      facts: facts,
      analysis: _analysis('first'),
      sourceDigest: _digest('a'),
      responseDigest: _digest('b'),
      exchangeId: 'response-1',
      timestamp: DateTime.utc(2026, 2, 1),
    );

PeriodicReportAnalysis _analysis(String summary) => PeriodicReportAnalysis(
  body: 'body',
  nutrition: 'nutrition',
  calorieBalance: 'balance',
  activity: 'activity',
  recovery: 'recovery',
  training: 'training',
  condition: 'condition',
  operation: 'operation',
  overallSummary: summary,
  nextPeriodFocus: 'focus',
);

String _digest(String value) => value * 64;
