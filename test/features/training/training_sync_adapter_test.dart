import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/models/morning_data.dart';
import 'package:or_app/core/models/work_type.dart';
import 'package:or_app/features/status/models/persisted_status_record.dart';
import 'package:or_app/features/status/repositories/status_repository.dart';
import 'package:or_app/features/sync/models/orlo_sync_models.dart';
import 'package:or_app/features/training/repository/custom_training_exercise_repository.dart';
import 'package:or_app/features/training/models/custom_training_exercise.dart';
import 'package:or_app/features/training/repository/indexed_db_training_repository.dart';
import 'package:or_app/features/training/sync/training_sync_adapter.dart';
import 'package:or_app/features/training/sync/training_sync_instruction_provider.dart';
import 'package:or_app/features/training/sync/training_sync_schema.dart';
import 'package:or_app/features/training/services/training_status_weight_resolver.dart';

import '../../repositories/indexed_db/fake_indexed_db_database.dart';

void main() {
  late FakeIndexedDbDatabase database;
  late IndexedDbTrainingSessionRepository repository;
  late TrainingSyncAdapter adapter;

  setUp(() {
    database = FakeIndexedDbDatabase();
    repository = IndexedDbTrainingSessionRepository(
      database,
      now: () => DateTime.utc(2026, 8, 2),
    );
    adapter = TrainingSyncAdapter(
      repository: repository,
      customExercises: _CustomExercises(),
    );
  });

  test(
    'validates formal session, identity, stretch, and evaluation fields',
    () async {
      final envelope = _envelope();
      expect(await adapter.validatePayload(envelope), isEmpty);
      final decoded = await TrainingSyncSchema.decode(
        payload: envelope.payload,
        operationDate: envelope.operationDate,
        idempotencyKey: envelope.idempotencyKey,
        customExercises: _CustomExercises(),
      );
      expect(decoded.session.dynamicStretchCompleted, isTrue);
      expect(decoded.session.cooldownStretchCompleted, isFalse);
      expect(decoded.session.overallEvaluation, 'Good session');
      expect(decoded.exerciseIds, ['benchpress']);
    },
  );

  test(
    'rejects key/date/identity/unknown field and invalid domain values',
    () async {
      final invalid = <OrloSyncEnvelope>[
        _envelope(idempotencyKey: _id(2)),
        _envelope(operationDate: '2026-08-02'),
        _envelope(
          change: (payload) => _exercise(payload)['exerciseId'] = 'wrong',
        ),
        _envelope(change: (payload) => _session(payload)['evaluation'] = 'no'),
        _envelope(change: (payload) => _set(payload)['type'] = 'legacyUnknown'),
        _envelope(change: (payload) => _set(payload)['weightKg'] = -1),
        _envelope(change: (payload) => _set(payload)['rpe'] = 11),
        _envelope(change: (payload) => _set(payload)['restAfterSeconds'] = -1),
      ];
      for (final envelope in invalid) {
        final issues = await adapter.validatePayload(envelope);
        expect(issues.map((issue) => issue.code), contains('payloadInvalid'));
      }
    },
  );

  test('accepts only registered custom exercise identities', () async {
    final envelope = _envelope(
      change: (payload) {
        final exercise = _exercise(payload);
        exercise['exerciseName'] = 'My Custom Move';
        exercise['exerciseId'] = 'mycustommove';
        exercise['equipment'] = <String, Object?>{
          'id': null,
          'name': 'My Attachment',
        };
      },
    );
    expect(await adapter.validatePayload(envelope), isNotEmpty);

    adapter = TrainingSyncAdapter(
      repository: repository,
      customExercises: _CustomExercises([
        const CustomTrainingExercise(id: 'custom-1', name: 'My Custom Move'),
      ]),
    );
    expect(await adapter.validatePayload(envelope), isEmpty);
  });

  test(
    'previews CREATE, imports fixed ID atomically, then previews NO CHANGES',
    () async {
      final envelope = _envelope();
      final first = await adapter.buildPreview(envelope);
      expect(first.create, 1);
      final result = await adapter.applyAndVerify(
        envelope: envelope,
        expectedPayloadDigest: 'payload-digest',
      );
      expect(result.success, isTrue);
      expect((await repository.findRecordById(_id(1)))?.recordVersion, 2);
      final second = await adapter.buildPreview(envelope);
      expect(second.noOp, 1);
      expect(second.create, 0);
    },
  );

  test(
    'same ID with different content is conflict and is not overwritten',
    () async {
      final original = _envelope();
      await adapter.applyAndVerify(
        envelope: original,
        expectedPayloadDigest: 'payload-digest',
      );
      final changed = _envelope(
        change: (payload) => _session(payload)['memo'] = 'changed',
      );
      expect(
        (await adapter.detectConflicts(changed)).single.severity,
        SyncIssueSeverity.conflict,
      );
      final before = await repository.findRecordById(_id(1));
      final result = await adapter.applyAndVerify(
        envelope: changed,
        expectedPayloadDigest: 'changed-digest',
      );
      expect(result.success, isFalse);
      expect(
        (await repository.findRecordById(_id(1)))?.v2Data?.memo,
        before?.v2Data?.memo,
      );
    },
  );

  test('same canonical content under another ID is persistent NO-OP', () async {
    await adapter.applyAndVerify(
      envelope: _envelope(),
      expectedPayloadDigest: 'first',
    );
    final resent = _envelope(recordId: _id(2), idempotencyKey: _id(2));
    final preview = await adapter.buildPreview(resent);
    expect(preview.noOp, 1);
    expect(await repository.findRecordById(_id(2)), isNull);
  });

  test('transaction failure rolls back without a partial record', () async {
    database.failNextTransactionWith = StateError('write failed');
    await expectLater(
      adapter.applyAndVerify(
        envelope: _envelope(),
        expectedPayloadDigest: 'failed',
      ),
      throwsA(isA<Exception>()),
    );
    expect(await repository.findRecordById(_id(1)), isNull);
  });

  test('calculates cardio calories from same-day STATUS weight', () async {
    adapter = TrainingSyncAdapter(
      repository: repository,
      customExercises: _CustomExercises(),
      weightResolver: TrainingStatusWeightResolver(
        repository: _StatusRepository({'2026-08-01': _status(80)}),
      ),
    );
    final envelope = _envelope(change: (payload) => _addCardio(payload));
    expect(await adapter.validatePayload(envelope), isEmpty);
    final result = await adapter.applyAndVerify(
      envelope: envelope,
      expectedPayloadDigest: 'cardio',
    );
    expect(result.success, isTrue);
    final cardio = (await repository.findRecordById(
      _id(1),
    ))!.v2Data!.cardioEntries.single;
    expect(cardio.estimatedCaloriesKcal, 70);
    expect(cardio.weightSnapshotKg, 80);
    expect(cardio.calculationMethod, 'metsAcsmV1');
    expect(cardio.calculationVersion, 1);
  });

  test('round-trips optional Training time and Strength snapshot', () async {
    adapter = TrainingSyncAdapter(
      repository: repository,
      customExercises: _CustomExercises(),
      weightResolver: TrainingStatusWeightResolver(
        repository: _StatusRepository({'2026-08-01': _status(80)}),
      ),
    );
    final envelope = _envelope(
      change: (payload) {
        final session = _session(payload);
        session['startTime'] = '2026-08-01T10:00:00+09:00';
        session['endTime'] = '2026-08-01T11:00:00+09:00';
        session['estimatedStrengthCaloriesKcal'] = null;
        session['strengthWeightSnapshotKg'] = null;
        session['strengthCalculationMethod'] = null;
        session['strengthCalculationVersion'] = null;
      },
    );

    expect(await adapter.validatePayload(envelope), isEmpty);
    final result = await adapter.applyAndVerify(
      envelope: envelope,
      expectedPayloadDigest: 'strength',
    );
    expect(result.success, isTrue);
    final record = await repository.findRecordById(_id(1));
    expect(record?.id, _id(1));
    expect(record?.v2Data?.startTime, '2026-08-01T10:00:00+09:00');
    expect(record?.v2Data?.endTime, '2026-08-01T11:00:00+09:00');
    expect(record?.v2Data?.estimatedStrengthCaloriesKcal, 294);
    expect(record?.v2Data?.strengthWeightSnapshotKg, 80);
    expect(
      record?.v2Data?.strengthCalculationMethod,
      'strengthSessionMetsAcsmV1',
    );
    expect(record?.v2Data?.strengthCalculationVersion, 1);
  });

  test(
    'uses the latest prior STATUS weight when same-day weight is absent',
    () async {
      adapter = TrainingSyncAdapter(
        repository: repository,
        customExercises: _CustomExercises(),
        weightResolver: TrainingStatusWeightResolver(
          repository: _StatusRepository({
            '2026-07-31': _status(80, localDate: '2026-07-31'),
          }),
        ),
      );
      final envelope = _envelope(change: (payload) => _addCardio(payload));
      final result = await adapter.applyAndVerify(
        envelope: envelope,
        expectedPayloadDigest: 'cardio-no-weight',
      );
      expect(result.success, isTrue);
      final cardio = (await repository.findRecordById(
        _id(1),
      ))!.v2Data!.cardioEntries.single;
      expect(cardio.estimatedCaloriesKcal, 70);
      expect(cardio.weightSnapshotKg, 80);
      expect(cardio.calculationMethod, 'metsAcsmV1');
      expect(cardio.calculationVersion, 1);
    },
  );

  test(
    'accepts a matching formal cardio snapshot and rejects mismatches',
    () async {
      final valid = _envelope(
        change: (payload) => _addCardio(payload, formalSnapshot: true),
      );
      expect(await adapter.validatePayload(valid), isEmpty);

      for (final key in <String>[
        'estimatedCaloriesKcal',
        'weightSnapshotKg',
        'calculationMethod',
        'calculationVersion',
      ]) {
        final invalid = _envelope(
          change: (payload) {
            _addCardio(payload, formalSnapshot: true);
            final cardio =
                (payload['cardio']! as List).single as Map<String, Object?>;
            cardio[key] = switch (key) {
              'estimatedCaloriesKcal' => 71,
              'weightSnapshotKg' => 0,
              'calculationMethod' => 'other',
              _ => 2,
            };
          },
        );
        expect(
          (await adapter.validatePayload(invalid)).map((issue) => issue.code),
          contains('payloadInvalid'),
        );
      }
    },
  );

  test('training instruction is schema-backed and forbids guessing', () {
    final text = const TrainingSyncInstructionProvider().build();
    expect(text, contains('dynamicStretchCompleted'));
    expect(text, contains('idempotencyKeyはpayload.session.recordId'));
    expect(text, contains('exerciseId'));
    expect(text, contains('legacyUnknownは禁止'));
    expect(text, contains('CardioにEquipment Fieldを追加しない'));
    expect(text, contains('JSON Objectのみ'));
  });
}

