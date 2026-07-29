import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/models/training_session.dart';
import 'package:or_app/data/indexed_db/indexed_db_migration_metadata.dart';
import 'package:or_app/data/indexed_db/indexed_db_quarantined_record.dart';
import 'package:or_app/data/indexed_db/indexed_db_store_names.dart';
import 'package:or_app/features/training/migration/training_record_lineage.dart';
import 'package:or_app/features/training/migration/training_v2_migration_executor.dart';
import 'package:or_app/features/training/migration/training_v2_migration_mapper.dart';
import 'package:or_app/features/training/models/persisted_training_record.dart';

import '../../repositories/indexed_db/fake_indexed_db_database.dart';

void main() {
  const migrationId = TrainingRecordLineage.shadowMigrationId;
  final timestamp = DateTime.utc(2026, 7, 30);

  test('writes target and prepared metadata atomically', () async {
    final database = FakeIndexedDbDatabase();
    final target = _target();
    final outcome = await _transaction(
      database,
    ).write(_candidatePlan(target), _writingMetadata(timestamp), timestamp);

    expect(outcome.metadata.status, IndexedDbMigrationStatus.prepared);
    expect(outcome.metadata.validCounts['writtenRecordCount'], 1);
    expect(
      database.rawRecord(IndexedDbStoreNames.trainingRecords, target.id),
      target.toRecord(),
    );
    expect(
      database.rawRecord(IndexedDbStoreNames.migrationMetadata, migrationId),
      outcome.metadata.toRecord(),
    );
  });

  test('skips a completely identical existing target', () async {
    final database = FakeIndexedDbDatabase();
    final target = _target();
    database.seed(
      IndexedDbStoreNames.trainingRecords,
      target.id,
      target.toRecord(),
    );

    final outcome = await _transaction(
      database,
    ).write(_candidatePlan(target), _writingMetadata(timestamp), timestamp);

    expect(outcome.metadata.validCounts['writtenRecordCount'], 0);
    expect(outcome.metadata.validCounts['skippedRecordCount'], 1);
    expect(outcome.quarantine, isEmpty);
  });

  test('quarantines a conflict without overwriting existing target', () async {
    final database = FakeIndexedDbDatabase();
    final target = _target();
    final existing = {
      ...target.toRecord(),
      'updatedAt': '2026-07-30T05:00:00Z',
    };
    database.seed(IndexedDbStoreNames.trainingRecords, target.id, existing);

    final outcome = await _transaction(
      database,
    ).write(_candidatePlan(target), _writingMetadata(timestamp), timestamp);

    expect(outcome.conflictCount, 1);
    expect(
      database.rawRecord(IndexedDbStoreNames.trainingRecords, target.id),
      existing,
    );
    expect(outcome.quarantine.single.errorCode, 'targetIdConflict');
    expect(outcome.quarantine.single.rawPayload, const {'source': true});
  });

  test('writes invalid source payload to quarantine', () async {
    final database = FakeIndexedDbDatabase();
    final plan = TrainingV2MigrationPlan(
      sourceCount: 1,
      sourceIds: const ['legacy-1'],
      sourcePayloads: const [
        {'broken': true},
      ],
      candidates: const [],
      problems: const [
        TrainingV2MigrationProblem(
          sourceId: 'legacy-1',
          sourceIndex: 0,
          rawPayload: {'broken': true},
          category: 'invalid',
          errorCode: 'invalidRecord',
          errorMessage: 'Invalid source.',
        ),
      ],
    );

    final outcome = await _transaction(
      database,
    ).write(plan, _writingMetadata(timestamp), timestamp);
    final stored = IndexedDbQuarantinedRecord.fromRecord(
      database.rawRecord(
        IndexedDbStoreNames.migrationQuarantine,
        outcome.quarantine.single.id,
      )!,
    );

    expect(stored.rawPayload, const {'broken': true});
    expect(outcome.metadata.quarantinedCounts['invalid'], 1);
  });

  test(
    'transaction failure does not write target or complete metadata',
    () async {
      final database = FakeIndexedDbDatabase();
      final target = _target();
      database.failNextTransactionWith = StateError('transaction failed');

      await expectLater(
        _transaction(
          database,
        ).write(_candidatePlan(target), _writingMetadata(timestamp), timestamp),
        throwsStateError,
      );

      expect(
        database.rawRecord(IndexedDbStoreNames.trainingRecords, target.id),
        isNull,
      );
      expect(
        database.rawRecord(IndexedDbStoreNames.migrationMetadata, migrationId),
        isNull,
      );
    },
  );
}

TrainingV2MigrationTransaction _transaction(FakeIndexedDbDatabase database) {
  return TrainingV2MigrationTransaction(
    database,
    migrationId: TrainingRecordLineage.shadowMigrationId,
    source: TrainingRecordLineage.shadowSourceSystem,
    sourceSection: IndexedDbStoreNames.trainingRecords,
  );
}

PersistedTrainingRecord _target() {
  const sourceId = 'training:00112233-4455-4677-8899-aabbccddeeff';
  final source = TrainingSession(
    date: '2026-07-30',
    memo: 'source',
    exercises: const [],
  );
  return TrainingV2MigrationMapper.map(
    targetId: TrainingRecordLineage.shadowIdForV1(sourceId),
    localDate: source.date,
    createdAt: DateTime.utc(2026, 7, 30),
    updatedAt: DateTime.utc(2026, 7, 30, 1),
    migrationSource: TrainingRecordLineage.shadowSource(
      sourceRecordId: sourceId,
      sourceIndex: 0,
    ),
    source: source,
  );
}

TrainingV2MigrationPlan _candidatePlan(PersistedTrainingRecord target) {
  return TrainingV2MigrationPlan(
    sourceCount: 1,
    sourceIds: const ['source'],
    sourcePayloads: const [
      {'source': true},
    ],
    candidates: [
      TrainingV2MigrationCandidate(
        sourceId: 'source',
        sourceIndex: 0,
        rawPayload: const {'source': true},
        target: target,
      ),
    ],
    problems: const [],
  );
}

IndexedDbMigrationMetadata _writingMetadata(DateTime timestamp) {
  return IndexedDbMigrationMetadata(
    id: TrainingRecordLineage.shadowMigrationId,
    status: IndexedDbMigrationStatus.writing,
    source: TrainingRecordLineage.shadowSourceSystem,
    targetDatabaseVersion: 4,
    attempt: 1,
    startedAt: timestamp,
    updatedAt: timestamp,
    sourceCounts: const {IndexedDbStoreNames.trainingRecords: 1},
    validCounts: const {
      'validRecordCount': 1,
      'invalidRecordCount': 0,
      'needsReviewRecordCount': 0,
      'conflictRecordCount': 0,
      'writtenRecordCount': 0,
      'skippedRecordCount': 0,
      'verifiedRecordCount': 0,
    },
  );
}
