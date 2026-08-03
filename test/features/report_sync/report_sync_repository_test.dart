import 'dart:collection';

import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/models/daily_log_confirmation.dart';
import 'package:or_app/core/models/morning_data.dart';
import 'package:or_app/core/models/work_type.dart';
import 'package:or_app/features/daily_log_confirmation/repository/daily_log_confirmation_repository.dart';
import 'package:or_app/features/operation_date/models/operation_local_date.dart';
import 'package:or_app/features/operation_date/repository/indexed_db_operation_state_repository.dart';
import 'package:or_app/features/report_sync/models/daily_debrief_record.dart';
import 'package:or_app/features/report_sync/models/morning_brief_record.dart';
import 'package:or_app/features/report_sync/models/report_sync_envelope.dart';
import 'package:or_app/features/report_sync/models/report_sync_history.dart';
import 'package:or_app/features/report_sync/models/report_sync_issue.dart';
import 'package:or_app/features/report_sync/repository/indexed_db_report_sync_repositories.dart';
import 'package:or_app/features/report_sync/services/report_sync_canonical_service.dart';
import 'package:or_app/features/report_sync/services/report_sync_codec.dart';
import 'package:or_app/features/report_sync/services/report_sync_persistence_service.dart';
import 'package:or_app/features/report_sync/services/report_sync_validator.dart';
import 'package:or_app/features/report_sync/services/status_report_sync_source_service.dart';
import 'package:or_app/features/status/repositories/indexed_db_status_repository.dart';

import '../../repositories/indexed_db/fake_indexed_db_database.dart';
import '../daily_log_confirmation/daily_log_confirmation_test_fixture.dart';

