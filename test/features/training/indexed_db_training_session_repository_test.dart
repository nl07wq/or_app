import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/models/cardio_entry.dart';
import 'package:or_app/core/models/cardio_entry_v2.dart';
import 'package:or_app/core/models/training_exercise.dart';
import 'package:or_app/core/models/training_exercise_v2.dart';
import 'package:or_app/core/models/training_session.dart';
import 'package:or_app/core/models/training_session_v2.dart';
import 'package:or_app/core/models/training_set.dart';
import 'package:or_app/core/models/training_set_v2.dart';
import 'package:or_app/data/indexed_db/indexed_db_store_names.dart';
import 'package:or_app/features/repositories/repository_exception.dart';
import 'package:or_app/features/training/models/persisted_training_record.dart';
import 'package:or_app/features/training/repository/indexed_db_training_repository.dart';
import 'package:or_app/features/training/repository/training_record_id_generator.dart';

import '../../repositories/indexed_db/fake_indexed_db_database.dart';

void main() {
  late FakeIndexedDbDatabase database;
  late int randomByte;
  late int clock;
  late IndexedDbTrainingSessionRepository repository;

  setUp(() {
    database = FakeIndexedDbDatabase();
    randomByte = 0;
    clock = 0;
    repository = IndexedDbTrainingSessionRepository(
      database,
      idGenerator: TrainingRecordIdGenerator(
        nextInt: (_) => randomByte++ & 0xff,
      ),
      now: () => DateTime.utc(2026, 7, 26).add(Duration(hours: clock++)),
    );
  });

  test(
    'saveNew assigns a UUID and persists a complete Domain round-trip',
    () async {
      final session = _session(memo: 'complete');

      final saved = await repository.saveNew(session);
      final restored = await repository.findById(saved.id);

      expect(
        saved.id,
        matches(
          RegExp(
            r'^training:[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-'
            r'[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
          ),
        ),
      );
      expect(restored?.session.toJson(), session.toJson());
      expect(restored?.session.exercises.single.equipmentId, 'power-rack');
      expect(restored?.session.exercises.single.sets.map((set) => set.weight), [
        20.0,
        82.5,
      ]);
      expect(restored?.session.cardioEntries.single.distanceKm, 3.25);
      expect(restored?.session.cardioEntries.single.estimatedCalories, 187.75);
    },
  );

  test('v2 update preserves ID and createdAt and changes updatedAt', () async {
    final saved = await repository.saveNewV2(_v2Session(memo: 'first'));
    await repository.updateV2ById(saved.id, _v2Session(memo: 'updated'));

    final envelope = PersistedTrainingRecord.fromRecord(
      (await database.findById(IndexedDbStoreNames.trainingRecords, saved.id))!,
    );
    expect(envelope.dataV2.memo, 'updated');
    expect(envelope.createdAt, DateTime.utc(2026, 7, 26));
    expect(envelope.updatedAt, DateTime.utc(2026, 7, 26, 1));
    expect(envelope.recordVersion, 2);
    expect(envelope.migrationSource, isNull);
  });

  test('updateById requires an existing ID', () async {
    const id = 'training:00112233-4455-4677-8899-aabbccddeeff';

    await expectLater(
      repository.updateById(id, _session()),
      throwsA(isA<RepositoryException>()),
    );
  });

  test(
    'keeps same-day multiple sessions and uses existing descending order',
    () async {
      const morningId = 'training:00112233-4455-4677-8899-aabbccddeeff';
      const eveningId = 'training:10112233-4455-4677-8899-aabbccddeeff';
      const nextDayId = 'training:20112233-4455-4677-8899-aabbccddeeff';
      await repository.saveWithId(
        morningId,
        _session(date: '2026-07-26T08:00:00+09:00', memo: 'morning'),
      );
      await repository.saveWithId(
        eveningId,
        _session(date: '2026-07-26T18:00:00+09:00', memo: 'evening'),
      );
      await repository.saveWithId(
        nextDayId,
        _session(date: '2026-07-27T06:00:00+09:00', memo: 'next'),
      );

      expect((await repository.findAll()).map((record) => record.id), [
        nextDayId,
        eveningId,
        morningId,
      ]);
      final daily = await repository.findByLocalDate('2026-07-26');
      expect(daily.map((record) => record.id), [eveningId, morningId]);
      expect(() => daily.clear(), throwsUnsupportedError);
    },
  );

  test(
    'localDate is fixed from source text without UTC recalculation',
    () async {
      const id = 'training:00112233-4455-4677-8899-aabbccddeeff';
      await repository.saveWithId(
        id,
        _session(date: '2026-07-26T00:30:00+09:00'),
      );

      final envelope = PersistedTrainingRecord.fromRecord(
        (await database.findById(IndexedDbStoreNames.trainingRecords, id))!,
      );
      expect(envelope.localDate, '2026-07-26');
    },
  );

  test(
    'returned data is a defensive copy and repository can be recreated',
    () async {
      const id = 'training:00112233-4455-4677-8899-aabbccddeeff';
      await repository.saveWithId(id, _session());
      final first = (await repository.findById(id))!;

      first.session.exercises.clear();

      final recreated = IndexedDbTrainingSessionRepository(database);
      expect((await recreated.findById(id))?.session.exercises, hasLength(1));
      final all = await repository.findAll();
      expect(() => all.clear(), throwsUnsupportedError);
    },
  );

  test('delete and clear affect only training_records', () async {
    final first = await repository.saveNewV2(_v2Session());
    final second = await repository.saveNewV2(
      _v2Session(date: '2026-07-27T10:15:00+09:00'),
    );
    database.seed(IndexedDbStoreNames.trainings, 'v1', {
      'id': 'v1',
      'data': const {},
    });
    database.seed(IndexedDbStoreNames.statusRecords, 'status', {
      'id': 'status',
    });

    await repository.deleteById(first.id);
    expect(await repository.findById(first.id), isNull);
    await repository.clear();

    expect(await repository.findAll(), isEmpty);
    expect(await repository.findById(second.id), isNull);
    expect(
      await database.findById(IndexedDbStoreNames.trainings, 'v1'),
      isNotNull,
    );
    expect(
      await database.findById(IndexedDbStoreNames.statusRecords, 'status'),
      isNotNull,
    );
  });

  test('does not report failed transaction as successful', () async {
    database.failNextTransactionWith = StateError('failed');

    await expectLater(
      repository.saveNew(_session()),
      throwsA(
        isA<RepositoryException>().having(
          (error) => error.code,
          'code',
          RepositoryErrorCode.transactionFailed,
        ),
      ),
    );
    expect(
      await database.findAll(IndexedDbStoreNames.trainingRecords),
      isEmpty,
    );
  });

  test('reports partial corruption without hiding valid records', () async {
    const id = 'training:00112233-4455-4677-8899-aabbccddeeff';
    await repository.saveWithId(id, _session());
    database.seed(IndexedDbStoreNames.trainingRecords, 'broken', {
      'id': 'broken',
      'recordVersion': 999,
    });

    final audit = await repository.findAllWithIssues();
    expect(audit.records, hasLength(1));
    expect(audit.issues.single.recordId, 'broken');
    await expectLater(
      repository.findAll(),
      throwsA(
        isA<RepositoryException>().having(
          (error) => error.code,
          'code',
          RepositoryErrorCode.partialCorruption,
        ),
      ),
    );
  });

  test('reads v1 and v2 records through every mixed read API', () async {
    const v1Id = 'training:00112233-4455-4677-8899-aabbccddeeff';
    const v2Id = 'training:10112233-4455-4677-8899-aabbccddeeff';
    await repository.saveWithId(
      v1Id,
      _session(date: '2026-07-26T08:00:00+09:00', memo: 'v1'),
    );
    _seedV2(database, id: v2Id);

    final all = await repository.findAll();
    expect(all.map((record) => record.id), [v2Id, v1Id]);
    expect(all.first.recordVersion, 2);
    expect(all.first.isEditable, isTrue);
    expect(all.last.recordVersion, 1);
    expect(all.last.isEditable, isFalse);
    expect((await repository.findById(v2Id))?.recordVersion, 2);
    expect(
      (await repository.findByLocalDate(
        '2026-07-26',
      )).map((record) => record.id),
      [v2Id, v1Id],
    );
    expect(
      (await repository.findAllRecords()).map((record) => record.recordVersion),
      [2, 1],
    );
  });

  test('mixed read issues do not hide valid v1 and v2 records', () async {
    const v1Id = 'training:00112233-4455-4677-8899-aabbccddeeff';
    const v2Id = 'training:10112233-4455-4677-8899-aabbccddeeff';
    await repository.saveWithId(v1Id, _session());
    _seedV2(database, id: v2Id);
    database.seed(IndexedDbStoreNames.trainingRecords, 'unknown', {
      'id': 'unknown',
      'recordVersion': 99,
    });
    const invalidV2Id = 'training:20112233-4455-4677-8899-aabbccddeeff';
    final invalidV2 = PersistedTrainingRecord.v2(
      id: invalidV2Id,
      localDate: '2026-07-26',
      createdAt: DateTime.utc(2026, 7, 26, 9),
      updatedAt: DateTime.utc(2026, 7, 26, 10),
      data: TrainingSessionV2(date: '2026-07-26'),
    ).toRecord();
    invalidV2['data'] = {
      ...Map<String, Object?>.from(invalidV2['data']! as Map),
      'exercises': 'bad',
    };
    database.seed(IndexedDbStoreNames.trainingRecords, invalidV2Id, invalidV2);

    final result = await repository.findAllWithIssues();

    expect(result.records.map((record) => record.id), [v2Id, v1Id]);
    expect(
      result.issues.map((issue) => issue.recordId),
      unorderedEquals(['unknown', invalidV2Id]),
    );
  });

  test('migration v2 is read-only and cannot overwrite source JSON', () async {
    const id = 'training:10112233-4455-4677-8899-aabbccddeeff';
    _seedV2(database, id: id, migrationSource: true);
    final before = Map<String, Object?>.from(
      (await database.findById(IndexedDbStoreNames.trainingRecords, id))!,
    );
    final projection = (await repository.findById(id))!;

    expect(projection.session.memo, 'v2 memo');
    expect(projection.session.exercises.single.sets.single.weight, 90);
    expect(projection.session.cardioEntries, isEmpty);
    expect(projection.readModel.cardioEntryCount, 1);
    await expectLater(
      repository.updateById(id, projection.session),
      throwsA(isA<RepositoryException>()),
    );
    await expectLater(
      repository.saveWithId(id, projection.session),
      throwsA(isA<RepositoryException>()),
    );
    await expectLater(
      repository.saveNew(projection.session),
      throwsA(isA<RepositoryException>()),
    );
    await expectLater(
      repository.deleteById(id),
      throwsA(isA<RepositoryException>()),
    );
    await expectLater(repository.clear(), throwsA(isA<RepositoryException>()));
    expect(
      await database.findById(IndexedDbStoreNames.trainingRecords, id),
      before,
    );
  });

  test('normal v2 rejects a localDate-changing update', () async {
    final saved = await repository.saveNewV2(_v2Session());

    await expectLater(
      repository.updateV2ById(
        saved.id,
        _v2Session(date: '2026-07-27T10:15:00+09:00'),
      ),
      throwsA(isA<RepositoryException>()),
    );
    expect((await repository.findById(saved.id))?.localDate, '2026-07-26');
  });

  test('v2 update changes only the target record', () async {
    final target = await repository.saveNewV2(_v2Session(memo: 'target'));
    final sibling = await repository.saveNewV2(
      _v2Session(date: '2026-07-27T10:15:00+09:00', memo: 'sibling'),
    );
    final siblingBefore = await database.findById(
      IndexedDbStoreNames.trainingRecords,
      sibling.id,
    );

    await repository.updateV2ById(
      target.id,
      _v2Session(memo: 'updated target'),
    );

    expect(
      (await repository.findById(target.id))?.readModel.v2Data?.memo,
      'updated target',
    );
    expect(
      await database.findById(IndexedDbStoreNames.trainingRecords, sibling.id),
      siblingBefore,
    );
  });

  test('findAllSessions excludes v2 from v1 calculations', () async {
    const v1Id = 'training:00112233-4455-4677-8899-aabbccddeeff';
    const v2Id = 'training:10112233-4455-4677-8899-aabbccddeeff';
    await repository.saveWithId(v1Id, _session(memo: 'v1'));
    _seedV2(database, id: v2Id);

    final sessions = await repository.findAllSessions();

    expect(sessions, hasLength(1));
    expect(sessions.single.memo, 'v1');
  });
}