OrloSyncEnvelope _envelope({
  String? recordId,
  String? idempotencyKey,
  String operationDate = '2026-08-01',
  void Function(Map<String, Object?> payload)? change,
}) {
  final id = recordId ?? _id(1);
  final payload = <String, Object?>{
    'session': <String, Object?>{
      'recordId': id,
      'localDate': '2026-08-01',
      'name': 'Morning Training',
      'grade': 'a',
      'memo': null,
      'dynamicStretchCompleted': true,
      'cooldownStretchCompleted': false,
      'overallEvaluation': 'Good session',
    },
    'exercises': <Object?>[
      <String, Object?>{
        'exerciseId': 'benchpress',
        'exerciseName': 'Bench Press',
        'equipment': <String, Object?>{
          'id': 'power_rack',
          'name': 'Power Rack',
        },
        'sets': <Object?>[
          <String, Object?>{
            'type': 'main',
            'weightKg': 80,
            'reps': 8,
            'rpe': 8,
            'restAfterSeconds': 120,
          },
        ],
        'evaluation': 'Stable',
        'nextTarget': null,
      },
    ],
    'cardio': <Object?>[],
  };
  change?.call(payload);
  return OrloSyncEnvelope(
    envelopeVersion: 1,
    schemaVersion: '1.0',
    dataType: 'training',
    packageId: 'package-1',
    idempotencyKey: idempotencyKey ?? id,
    source: OrloSyncSource(
      type: 'test',
      generatedAt: DateTime.utc(2026, 8, 1),
      producer: 'test',
    ),
    operationDate: operationDate,
    payload: payload,
  );
}

