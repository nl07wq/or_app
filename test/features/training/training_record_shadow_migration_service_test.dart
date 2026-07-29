import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/models/cardio_entry.dart';
import 'package:or_app/core/models/training_exercise.dart';
import 'package:or_app/core/models/training_session.dart';
import 'package:or_app/core/models/training_set.dart';
import 'package:or_app/data/indexed_db/indexed_db_migration_metadata.dart';
import 'package:or_app/data/indexed_db/indexed_db_store_names.dart';
import 'package:or_app/features/repositories/repository_exception.dart';
import 'package:or_app/features/training/migration/training_record_lineage.dart';
import 'package:or_app/features/training/migration/training_record_shadow_migration_service.dart';
import 'package:or_app/features/training/migration/training_v2_migration_mapper.dart';
import 'package:or_app/features/training/models/persisted_training_record.dart';
import 'package:or_app/features/training/repository/indexed_db_training_repository.dart';

import '../../repositories/indexed_db/fake_indexed_db_database.dart';

void main() {
  const sourceId = 'training:00112233-4455-4677-8899-aabbccddeeff';
  final createdAt = DateTime.utc(2026, 7, 26, 1);
  final updatedAt = DateTime.utc(2026, 7, 26, 2);

  PersistedTrainingRecord sourceRecord({String? equipmentId = 'dumbbells'}) {
    return PersistedTrainingRecord(
      id: sourceId,
      localDate: '2026-07-26',
      createdAt: createdAt,
      updatedAt: updatedAt,
      data: _session(equipmentId: equipmentId),
    );
  }

  test('shadow IDs and lineage are stable and source-specific', () {
    const secondId = 'training:10112233-4455-4677-8899-aabbccddeeff';
    final first = TrainingRecordLineage.shadowIdForV1(sourceId);

    expect(TrainingRecordLineage.shadowIdForV1(sourceId), first);
    expect(TrainingRecordLineage.shadowIdForV1(secondId), isNot(first));
    expect(
      first,
      matches(
        RegExp(
          r'^training:[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-'
          r'[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ),
      ),
    );
    final lineage = TrainingRecordLineage.shadowSource(
      sourceRecordId: sourceId,
      sourceIndex: 7,
    );
    expect(lineage.migrationId, TrainingRecordLineage.shadowMigrationId);
    expect(lineage.sourceSystem, TrainingRecordLineage.shadowSourceSystem);
    expect(lineage.sourceKey, sourceId);
  });

  test(
    'creates a deterministic v2 shadow and preserves the v1 envelope',
    () async {
      final database = FakeIndexedDbDatabase();
      final source = sourceRecord();
      database.seed(
        IndexedDbStoreNames.trainingRecords,
        source.id,
        source.toRecord(),
      );
      final before = database.rawRecord(
        IndexedDbStoreNames.trainingRecords,
        source.id,
      );

      final result = await TrainingRecordShadowMigrationService(
        database,
        now: () => DateTime.utc(2026, 7, 30),
        ownerId: 'test',
      ).migrate();

      final targetId = TrainingRecordLineage.shadowIdForV1(source.id);
      expect(result.targetIds, {targetId});
      expect(
        database.rawRecord(IndexedDbStoreNames.trainingRecords, source.id),
        before,
      );
      final target = PersistedTrainingRecord.fromRecord(
        database.rawRecord(IndexedDbStoreNames.trainingRecords, targetId)!,
      );
      expect(target.recordVersion, 2);
      expect(target.createdAt, createdAt);
      expect(target.updatedAt, updatedAt);
      expect(target.localDate, source.localDate);
      expect(
        target.migrationSource?.migrationId,
        TrainingRecordLineage.shadowMigrationId,
      );
      expect(
        target.migrationSource?.sourceSystem,
        TrainingRecordLineage.shadowSourceSystem,
      );
      expect(target.migrationSource?.sourceKey, source.id);
      expect(target.dataV2.memo, source.data.memo);
      expect(target.dataV2.sessionName, isNull);
      expect(target.dataV2.sessionGrade, isNull);
      expect(target.dataV2.dynamicStretchCompleted, isNull);
      expect(target.dataV2.cooldownStretchCompleted, isNull);
      expect(target.dataV2.overallEvaluation, isNull);
      final exercise = target.dataV2.exercises.single;
      expect(exercise.equipment?.catalogId, 'dumbbells');
      expect(exercise.equipment?.name, 'Dumbbells');
      expect(exercise.evaluation, isNull);
      expect(exercise.nextTarget, isNull);
      expect(exercise.sets.single.setType.name, 'legacyUnknown');
      expect(exercise.sets.single.rpe, isNull);
      expect(exercise.sets.single.restAfterSeconds, isNull);
      final cardio = target.dataV2.cardioEntries.single;
      expect(cardio.purpose.name, 'legacyUnknown');
      expect(cardio.durationSeconds, 600);
      expect(cardio.legacyIntensity, 'moderate');
      expect(cardio.mets, isNull);
      expect(cardio.legacyReferenceCaloriesKcal, 42);
      expect(cardio.estimatedCaloriesKcal, isNull);
      expect(cardio.weightSnapshotKg, isNull);

      final metadata = IndexedDbMigrationMetadata.fromRecord(
        database.rawRecord(
          IndexedDbStoreNames.migrationMetadata,
          TrainingRecordShadowMigrationService.migrationId,
        )!,
      );
      expect(metadata.status, IndexedDbMigrationStatus.completed);
      expect(metadata.expectedRecordIds[IndexedDbStoreNames.trainingRecords], [
        targetId,
      ]);
    },
  );

  test(
    'completed migration is idempotent and does not migrate v2 records',
    () async {
      final database = FakeIndexedDbDatabase();
      final source = sourceRecord();
      database.seed(
        IndexedDbStoreNames.trainingRecords,
        source.id,
        source.toRecord(),
      );
      final service = TrainingRecordShadowMigrationService(
        database,
        now: () => DateTime.utc(2026, 7, 30),
        ownerId: 'test',
      );
      final first = await service.migrate();
      final recordsAfterFirst = await database.findAll(
        IndexedDbStoreNames.trainingRecords,
      );
      final second = await service.migrate();

      expect(first.alreadyCompleted, isFalse);
      expect(second.alreadyCompleted, isTrue);
      expect(
        await database.findAll(IndexedDbStoreNames.trainingRecords),
        recordsAfterFirst,
      );
      expect(recordsAfterFirst, hasLength(2));
    },
  );

  test(
    'lineage stays idempotent when source ordering changes on retry',
    () async {
      final database = FakeIndexedDbDatabase();
      final source = sourceRecord();
      database.seed(
        IndexedDbStoreNames.trainingRecords,
        source.id,
        source.toRecord(),
      );
      final firstService = TrainingRecordShadowMigrationService(
        database,
        now: () => DateTime.utc(2026, 7, 30),
        ownerId: 'first',
      );
      await firstService.migrate();
      final targetId = TrainingRecordLineage.shadowIdForV1(source.id);
      final targetBefore = database.rawRecord(
        IndexedDbStoreNames.trainingRecords,
        targetId,
      );
      await database.deleteById(
        IndexedDbStoreNames.migrationMetadata,
        TrainingRecordShadowMigrationService.migrationId,
      );
      const earlierId = 'training:00000000-0000-4000-8000-000000000000';
      final earlier = PersistedTrainingRecord(
        id: earlierId,
        localDate: '2026-07-25',
        createdAt: createdAt,
        updatedAt: updatedAt,
        data: _session(date: '2026-07-25T09:00:00Z'),
      );
      database.seed(
        IndexedDbStoreNames.trainingRecords,
        earlier.id,
        earlier.toRecord(),
      );

      final result = await TrainingRecordShadowMigrationService(
        database,
        now: () => DateTime.utc(2026, 8, 1),
        ownerId: 'second',
      ).migrate();

      expect(result.skippedCount, 1);
      expect(result.writtenCount, 1);
      expect(
        database.rawRecord(IndexedDbStoreNames.trainingRecords, targetId),
        targetBefore,
      );
    },
  );

  test(
    'completed verification does not compare the mutable target store',
    () async {
      final database = FakeIndexedDbDatabase();
      final source = sourceRecord();
      database.seed(
        IndexedDbStoreNames.trainingRecords,
        source.id,
        source.toRecord(),
      );
      final service = TrainingRecordShadowMigrationService(
        database,
        now: () => DateTime.utc(2026, 7, 30),
        ownerId: 'test',
      );
      await service.migrate();
      await database.deleteById(
        IndexedDbStoreNames.trainingRecords,
        TrainingRecordLineage.shadowIdForV1(source.id),
      );

      final result = await service.migrate();

      expect(result.alreadyCompleted, isTrue);
      expect(
        await database.findById(IndexedDbStoreNames.trainingRecords, source.id),
        isNotNull,
      );
    },
  );

  test('completed verification still rejects corrupt metadata', () async {
    final database = FakeIndexedDbDatabase();
    final source = sourceRecord();
    database.seed(
      IndexedDbStoreNames.trainingRecords,
      source.id,
      source.toRecord(),
    );
    final service = TrainingRecordShadowMigrationService(
      database,
      now: () => DateTime.utc(2026, 7, 30),
      ownerId: 'test',
    );
    await service.migrate();
    final metadata = database.rawRecord(
      IndexedDbStoreNames.migrationMetadata,
      TrainingRecordShadowMigrationService.migrationId,
    )!;
    metadata['targetDigest'] = 'invalid';
    database.seed(
      IndexedDbStoreNames.migrationMetadata,
      TrainingRecordShadowMigrationService.migrationId,
      metadata,
    );

    await expectLater(
      service.migrate(),
      throwsA(
        isA<RepositoryException>().having(
          (error) => error.code,
          'code',
          RepositoryErrorCode.verificationFailed,
        ),
      ),
    );
  });

  test('completed verification retains quarantine completeness', () async {
    final database = FakeIndexedDbDatabase();
    final source = sourceRecord(equipmentId: 'unknown-machine');
    database.seed(
      IndexedDbStoreNames.trainingRecords,
      source.id,
      source.toRecord(),
    );
    final service = TrainingRecordShadowMigrationService(
      database,
      now: () => DateTime.utc(2026, 7, 30),
      ownerId: 'test',
    );
    final first = await service.migrate();
    await database.deleteById(
      IndexedDbStoreNames.migrationQuarantine,
      first.quarantineIds.single,
    );

    await expectLater(
      service.migrate(),
      throwsA(
        isA<RepositoryException>().having(
          (error) => error.code,
          'code',
          RepositoryErrorCode.verificationFailed,
        ),
      ),
    );
  });

  test(
    'unknown equipment is quarantined without changing the v1 source',
    () async {
      final database = FakeIndexedDbDatabase();
      final source = sourceRecord(equipmentId: 'unknown-machine');
      database.seed(
        IndexedDbStoreNames.trainingRecords,
        source.id,
        source.toRecord(),
      );
      final before = source.toRecord();

      final result = await TrainingRecordShadowMigrationService(
        database,
        now: () => DateTime.utc(2026, 7, 30),
        ownerId: 'test',
      ).migrate();

      expect(result.validCount, 0);
      expect(result.needsReviewCount, 1);
      expect(result.quarantineIds, hasLength(1));
      expect(
        database.rawRecord(IndexedDbStoreNames.trainingRecords, source.id),
        before,
      );
      expect(
        database.rawRecord(
          IndexedDbStoreNames.trainingRecords,
          TrainingRecordLineage.shadowIdForV1(source.id),
        ),
        isNull,
      );
    },
  );

  test(
    'different target at the deterministic ID is a protected conflict',
    () async {
      final database = FakeIndexedDbDatabase();
      final source = sourceRecord();
      database.seed(
        IndexedDbStoreNames.trainingRecords,
        source.id,
        source.toRecord(),
      );
      final targetId = TrainingRecordLineage.shadowIdForV1(source.id);
      final conflicting = TrainingV2MigrationMapper.map(
        targetId: targetId,
        localDate: source.localDate,
        createdAt: createdAt,
        updatedAt: updatedAt,
        migrationSource: TrainingRecordLineage.shadowSource(
          sourceRecordId: source.id,
          sourceIndex: 0,
        ),
        source: _session(memo: 'different'),
      );
      database.seed(
        IndexedDbStoreNames.trainingRecords,
        targetId,
        conflicting.toRecord(),
      );
      final before = conflicting.toRecord();

      await expectLater(
        TrainingRecordShadowMigrationService(
          database,
          now: () => DateTime.utc(2026, 7, 30),
          ownerId: 'test',
        ).migrate(),
        throwsA(isA<RepositoryException>()),
      );

      expect(
        database.rawRecord(IndexedDbStoreNames.trainingRecords, targetId),
        before,
      );
      final metadata = IndexedDbMigrationMetadata.fromRecord(
        database.rawRecord(
          IndexedDbStoreNames.migrationMetadata,
          TrainingRecordShadowMigrationService.migrationId,
        )!,
      );
      expect(metadata.status, IndexedDbMigrationStatus.failed);
    },
  );

  test(
    'preferred reads suppress only the explicitly shadowed v1 source',
    () async {
      final database = FakeIndexedDbDatabase();
      final first = sourceRecord();
      const secondId = 'training:10112233-4455-4677-8899-aabbccddeeff';
      final second = PersistedTrainingRecord(
        id: secondId,
        localDate: '2026-07-27',
        createdAt: createdAt,
        updatedAt: updatedAt,
        data: _session(date: '2026-07-27T09:00:00Z'),
      );
      database.seed(
        IndexedDbStoreNames.trainingRecords,
        first.id,
        first.toRecord(),
      );
      database.seed(
        IndexedDbStoreNames.trainingRecords,
        second.id,
        second.toRecord(),
      );
      await TrainingRecordShadowMigrationService(
        database,
        now: () => DateTime.utc(2026, 7, 30),
        ownerId: 'test',
      ).migrate();
      final repository = IndexedDbTrainingSessionRepository(database);

      final preferred = await repository.findAllRecords();
      final audit = await repository.findAllRecordsIncludingSuperseded();
      expect(preferred, hasLength(2));
      expect(
        preferred.map((record) => record.id),
        containsAll([
          TrainingRecordLineage.shadowIdForV1(first.id),
          TrainingRecordLineage.shadowIdForV1(second.id),
        ]),
      );
      expect(audit, hasLength(4));
      expect(
        audit
            .where((record) => record.recordVersion == 1 && !record.isEditable)
            .map((record) => record.id),
        containsAll([first.id, second.id]),
      );
      expect(await repository.findAllSessions(), hasLength(2));
    },
  );

  test('shadow and superseded source reject update and delete', () async {
    final database = FakeIndexedDbDatabase();
    final source = sourceRecord();
    database.seed(
      IndexedDbStoreNames.trainingRecords,
      source.id,
      source.toRecord(),
    );
    await TrainingRecordShadowMigrationService(
      database,
      now: () => DateTime.utc(2026, 7, 30),
      ownerId: 'test',
    ).migrate();
    final repository = IndexedDbTrainingSessionRepository(database);
    final targetId = TrainingRecordLineage.shadowIdForV1(source.id);

    await expectLater(
      repository.updateById(source.id, _session(memo: 'changed')),
      throwsA(isA<RepositoryException>()),
    );
    await expectLater(
      repository.deleteById(source.id),
      throwsA(isA<RepositoryException>()),
    );
    await expectLater(
      repository.deleteById(targetId),
      throwsA(isA<RepositoryException>()),
    );
    expect(
      await database.findById(IndexedDbStoreNames.trainingRecords, source.id),
      isNotNull,
    );
    expect(
      await database.findById(IndexedDbStoreNames.trainingRecords, targetId),
      isNotNull,
    );
  });

  test(
    'repository reports an inconsistent known lineage as corruption',
    () async {
      final database = FakeIndexedDbDatabase();
      final source = sourceRecord();
      final target = TrainingV2MigrationMapper.map(
        targetId: TrainingRecordLineage.shadowIdForV1(source.id),
        localDate: source.localDate,
        createdAt: source.createdAt,
        updatedAt: source.updatedAt,
        migrationSource: TrainingRecordLineage.shadowSource(
          sourceRecordId: source.id,
          sourceIndex: 0,
        ),
        source: source.data,
      ).toRecord();
      final migrationSource = Map<String, Object?>.from(
        target['migrationSource']! as Map,
      );
      migrationSource['sourceKey'] =
          'training:10112233-4455-4677-8899-aabbccddeeff';
      target['migrationSource'] = migrationSource;
      database.seed(
        IndexedDbStoreNames.trainingRecords,
        target['id']! as String,
        target,
      );

      final audit = await IndexedDbTrainingSessionRepository(
        database,
      ).findAllWithIssues();

      expect(audit.records, isEmpty);
      expect(audit.issues.single.code, 'invalidRecord');
    },
  );
}

TrainingSession _session({
  String date = '2026-07-26T09:00:00Z',
  String memo = 'legacy memo',
  String? equipmentId = 'dumbbells',
}) {
  return TrainingSession(
    date: date,
    memo: memo,
    exercises: [
      TrainingExercise(
        exerciseName: 'Bench Press',
        order: 1,
        equipmentId: equipmentId,
        sets: const [TrainingSet(setNo: 1, weight: 80, reps: 8)],
      ),
    ],
    cardioEntries: [
      CardioEntry(
        type: CardioType.walking,
        intensity: CardioIntensity.moderate,
        durationMinutes: 10,
        distanceKm: 1,
        estimatedCalories: 42,
      ),
    ],
  );
}
