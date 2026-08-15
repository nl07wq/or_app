import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/data/indexed_db/indexed_db_store_names.dart';
import 'package:or_app/data/indexed_db/indexed_db_database_contract.dart';
import 'package:or_app/features/daily_aggregate/models/daily_aggregate_v1.dart';
import 'package:or_app/features/daily_log_confirmation/models/persisted_daily_log_confirmation_record.dart';
import 'package:or_app/features/import_export/models/backup_package.dart';
import 'package:or_app/features/import_export/services/backup_store_registry.dart';
import 'package:or_app/features/operation_date/models/operation_local_date.dart';
import 'package:or_app/features/operation_date/models/operation_active_attempt.dart';
import 'package:or_app/features/operation_date/models/operation_state.dart';
import 'package:or_app/features/report_sync/models/daily_debrief_record.dart';
import 'package:or_app/features/report_sync/models/report_sync_envelope.dart';
import 'package:or_app/features/report_sync/models/report_sync_issue.dart';
import 'package:or_app/features/report_sync/repository/indexed_db_report_sync_repositories.dart';
import 'package:or_app/features/report_sync/services/report_sync_canonical_service.dart';
import 'package:or_app/features/report_sync/services/daily_debrief_source_service.dart';
import 'package:or_app/features/report_sync/services/daily_debrief_analysis_response_validator.dart';
import 'package:or_app/features/report_sync/services/report_sync_exchange_gateway.dart';
import 'package:or_app/features/repositories/app_repository_container.dart';
import 'package:or_app/core/services/daily_log_confirmation_validation.dart';

import '../../repositories/indexed_db/fake_indexed_db_database.dart';
import '../daily_log_confirmation/daily_log_confirmation_test_fixture.dart';

