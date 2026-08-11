import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/data/indexed_db/indexed_db_store_names.dart';
import 'package:or_app/data/indexed_db/indexed_db_database_contract.dart';
import 'package:or_app/features/daily_aggregate/models/daily_aggregate_v1.dart';
import 'package:or_app/features/daily_log_confirmation/models/persisted_daily_log_confirmation_record.dart';
import 'package:or_app/features/import_export/models/backup_package.dart';
import 'package:or_app/features/import_export/services/backup_store_registry.dart';
import 'package:or_app/features/operation_date/models/operation_local_date.dart';
import 'package:or_app/features/report_sync/models/daily_debrief_record.dart';
import 'package:or_app/features/report_sync/models/report_sync_envelope.dart';
import 'package:or_app/features/report_sync/models/report_sync_issue.dart';
import 'package:or_app/features/report_sync/repository/indexed_db_report_sync_repositories.dart';
import 'package:or_app/features/report_sync/services/report_sync_canonical_service.dart';
import 'package:or_app/features/report_sync/services/daily_debrief_source_service.dart';
import 'package:or_app/features/report_sync/services/report_sync_exchange_gateway.dart';
import 'package:or_app/features/repositories/app_repository_container.dart';

import '../../repositories/indexed_db/fake_indexed_db_database.dart';
import '../daily_log_confirmation/daily_log_confirmation_test_fixture.dart';

