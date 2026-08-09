import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/models/morning_data.dart';
import 'package:or_app/features/daily_aggregate/models/daily_aggregate_v1.dart';
import 'package:or_app/features/daily_aggregate/repository/indexed_db_daily_aggregate_repository.dart';
import 'package:or_app/features/operation_sync/models/operation_sync_history.dart';
import 'package:or_app/features/operation_sync/services/historical_dns_workflow.dart';
import 'package:or_app/features/operation_sync/services/operation_transfer_id_generator.dart';

import '../../repositories/indexed_db/fake_indexed_db_database.dart';

void main() {
  late FakeIndexedDbDatabase database;
  late IndexedDbDailyAggregateRepository repository;
  late HistoricalDnsWorkflowService workflow;

  setUp(() {
    database = FakeIndexedDbDatabase();
    repository = IndexedDbDailyAggregateRepository(database);
    workflow = HistoricalDnsWorkflowService(
      database: database,
      repository: repository,
      clock: () => DateTime.utc(2026, 8, 9, 12),
      operationIdGenerator: OperationTransferIdGenerator(nextInt: (_) => 7),
    );
  });

  test('prompt requires range midpoint and preserves only approved data', () {
    final prompt = workflow.buildPrompt(
      startDate: '2026-08-08',
      endDate: '2026-08-08',
    );

    expect(prompt, contains('2500 through 2800 becomes 2650'));
    expect(prompt, contains('-1000 through -1300 becomes -1150'));
    expect(prompt, contains('This midpoint conversion is the only permitted'));
    expect(prompt, contains('a deficit is negative'));
    expect(prompt, contains('digestiveEvents'));
    expect(prompt, contains('conditionFactSummary'));
    expect(prompt, contains('operationStatus'));
    expect(prompt, contains('Do not add any CI field'));
    expect(prompt, contains('do not add hydration breakdown'));
    expect(prompt, contains('Do not add record status'));
    expect(prompt, isNot(contains('Do not add CI, hydration breakdown,')));
  });

  test(
    'expanded historical DNS record is accepted without data loss',
    () async {
      final preview = await workflow.preview(
        jsonEncode(_envelope([_record('2026-08-08')])),
        startDate: '2026-08-08',
        endDate: '2026-08-08',
      );

      expect(preview.receivedCount, 1);
      expect(preview.newCount, 1);
      expect(preview.canApply, isTrue);
      final aggregate = preview.records.single.aggregate!;
      expect(aggregate.estimatedExpenditureKcal, 2650);
      expect(aggregate.estimatedCalorieBalanceKcal, -1150);
      expect(aggregate.digestiveEvents, hasLength(2));
      expect(aggregate.digestiveEvents.first.toJson(), {
        'amount': 3,
        'shape': 2,
        'relief': null,
      });
      expect(aggregate.operationStatus, 'RED');
      expect(aggregate.conditionFactSummary, contains('排便2回'));
    },
  );

  test('CI and other excluded fields are rejected', () async {
    final record = _record('2026-08-08')
      ..['ci'] = 542
      ..['hydrationBreakdown'] = const []
      ..['recordStatus'] = 'Fixed';
    final preview = await workflow.preview(
      jsonEncode(_envelope([record])),
      startDate: '2026-08-08',
      endDate: '2026-08-08',
    );

    expect(preview.invalidCount, 1);
    expect(preview.canApply, isFalse);
    expect(preview.records.single.issues.single.message, contains('unknown'));
  });

  test('apply round-trips expanded aggregate and audit', () async {
    final preview = await workflow.preview(
      jsonEncode(_envelope([_record('2026-08-08')])),
      startDate: '2026-08-08',
      endDate: '2026-08-08',
    );
    final result = await workflow.apply(preview);

    final stored = await repository.getByDate('2026-08-08');
    expect(stored, isNotNull);
    expect(stored!.sourceType, DailyAggregateSourceType.legacyDns);
    expect(stored.toJson(), preview.records.single.aggregate!.toJson());
    expect(stored.estimatedExpenditureKcal, 2650);
    expect(stored.estimatedCalorieBalanceKcal, -1150);
    expect(stored.digestiveEvents, hasLength(2));
    expect(stored.operationStatus, 'RED');
    expect(stored.conditionFactSummary, hasLength(6));
    expect(result.record.workflowKind, 'historicalDns');
    expect(result.record.recordType, 'dailyAggregateV1');
    expect(result.record.appliedCount, 1);
    expect(
      (await workflow.listRecords()).single.operationId,
      result.record.operationId,
    );
  });

  test('old DailyAggregate record remains readable without inferred data', () {
    final oldRecord = _aggregate('2026-08-08', weightKg: 80).toJson()
      ..remove('estimatedExpenditureKcal')
      ..remove('estimatedCalorieBalanceKcal')
      ..remove('digestiveEvents')
      ..remove('operationStatus')
      ..remove('conditionFactSummary');

    final restored = DailyAggregateV1.fromJson(oldRecord);

    expect(restored.estimatedExpenditureKcal, isNull);
    expect(restored.estimatedCalorieBalanceKcal, isNull);
    expect(restored.digestiveEvents, isEmpty);
    expect(restored.operationStatus, isNull);
    expect(restored.conditionFactSummary, isEmpty);
    expect(restored.toJson(), isNot(contains('estimatedExpenditureKcal')));
  });
}

Map<String, Object?> _envelope(List<Map<String, Object?>> records) => {
  'format': 'operation-reboot-operation-sync',
  'envelopeVersion': 1,
  'schemaVersion': '1.0',
  'direction': 'response',
  'exchangeType': 'historicalDns',
  'exchangeId': 'dns-response-2026-08-08',
  'createdAt': '2026-08-09T12:00:00.000Z',
  'payload': {
    'recordType': 'dailyAggregateV1',
    'sourceMode': 'dateRange',
    'importMode': 'missingRecordsOnly',
    'requestedStartDate': '2026-08-08',
    'requestedEndDate': '2026-08-08',
    'records': records,
  },
  'packageDigest': null,
};

Map<String, Object?> _record(String date, {double weightKg = 95.6}) =>
    _aggregate(date, weightKg: weightKg).toJson();

DailyAggregateV1 _aggregate(String date, {required double weightKg}) =>
    DailyAggregateV1(
      operationDate: date,
      weightKg: weightKg,
      bodyFatPercent: 32.5,
      sleepDurationMinutes: 420,
      sleepScore: 80,
      sleepType: SleepType.sleep,
      plantarFasciitisLevel: 2,
      workStartTime: '10:00',
      workEndTime: '18:00',
      workBreakMinutes: 60,
      actualWorkMinutes: 420,
      intakeCaloriesKcal: 2000,
      estimatedExpenditureKcal: 2650,
      estimatedCalorieBalanceKcal: -1150,
      proteinG: 120,
      fatG: 60,
      carbsG: 200,
      hydrationMl: 2500,
      officialSteps: 8000,
      measuredSteps: 8200,
      trainingPerformed: true,
      digestiveCount: 1,
      digestiveEvents: const [
        DailyAggregateDigestiveEventV1(amount: 3, shape: 2, relief: null),
        DailyAggregateDigestiveEventV1(amount: 2, shape: 3, relief: null),
      ],
      operationStatus: 'RED',
      conditionFactSummary: const [
        '睡眠2時間21分',
        '正式歩数6,970歩',
        '水分3,600mL',
        'トレーニングなし',
        '排便2回',
        '夕食は帰宅後就寝により欠食',
      ],
      sourceType: DailyAggregateSourceType.legacyDns,
    );