void main() {
  const date = '2026-08-09';
  final timestamp = DateTime.utc(2026, 8, 9, 23);

  test('awaiting debrief defaults to the current operation date', () async {
    final database = FakeIndexedDbDatabase();
    final container = AppRepositoryContainer.indexedDb(database);
    final operationDate = OperationLocalDate.parse(date);
    await container.operationState.createInitial(operationDate);
    final state = await container.operationState.requireCurrent();
    await container.operationState.save(
      state.copyWith(
        phase: OperationPhase.awaitingDebrief,
        activeAttempt: OperationActiveAttempt(
          idempotencyKey: 'daily-close:$date',
          targetLocalDate: operationDate,
          startedAt: timestamp,
          confirmationId: 'confirmation:$date',
          confirmationDigest: _digest('confirmation'),
        ),
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
    await container.dailyAggregates.put(_aggregate(date));

    expect(await container.dailyDebriefSources.defaultEligibleDate(), date);
    final gateway = ProductionReportSyncExchangeGateway(
      container: container,
      clock: () => timestamp,
    );
    final preparation = await gateway.prepareRequest(
      ReportSyncExchangeType.dailyDebrief,
    );
    expect(preparation.operationDate, date);
    gateway.instruction(ReportSyncExchangeType.dailyDebrief, preparation);
    final preview = await gateway.previewResponse(
      ReportSyncExchangeType.dailyDebrief,
      jsonEncode(_analysis().toJson()),
      targetDate: date,
    );
    expect(preview.operationDate, date);
    await gateway.apply(preview);
    final record = (await container.dailyDebriefs.readByLocalDate(date))!;
    expect(
      await container.dailyDebriefSources.projectLifecycle(record),
      DailyDebriefLifecycleStatus.active,
    );
  });

  test(
    'ready open operation date leads eligible dates without replacing history',
    () async {
      final database = FakeIndexedDbDatabase();
      final container = AppRepositoryContainer.indexedDb(database);
      const currentDate = '2026-08-10';
      await container.operationState.createInitial(
        OperationLocalDate.parse(currentDate),
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
      await container.dailyAggregates.put(_aggregate(date));
      final currentValidation = DailyLogConfirmationValidation.validate(
        morning: completeConfirmation(date: DateTime(2026, 8, 10)).morning,
        food: completeConfirmation(date: DateTime(2026, 8, 10)).food,
        activity: completeConfirmation(date: DateTime(2026, 8, 10)).activity!,
        training: completeConfirmation(date: DateTime(2026, 8, 10)).training,
      );

      expect(await container.dailyDebriefSources.eligibleDates(), [date]);
      expect(
        await container.dailyDebriefSources.eligibleDates(
          currentOperationDateValidation: currentValidation,
        ),
        [currentDate, date],
      );
      expect(
        await container.dailyDebriefSources.defaultEligibleDate(
          currentOperationDateValidation: currentValidation,
        ),
        currentDate,
      );
      expect(await container.dailyDebriefSources.defaultEligibleDate(), date);
    },
  );

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

  test('analysis-only validator enforces the complete compact schema', () {
    const validator = DailyDebriefAnalysisResponseValidator();
    final valid = _analysis().toJson();
    expect(
      validator.decode(jsonEncode(valid), hasMorningBrief: false).toJson(),
      valid,
    );

    final missing = Map<String, Object?>.from(valid)..remove('nextDayHandoff');
    final invalidOutcome = _deepCopy(valid);
    invalidOutcome['commanderIntentEvaluation'] = {
      'outcome': 'invalid',
      'rationale': '評価',
      'evidence': <Object?>[],
    };
    final invalidDomain = _deepCopy(valid);
    (invalidDomain['domainEvaluations']! as Map<String, Object?>)['unknown'] =
        '評価';
    final invalidArray = _deepCopy(valid);
    (invalidArray['crossAnalysis']! as Map<String, Object?>)['keyFactors'] =
        '回復';
    final emptyString = _deepCopy(valid);
    (emptyString['domainEvaluations']! as Map<String, Object?>)['body'] = ' ';
    final tooMany = _deepCopy(valid);
    (tooMany['nextDayHandoff']! as Map<String, Object?>)['watchPoints'] = [
      '1',
      '2',
      '3',
      '4',
    ];

    for (final invalid in [
      {...valid, 'unknown': true},
      missing,
      invalidOutcome,
      invalidDomain,
      invalidArray,
      emptyString,
      tooMany,
    ]) {
      expect(
        () => validator.decode(jsonEncode(invalid), hasMorningBrief: true),
        throwsA(isA<ReportSyncException>()),
      );
    }
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
      await expectLater(
        gateway.previewResponse(
          ReportSyncExchangeType.dailyDebrief,
          jsonEncode(_analysis().toJson()),
          targetDate: date,
        ),
        throwsA(isA<ReportSyncException>()),
      );
      final prompt = gateway.instruction(
        ReportSyncExchangeType.dailyDebrief,
        preparation,
      );
      expect(prompt, contains('"dailyAggregate"'));
      expect(prompt, contains('"recentContext"'));
      expect(prompt, contains('"windowStart": "2026-08-03"'));
      expect(prompt, contains('"windowEnd": "2026-08-09"'));
      expect(prompt, contains('records-source Daily Aggregates'));
      expect(prompt, contains('2139.23kcal as 2,139kcal'));
      expect(prompt, contains('229 minutes is 3:49'));
      expect(prompt, contains('use only officialSteps'));
      expect(prompt, contains('use that classification exactly'));
      expect(prompt, contains('do not create another threshold'));
      expect(prompt, contains('comparisonLevel is separate from trend'));
      expect(prompt, contains('never MORNING BRIEF or MORNING ROUTINE'));
      expect(prompt, contains('"commanderIntentEvaluation": null'));
      expect(prompt, contains('exactly one fenced Plain Text code block'));
      expect(prompt, contains('opening fence is ```text'));
      expect(prompt, contains('closing fence is ```'));
      expect(prompt, contains('Return nothing outside that code block'));
      expect(
        prompt,
        contains('SECTION RESPONSIBILITY AND GLOBAL NON-DUPLICATION'),
      );
      expect(
        prompt,
        contains(
          'crossAnalysis.interactions requires a supported relationship',
        ),
      );
      expect(
        prompt,
        contains('Empty arrays and null domain evaluations are valid'),
      );
      expect(
        prompt,
        contains('Inside the code block, return exactly one JSON object'),
      );
      expect(
        prompt,
        contains('copied content must start with { and end with }'),
      );
      expect(prompt, contains('ASCII half-width double quotation marks'));
      expect(prompt, contains('Never use smart or curly quotes'));
      expect(prompt, contains('Do not add unknown fields'));
      expect(prompt, contains('omit required fields'));
      expect(prompt, contains('Nullable fields must be explicit null'));
      expect(prompt, contains('use [] when empty'));
      expect(prompt, contains('object and array nesting is balanced'));
      expect(prompt, contains('every opening brace, bracket, and ASCII quote'));
      expect(prompt, contains('no extra or missing closing brace'));
      expect(prompt, contains('there is no trailing comma'));
      expect(prompt, contains('trainingPerformed is false'));
      expect(prompt, contains('domainEvaluations.training must be null'));
      expect(prompt, contains('body, recovery, condition, work, nutrition'));
      expect(prompt, contains('When a domain has no formal fact'));
      expect(prompt, contains('62.06999999999999 as 62.07g'));
      expect(prompt, contains('295.53999999999996 as 295.54g'));
      expect(prompt, contains('2139.23kcal as 2,139kcal'));
      expect(prompt, contains('2685.6kcal as 2,686kcal'));
      expect(prompt, contains('-355.6kcal as -356kcal'));
      expect(prompt, isNot(contains('2685.6 becomes 2,685.6')));
      expect(prompt, contains('formatting applies only to analysis prose'));
      expect(prompt, contains('do not alter, round, recalculate'));
      expect(
        prompt,
        contains('do not change or recalculate any source digest'),
      );
      expect(prompt, contains('instead of merely repeating or re-listing'));
      expect(prompt, contains('does not confirm'));
      expect(
        prompt,
        contains('rather than exposing internal field identifiers'),
      );
      expect(prompt, contains('raw boolean expressions'));
      expect(prompt, contains('cannot be confirmed or evaluated'));
      expect(prompt, contains('must not decide the next-day operation'));
      expect(prompt, contains('must be no more than two sentences'));
      expect(prompt, contains('evidence must contain at most 3'));
      expect(prompt, contains('successes must contain at most 3'));
      expect(prompt, contains('adjustments must contain at most 2'));
      expect(
        prompt,
        contains('Each crossAnalysis array must contain at most 2'),
      );
      expect(prompt, contains('may be []'));
      expect(
        prompt,
        contains('domain evaluation should generally be one sentence'),
      );
      expect(prompt, contains('watchPoints must contain at most 3'));
      expect(prompt, contains('do not repeatedly list sleep'));
      expect(prompt, contains('whether a break was actually used for rest'));
      expect(prompt, contains('whether sleep began immediately after work'));
      expect(prompt, contains('what happened after returning home'));
      expect(prompt, contains('use 睡眠 and 睡眠スコア'));
      expect(prompt, contains('Never write Sleep Score or SLEEP SCORE'));
      expect(
        prompt,
        contains('never expose 正式歩数, Official Steps, or officialSteps'),
      );
      expect(prompt, contains('Continue to ignore measured or raw steps'));
      expect(prompt, contains('Invalid JSON cannot be imported'));
      expect(prompt, contains('Do not rely on the app to repair smart quotes'));
      expect(prompt, contains('COMPLETE ANALYSIS SHAPE'));
      expect(prompt, contains('Do not return an envelope'));
      expect(prompt, contains('Operation Reboot retains and binds'));
      expect(prompt, isNot(contains('COMPLETE RESPONSE SHAPE')));
      expect(prompt, isNot(contains('"exchangeId": "<UNIQUE_RESPONSE_ID>"')));
      expect(prompt, isNot(contains('"packageDigest": null')));
      expect(prompt, isNot(contains('"dailySummary":')));
      expect(prompt, isNot(contains('"carryover":')));
      expect(prompt, isNot(contains('"data"')));
      expect(prompt, contains('"fatG": 62.06999999999999'));
      expect(prompt, contains('"carbsG": 295.53999999999996'));
      expect(
        prompt,
        contains('"estimatedCalorieBalanceKcal": -355.5999999999999'),
      );
      expect(
        () => container.reportSyncCodec.decode(
          '{"format":"operation-reboot-report-sync"}}',
        ),
        throwsA(anything),
      );
      for (final malformed in const [
        '{“format”:“operation-reboot-report-sync”}',
        '{"format":"operation-reboot-report-sync"',
        '{"format":"operation-reboot-report-sync",}',
        '```text\n{"format":"operation-reboot-report-sync"}\n```',
      ]) {
        expect(
          () => container.reportSyncCodec.decode(malformed),
          throwsA(anything),
        );
      }

      final normalizationRaw = jsonEncode(
        _analysis(body: '本人は“休養”を選択した').toJson(),
      );
      for (final normalizedInput in [
        normalizationRaw,
        '  \n$normalizationRaw\n  ',
        '\uFEFF$normalizationRaw',
        '```text\n$normalizationRaw\n```',
        '```json\n$normalizationRaw\n```',
        '```\n$normalizationRaw\n```',
      ]) {
        final preview = await gateway.previewResponse(
          ReportSyncExchangeType.dailyDebrief,
          normalizedInput,
          targetDate: date,
        );
        expect(preview.disposition, ReportSyncDisposition.create);
        final previewAnalysis = Map<String, Object?>.from(
          preview.envelope!.payload['analysis']! as Map,
        );
        expect(preview.envelope!.operationDate, date);
        expect(preview.envelope!.payload['recordVersion'], 1);
        expect(
          preview.envelope!.payload['sources'],
          source.references.toJson(),
        );
        expect(preview.envelope!.createdAt, timestamp);
        expect(preview.envelope!.packageDigest, isNotEmpty);
        final domains = Map<String, Object?>.from(
          previewAnalysis['domainEvaluations']! as Map,
        );
        expect(domains['body'], '本人は“休養”を選択した');
      }

      final unknownFields = Map<String, Object?>.from(
        jsonDecode(normalizationRaw) as Map,
      )..['unknownField'] = true;
      for (final invalidInput in [
        normalizationRaw.replaceAll('"', '”'),
        '$normalizationRaw}',
        normalizationRaw.substring(0, normalizationRaw.length - 1),
        '```text\n${jsonEncode(unknownFields)}\n```',
        container.reportSyncCodec.encode(
          container.reportSyncCodec.create(
            direction: ReportSyncDirection.response,
            exchangeType: ReportSyncExchangeType.dailyDebrief,
            exchangeId: 'legacy-full-envelope',
            operationDate: date,
            createdAt: timestamp,
            confirmationDigest: null,
            payload: {
              'operationDate': date,
              'recordVersion': 1,
              'sources': source.references.toJson(),
              'analysis': _analysis().toJson(),
            },
            schemaVersion: ReportSyncEnvelope.importSchemaVersion2,
          ),
        ),
      ]) {
        await expectLater(
          gateway.previewResponse(
            ReportSyncExchangeType.dailyDebrief,
            invalidInput,
            targetDate: date,
          ),
          throwsA(isA<ReportSyncException>()),
        );
      }

      await container.dailyAggregates.put(_aggregate(date, hydrationMl: 2100));
      final sourceChangedPreview = await gateway.previewResponse(
        ReportSyncExchangeType.dailyDebrief,
        normalizationRaw,
        targetDate: date,
      );
      expect(sourceChangedPreview.disposition, ReportSyncDisposition.blocked);
      await container.dailyAggregates.put(_aggregate(date));

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

      Future<ReportSyncResponsePreview> previewAnalysis(
        DailyDebriefAnalysis analysis,
      ) async {
        final boundPreparation = await gateway.prepareRequest(
          ReportSyncExchangeType.dailyDebrief,
          targetDate: date,
        );
        gateway.instruction(
          ReportSyncExchangeType.dailyDebrief,
          boundPreparation,
        );
        return gateway.previewResponse(
          ReportSyncExchangeType.dailyDebrief,
          jsonEncode(analysis.toJson()),
          targetDate: date,
        );
      }

      Future<void> importAnalysis(DailyDebriefAnalysis analysis) async {
        final preview = await previewAnalysis(analysis);
        final result = await gateway.apply(preview);
        expect(result.readBackVerified, isTrue);
      }

      final firstPreview = await previewAnalysis(_analysis());
      await gateway.apply(firstPreview);
      await expectLater(
        gateway.apply(firstPreview),
        throwsA(isA<ReportSyncException>()),
      );
      await importAnalysis(_analysis(body: '更新後の評価'));
      await importAnalysis(_analysis(body: '3回目の評価'));
      final saved = (await container.dailyDebriefs.readByLocalDate(date))!;
      expect(saved.revision, 3);
      expect(saved.previousRevisions, hasLength(2));
      expect(
        saved.previousRevisions.map((value) => value.sources.toJson()),
        everyElement(source.references.toJson()),
      );
      expect(
        await container.dailyDebriefSources.projectLifecycle(saved),
        DailyDebriefLifecycleStatus.active,
      );
      expect(
        (await container.reportSyncHistory.list()).where(
          (value) => value.exchangeType == ReportSyncExchangeType.dailyDebrief,
        ),
        hasLength(3),
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
  estimatedCalorieBalanceKcal: -355.5999999999999,
  proteinG: 150,
  fatG: 62.06999999999999,
  carbsG: 295.53999999999996,
  hydrationMl: hydrationMl,
  officialSteps: 8000,
  measuredSteps: 8000,
  trainingPerformed: false,
  digestiveCount: 1,
  sourceType: sourceType,
);

String _digest(String value) => ReportSyncCanonicalService.digest(value);

Map<String, Object?> _deepCopy(Map<String, Object?> value) =>
    Map<String, Object?>.from(jsonDecode(jsonEncode(value)) as Map);
