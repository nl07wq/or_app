import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/models/cardio_entry.dart';
import 'package:or_app/core/models/training_exercise.dart';
import 'package:or_app/core/models/training_session.dart';
import 'package:or_app/core/models/training_session_v2.dart';
import 'package:or_app/core/models/training_set.dart';
import 'package:or_app/data/indexed_db/indexed_db_database_contract.dart';
import 'package:or_app/data/indexed_db/indexed_db_migration_metadata.dart';
import 'package:or_app/data/indexed_db/indexed_db_quarantined_record.dart';
import 'package:or_app/data/indexed_db/indexed_db_schema.dart';
import 'package:or_app/data/indexed_db/indexed_db_store_names.dart';
import 'package:or_app/features/repositories/repository_exception.dart';
import 'package:or_app/features/training/migration/training_legacy_reader.dart';
import 'package:or_app/features/training/migration/training_migration_service.dart';
import 'package:or_app/features/training/models/persisted_training_record.dart';
import 'package:or_app/features/training/repository/indexed_db_training_repository.dart';
import 'package:or_app/features/training/repository/training_record_id_generator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../repositories/indexed_db/fake_indexed_db_database.dart';

void main() {
  const legacyKey = TrainingLegacyReader.sourceKey;
  final migrationTime = DateTime.parse('2026-07-26T00:00:00Z');

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'raw Reader separates records without changing SharedPreferences',
    () async {
      final valid = jsonEncode(_session().toJson());
      final invalidJson = '{invalid';
      final invalidSchema = jsonEncode({'date': '2026-07-26'});
      final original = [valid, invalidJson, invalidSchema];
      SharedPreferences.setMockInitialValues({legacyKey: original});

      final result = await TrainingLegacyReader().read();

      expect(result.sourceCount, 3);
      expect(result.validRecords.single.data.toJson(), _session().toJson());
      expect(result.invalidRecords.map((record) => record.errorCode), [
        'invalidJson',
        'invalidSchema',
      ]);
      expect(
        (await SharedPreferences.getInstance()).getStringList(legacyKey),
        original,
      );
    },
  );

  test('migrates zero records and completes metadata', () async {
    final database = FakeIndexedDbDatabase();

    final result = await _service(database, migrationTime).migrate();

    expect(result.sourceCount, 0);
    expect(result.trainingRecordIds, isEmpty);
    final metadata = _metadata(database);
    expect(metadata.status, IndexedDbMigrationStatus.completed);
    expect(metadata.targetDatabaseVersion, IndexedDbSchema.databaseVersion);
    expect(metadata.sourceIdDigest, isNotNull);
    expect(metadata.targetIdDigest, isNotNull);
    expect(metadata.targetDigest, isNotNull);
    expect(metadata.validCounts['verifiedRecordCount'], 0);
    expect(await database.findAll(IndexedDbStoreNames.activityDrafts), isEmpty);
  });

  test('migrates complete Domain data without recalculation', () async {
    final session = _session(
      memo: 'complete',
      weight: 82.75,
      reps: 9,
      distance: 3.333,
      calories: 187.125,
    );
    final original = [jsonEncode(session.toJson())];
    SharedPreferences.setMockInitialValues({legacyKey: original});
    final database = FakeIndexedDbDatabase();

    final result = await _service(database, migrationTime).migrate();

    expect(result.validCount, 1);
    expect(result.writtenCount, 1);
    final record = (await IndexedDbTrainingSessionRepository(
      database,
    ).findAll()).single;
    expect(record.session.toJson(), session.toJson());
    expect(record.session.exercises.map((exercise) => exercise.exerciseName), [
      'BenchPress',
      'HackSquat',
    ]);
    expect(record.session.exercises.first.sets.map((set) => set.weight), [
      20.0,
      82.75,
    ]);
    expect(record.session.exercises.first.sets.last.reps, 9);
    expect(record.session.exercises.first.equipmentId, 'power-rack');
    expect(record.session.cardioEntries.map((entry) => entry.type), [
      CardioType.running,
      CardioType.walking,
    ]);
    expect(record.session.cardioEntries.first.distanceKm, 3.333);
    expect(record.session.cardioEntries.first.estimatedCalories, 187.125);
    expect(
      (await SharedPreferences.getInstance()).getStringList(legacyKey),
      original,
    );
  });

  test('preserves multiple days and same-day multiple sessions', () async {
    final sessions = [
      _session(date: '2026-07-26T08:00:00+09:00', memo: 'morning'),
      _session(date: '2026-07-26T18:00:00+09:00', memo: 'evening'),
      _session(date: '2026-07-27T07:00:00+09:00', memo: 'next'),
    ];
    SharedPreferences.setMockInitialValues({
      legacyKey: sessions
          .map((session) => jsonEncode(session.toJson()))
          .toList(),
    });
    final database = FakeIndexedDbDatabase();

    final result = await _service(database, migrationTime).migrate();

    expect(result.trainingRecordIds, hasLength(3));
    final repository = IndexedDbTrainingSessionRepository(database);
    expect(await repository.findByLocalDate('2026-07-26'), hasLength(2));
    expect((await repository.findAll()).map((record) => record.session.memo), [
      'next',
      'evening',
      'morning',
    ]);
  });

  test(
    'preserves completely identical records with duplicate ordinals',
    () async {
      final raw = jsonEncode(_session().toJson());
      SharedPreferences.setMockInitialValues({
        legacyKey: [raw, raw],
      });
      final database = FakeIndexedDbDatabase();

      final result = await _service(database, migrationTime).migrate();

      expect(result.validCount, 2);
      expect(result.trainingRecordIds, hasLength(2));
      final stored = (await database.findAll(
        IndexedDbStoreNames.trainingRecords,
      )).map(PersistedTrainingRecord.fromRecord).toList();
      expect(
        stored.map((record) => record.migrationSource?.duplicateOrdinal),
        containsAll([0, 1]),
      );
      expect(
        stored
            .map(
              (record) =>
                  TrainingLegacyIdGenerator.canonicalJson(record.data.toJson()),
            )
            .toSet(),
        hasLength(1),
      );
    },
  );

  test('same timestamp with different content remains separate', () async {
    final first = _session(memo: 'first');
    final second = _session(memo: 'second');
    SharedPreferences.setMockInitialValues({
      legacyKey: [jsonEncode(first.toJson()), jsonEncode(second.toJson())],
    });
    final database = FakeIndexedDbDatabase();

    final result = await _service(database, migrationTime).migrate();

    expect(result.trainingRecordIds, hasLength(2));
    expect(
      (await IndexedDbTrainingSessionRepository(
        database,
      ).findAll()).map((record) => record.session.memo),
      containsAll(['first', 'second']),
    );
  });

  test(
    'deterministic IDs remain stable across independent migrations',
    () async {
      final source = [
        jsonEncode(_session(memo: 'one').toJson()),
        jsonEncode(_session(memo: 'two').toJson()),
      ];
      SharedPreferences.setMockInitialValues({legacyKey: source});
      final firstDatabase = FakeIndexedDbDatabase();
      final first = await _service(firstDatabase, migrationTime).migrate();

      SharedPreferences.setMockInitialValues({legacyKey: source});
      final secondDatabase = FakeIndexedDbDatabase();
      final second = await _service(secondDatabase, migrationTime).migrate();

      expect(first.trainingRecordIds, second.trainingRecordIds);
    },
  );

  test('matching existing ID is an idempotent match', () async {
    final session = _session();
    final raw = jsonEncode(session.toJson());
    SharedPreferences.setMockInitialValues({
      legacyKey: [raw],
    });
    final id = const TrainingLegacyIdGenerator().generate(
      sessionJson: session.toJson(),
      sourceIndex: 0,
      duplicateOrdinal: 0,
    );
    final database = FakeIndexedDbDatabase();
    final existing = PersistedTrainingRecord(
      id: id,
      localDate: '2026-07-26',
      createdAt: DateTime.utc(2026, 7, 20),
      updatedAt: DateTime.utc(2026, 7, 20),
      data: session,
    );
    database.seed(IndexedDbStoreNames.trainingRecords, id, existing.toRecord());

    final result = await _service(database, migrationTime).migrate();

    expect(result.existingMatchCount, 1);
    expect(result.writtenCount, 0);
    final restored = PersistedTrainingRecord.fromRecord(
      (await database.findById(IndexedDbStoreNames.trainingRecords, id))!,
    );
    expect(restored.createdAt, existing.createdAt);
  });

  test('existing different payload is quarantined and not completed', () async {
    final legacy = _session(memo: 'legacy');
    final other = _session(date: '2026-07-27T10:00:00+09:00', memo: 'other');
    SharedPreferences.setMockInitialValues({
      legacyKey: [jsonEncode(legacy.toJson()), jsonEncode(other.toJson())],
    });
    final id = const TrainingLegacyIdGenerator().generate(
      sessionJson: legacy.toJson(),
      sourceIndex: 0,
      duplicateOrdinal: 0,
    );
    final database = FakeIndexedDbDatabase();
    database.seed(
      IndexedDbStoreNames.trainingRecords,
      id,
      PersistedTrainingRecord(
        id: id,
        localDate: '2026-07-26',
        createdAt: migrationTime,
        updatedAt: migrationTime,
        data: _session(memo: 'indexeddb'),
      ).toRecord(),
    );

    await expectLater(
      _service(database, migrationTime).migrate(),
      throwsA(isA<RepositoryException>()),
    );

    expect(_metadata(database).status, IndexedDbMigrationStatus.failed);
    expect(
      (await IndexedDbTrainingSessionRepository(
        database,
      ).findById(id))?.session.memo,
      'indexeddb',
    );
    expect(
      (await IndexedDbTrainingSessionRepository(
        database,
      ).findAll()).map((record) => record.session.memo),
      contains('other'),
    );
    final quarantine = await _trainingQuarantine(database);
    expect(quarantine.single.errorCode, 'targetIdConflict');
    expect(quarantine.single.conflictingRecordId, id);
    expect(quarantine.single.existingPayloadDigest, isNotNull);
    expect(quarantine.single.legacyPayloadDigest, isNotNull);
    expect(quarantine.single.conflictType, 'targetIdConflict');
  });

  test(
    'generated Legacy ID conflict is quarantined and not completed',
    () async {
      SharedPreferences.setMockInitialValues({
        legacyKey: [
          jsonEncode(_session(memo: 'first').toJson()),
          jsonEncode(_session(memo: 'second').toJson()),
        ],
      });
      final database = FakeIndexedDbDatabase();
      const collisionId = 'legacy-training:deadbeef:0000';
      final service = TrainingMigrationService(
        database,
        legacyIdFactory: (_, _, _) => collisionId,
        now: () => migrationTime,
        ownerId: 'test',
      );

      await expectLater(service.migrate(), throwsA(isA<RepositoryException>()));

      expect(_metadata(database).status, IndexedDbMigrationStatus.failed);
      final quarantine = await _trainingQuarantine(database);
      expect(quarantine, hasLength(2));
      expect(
        quarantine.map((record) => record.errorCode),
        everyElement('legacyIdConflict'),
      );
      expect(
        await database.findAll(IndexedDbStoreNames.trainingRecords),
        isEmpty,
      );
    },
  );

  test(
    'invalid records are quarantined while valid records complete',
    () async {
      final original = [
        jsonEncode(_session().toJson()),
        '{invalid',
        jsonEncode({'date': '2026-07-26'}),
      ];
      SharedPreferences.setMockInitialValues({legacyKey: original});
      final database = FakeIndexedDbDatabase();

      final result = await _service(database, migrationTime).migrate();

      expect(result.validCount, 1);
      expect(result.invalidCount, 2);
      expect(result.conflictCount, 0);
      expect(await _trainingQuarantine(database), hasLength(2));
      expect(_metadata(database).status, IndexedDbMigrationStatus.completed);
      expect(
        (await SharedPreferences.getInstance()).getStringList(legacyKey),
        original,
      );
    },
  );

  test('completed migration rerun verifies without duplicate writes', () async {
    SharedPreferences.setMockInitialValues({
      legacyKey: [jsonEncode(_session().toJson())],
    });
    final database = FakeIndexedDbDatabase();
    final service = _service(database, migrationTime);

    final first = await service.migrate();
    final second = await service.migrate();

    expect(first.alreadyCompleted, isFalse);
    expect(second.alreadyCompleted, isTrue);
    expect(second.trainingRecordIds, first.trainingRecordIds);
    expect(
      await database.findAll(IndexedDbStoreNames.trainingRecords),
      hasLength(1),
    );
  });

  test('completed v3 metadata stays complete after v4 Store upgrade', () async {
    final database = FakeIndexedDbDatabase();
    final service = _service(database, migrationTime);
    await service.migrate();
    final metadata = _metadata(database).toRecord()
      ..['targetDatabaseVersion'] = 3;
    database.seed(
      IndexedDbStoreNames.migrationMetadata,
      TrainingMigrationService.migrationId,
      metadata,
    );

    final result = await service.migrate();

    expect(result.alreadyCompleted, isTrue);
    expect(await database.findAll(IndexedDbStoreNames.activityDrafts), isEmpty);
  });

  test(
    'completed Migration permits normal v2 and formal Store changes',
    () async {
      SharedPreferences.setMockInitialValues({
        legacyKey: [
          jsonEncode(_session(memo: 'edit')),
          jsonEncode(
            _session(date: '2026-07-27T10:15:00+09:00', memo: 'delete'),
          ),
        ],
      });
      final database = FakeIndexedDbDatabase();
      final service = _service(database, migrationTime);
      final first = await service.migrate();
      final ids = first.trainingRecordIds.toList()..sort();
      final repository = IndexedDbTrainingSessionRepository(
        database,
        now: () => migrationTime.add(const Duration(days: 1)),
      );

      await database.deleteById(IndexedDbStoreNames.trainingRecords, ids.last);
      final added = await repository.saveNewV2(
        TrainingSessionV2(date: '2026-07-28T10:15:00+09:00', memo: 'added'),
      );

      final result = await service.migrate();

      expect(result.alreadyCompleted, isTrue);
      expect(result.trainingRecordIds, first.trainingRecordIds);
      expect(await repository.findById(ids.first), isNotNull);
      expect(await repository.findById(ids.last), isNull);
      expect(
        (await repository.findById(added.id))?.readModel.v2Data?.memo,
        'added',
      );
    },
  );

  test(
    'completed Migration permits REPLACE ALL equivalent and empty Store',
    () async {
      SharedPreferences.setMockInitialValues({
        legacyKey: [jsonEncode(_session(memo: 'legacy'))],
      });
      final database = FakeIndexedDbDatabase();
      final service = _service(database, migrationTime);
      final first = await service.migrate();

      await database.clear(IndexedDbStoreNames.trainingRecords);
      const replacementId = 'training:00000000-0000-4000-8000-000000000002';
      await IndexedDbTrainingSessionRepository(
        database,
        now: () => migrationTime.add(const Duration(days: 1)),
      ).saveWithId(
        replacementId,
        _session(date: '2026-07-29T10:15:00+09:00', memo: 'replacement'),
      );

      final replaced = await service.migrate();
      expect(replaced.alreadyCompleted, isTrue);
      expect(replaced.trainingRecordIds, first.trainingRecordIds);
      expect(
        await database.findById(
          IndexedDbStoreNames.trainingRecords,
          replacementId,
        ),
        isNotNull,
      );

      await database.clear(IndexedDbStoreNames.trainingRecords);
      expect((await service.migrate()).alreadyCompleted, isTrue);
      expect(
        await database.findAll(IndexedDbStoreNames.trainingRecords),
        isEmpty,
      );
    },
  );

  test('completed Migration rejects invalid metadata contract', () async {
    final mutations = <void Function(Map<String, Object?>)>[
      (record) => record['id'] = 'wrong-migration-id',
      (record) => record['source'] = 'wrong-source',
      (record) => record['targetDatabaseVersion'] = 99,
      (record) => record['completedAt'] = null,
      (record) => record['attempt'] = 0,
      (record) => record['sourceDigest'] = 'not-a-digest',
      (record) => record['targetDigest'] = 'not-a-digest',
      (record) => record['targetIdDigest'] = '00000000',
      (record) {
        final expected = Map<String, Object?>.from(
          record['expectedRecordIds']! as Map,
        )..remove(IndexedDbStoreNames.trainingRecords);
        record['expectedRecordIds'] = expected;
      },
      (record) {
        final expected = Map<String, Object?>.from(
          record['expectedRecordIds']! as Map,
        )..remove(IndexedDbStoreNames.migrationQuarantine);
        record['expectedRecordIds'] = expected;
      },
      (record) {
        final expected = Map<String, Object?>.from(
          record['expectedRecordIds']! as Map,
        )..[IndexedDbStoreNames.trainingRecords] = ['not-a-training-id'];
        record['expectedRecordIds'] = expected;
      },
      (record) {
        final counts = Map<String, Object?>.from(record['validCounts']! as Map)
          ..['verifiedRecordCount'] = -1;
        record['validCounts'] = counts;
      },
    ];

    for (final mutate in mutations) {
      final database = FakeIndexedDbDatabase();
      final service = _service(database, migrationTime);
      SharedPreferences.setMockInitialValues({
        legacyKey: [jsonEncode(_session())],
      });
      await service.migrate();
      final metadata = _metadata(database).toRecord();
      mutate(metadata);
      database.seed(
        IndexedDbStoreNames.migrationMetadata,
        TrainingMigrationService.migrationId,
        metadata,
      );

      await expectLater(service.migrate(), _isCompletedVerificationFailure);
    }
  });

  test('completed Migration keeps strict quarantine verification', () async {
    for (final addUnexpected in [false, true]) {
      SharedPreferences.setMockInitialValues({
        legacyKey: [jsonEncode(_session()), '{invalid'],
      });
      final database = FakeIndexedDbDatabase();
      final service = _service(database, migrationTime);
      await service.migrate();
      final quarantine = await _trainingQuarantine(database);
      expect(quarantine, hasLength(1));

      if (addUnexpected) {
        final extra = IndexedDbQuarantinedRecord(
          id: 'quarantine:training:invalid:99999999',
          migrationId: TrainingMigrationService.migrationId,
          sourceSystem: TrainingLegacyReader.sourceSystem,
          sourceKey: TrainingLegacyReader.sourceKey,
          sourceSection: TrainingLegacyReader.sourceKey,
          sourceIndex: 99999999,
          rawPayload: '{invalid',
          errorCode: 'invalidJson',
          errorMessage: 'unexpected audit record',
          quarantinedAt: migrationTime,
        );
        await database.put(
          IndexedDbStoreNames.migrationQuarantine,
          extra.toRecord(),
        );
      } else {
        await database.deleteById(
          IndexedDbStoreNames.migrationQuarantine,
          quarantine.single.id,
        );
      }

      await expectLater(service.migrate(), _isCompletedVerificationFailure);
    }
  });

  test(
    'transaction failure remains incomplete and retry is idempotent',
    () async {
      final original = [jsonEncode(_session().toJson())];
      SharedPreferences.setMockInitialValues({legacyKey: original});
      final database = FakeIndexedDbDatabase()..failOnTransactionNumber = 2;
      final service = _service(database, migrationTime);

      await expectLater(service.migrate(), throwsA(isA<RepositoryException>()));

      expect(_metadata(database).status, IndexedDbMigrationStatus.failed);
      expect(
        await database.findAll(IndexedDbStoreNames.trainingRecords),
        isEmpty,
      );
      database.failOnTransactionNumber = null;
      final retried = await service.migrate();
      expect(retried.validCount, 1);
      expect(
        await database.findAll(IndexedDbStoreNames.trainingRecords),
        hasLength(1),
      );
      expect(
        (await SharedPreferences.getInstance()).getStringList(legacyKey),
        original,
      );
    },
  );

  test(
    'post-commit verification failure does not complete migration',
    () async {
      SharedPreferences.setMockInitialValues({
        legacyKey: [jsonEncode(_session().toJson())],
      });
      final backing = FakeIndexedDbDatabase();
      final database = _CorruptAfterCommitDatabase(backing);
      final service = TrainingMigrationService(
        database,
        now: () => migrationTime,
        ownerId: 'test',
      );

      await expectLater(service.migrate(), throwsA(isA<RepositoryException>()));

      expect(_metadata(backing).status, IndexedDbMigrationStatus.failed);
      expect(
        await backing.findAll(IndexedDbStoreNames.trainingRecords),
        hasLength(1),
      );
    },
  );

  test('migration does not touch the v1 trainings Store', () async {
    SharedPreferences.setMockInitialValues({
      legacyKey: [jsonEncode(_session().toJson())],
    });
    final database = FakeIndexedDbDatabase();
    database.seed(IndexedDbStoreNames.trainings, 'v1-record', {
      'id': 'v1-record',
      'data': {'legacy': true},
    });

    await _service(database, migrationTime).migrate();

    expect(
      await database.findById(IndexedDbStoreNames.trainings, 'v1-record'),
      {
        'id': 'v1-record',
        'data': {'legacy': true},
      },
    );
  });
}

