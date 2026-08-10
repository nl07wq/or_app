import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/data/indexed_db/indexed_db_store_names.dart';
import 'package:or_app/features/operation_sync/models/operation_sync_history.dart';
import 'package:or_app/features/operation_sync/services/historical_training_workflow.dart';
import 'package:or_app/features/operation_sync/services/operation_transfer_id_generator.dart';
import 'package:or_app/features/training/models/custom_training_exercise.dart';
import 'package:or_app/features/training/repository/custom_training_exercise_repository.dart';
import 'package:or_app/features/training/repository/training_record_id_generator.dart';
import 'package:or_app/features/training/services/exercise_name_localization.dart';

import '../../repositories/indexed_db/fake_indexed_db_database.dart';

void main() {
  late FakeIndexedDbDatabase database;
  late HistoricalTrainingWorkflowService workflow;

  setUp(() {
    database = FakeIndexedDbDatabase();
    workflow = _workflow(database);
  });

  test('builds an inclusive date-range prompt without all-record wording', () {
    final prompt = workflow.buildPrompt(
      startDate: '2026-06-01',
      endDate: '2026-06-30',
    );

    expect(prompt, contains('from 2026-06-01 through 2026-06-30, inclusive'));
    expect(prompt, contains('requestedStartDate "2026-06-01"'));
    expect(prompt, contains('requestedEndDate "2026-06-30"'));
    expect(prompt, isNot(contains('ALL AVAILABLE RECORDS')));
    expect(prompt, contains('Do not output a record before 2026-06-01'));
    expect(prompt, contains('formal recordId when known'));
    expect(prompt, contains('Never generate, infer, or reconstruct recordId'));
    expect(prompt, contains('"recordId": null'));
    expect(
      () =>
          workflow.buildPrompt(startDate: '2026-06-30', endDate: '2026-06-01'),
      throwsFormatException,
    );
  });

  test(
    'accepts optional formal recordId and validates existing ID formats',
    () async {
      const formalId = 'training:11111111-1111-4111-8111-111111111111';
      const legacyId = 'legacy-training:1234abcd:0001';

      final withoutId = await workflow.preview(
        jsonEncode(
          _envelope([_record('2026-06-01', 'old-json')], endDate: '2026-06-01'),
        ),
        startDate: '2026-06-01',
        endDate: '2026-06-01',
      );
      expect(withoutId.records.single.recordId, isNull);
      expect(withoutId.newCount, 1);

      for (final recordId in [formalId, legacyId]) {
        final preview = await workflow.preview(
          jsonEncode(
            _envelope(
              [
                _record(
                  '2026-06-02',
                  'with-$recordId',
                  includeRecordId: true,
                  recordId: recordId,
                ),
              ],
              startDate: '2026-06-02',
              endDate: '2026-06-02',
            ),
          ),
          startDate: '2026-06-02',
          endDate: '2026-06-02',
        );
        expect(preview.invalidCount, 0);
        expect(preview.records.single.recordId, recordId);
        expect(preview.records.single.targetRecordId, recordId);
        expect(preview.records.single.persistedRecord!.id, recordId);
      }

      final invalid = await workflow.preview(
        jsonEncode(
          _envelope(
            [
              _record(
                '2026-06-03',
                'invalid-id',
                includeRecordId: true,
                recordId: 'training:not-a-uuid',
              ),
            ],
            startDate: '2026-06-03',
            endDate: '2026-06-03',
          ),
        ),
        startDate: '2026-06-03',
        endDate: '2026-06-03',
      );
      expect(invalid.invalidCount, 1);
    },
  );

  test(
    'strictly validates the historical envelope and package digest',
    () async {
      final valid = _envelope([
        _record('2026-06-01', 'source-1'),
        _record('2026-06-30', 'source-2'),
      ]);
      final preview = await workflow.preview(
        jsonEncode(valid),
        startDate: '2026-06-01',
        endDate: '2026-06-30',
      );
      expect(preview.receivedCount, 2);
      expect(preview.newCount, 2);
      expect(preview.packageDigest, matches(RegExp(r'^[0-9a-f]{64}$')));

      final unknown = _copy(valid)..['unknown'] = true;
      await expectLater(
        workflow.preview(
          jsonEncode(unknown),
          startDate: '2026-06-01',
          endDate: '2026-06-30',
        ),
        throwsFormatException,
      );
      final missing = _copy(valid)..remove('exchangeId');
      await expectLater(
        workflow.preview(
          jsonEncode(missing),
          startDate: '2026-06-01',
          endDate: '2026-06-30',
        ),
        throwsFormatException,
      );
      final suppliedDigest = _copy(valid)..['packageDigest'] = '0' * 64;
      await expectLater(
        workflow.preview(
          jsonEncode(suppliedDigest),
          startDate: '2026-06-01',
          endDate: '2026-06-30',
        ),
        throwsFormatException,
      );
    },
  );

  test('accepts a historical record with a null session name', () async {
    final preview = await workflow.preview(
      jsonEncode(
        _envelope(
          [_record('2026-08-03', 'source-null-name', sessionName: null)],
          startDate: '2026-08-03',
          endDate: '2026-08-03',
        ),
      ),
      startDate: '2026-08-03',
      endDate: '2026-08-03',
    );

    expect(preview.receivedCount, 1);
    expect(preview.newCount, 1);
    expect(preview.invalidCount, 0);
    expect(preview.blockedCount, 0);
    expect(preview.canApply, isTrue);
    final session = preview.records.single.persistedRecord!.dataV2;
    expect(session.sessionName, isNull);
    expect(session.exercises, hasLength(1));
  });

  test('rejects records outside the inclusive requested range', () async {
    final preview = await workflow.preview(
      jsonEncode(
        _envelope([
          _record('2026-05-31', 'before'),
          _record('2026-06-15', 'inside'),
          _record('2026-07-01', 'after'),
        ]),
      ),
      startDate: '2026-06-01',
      endDate: '2026-06-30',
    );

    expect(preview.receivedCount, 3);
    expect(preview.newCount, 1);
    expect(preview.invalidCount, 2);
    expect(preview.canApply, isFalse);
  });

  test(
    'accepts built-in Face Pull with null equipment without custom registry',
    () async {
      final preview = await workflow.preview(
        jsonEncode(
          _envelope([
            _record(
              '2026-06-19',
              'face-pull',
              exerciseName: 'Face Pull',
              equipment: null,
            ),
          ], endDate: '2026-06-19'),
        ),
        startDate: '2026-06-01',
        endDate: '2026-06-19',
      );

      expect(preview.newCount, 1);
      expect(preview.invalidCount, 0);
      final exercise =
          preview.records.single.persistedRecord!.dataV2.exercises.single;
      expect(exercise.exerciseName, 'Face Pull');
      expect(exerciseIdentityKey(exercise.exerciseName), 'facepull');
      expect(exercise.equipment, isNull);
    },
  );

  test('normalizes approved null-equipment dumbbell alias', () async {
    final preview = await workflow.preview(
      jsonEncode(
        _envelope([
          _record(
            '2026-06-01',
            'alias-null',
            exerciseName: 'Dumbbell Shoulder Press',
            equipment: null,
          ),
        ], endDate: '2026-06-01'),
      ),
      startDate: '2026-06-01',
      endDate: '2026-06-01',
    );

    expect(preview.newCount, 1);
    final exercise =
        preview.records.single.persistedRecord!.dataV2.exercises.single;
    expect(exercise.exerciseName, 'Shoulder Press');
    expect(exerciseIdentityKey(exercise.exerciseName), 'shoulderpress');
    expect(exercise.equipment?.catalogId, 'dumbbells');
    expect(exercise.equipment?.name, 'Dumbbells');
  });

  test(
    'normalizes approved separated dumbbell alias without overwriting input',
    () async {
      final equipment = <String, Object?>{'id': null, 'name': 'Dumbbells'};
      final source = _record(
        '2026-06-01',
        'alias-separated',
        exerciseName: 'Dumbbell Shoulder Press',
        equipment: equipment,
      );
      final preview = await workflow.preview(
        jsonEncode(_envelope([source], endDate: '2026-06-01')),
        startDate: '2026-06-01',
        endDate: '2026-06-01',
      );

      expect(preview.newCount, 1);
      expect(equipment, {'id': null, 'name': 'Dumbbells'});
      final exercise =
          preview.records.single.persistedRecord!.dataV2.exercises.single;
      expect(exercise.exerciseName, 'Shoulder Press');
      expect(exerciseIdentityKey(exercise.exerciseName), 'shoulderpress');
      expect(exercise.equipment?.catalogId, 'dumbbells');
      expect(exercise.equipment?.name, 'Dumbbells');
    },
  );

  test('does not apply the dumbbell alias to partial matches', () async {
    final records = <Map<String, Object?>>[
      _record(
        '2026-06-01',
        'wrong-name',
        exerciseName: 'Dumbbell Shoulder Press Extra',
        equipment: null,
      ),
      _record(
        '2026-06-02',
        'wrong-equipment',
        exerciseName: 'Dumbbell Shoulder Press',
        equipment: {'id': null, 'name': 'Barbell'},
      ),
      _record(
        '2026-06-03',
        'existing-id',
        exerciseName: 'Dumbbell Shoulder Press',
        equipment: {'id': 'dumbbells', 'name': 'Dumbbells'},
      ),
    ];
    final preview = await workflow.preview(
      jsonEncode(_envelope(records, endDate: '2026-06-03')),
      startDate: '2026-06-01',
      endDate: '2026-06-03',
    );

    expect(preview.invalidCount, 3);
    expect(preview.newCount, 0);
  });

  test(
    'applies multiple records atomically and verifies both stores',
    () async {
      final response = jsonEncode(
        _envelope([
          _record('2026-06-01', 'source-1'),
          _record('2026-06-02', 'source-2'),
        ], endDate: '2026-06-02'),
      );
      final preview = await workflow.preview(
        response,
        startDate: '2026-06-01',
        endDate: '2026-06-02',
      );
      final result = await workflow.apply(preview);

      expect(database.transactionCount, 1);
      expect(
        await database.findAll(IndexedDbStoreNames.trainingRecords),
        hasLength(2),
      );
      final stored = await database.findById(
        IndexedDbStoreNames.operationSyncHistory,
        result.record.operationId,
      );
      expect(stored, isNotNull);
      expect(OperationSyncRecord.fromRecord(stored!).appliedCount, 2);
      expect(
        (await workflow.listRecords()).single.operationId,
        result.record.operationId,
      );

      final repeated = await workflow.preview(
        response,
        startDate: '2026-06-01',
        endDate: '2026-06-02',
      );
      expect(repeated.identicalCount, 2);
      expect(repeated.newCount, 0);
    },
  );

  test('rolls back training and sync record when read-back fails', () async {
    final preview = await workflow.preview(
      jsonEncode(
        _envelope([_record('2026-06-01', 'source-1')], endDate: '2026-06-01'),
      ),
      startDate: '2026-06-01',
      endDate: '2026-06-01',
    );
    database.failNextReadAfterPutForStore = IndexedDbStoreNames.trainingRecords;

    await expectLater(workflow.apply(preview), throwsStateError);
    expect(
      await database.findAll(IndexedDbStoreNames.trainingRecords),
      isEmpty,
    );
    expect(
      await database.findAll(IndexedDbStoreNames.operationSyncHistory),
      isEmpty,
    );
  });

  test('blocks apply when any record is invalid', () async {
    final preview = await workflow.preview(
      jsonEncode(
        _envelope([
          _record('2026-06-01', 'valid'),
          _record(
            '2026-06-02',
            'invalid',
            exerciseName: 'Unregistered Exercise',
            equipment: null,
          ),
        ], endDate: '2026-06-02'),
      ),
      startDate: '2026-06-01',
      endDate: '2026-06-02',
    );

    expect(preview.newCount, 1);
    expect(preview.invalidCount, 1);
    await expectLater(workflow.apply(preview), throwsStateError);
    expect(
      await database.findAll(IndexedDbStoreNames.trainingRecords),
      isEmpty,
    );
  });

  test(
    'imports only selected NEW records and audits unselected records',
    () async {
      final preview = await workflow.preview(
        jsonEncode(
          _envelope([
            _record('2026-06-01', 'source-1'),
            _record('2026-06-02', 'source-2'),
          ], endDate: '2026-06-02'),
        ),
        startDate: '2026-06-01',
        endDate: '2026-06-02',
      );

      final result = await workflow.apply(preview, selectedIndexes: const {1});
      final stored = await database.findAll(
        IndexedDbStoreNames.trainingRecords,
      );

      expect(stored, hasLength(1));
      expect(stored.single['localDate'], '2026-06-02');
      expect(result.record.newCount, 1);
      expect(result.record.excludedCount, 1);
      expect(result.record.appliedCount, 1);
      expect(
        result.record.records[0].disposition,
        OperationSyncRecordDisposition.excluded,
      );
      expect(
        result.record.records[1].disposition,
        OperationSyncRecordDisposition.newRecord,
      );
    },
  );

  test(
    'bridges legacy JSON by sourceRecordId and classifies changes as DIFFERENT',
    () async {
      final original = jsonEncode(
        _envelope([_record('2026-06-01', 'source-1')], endDate: '2026-06-01'),
      );
      final first = await workflow.preview(
        original,
        startDate: '2026-06-01',
        endDate: '2026-06-01',
      );
      await workflow.apply(first);

      final identical = await workflow.preview(
        original,
        startDate: '2026-06-01',
        endDate: '2026-06-01',
      );
      expect(identical.identicalCount, 1);
      expect(identical.records.single.isSelectable, isFalse);

      final changedRecord = _record('2026-06-01', 'source-1');
      final session = Map<String, Object?>.from(
        changedRecord['session']! as Map,
      );
      final header = Map<String, Object?>.from(session['session']! as Map)
        ..['memo'] = 'changed';
      session['session'] = header;
      changedRecord['session'] = session;
      final different = await workflow.preview(
        jsonEncode(_envelope([changedRecord], endDate: '2026-06-01')),
        startDate: '2026-06-01',
        endDate: '2026-06-01',
      );
      expect(different.blockedCount, 0);
      expect(different.differentCount, 1);
      expect(different.records.single.isSelectable, isTrue);
      expect(different.records.single.differences, isNotEmpty);
      expect(
        await database.findAll(IndexedDbStoreNames.trainingRecords),
        hasLength(1),
      );
    },
  );

  test(
    'classifies formal identity and replaces canonical content safely',
    () async {
      const recordId = 'training:22222222-2222-4222-8222-222222222222';
      final initial = await workflow.preview(
        jsonEncode(
          _envelope(
            [
              _record(
                '2026-06-10',
                'formal-source',
                includeRecordId: true,
                recordId: recordId,
              ),
            ],
            startDate: '2026-06-10',
            endDate: '2026-06-10',
          ),
        ),
        startDate: '2026-06-10',
        endDate: '2026-06-10',
      );
      await workflow.apply(initial);
      final storedBefore = Map<String, Object?>.from(
        (await database.findById(
          IndexedDbStoreNames.trainingRecords,
          recordId,
        ))!,
      );
      storedBefore['createdAt'] = '2026-06-10T01:00:00.000Z';
      storedBefore['updatedAt'] = '2026-06-10T01:00:00.000Z';
      database.seed(
        IndexedDbStoreNames.trainingRecords,
        recordId,
        storedBefore,
      );

      final identical = await workflow.preview(
        jsonEncode(
          _envelope(
            [
              _record(
                '2026-06-10',
                'formal-source',
                includeRecordId: true,
                recordId: recordId,
              ),
            ],
            startDate: '2026-06-10',
            endDate: '2026-06-10',
          ),
        ),
        startDate: '2026-06-10',
        endDate: '2026-06-10',
      );
      expect(identical.identicalCount, 1);

      final different = await workflow.preview(
        jsonEncode(
          _envelope(
            [
              _record(
                '2026-06-10',
                'formal-source',
                includeRecordId: true,
                recordId: recordId,
                memo: 'incoming correction',
              ),
            ],
            startDate: '2026-06-10',
            endDate: '2026-06-10',
          ),
        ),
        startDate: '2026-06-10',
        endDate: '2026-06-10',
      );
      expect(different.differentCount, 1);
      expect(
        different.records.single.differences.map((value) => value.field),
        contains('session.memo'),
      );

      final result = await workflow.apply(different);
      final readBack = await database.findById(
        IndexedDbStoreNames.trainingRecords,
        recordId,
      );
      expect(readBack!['id'], recordId);
      expect(readBack['createdAt'], '2026-06-10T01:00:00.000Z');
      expect(readBack['updatedAt'], '2026-08-04T01:00:00.000Z');
      expect((readBack['data'] as Map)['memo'], 'incoming correction');
      expect(result.record.replacedCount, 1);
      expect(result.record.conflictCount, 0);
      expect(
        result.record.records.single.disposition,
        OperationSyncRecordDisposition.replaced,
      );
    },
  );

  test(
    'blocks unsafe identity and preserves unselected DIFFERENT records',
    () async {
      const recordId = 'training:33333333-3333-4333-8333-333333333333';
      final initial = await workflow.preview(
        jsonEncode(
          _envelope(
            [
              _record(
                '2026-06-20',
                'original',
                includeRecordId: true,
                recordId: recordId,
              ),
            ],
            startDate: '2026-06-20',
            endDate: '2026-06-20',
          ),
        ),
        startDate: '2026-06-20',
        endDate: '2026-06-20',
      );
      await workflow.apply(initial);

      final wrongDate = await workflow.preview(
        jsonEncode(
          _envelope(
            [
              _record(
                '2026-06-21',
                'wrong-date',
                includeRecordId: true,
                recordId: recordId,
              ),
            ],
            startDate: '2026-06-21',
            endDate: '2026-06-21',
          ),
        ),
        startDate: '2026-06-21',
        endDate: '2026-06-21',
      );
      expect(wrongDate.blockedCount, 1);

      final noIdentity = await workflow.preview(
        jsonEncode(
          _envelope(
            [_record('2026-06-20', 'unrelated-source', memo: 'different')],
            startDate: '2026-06-20',
            endDate: '2026-06-20',
          ),
        ),
        startDate: '2026-06-20',
        endDate: '2026-06-20',
      );
      expect(noIdentity.blockedCount, 1);

      final different = await workflow.preview(
        jsonEncode(
          _envelope(
            [
              _record(
                '2026-06-20',
                'original',
                includeRecordId: true,
                recordId: recordId,
                memo: 'not selected',
              ),
              _record('2026-06-22', 'new-selected'),
            ],
            startDate: '2026-06-20',
            endDate: '2026-06-22',
          ),
        ),
        startDate: '2026-06-20',
        endDate: '2026-06-22',
      );
      await workflow.apply(different, selectedIndexes: const {1});
      final unchanged = await database.findById(
        IndexedDbStoreNames.trainingRecords,
        recordId,
      );
      expect((unchanged!['data'] as Map)['memo'], isNull);
    },
  );
}

