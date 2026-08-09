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
    expect(
      () =>
          workflow.buildPrompt(startDate: '2026-06-30', endDate: '2026-06-01'),
      throwsFormatException,
    );
  });

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
  String exerciseName = 'Bench Press',
  Object? equipment = const {'id': 'power_rack', 'name': 'Power Rack'},
  Object? sessionName = 'Historical Training',
}) => {
  'operationDate': date,
  'sourceRecordId': sourceRecordId,
  'session': {
    'session': {
      'localDate': date,
      'name': sessionName,
      'grade': 'a',
      'memo': null,
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
