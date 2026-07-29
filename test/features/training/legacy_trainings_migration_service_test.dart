import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/models/training_exercise.dart';
import 'package:or_app/core/models/training_session.dart';
import 'package:or_app/core/models/training_set.dart';
import 'package:or_app/data/indexed_db/indexed_db_migration_metadata.dart';
import 'package:or_app/data/indexed_db/indexed_db_store_names.dart';
import 'package:or_app/features/training/migration/legacy_trainings_migration_service.dart';
import 'package:or_app/features/training/migration/training_record_lineage.dart';
import 'package:or_app/features/training/models/persisted_training_record.dart';
import 'package:or_app/features/repositories/repository_exception.dart';

import '../../repositories/indexed_db/fake_indexed_db_database.dart';

void main() {
  test(
    'missing or empty legacy store completes without creating records',
    () async {
      final database = FakeIndexedDbDatabase();

      final result = await LegacyTrainingsMigrationService(
        database,
        now: () => DateTime.utc(2026, 7, 30),
        ownerId: 'test',
      ).migrate();

      expect(result.sourceCount, 0);
      expect(result.targetIds, isEmpty);
      expect(await database.findAll(IndexedDbStoreNames.trainings), isEmpty);
      expect(
        await database.findAll(IndexedDbStoreNames.trainingRecords),
        isEmpty,
      );
    },
  );

  test(
    'imports legacy store as deterministic v2 without changing source',
    () async {
      final database = FakeIndexedDbDatabase();
      final legacy = {'id': 'old-1', 'data': _session().toJson()};
      database.seed(IndexedDbStoreNames.trainings, 'old-1', legacy);
      final before = database.rawRecord(IndexedDbStoreNames.trainings, 'old-1');

      final service = LegacyTrainingsMigrationService(
        database,
        now: () => DateTime.utc(2026, 7, 30),
        ownerId: 'test',
      );
      final first = await service.migrate();
      final second = await service.migrate();

      final targetId = TrainingRecordLineage.targetIdForLegacyStore('old-1');
      expect(first.targetIds, {targetId});
      expect(second.alreadyCompleted, isTrue);
      expect(
        database.rawRecord(IndexedDbStoreNames.trainings, 'old-1'),
        before,
      );
      final target = PersistedTrainingRecord.fromRecord(
        database.rawRecord(IndexedDbStoreNames.trainingRecords, targetId)!,
      );
      expect(target.recordVersion, 2);
      expect(
        target.migrationSource?.migrationId,
        TrainingRecordLineage.legacyStoreMigrationId,
      );
      expect(
        target.migrationSource?.sourceSystem,
        TrainingRecordLineage.legacyStoreSourceSystem,
      );
      expect(target.migrationSource?.sourceKey, 'old-1');
      expect(
        target.dataV2.exercises.single.sets.single.setType.name,
        'legacyUnknown',
      );
      final metadata = IndexedDbMigrationMetadata.fromRecord(
        database.rawRecord(
          IndexedDbStoreNames.migrationMetadata,
          LegacyTrainingsMigrationService.migrationId,
        )!,
      );
      expect(metadata.status, IndexedDbMigrationStatus.completed);
    },
  );

  test(
    'invalid and unknown equipment records retain original payload in quarantine',
    () async {
      final database = FakeIndexedDbDatabase();
      final unknown = _session(equipmentId: 'unknown').toJson();
      database.seed(IndexedDbStoreNames.trainings, 'unknown', {
        'id': 'unknown',
        'data': unknown,
      });
      database.seed(IndexedDbStoreNames.trainings, 'invalid', {
        'id': 'invalid',
        'data': {'not': 'a session'},
      });
      final before = await database.findAll(IndexedDbStoreNames.trainings);

      final result = await LegacyTrainingsMigrationService(
        database,
        now: () => DateTime.utc(2026, 7, 30),
        ownerId: 'test',
      ).migrate();

      expect(result.invalidCount, 1);
      expect(result.needsReviewCount, 1);
      expect(result.quarantineIds, hasLength(2));
      expect(await database.findAll(IndexedDbStoreNames.trainings), before);
      final quarantine = await database.findAll(
        IndexedDbStoreNames.migrationQuarantine,
      );
      expect(quarantine, hasLength(2));
      expect(
        quarantine.map((record) => record['rawPayload']),
        containsAll([
          {'id': 'unknown', 'data': unknown},
          {
            'id': 'invalid',
            'data': {'not': 'a session'},
          },
        ]),
      );
    },
  );

  test('existing identical target is skipped without rewrite', () async {
    final database = FakeIndexedDbDatabase();
    database.seed(IndexedDbStoreNames.trainings, 'old-1', {
      'id': 'old-1',
      'data': _session().toJson(),
    });
    final firstService = LegacyTrainingsMigrationService(
      database,
      now: () => DateTime.utc(2026, 7, 30),
      ownerId: 'first',
    );
    await firstService.migrate();
    final targetId = TrainingRecordLineage.targetIdForLegacyStore('old-1');
    final targetBefore = database.rawRecord(
      IndexedDbStoreNames.trainingRecords,
      targetId,
    );
    await database.deleteById(
      IndexedDbStoreNames.migrationMetadata,
      LegacyTrainingsMigrationService.migrationId,
    );

    final result = await LegacyTrainingsMigrationService(
      database,
      now: () => DateTime.utc(2026, 8, 1),
      ownerId: 'second',
    ).migrate();

    expect(result.writtenCount, 0);
    expect(result.skippedCount, 1);
    expect(
      database.rawRecord(IndexedDbStoreNames.trainingRecords, targetId),
      targetBefore,
    );
  });

  test('different existing target is quarantined without overwrite', () async {
    final database = FakeIndexedDbDatabase();
    database.seed(IndexedDbStoreNames.trainings, 'old-1', {
      'id': 'old-1',
      'data': _session().toJson(),
    });
    final service = LegacyTrainingsMigrationService(
      database,
      now: () => DateTime.utc(2026, 7, 30),
      ownerId: 'first',
    );
    await service.migrate();
    final targetId = TrainingRecordLineage.targetIdForLegacyStore('old-1');
    final target = database.rawRecord(
      IndexedDbStoreNames.trainingRecords,
      targetId,
    )!;
    final data = Map<String, Object?>.from(target['data']! as Map);
    data['memo'] = 'conflicting target';
    target['data'] = data;
    database.seed(IndexedDbStoreNames.trainingRecords, targetId, target);
    await database.deleteById(
      IndexedDbStoreNames.migrationMetadata,
      LegacyTrainingsMigrationService.migrationId,
    );
    final before = database.rawRecord(
      IndexedDbStoreNames.trainingRecords,
      targetId,
    );

    await expectLater(
      LegacyTrainingsMigrationService(
        database,
        now: () => DateTime.utc(2026, 8, 1),
        ownerId: 'second',
      ).migrate(),
      throwsA(isA<RepositoryException>()),
    );

    expect(
      database.rawRecord(IndexedDbStoreNames.trainingRecords, targetId),
      before,
    );
    expect(
      await database.findById(IndexedDbStoreNames.trainings, 'old-1'),
      isNotNull,
    );
  });
}

TrainingSession _session({String? equipmentId = 'dumbbells'}) {
  return TrainingSession(
    date: '2026-07-26T09:00:00Z',
    memo: 'legacy',
    exercises: [
      TrainingExercise(
        exerciseName: 'Bench Press',
        order: 1,
        equipmentId: equipmentId,
        sets: const [TrainingSet(setNo: 1, weight: 80, reps: 8)],
      ),
    ],
  );
}