class _CorruptAfterCommitDatabase implements IndexedDbDatabase {
  final FakeIndexedDbDatabase _delegate;
  var _transactionCount = 0;
  var _corruptTrainingReads = false;

  _CorruptAfterCommitDatabase(this._delegate);

  @override
  Future<void> put(String storeName, Map<String, Object?> record) {
    return _delegate.put(storeName, record);
  }

  @override
  Future<Map<String, Object?>?> findById(String storeName, String id) {
    return _delegate.findById(storeName, id);
  }

  @override
  Future<List<Map<String, Object?>>> findAll(String storeName) async {
    final records = await _delegate.findAll(storeName);
    if (_corruptTrainingReads &&
        storeName == IndexedDbStoreNames.trainingRecords &&
        records.isNotEmpty) {
      final data = records.first['data']! as Map<String, Object?>;
      data['memo'] = 'corrupted-after-commit';
    }
    return records;
  }

  @override
  Future<void> deleteById(String storeName, String id) {
    return _delegate.deleteById(storeName, id);
  }

  @override
  Future<void> clear(String storeName) {
    return _delegate.clear(storeName);
  }

  @override
  Future<T> runTransaction<T>({
    required Iterable<String> storeNames,
    required IndexedDbTransactionMode mode,
    required Future<T> Function(IndexedDbTransaction transaction) action,
  }) async {
    _transactionCount++;
    final result = await _delegate.runTransaction(
      storeNames: storeNames,
      mode: mode,
      action: action,
    );
    if (_transactionCount == 2) {
      _corruptTrainingReads = true;
    }
    return result;
  }
}