void main() {
  const date = '2026-08-09';
  final timestamp = DateTime.utc(2026, 8, 9, 23);

  test('strict model creates revision 1 and preserves complete revisions', () {
    final sources = _sources(date);
    final first = DailyDebriefRecord.initial(
      localDate: date,
      sources: sources,
      analysis: _analysis(),
      responseDigest: _digest('first'),
      timestamp: timestamp,
    );
    final second = first.revise(
      sources: sources,
      analysis: _analysis(body: '更新後の評価'),
      responseDigest: _digest('second'),
      timestamp: timestamp.add(const Duration(hours: 1)),
    );
    final restored = DailyDebriefRecord.fromRecord(second.toRecord());

    expect(first.recordVersion, 1);
    expect(restored.revision, 2);
    expect(restored.previousRevisions, hasLength(1));
    expect(
      restored.previousRevisions.single.sources.toJson(),
      sources.toJson(),
    );
    expect(restored.createdAt, timestamp);
    expect(restored.updatedAt, timestamp.add(const Duration(hours: 1)));
    expect(
      () => DailyDebriefRecord.fromRecord({
        ...first.toRecord(),
        'dailySummary': 'forbidden',
      }),
      throwsFormatException,
    );
    expect(
      () => DailyDebriefAnalysis.fromJson({
        ..._analysis().toJson(),
        'carryover': <Object?>[],
      }),
      throwsFormatException,
    );
    expect(
      () => DailyDebriefAnalysis.fromJson({
        ..._analysis().toJson(),
        'domainEvaluations': {
          ..._analysis().domainEvaluations.toJson(),
          'body': '   ',
        },
      }),
      throwsFormatException,
    );
  });

  test(
    'repository keeps one canonical record per date and backup validates it',
    () async {
      final database = FakeIndexedDbDatabase();
      final repository = IndexedDbDailyDebriefRepository(database);
      final record = DailyDebriefRecord.initial(
        localDate: date,
        sources: _sources(date),
        analysis: _analysis(),
        responseDigest: _digest('response'),
        timestamp: timestamp,
      );
      await database.runTransaction<void>(
        storeNames: const [IndexedDbStoreNames.dailyDebriefRecords],
        mode: IndexedDbTransactionMode.readWrite,
        action: (transaction) async {
          await repository.putInTransaction(transaction, record);
        },
      );

      expect((await repository.list()), hasLength(1));
      expect(
        (await repository.readByLocalDate(date))!.toRecord(),
        record.toRecord(),
      );
      expect(
        () => BackupStoreRegistry.validateRecord(
          BackupSections.dailyDebriefRecords,
          record.toRecord(),
        ),
        returnsNormally,
      );
    },
  );

  test(
    'formal source, prompt, atomic import, revision, and lifecycle work',
    () async {
      final database = FakeIndexedDbDatabase();
      final container = AppRepositoryContainer.indexedDb(database);
      await container.operationState.createInitial(
        OperationLocalDate.parse('2026-08-10'),
      );
      final state = await container.operationState.requireCurrent();
      await container.operationState.save(
        state.copyWith(
          lastFinalizedDate: OperationLocalDate.parse(date),
          updatedAt: state.updatedAt.add(const Duration(seconds: 1)),
        ),
        expectedRevision: state.revision,
      );
      await container.confirmationLifecycle.createV2(
        PersistedDailyLogConfirmationRecord.initialFinalizedV2(
          id: 'confirmation:$date',
          localDate: date,
          data: completeConfirmation(date: DateTime(2026, 8, 9)),
          timestamp: timestamp,
        ),
      );
      await container.dailyAggregates.put(
        _aggregate(date, sourceType: DailyAggregateSourceType.legacyDns),
      );
      expect(
        () => container.dailyDebriefSources.requireEligible(date),
        throwsA(isA<DailyDebriefSourceException>()),
      );
      await container.dailyAggregates.put(_aggregate(date));
      final source = await container.dailyDebriefSources.requireEligible(date);
      expect(await container.dailyDebriefSources.defaultEligibleDate(), date);
      expect(source.references.morningBrief, isNull);

      final gateway = ProductionReportSyncExchangeGateway(
        container: container,
        clock: () => timestamp,
      );
      final preparation = await gateway.prepareRequest(
        ReportSyncExchangeType.dailyDebrief,
        targetDate: date,
      );
      final prompt = gateway.instruction(
        ReportSyncExchangeType.dailyDebrief,
        preparation,
      );
      expect(prompt, contains('"dailyAggregate"'));
      expect(prompt, contains('"commanderIntentEvaluation": null'));
      expect(prompt, isNot(contains('"dailySummary":')));
      expect(prompt, isNot(contains('"data"')));

      final changedSources = DailyDebriefSources(
        dailyAggregate: DailyDebriefDailyAggregateReference(
          operationDate: date,
          sourceType: 'records',
          recordDigest: _digest('changed'),
        ),
        confirmation: source.references.confirmation,
        morningBrief: source.references.morningBrief,
      );
      final staleResponse = container.reportSyncCodec.create(
        direction: ReportSyncDirection.response,
        exchangeType: ReportSyncExchangeType.dailyDebrief,
        exchangeId: 'stale-dd',
        operationDate: date,
        createdAt: timestamp,
        confirmationDigest: null,
        payload: {
          'operationDate': date,
          'recordVersion': 1,
          'sources': changedSources.toJson(),
          'analysis': _analysis().toJson(),
        },
        schemaVersion: ReportSyncEnvelope.importSchemaVersion2,
      );
      expect(
        () => container.reportSyncPersistence.importDailyDebrief(
          staleResponse,
          sourceService: container.dailyDebriefSources,
          repository: container.dailyDebriefs,
        ),
        throwsA(isA<ReportSyncException>()),
      );
      expect(await container.dailyDebriefs.readByLocalDate(date), isNull);
      expect(await container.reportSyncHistory.list(), isEmpty);

      Future<void> importAnalysis(
        DailyDebriefAnalysis analysis,
        String id,
      ) async {
        final payload = {
          'operationDate': date,
          'recordVersion': 1,
          'sources': source.references.toJson(),
          'analysis': analysis.toJson(),
        };
        final response = container.reportSyncCodec.create(
          direction: ReportSyncDirection.response,
          exchangeType: ReportSyncExchangeType.dailyDebrief,
          exchangeId: id,
          operationDate: date,
          createdAt: timestamp,
          confirmationDigest: null,
          payload: payload,
          schemaVersion: ReportSyncEnvelope.importSchemaVersion2,
        );
        await container.reportSyncPersistence.importDailyDebrief(
          response,
          sourceService: container.dailyDebriefSources,
          repository: container.dailyDebriefs,
        );
      }

      await importAnalysis(_analysis(), 'dd-1');
      await importAnalysis(_analysis(body: '更新後の評価'), 'dd-2');
      final saved = (await container.dailyDebriefs.readByLocalDate(date))!;
      expect(saved.revision, 2);
      expect(
        saved.previousRevisions.single.sources.toJson(),
        source.references.toJson(),
      );
      expect(
        await container.dailyDebriefSources.projectLifecycle(saved),
        DailyDebriefLifecycleStatus.active,
      );
      expect(
        (await container.reportSyncHistory.list()).where(
          (value) => value.exchangeType == ReportSyncExchangeType.dailyDebrief,
        ),
        hasLength(2),
      );

      await container.dailyAggregates.put(_aggregate(date, hydrationMl: 2500));
      expect(
        await container.dailyDebriefSources.projectLifecycle(saved),
        DailyDebriefLifecycleStatus.stale,
      );
      await container.dailyAggregates.deleteByDate(date);
      expect(
        await container.dailyDebriefSources.projectLifecycle(saved),
        DailyDebriefLifecycleStatus.invalidated,
      );
    },
  );
}