HistoricalTrainingWorkflowService _workflow(FakeIndexedDbDatabase database) {
  var trainingByte = 0;
  var operationByte = 64;
  return HistoricalTrainingWorkflowService(
    database: database,
    customExercises: const _CustomExercises(),
    clock: () => DateTime.utc(2026, 8, 4, 1),
    idGenerator: TrainingRecordIdGenerator(
      nextInt: (_) => trainingByte++ & 0xff,
    ),
    operationIdGenerator: OperationTransferIdGenerator(
      nextInt: (_) => operationByte++ & 0xff,
    ),
  );
}

Map<String, Object?> _envelope(
  List<Map<String, Object?>> records, {
  String startDate = '2026-06-01',
  String endDate = '2026-06-30',
}) => {
  'format': 'operation-reboot-operation-sync',
  'envelopeVersion': 1,
  'schemaVersion': '1.0',
  'direction': 'response',
  'exchangeType': 'historicalTraining',
  'exchangeId': 'historical-test-response',
  'createdAt': '2026-08-04T00:00:00.000Z',
  'payload': {
    'recordType': 'trainingV2',
    'sourceMode': 'dateRange',
    'importMode': 'missingRecordsOnly',
    'requestedStartDate': startDate,
    'requestedEndDate': endDate,
    'records': records,
  },
  'packageDigest': null,
};