TrainingMigrationService _service(
  FakeIndexedDbDatabase database,
  DateTime migrationTime,
) {
  return TrainingMigrationService(
    database,
    now: () => migrationTime,
    ownerId: 'test',
  );
}

IndexedDbMigrationMetadata _metadata(FakeIndexedDbDatabase database) {
  return IndexedDbMigrationMetadata.fromRecord(
    database.rawRecord(
      IndexedDbStoreNames.migrationMetadata,
      TrainingMigrationService.migrationId,
    )!,
  );
}

Future<List<IndexedDbQuarantinedRecord>> _trainingQuarantine(
  FakeIndexedDbDatabase database,
) async {
  return (await database.findAll(IndexedDbStoreNames.migrationQuarantine))
      .map(IndexedDbQuarantinedRecord.fromRecord)
      .where(
        (record) => record.migrationId == TrainingMigrationService.migrationId,
      )
      .toList();
}

final _isCompletedVerificationFailure = throwsA(
  isA<RepositoryException>()
      .having(
        (error) => error.operation,
        'operation',
        'training.migration.verifyCompleted',
      )
      .having(
        (error) => error.code,
        'code',
        RepositoryErrorCode.verificationFailed,
      ),
);

TrainingSession _session({
  String date = '2026-07-26T10:15:00+09:00',
  String memo = 'memo',
  double weight = 82.5,
  int reps = 8,
  double distance = 3.25,
  double calories = 187.75,
}) {
  return TrainingSession(
    date: date,
    memo: memo,
    exercises: [
      TrainingExercise(
        exerciseName: 'BenchPress',
        order: 0,
        equipmentId: 'power-rack',
        sets: [
          const TrainingSet(setNo: 1, weight: 20, reps: 12),
          TrainingSet(setNo: 2, weight: weight, reps: reps),
        ],
      ),
      const TrainingExercise(
        exerciseName: 'HackSquat',
        order: 1,
        equipmentId: 'hack-squat-machine',
        sets: [TrainingSet(setNo: 1, weight: 120, reps: 10)],
      ),
    ],
    cardioEntries: [
      CardioEntry(
        type: CardioType.running,
        intensity: CardioIntensity.moderate,
        durationMinutes: 24,
        distanceKm: distance,
        notes: 'steady',
        estimatedCalories: calories,
      ),
      CardioEntry(
        type: CardioType.walking,
        intensity: CardioIntensity.light,
        durationMinutes: 15,
        distanceKm: 1.1,
        notes: 'cooldown',
        estimatedCalories: 45.5,
      ),
    ],
  );
}