void main() {
  final timestamp = DateTime.utc(2026, 8, 2, 12);
  const digest =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

  test('Morning Brief create is immutable and read-back verified', () async {
    final database = FakeIndexedDbDatabase();
    final repository = IndexedDbMorningBriefRepository(database);
    final record = MorningBriefRecord(
      localDate: '2026-08-02',
      requestId: 'request-1',
      requestDigest: digest,
      responseDigest: digest,
      generatedAt: timestamp,
      importedAt: timestamp,
      situationAnalysis: 'facts only',
      operationStatus: MorningBriefOperationStatus.green,
      commanderIntent: 'intent',
      argoComment: 'comment',
      strategicResourceDecision: 'decision',
      actions: const [
        MorningBriefAction(actionId: 'a1', text: 'act', priority: 'high'),
      ],
      createdAt: timestamp,
      updatedAt: timestamp,
    );
    expect((await repository.create(record)).localDate, '2026-08-02');
    expect((await repository.create(record)).responseDigest, digest);
    final changed = MorningBriefRecord.fromRecord({
      ...record.toRecord(),
      'argoComment': 'changed',
    });
    expect(
      () => repository.create(changed),
      throwsA(isA<ReportSyncException>()),
    );
    expect(await repository.list(), hasLength(1));
  });

  test('Morning Brief v2 normalizes nested dynamic maps on mixed read', () {
    final record = MorningBriefRecord.v2(
      localDate: '2026-08-02',
      sourceType: 'status',
      sourceOperationDate: '2026-08-02',
      sourceRecordId: 'status:2026-08-02',
      sourceDigest: digest,
      responseDigest: digest,
      exchangeId: 'exchange-v2',
      generatedAt: timestamp,
      importedAt: timestamp,
      situationAnalysisV2: const MorningBriefSituationAnalysis(
        body: '身体を確認しました。',
        recovery: '回復を確認しました。',
        condition: '体調を確認しました。',
        work: '勤務を確認しました。',
        carryover: '引継ぎを確認しました。',
        overall: '全体を確認しました。',
      ),
      operatingPolicy: '回復を優先します。',
      strategicResourceDecisionV2: const MorningBriefStrategicResourceDecision(
        decision: '回復資源を選択します。',
        targetResource: null,
        rationale: '正式記録に基づく判断です。',
        execution: null,
      ),
      operationStatus: MorningBriefOperationStatus.green,
      commanderIntent: '重要事項を確実に進めます。',
      actions: const [
        MorningBriefAction(
          actionId: '2026-08-02:action:1',
          text: '状態を確認します。',
          priority: 'high',
        ),
      ],
      createdAt: timestamp,
      updatedAt: timestamp,
    );
    final stored = record.toRecord();
    stored['situationAnalysis'] = LinkedHashMap<Object?, Object?>.from(
      stored['situationAnalysis'] as Map,
    );
    stored['strategicResourceDecision'] = LinkedHashMap<Object?, Object?>.from(
      stored['strategicResourceDecision'] as Map,
    );
    stored['actions'] = [
      LinkedHashMap<Object?, Object?>.from(
        (stored['actions'] as List).single as Map,
      ),
    ];

    expect(MorningBriefRecord.fromRecord(stored).toRecord(), record.toRecord());
  });

  test(
    'Daily Debrief and history reject different content for same key',
    () async {
      final database = FakeIndexedDbDatabase();
      final debriefs = IndexedDbDailyDebriefRepository(database);
      final histories = IndexedDbReportSyncHistoryRepository(database);
      final debrief = DailyDebriefRecord(
        localDate: '2026-08-02',
        requestId: 'request-1',
        requestDigest: digest,
        responseDigest: digest,
        confirmationDigest: digest,
        generatedAt: timestamp,
        importedAt: timestamp,
        dailySummary: 'summary',
        commanderIntentEvaluation: 'ok',
        successes: const ['one'],
        issues: const [],
        nutritionEvaluation: 'ok',
        activityEvaluation: 'ok',
        trainingEvaluation: 'ok',
        recoveryEvaluation: 'ok',
        carryover: const [],
        tomorrowConsiderations: const ['rest'],
        createdAt: timestamp,
        updatedAt: timestamp,
      );
      await debriefs.create(debrief);
      expect(
        (await debriefs.readByLocalDate('2026-08-02'))?.dailySummary,
        'summary',
      );
      final history = ReportSyncHistory(
        exchangeId: 'exchange-1',
        exchangeType: ReportSyncExchangeType.dailyDebrief,
        direction: ReportSyncDirection.response,
        operationDate: '2026-08-02',
        requestId: 'request-1',
        requestDigest: digest,
        responseDigest: digest,
        confirmationDigest: digest,
        startedAt: timestamp,
        completedAt: timestamp,
        result: ReportSyncHistoryResult.success,
        packageDigest: digest,
      );
      await histories.create(history);
      expect((await histories.create(history)).toRecord(), history.toRecord());
      final changed = ReportSyncHistory.fromRecord({
        ...history.toRecord(),
        'packageDigest':
            'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
      });
      expect(
        () => histories.create(changed),
        throwsA(isA<ReportSyncException>()),
      );
    },
  );

  test(
    'Morning Brief response imports without saved request history',
    () async {
      final database = FakeIndexedDbDatabase();
      final histories = IndexedDbReportSyncHistoryRepository(database);
      final operationState = IndexedDbOperationStateRepository(database);
      await operationState.createInitial(
        OperationLocalDate.parse('2026-08-02'),
      );
      await IndexedDbStatusRepository(database).save(
        MorningData(
          date: '2026-08-02',
          weight: 70,
          bodyFat: 20,
          sleepHours: 7,
          sleepScore: 80,
          footPain: 3,
          workType: WorkType.work,
          workStart: '09:00',
          workEnd: '18:00',
          workBreak: '01:00',
          workHours: 8,
          memo: '',
        ),
      );
      final service = ReportSyncPersistenceService(
        database: database,
        historyRepository: histories,
        validator: ReportSyncValidator(
          historyRepository: histories,
          confirmationRepository: _NoConfirmationStore(),
          operationStateRepository: operationState,
        ),
        clock: () => timestamp,
      );
      const codec = ReportSyncCodec();
      final source = await StatusReportSyncSourceService(
        database,
      ).generate(operationDate: '2026-08-02', exportedAt: timestamp);
      final response = codec.create(
        direction: ReportSyncDirection.response,
        schemaVersion: ReportSyncEnvelope.importSchemaVersion2,
        exchangeType: ReportSyncExchangeType.morningBrief,
        exchangeId: 'response-exchange',
        operationDate: '2026-08-02',
        createdAt: timestamp,
        payload: {
          'operationDate': '2026-08-02',
          'source': {
            'sourceType': 'status',
            'sourceOperationDate': '2026-08-02',
            'sourceRecordId': source.source.sourceRecordId,
            'sourceDigest': source.sourceDigest,
          },
          'content': {
            'situationAnalysis': {
              'body': '体重と体脂肪率は正式記録どおりです。',
              'recovery': '睡眠時間と睡眠スコアを確認しました。',
              'condition': '足の痛みを考慮します。',
              'work': '勤務時間を考慮します。',
              'carryover': '前日情報は利用できません。',
              'overall': '負荷を抑えて安定運用します。',
            },
            'operatingPolicy': '回復を優先しながら必要事項を進めます。',
            'strategicResourceDecision': {
              'decision': '回復資源を優先します。',
              'targetResource': null,
              'rationale': '足の痛みが記録されているためです。',
              'execution': null,
            },
            'operationStatus': 'green',
            'commanderIntent': '回復を守りながら重要事項を確実に進めます。',
            'actions': const [
              {'text': '足の状態を確認してから行動します。', 'priority': 'high'},
            ],
          },
        },
      );
      final result = await service.importMorningBrief(
        codec.decode(codec.encode(response)),
      );
      expect(result.result, ReportSyncHistoryResult.success);
      expect(
        (await IndexedDbMorningBriefRepository(
          database,
        ).readByLocalDate('2026-08-02'))?.recordVersion,
        MorningBriefRecord.currentRecordVersion,
      );
      expect((await histories.list()).length, 1);
    },
  );

  test('Daily Debrief requires confirmed date and exact digest', () async {
    final database = FakeIndexedDbDatabase();
    final histories = IndexedDbReportSyncHistoryRepository(database);
    final operationState = IndexedDbOperationStateRepository(database);
    final initial = await operationState.createInitial(
      OperationLocalDate.parse('2026-08-03'),
    );
    await operationState.save(
      initial.copyWith(
        lastFinalizedDate: OperationLocalDate.parse('2026-08-02'),
        revision: initial.revision + 1,
        updatedAt: initial.updatedAt.add(const Duration(microseconds: 1)),
      ),
      expectedRevision: initial.revision,
    );
    final confirmation = completeConfirmation(date: DateTime(2026, 8, 2));
    final confirmationDigest = ReportSyncCanonicalService.digest(
      confirmation.toJson(),
    );
    final service = ReportSyncPersistenceService(
      database: database,
      historyRepository: histories,
      validator: ReportSyncValidator(
        historyRepository: histories,
        confirmationRepository: _NoConfirmationStore(confirmation),
        operationStateRepository: operationState,
      ),
      clock: () => timestamp,
    );
    const codec = ReportSyncCodec();
    final response = codec.create(
      direction: ReportSyncDirection.response,
      exchangeType: ReportSyncExchangeType.dailyDebrief,
      exchangeId: 'response-dd',
      operationDate: '2026-08-02',
      createdAt: timestamp,
      confirmationDigest: confirmationDigest,
      payload: {
        'operationDate': '2026-08-02',
        'confirmationDigest': confirmationDigest,
        'generatedAt': timestamp.toIso8601String(),
        'content': {
          'dailySummary': 'summary',
          'commanderIntentEvaluation': 'evaluation',
          'successes': const ['success'],
          'issues': const <String>[],
          'nutritionEvaluation': 'nutrition',
          'activityEvaluation': 'activity',
          'trainingEvaluation': 'training',
          'recoveryEvaluation': 'recovery',
          'carryover': const <String>[],
          'tomorrowConsiderations': const ['consideration'],
        },
      },
    );
    expect(
      (await service.importDailyDebrief(
        codec.decode(codec.encode(response)),
      )).result,
      ReportSyncHistoryResult.success,
    );
    expect(
      await IndexedDbDailyDebriefRepository(
        database,
      ).readByLocalDate('2026-08-02'),
      isNotNull,
    );
  });

  test(
    'History persists all four exchange types without raw payload',
    () async {
      final database = FakeIndexedDbDatabase();
      final repository = IndexedDbReportSyncHistoryRepository(database);
      for (final type in ReportSyncExchangeType.values) {
        final history = ReportSyncHistory(
          exchangeId: 'exchange-${type.stableId}',
          exchangeType: type,
          direction: ReportSyncDirection.request,
          operationDate: '2026-08-02',
          requestId: 'request-${type.stableId}',
          requestDigest: digest,
          startedAt: timestamp,
          completedAt: timestamp,
          result: ReportSyncHistoryResult.success,
          packageDigest: digest,
        );
        final stored = await repository.create(history);
        expect(stored.toRecord().keys, ReportSyncHistory.fields);
        expect(stored.toRecord(), isNot(contains('payload')));
        expect(stored.toRecord(), isNot(contains('rawText')));
      }
      expect(await repository.list(), hasLength(4));
    },
  );
}

class _NoConfirmationStore implements DailyLogConfirmationStore {
  final DailyLogConfirmation? value;
  _NoConfirmationStore([this.value]);
  @override
  Future<void> clear() async {}
  @override
  Future<void> deleteByLocalDate(String localDate) async {}
  @override
  Future<List<DailyLogConfirmation>> findAll() async => const [];
  @override
  Future<DailyLogConfirmation?> findByLocalDate(String localDate) async =>
      value;
  @override
  Future<DailyLogConfirmation?> findLatest() async => null;
  @override
  Future<bool> isConfirmed(String localDate) async => false;
  @override
  Future<void> save(DailyLogConfirmation confirmation) async {}
}