DailyDebriefSources _sources(String date) => DailyDebriefSources(
  dailyAggregate: DailyDebriefDailyAggregateReference(
    operationDate: date,
    sourceType: 'records',
    recordDigest: _digest('aggregate'),
  ),
  confirmation: DailyDebriefConfirmationReference(
    recordId: 'confirmation:$date',
    recordVersion: 2,
    revision: 1,
    snapshotDigest: '1234abcd',
    recordDigest: _digest('confirmation'),
  ),
  morningBrief: null,
);

DailyDebriefAnalysis _analysis({String? body = '体調は安定しました'}) =>
    DailyDebriefAnalysis(
      commanderIntentEvaluation: null,
      domainEvaluations: DailyDebriefDomainEvaluations(
        body: body,
        recovery: '回復は良好でした',
        condition: null,
        work: null,
        nutrition: '栄養摂取を確認しました',
        hydration: '水分摂取を確認しました',
        activity: '活動量を確認しました',
        training: null,
      ),
      crossAnalysis: DailyDebriefCrossAnalysis(
        keyFactors: const ['回復'],
        interactions: const [],
        constraints: const [],
        resources: const [],
      ),
      executionEvaluation: DailyDebriefExecutionEvaluation(
        successes: const ['記録を完了しました'],
        adjustments: const [],
      ),
      nextDayHandoff: DailyDebriefNextDayHandoff(
        watchPoints: const ['回復状態を確認します'],
      ),
    );

DailyAggregateV1 _aggregate(
  String date, {
  double hydrationMl = 2000,
  DailyAggregateSourceType sourceType = DailyAggregateSourceType.records,
}) => DailyAggregateV1(
  operationDate: date,
  weightKg: 80,
  bodyFatPercent: 20,
  sleepDurationMinutes: 420,
  sleepScore: 80,
  sleepType: null,
  plantarFasciitisLevel: 1,
  workStartTime: null,
  workEndTime: null,
  workBreakMinutes: null,
  actualWorkMinutes: null,
  intakeCaloriesKcal: 2000,
  estimatedExpenditureKcal: 2300,
  estimatedCalorieBalanceKcal: -300,
  proteinG: 150,
  fatG: 60,
  carbsG: 200,
  hydrationMl: hydrationMl,
  officialSteps: 8000,
  measuredSteps: 8000,
  trainingPerformed: false,
  digestiveCount: 1,
  sourceType: sourceType,
);

String _digest(String value) => ReportSyncCanonicalService.digest(value);
