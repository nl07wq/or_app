import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/models/daily_log_confirmation.dart';
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
      final response = codec.create(
        direction: ReportSyncDirection.response,
        exchangeType: ReportSyncExchangeType.morningBrief,
        exchangeId: 'response-exchange',
        operationDate: '2026-08-02',
        createdAt: timestamp,
        payload: {
          'operationDate': '2026-08-02',
          'generatedAt': timestamp.toIso8601String(),
          'content': {
            'situationAnalysis': 'analysis',
            'operationStatus': 'green',
            'commanderIntent': 'intent',
            'argoComment': 'comment',
            'strategicResourceDecision': 'decision',
            'actions': const [
              {'actionId': 'action-1', 'text': 'act', 'priority': 'high'},
            ],
          },
        },
      );
      final result = await service.importMorningBrief(
        codec.decode(codec.encode(response)),
      );
      expect(result.result, ReportSyncHistoryResult.success);
      expect(
        await IndexedDbMorningBriefRepository(
          database,
        ).readByLocalDate('2026-08-02'),
        isNotNull,
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