void _seedV2(
  FakeIndexedDbDatabase database, {
  required String id,
  String date = '2026-07-26T18:00:00+09:00',
  bool migrationSource = false,
}) {
  final data = _v2Session(date: date);
  database.seed(
    IndexedDbStoreNames.trainingRecords,
    id,
    (migrationSource
            ? PersistedTrainingRecord.v2ForMigration(
                id: id,
                localDate: date.substring(0, 10),
                createdAt: DateTime.utc(2026, 7, 26, 9),
                updatedAt: DateTime.utc(2026, 7, 26, 10),
                migrationSource: const TrainingMigrationSource(
                  migrationId: 'test_migration',
                  sourceSystem: 'test',
                  sourceKey: 'training',
                  sourceIndex: 0,
                  duplicateOrdinal: 0,
                ),
                data: data,
              )
            : PersistedTrainingRecord.v2(
                id: id,
                localDate: date.substring(0, 10),
                createdAt: DateTime.utc(2026, 7, 26, 9),
                updatedAt: DateTime.utc(2026, 7, 26, 10),
                data: data,
              ))
        .toRecord(),
  );
}

TrainingSessionV2 _v2Session({
  String date = '2026-07-26T18:00:00+09:00',
  String memo = 'v2 memo',
}) {
  return TrainingSessionV2(
    date: date,
    sessionName: 'Evening',
    memo: memo,
    exercises: [
      TrainingExerciseV2(
        exerciseName: 'Squat',
        order: 1,
        sets: [
          TrainingSetV2(
            setNo: 1,
            setType: TrainingSetType.main,
            weightKg: 90,
            reps: 5,
          ),
        ],
      ),
    ],
    cardioEntries: [
      CardioEntryV2(
        purpose: CardioPurpose.main,
        type: CardioType.running,
        durationSeconds: 90,
        estimatedCaloriesKcal: 20,
      ),
    ],
  );
}

TrainingSession _session({
  String date = '2026-07-26T10:15:00+09:00',
  String memo = 'memo',
}) {
  return TrainingSession(
    date: date,
    memo: memo,
    exercises: const [
      TrainingExercise(
        exerciseName: 'BenchPress',
        order: 0,
        equipmentId: 'power-rack',
        sets: [
          TrainingSet(setNo: 1, weight: 20, reps: 12),
          TrainingSet(setNo: 2, weight: 82.5, reps: 8),
        ],
      ),
    ],
    cardioEntries: [
      CardioEntry(
        type: CardioType.running,
        intensity: CardioIntensity.moderate,
        durationMinutes: 24,
        distanceKm: 3.25,
        notes: 'steady',
        estimatedCalories: 187.75,
      ),
    ],
  );
}