Map<String, Object?> _record(
  String date,
  String sourceRecordId, {
  bool includeRecordId = false,
  String? recordId,
  String exerciseName = 'Bench Press',
  Object? equipment = const {'id': 'power_rack', 'name': 'Power Rack'},
  Object? sessionName = 'Historical Training',
  String? memo,
}) => {
  'operationDate': date,
  if (includeRecordId) 'recordId': recordId,
  'sourceRecordId': sourceRecordId,
  'session': {
    'session': {
      'localDate': date,
      'name': sessionName,
      'grade': 'a',
      'memo': memo,
      'dynamicStretchCompleted': true,
      'cooldownStretchCompleted': true,
      'overallEvaluation': null,
    },
    'exercises': [
      {
        'exerciseName': exerciseName,
        'equipment': equipment,
        'sets': [
          {
            'type': 'main',
            'weightKg': 20,
            'reps': 10,
            'rpe': 8,
            'restAfterSeconds': 60,
          },
        ],
        'evaluation': null,
        'nextTarget': null,
      },
    ],
    'cardio': <Object?>[],
  },
};

Map<String, Object?> _copy(Map<String, Object?> value) =>
    Map<String, Object?>.from(jsonDecode(jsonEncode(value)) as Map);

class _CustomExercises implements CustomTrainingExerciseRepository {
  const _CustomExercises();

  @override
  Future<List<CustomTrainingExercise>> findAll() async => const [];

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