Map<String, Object?> _session(Map<String, Object?> payload) =>
    payload['session']! as Map<String, Object?>;
Map<String, Object?> _exercise(Map<String, Object?> payload) =>
    (payload['exercises']! as List).first as Map<String, Object?>;
Map<String, Object?> _set(Map<String, Object?> payload) =>
    (_exercise(payload)['sets']! as List).first as Map<String, Object?>;

void _addCardio(Map<String, Object?> payload, {bool formalSnapshot = false}) {
  payload['cardio'] = <Object?>[
    <String, Object?>{
      'purpose': 'main',
      'type': 'running',
      'durationSeconds': 600,
      'distanceKm': 2,
      'mets': 5,
      'averageHeartRateBpm': 140,
      'maximumHeartRateBpm': 160,
      'averageSpeedKmh': 12,
      'estimatedCaloriesKcal': formalSnapshot ? 70 : null,
      'weightSnapshotKg': formalSnapshot ? 80 : null,
      'calculationMethod': formalSnapshot ? 'metsAcsmV1' : null,
      'calculationVersion': formalSnapshot ? 1 : null,
      'notes': null,
    },
  ];
}

String _id(int value) =>
    'training:00000000-0000-4000-8000-${value.toString().padLeft(12, '0')}';

class _CustomExercises implements CustomTrainingExerciseRepository {
  const _CustomExercises([this.values = const []]);

