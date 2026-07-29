import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/data/indexed_db/indexed_db_migration_metadata.dart';
import 'package:or_app/data/indexed_db/indexed_db_store_names.dart';
import 'package:or_app/features/repositories/repository_exception.dart';
import 'package:or_app/features/training/migration/training_record_lineage.dart';
import 'package:or_app/features/training/migration/training_v2_migration_executor.dart';

import '../../repositories/indexed_db/fake_indexed_db_database.dart';

void main() {
  const migrationId = TrainingRecordLineage.shadowMigrationId;
  const source = TrainingRecordLineage.shadowSourceSystem;
  const sourceSection = IndexedDbStoreNames.trainingRecords;
  final initialTime = DateTime.utc(2026, 7, 30);

  TrainingV2MigrationMetadataService service(
    FakeIndexedDbDatabase database, {
    String ownerId = 'owner-a',
    DateTime? now,
  }) {
    return TrainingV2MigrationMetadataService(
      database,
      migrationId: migrationId,
      source: source,
      sourceSection: sourceSection,
      ownerId: ownerId,
      now: () => now ?? initialTime,
    );
  }

  test('acquires a five-minute lease and starts attempt one', () async {
    final metadata = await service(FakeIndexedDbDatabase()).acquireLease();

    expect(metadata.status, IndexedDbMigrationStatus.validating);
    expect(metadata.attempt, 1);
    expect(metadata.ownerId, 'owner-a');
    expect(
      metadata.leaseExpiresAt,
      initialTime.add(TrainingV2MigrationMetadataService.leaseDuration),
    );
  });

  test('rejects another owner while the lease is valid', () async {
    final database = FakeIndexedDbDatabase();
    await service(database).acquireLease();

    expect(
      () => service(database, ownerId: 'owner-b').acquireLease(),
      throwsA(
        isA<RepositoryException>().having(
          (error) => error.code,
          'code',
          RepositoryErrorCode.migrationFailed,
        ),
      ),
    );
  });

  test('reacquires an expired lease and increments attempt', () async {
    final database = FakeIndexedDbDatabase();
    await service(database).acquireLease();
    final later = initialTime.add(const Duration(minutes: 6));

    final metadata = await service(
      database,
      ownerId: 'owner-b',
      now: later,
    ).acquireLease();

    expect(metadata.attempt, 2);
    expect(metadata.ownerId, 'owner-b');
    expect(metadata.startedAt, later);
  });

  test('validates internally consistent completed metadata', () async {
    final database = FakeIndexedDbDatabase();
    final metadataService = service(database);
    final active = await metadataService.acquireLease();
    final writing = metadataService.buildWriting(active, _emptyPlan());
    final prepared = _prepareEmpty(writing);
    final completed = metadataService.buildCompleted(
      prepared,
      verifiedRecordCount: 0,
    );

    expect(
      () => metadataService.validateCompleted(
        completed,
        TrainingV2MigrationIntegrity(database, migrationId: migrationId),
      ),
      returnsNormally,
    );
  });

  test('rejects invalid counts and malformed digests', () async {
    final database = FakeIndexedDbDatabase();
    final metadataService = service(database);
    final active = await metadataService.acquireLease();
    final writing = metadataService.buildWriting(active, _emptyPlan());
    final completed = metadataService.buildCompleted(
      _prepareEmpty(writing).copyWith(
        validCounts: {
          ...writing.validCounts,
          'validRecordCount': 1,
          'writtenRecordCount': 1,
        },
        targetDigest: 'invalid',
      ),
      verifiedRecordCount: 1,
    );

    expect(
      () => metadataService.validateCompleted(
        completed,
        TrainingV2MigrationIntegrity(database, migrationId: migrationId),
      ),
      throwsA(
        isA<RepositoryException>().having(
          (error) => error.code,
          'code',
          RepositoryErrorCode.verificationFailed,
        ),
      ),
    );
  });

  test('writes failed metadata without completing migration', () async {
    final database = FakeIndexedDbDatabase();
    final metadataService = service(database);
    final active = await metadataService.acquireLease();

    await metadataService.markFailed(active, StateError('write failed'));

    final stored = IndexedDbMigrationMetadata.fromRecord(
      database.rawRecord(IndexedDbStoreNames.migrationMetadata, migrationId)!,
    );
    expect(stored.status, IndexedDbMigrationStatus.failed);
    expect(stored.completedAt, isNull);
    expect(stored.ownerId, isNull);
    expect(stored.errorCode, RepositoryErrorCode.migrationFailed.name);
  });

  test(
    'completed validation does not inspect the current target store',
    () async {
      final database = FakeIndexedDbDatabase();
      final metadataService = service(database);
      final active = await metadataService.acquireLease();
      final completed = metadataService.buildCompleted(
        _prepareEmpty(metadataService.buildWriting(active, _emptyPlan())),
        verifiedRecordCount: 0,
      );
      database.seed(IndexedDbStoreNames.trainingRecords, 'unrelated', const {
        'id': 'unrelated',
        'broken': true,
      });

      expect(
        () => metadataService.validateCompleted(
          completed,
          TrainingV2MigrationIntegrity(database, migrationId: migrationId),
        ),
        returnsNormally,
      );
    },
  );
}

TrainingV2MigrationPlan _emptyPlan() {
  return TrainingV2MigrationPlan(
    sourceCount: 0,
    sourceIds: const [],
    sourcePayloads: const [],
    candidates: const [],
    problems: const [],
  );
}

IndexedDbMigrationMetadata _prepareEmpty(IndexedDbMigrationMetadata metadata) {
  return metadata.copyWith(
    status: IndexedDbMigrationStatus.prepared,
    expectedRecordIds: const {
      IndexedDbStoreNames.trainingRecords: [],
      IndexedDbStoreNames.migrationQuarantine: [],
    },
    targetIdDigest: TrainingV2MigrationIntegrity.digest(const []),
    targetDigest: TrainingV2MigrationIntegrity.digestCanonical(const []),
  );
}
