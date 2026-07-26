import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/models/cardio_entry.dart';
import 'package:or_app/core/models/training_exercise.dart';
import 'package:or_app/core/models/training_session.dart';
import 'package:or_app/core/models/training_set.dart';
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

  test(
    'specified ID update preserves createdAt and changes updatedAt',
    () async {
      const id = 'training:00112233-4455-4677-8899-aabbccddeeff';
      await repository.saveWithId(id, _session(memo: 'first'));
      await repository.saveWithId(id, _session(memo: 'updated'));

      final envelope = PersistedTrainingRecord.fromRecord(
        (await database.findById(IndexedDbStoreNames.trainingRecords, id))!,
      );
      expect(envelope.data.memo, 'updated');
      expect(envelope.createdAt, DateTime.utc(2026, 7, 26));
      expect(envelope.updatedAt, DateTime.utc(2026, 7, 26, 1));
    },
  );

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
    const firstId = 'training:00112233-4455-4677-8899-aabbccddeeff';
    const secondId = 'training:10112233-4455-4677-8899-aabbccddeeff';
    await repository.saveWithId(firstId, _session());
    await repository.saveWithId(secondId, _session());
    database.seed(IndexedDbStoreNames.trainings, 'v1', {
      'id': 'v1',
      'data': const {},
    });
    database.seed(IndexedDbStoreNames.statusRecords, 'status', {
      'id': 'status',
    });

    await repository.deleteById(firstId);
    expect(await repository.findById(firstId), isNull);
    await repository.clear();

    expect(await repository.findAll(), isEmpty);
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
