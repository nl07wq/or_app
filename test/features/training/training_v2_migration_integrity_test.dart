import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/models/training_session.dart';
import 'package:or_app/data/indexed_db/indexed_db_migration_metadata.dart';
import 'package:or_app/data/indexed_db/indexed_db_store_names.dart';
import 'package:or_app/features/training/migration/training_record_lineage.dart';
import 'package:or_app/features/training/migration/training_v2_migration_executor.dart';
import 'package:or_app/features/training/migration/training_v2_migration_mapper.dart';
import 'package:or_app/features/training/models/persisted_training_record.dart';

import '../../repositories/indexed_db/fake_indexed_db_database.dart';

void main() {
  const migrationId = TrainingRecordLineage.shadowMigrationId;

  test('canonical JSON and digests are stable across map and list order', () {
    final first = {
      'b': 2,
      'a': [
        {'y': 2, 'x': 1},
      ],
    };
    final second = {
      'a': [
        {'x': 1, 'y': 2},
      ],
      'b': 2,
    };

    expect(
      TrainingV2MigrationIntegrity.canonicalJson(first),
      TrainingV2MigrationIntegrity.canonicalJson(second),
    );
    expect(
      TrainingV2MigrationIntegrity.digestCanonical([first, second]),
      TrainingV2MigrationIntegrity.digestCanonical([second, first]),
    );
    expect(
      TrainingV2MigrationIntegrity.digest(['b', 'a']),
      TrainingV2MigrationIntegrity.digest(['a', 'b']),
    );
    expect(
      TrainingV2MigrationIntegrity.sameSet(['a', 'b'], ['b', 'a']),
      isTrue,
    );
  });

  test('plan rejects a source count mismatch', () {
    expect(
      () => TrainingV2MigrationPlan(
        sourceCount: 1,
        sourceIds: const [],
        sourcePayloads: const [],
        candidates: const [],
        problems: const [],
      ),
      throwsFormatException,
    );
  });

  test('training ID validation rejects malformed IDs', () {
    expect(
      TrainingV2MigrationIntegrity.isTrainingId(
        'training:00112233-4455-4677-8899-aabbccddeeff',
      ),
      isTrue,
    );
    expect(TrainingV2MigrationIntegrity.isTrainingId('training:bad'), isFalse);
  });

  test('initial verification detects target content differences', () async {
    final database = FakeIndexedDbDatabase();
    final target = _target();
    final different = PersistedTrainingRecord.v2ForMigration(
      id: target.id,
      localDate: target.localDate,
      createdAt: target.createdAt,
      updatedAt: target.updatedAt.add(const Duration(minutes: 1)),
      migrationSource: target.migrationSource!,
      data: target.dataV2,
    );
    database.seed(
      IndexedDbStoreNames.trainingRecords,
      target.id,
      different.toRecord(),
    );
    final plan = _plan(target);
    final outcome = _outcome(target);

    expect(
      () => TrainingV2MigrationIntegrity(
        database,
        migrationId: migrationId,
      ).verifyInitial(plan, outcome, (_) async => true),
      throwsFormatException,
    );
  });

  test('initial verification detects source changes', () async {
    final database = FakeIndexedDbDatabase();
    final target = _target();
    database.seed(
      IndexedDbStoreNames.trainingRecords,
      target.id,
      target.toRecord(),
    );

    expect(
      () => TrainingV2MigrationIntegrity(
        database,
        migrationId: migrationId,
      ).verifyInitial(_plan(target), _outcome(target), (_) async => false),
      throwsFormatException,
    );
  });

  test('completed verification detects quarantine set differences', () async {
    final database = FakeIndexedDbDatabase();
    final metadata = _metadata(
      expectedRecordIds: const {
        IndexedDbStoreNames.trainingRecords: [],
        IndexedDbStoreNames.migrationQuarantine: [
          'quarantine:training-v2:12345678:invalid',
        ],
      },
    );

    expect(
      () => TrainingV2MigrationIntegrity(
        database,
        migrationId: migrationId,
      ).verifyCompletedQuarantine(metadata),
      throwsFormatException,
    );
  });
}

PersistedTrainingRecord _target() {
  const sourceId = 'training:00112233-4455-4677-8899-aabbccddeeff';
  final source = PersistedTrainingRecord(
    id: sourceId,
    localDate: '2026-07-30',
    createdAt: DateTime.utc(2026, 7, 30),
    updatedAt: DateTime.utc(2026, 7, 30, 1),
    data: TrainingSession(
      date: '2026-07-30',
      memo: 'source',
      exercises: const [],
    ),
  );
  return TrainingV2MigrationMapper.map(
    targetId: TrainingRecordLineage.shadowIdForV1(sourceId),
    localDate: source.localDate,
    createdAt: source.createdAt,
    updatedAt: source.updatedAt,
    migrationSource: TrainingRecordLineage.shadowSource(
      sourceRecordId: sourceId,
      sourceIndex: 0,
    ),
    source: source.data,
  );
}

TrainingV2MigrationPlan _plan(PersistedTrainingRecord target) {
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

TrainingV2MigrationWriteOutcome _outcome(PersistedTrainingRecord target) {
  return TrainingV2MigrationWriteOutcome(
    metadata: _metadata(
      expectedRecordIds: {
        IndexedDbStoreNames.trainingRecords: [target.id],
        IndexedDbStoreNames.migrationQuarantine: const [],
      },
      targetIdDigest: TrainingV2MigrationIntegrity.digest([target.id]),
      targetDigest: TrainingV2MigrationIntegrity.digestCanonical([
        target.toRecord(),
      ]),
    ),
    targets: [target],
    quarantine: const [],
  );
}

IndexedDbMigrationMetadata _metadata({
  required Map<String, List<String>> expectedRecordIds,
  String? targetIdDigest,
  String? targetDigest,
}) {
  final timestamp = DateTime.utc(2026, 7, 30);
  return IndexedDbMigrationMetadata(
    id: TrainingRecordLineage.shadowMigrationId,
    status: IndexedDbMigrationStatus.completed,
    source: TrainingRecordLineage.shadowSourceSystem,
    targetDatabaseVersion: 4,
    attempt: 1,
    startedAt: timestamp,
    updatedAt: timestamp,
    completedAt: timestamp,
    sourceCounts: const {IndexedDbStoreNames.trainingRecords: 1},
    validCounts: const {
      'validRecordCount': 1,
      'invalidRecordCount': 0,
      'needsReviewRecordCount': 0,
      'conflictRecordCount': 0,
      'writtenRecordCount': 1,
      'skippedRecordCount': 0,
      'verifiedRecordCount': 1,
    },
    quarantinedCounts: const {'invalid': 0, 'needsReview': 0, 'conflict': 0},
    expectedRecordIds: expectedRecordIds,
    sourceDigest: '12345678',
    sourceIdDigest: '12345678',
    targetIdDigest: targetIdDigest ?? '12345678',
    targetDigest: targetDigest ?? '12345678',
  );
}