  final List<CustomTrainingExercise> values;

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
  @override
  Future<List<CustomTrainingExercise>> findAll() async => values;
}

MorningData _status(double weight, {String localDate = '2026-08-01'}) =>
    MorningData(
      date: localDate,
      weight: weight,
      bodyFat: 0,
      sleepHours: 0,
      sleepScore: 0,
      footPain: 0,
      workType: WorkType.holiday,
      workStart: '',
      workEnd: '',
      workBreak: '',
      workHours: 0,
      memo: '',
    );

class _StatusRepository implements StatusRepository {
  _StatusRepository(this.values);

  final Map<String, MorningData> values;

  @override
  Future<MorningData?> findByLocalDate(String localDate) async =>
      values[localDate];

  @override
  Future<StatusReadResult> findAllCanonical() async => StatusReadResult(
    records: values.entries.map(
      (entry) => PersistedStatusRecord(
        id: PersistedStatusRecord.canonicalId(entry.key),
        localDate: entry.key,
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
        canonicalDate: entry.key,
        recordKind: StatusRecordKind.canonical,
        data: entry.value,
      ),
    ),
  );

  @override
  Future<StatusReadResult> findAllIncludingRevisions() => findAllCanonical();

  @override
  Future<MorningData?> findLatest() async => null;

  @override
  Future<StatusReadResult> getRange(String startDate, String endDate) async =>
      StatusReadResult(records: const []);

  @override
  Future<void> save(MorningData data) async {}

  @override
  Future<void> deleteByLocalDate(String localDate) async {}

  @override
  Future<void> clear() async {}
}
