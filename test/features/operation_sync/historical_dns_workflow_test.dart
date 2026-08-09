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

  test('valid legacy DNS record is classified as NEW', () async {
    final preview = await workflow.preview(
      jsonEncode(_envelope([_record('2026-08-08')])),
      startDate: '2026-08-08',
      endDate: '2026-08-08',
    );

    expect(preview.receivedCount, 1);
    expect(preview.newCount, 1);
    expect(preview.canApply, isTrue);
  });

  test('missing nullable fields are preserved as null', () async {
    final record = _record('2026-08-08')
      ..remove('weightKg')
      ..remove('sleepScore')
      ..remove('officialSteps');
    final preview = await workflow.preview(
      jsonEncode(_envelope([record])),
      startDate: '2026-08-08',
      endDate: '2026-08-08',
    );

    final aggregate = preview.records.single.aggregate!;
    expect(aggregate.weightKg, isNull);
    expect(aggregate.sleepScore, isNull);
    expect(aggregate.officialSteps, isNull);
  });

  test('unknown record field is INVALID and blocks apply', () async {
    final record = _record('2026-08-08')..['unknown'] = true;
    final preview = await workflow.preview(
      jsonEncode(_envelope([record])),
      startDate: '2026-08-08',
      endDate: '2026-08-08',
    );

    expect(preview.invalidCount, 1);
    expect(preview.canApply, isFalse);
    expect(preview.records.single.issues.single.message, contains('unknown'));
  });

  test('existing operation date is never overwritten', () async {
    final existing = _aggregate('2026-08-08', weightKg: 80);
    await repository.put(existing);

    final preview = await workflow.preview(
      jsonEncode(_envelope([_record('2026-08-08', weightKg: 99)])),
      startDate: '2026-08-08',
      endDate: '2026-08-08',
    );

    expect(preview.identicalCount, 1);
    expect(preview.newCount, 0);
    expect(preview.canApply, isFalse);
    expect((await repository.getByDate('2026-08-08'))!.weightKg, 80);
  });

  test('apply saves and reads back legacyDns aggregate and audit', () async {
    final preview = await workflow.preview(
      jsonEncode(_envelope([_record('2026-08-08')])),
      startDate: '2026-08-08',
      endDate: '2026-08-08',
    );
    final result = await workflow.apply(preview);

    final stored = await repository.getByDate('2026-08-08');
    expect(stored, isNotNull);
    expect(stored!.sourceType, DailyAggregateSourceType.legacyDns);
    expect(result.record.workflowKind, 'historicalDns');
    expect(result.record.recordType, 'dailyAggregateV1');
    expect(result.record.appliedCount, 1);
    expect(
      (await workflow.listRecords()).single.operationId,
      result.record.operationId,
    );
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
      proteinG: 120,
      fatG: 60,
      carbsG: 200,
      hydrationMl: 2500,
      officialSteps: 8000,
      measuredSteps: 8200,
      trainingPerformed: true,
      digestiveCount: 1,
      sourceType: DailyAggregateSourceType.legacyDns,
    );
