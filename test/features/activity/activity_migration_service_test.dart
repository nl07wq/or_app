import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/models/activity_data.dart';
import 'package:or_app/core/models/bowel_movement_record.dart';
import 'package:or_app/data/indexed_db/indexed_db_migration_metadata.dart';
import 'package:or_app/data/indexed_db/indexed_db_quarantined_record.dart';
import 'package:or_app/data/indexed_db/indexed_db_schema.dart';
import 'package:or_app/data/indexed_db/indexed_db_store_names.dart';
import 'package:or_app/features/activity/migration/activity_legacy_reader.dart';
import 'package:or_app/features/activity/migration/activity_migration_service.dart';
import 'package:or_app/features/activity/models/persisted_activity_record.dart';
import 'package:or_app/features/activity/repository/activity_repository.dart';
import 'package:or_app/features/activity/repository/indexed_db_activity_repository.dart';
import 'package:or_app/features/repositories/repository_exception.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../repositories/indexed_db/fake_indexed_db_database.dart';

void main() {
  const legacyKey = ActivityLegacyReader.sourceKey;
  final migrationTime = DateTime.parse('2026-07-26T00:00:00Z');

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('raw Reader separates records without changing source', () async {
    final valid = jsonEncode(_activityJson(DateTime(2026, 7, 26), steps: 5000));
    final invalidJson = '{not-json';
    final invalidSchema = jsonEncode({'date': '2026-07-26T00:00:00'});
    final original = [valid, invalidJson, invalidSchema];
    SharedPreferences.setMockInitialValues({legacyKey: original});

    final result = await ActivityLegacyReader().read();

    expect(result.sourceCount, 3);
    expect(result.validRecords.single.sourceIndex, 0);
    expect(result.invalidRecords.map((record) => record.errorCode), [
      'invalidJson',
      'invalidSchema',
    ]);
    expect(
      (await SharedPreferences.getInstance()).getStringList(legacyKey),
      original,
    );
  });

  test('migrates zero records and completes v4 metadata', () async {
    final database = FakeIndexedDbDatabase();

    final result = await _service(database, migrationTime).migrate();

    expect(result.sourceCount, 0);
    expect(result.activityRecordIds, isEmpty);
    expect(_metadata(database).status, IndexedDbMigrationStatus.completed);
    expect(
      _metadata(database).targetDatabaseVersion,
      IndexedDbSchema.databaseVersion,
    );
    expect(IndexedDbSchema.databaseVersion, 4);
    expect(await database.findAll(IndexedDbStoreNames.activityDrafts), isEmpty);
  });

  test('migrates one record with all Activity fields intact', () async {
    final raw = _activityJson(
      DateTime(2026, 7, 26),
      steps: 6500,
      carryOver: 500,
      officialSteps: 6200,
      bowel: BowelMovementRecord.recorded(amount: 2, shape: 3),
      note: 'complete',
    );
    SharedPreferences.setMockInitialValues({
      legacyKey: [jsonEncode(raw)],
    });
    final database = FakeIndexedDbDatabase();

    final result = await _service(database, migrationTime).migrate();

    expect(result.validCount, 1);
    expect(result.canonicalCount, 1);
    expect(result.activityRecordIds, {'activity:2026-07-26'});
    final restored = await IndexedDbActivityRepository(
      database,
    ).findByDate(DateTime(2026, 7, 26));
    expect(restored?.toJson(), raw);
    expect(restored?.measuredSteps, 6500);
    expect(restored?.carryOver, 500);
    expect(restored?.officialSteps, 6200);
    expect(restored?.bowelMovement.status, BowelMovementStatus.recorded);
    expect(restored?.bowelMovement.amount, 2);
    expect(restored?.bowelMovement.shape, 3);
    expect(restored?.note, 'complete');
  });

  test('keeps legacy steps-only Carry Over compatibility', () async {
    final raw = {'date': '2026-07-26T00:00:00.000', 'steps': 4321};
    SharedPreferences.setMockInitialValues({
      legacyKey: [jsonEncode(raw)],
    });
    final database = FakeIndexedDbDatabase();

    await _service(database, migrationTime).migrate();

    final restored = await IndexedDbActivityRepository(
      database,
    ).findByDate(DateTime(2026, 7, 26));
    expect(restored?.measuredSteps, 4321);
    expect(restored?.carryOver, 0);
    expect(restored?.carryOverEntered, isFalse);
    expect(restored?.bowelMovement.status, BowelMovementStatus.unconfirmed);
  });

  test(
    'migrates multiple dates and preserves same-day legacy revisions',
    () async {
      final records = [
        _activityJson(DateTime(2026, 7, 25), steps: 4000),
        _activityJson(
          DateTime(2026, 7, 26),
          steps: 5000,
          updatedAt: DateTime.utc(2026, 7, 26, 8),
          note: 'older',
        ),
        _activityJson(
          DateTime(2026, 7, 26),
          steps: 6000,
          carryOver: 1000,
          bowel: const BowelMovementRecord.none(),
          updatedAt: DateTime.utc(2026, 7, 26, 10),
          note: 'newer',
        ),
      ];
      SharedPreferences.setMockInitialValues({
        legacyKey: records.map(jsonEncode).toList(),
      });
      final database = FakeIndexedDbDatabase();

      final result = await _service(database, migrationTime).migrate();

      expect(result.sourceCount, 3);
      expect(result.validCount, 3);
      expect(result.canonicalCount, 2);
      expect(result.legacyRevisionCount, 1);
      expect(
        result.activityRecordIds,
        containsAll({
          'activity:2026-07-25',
          'activity:2026-07-26',
          'legacy-activity:2026-07-26:0001',
        }),
      );
      final repository = IndexedDbActivityRepository(database);
      expect((await repository.findAll()), hasLength(2));
      expect(
        (await repository.findByDate(DateTime(2026, 7, 26)))?.measuredSteps,
        6000,
      );
      final audit = await repository.findAllIncludingRevisions();
      expect(audit.records, hasLength(3));
      expect(
        audit.records
            .singleWhere(
              (record) =>
                  record.recordKind == ActivityRecordKind.legacyRevision,
            )
            .data
            .note,
        'older',
      );
    },
  );

  test('same timestamp uses the later source array entry', () async {
    final timestamp = DateTime.utc(2026, 7, 26, 8);
    SharedPreferences.setMockInitialValues({
      legacyKey: [
        jsonEncode(
          _activityJson(
            DateTime(2026, 7, 26),
            steps: 5000,
            updatedAt: timestamp,
            note: 'first',
          ),
        ),
        jsonEncode(
          _activityJson(
            DateTime(2026, 7, 26),
            steps: 6000,
            updatedAt: timestamp,
            note: 'second',
          ),
        ),
      ],
    });
    final database = FakeIndexedDbDatabase();

    await _service(database, migrationTime).migrate();

    final repository = IndexedDbActivityRepository(database);
    expect(
      (await repository.findByDate(DateTime(2026, 7, 26)))?.note,
      'second',
    );
    final revision = (await repository.findAllIncludingRevisions()).records
        .singleWhere(
          (record) => record.recordKind == ActivityRecordKind.legacyRevision,
        );
    expect(revision.id, 'legacy-activity:2026-07-26:0001');
    expect(revision.data.note, 'first');
  });

  test('quarantines invalid JSON and schema while keeping valid', () async {
    final original = [
      jsonEncode(_activityJson(DateTime(2026, 7, 26), steps: 5000)),
      '{broken-json',
      jsonEncode({
        ..._activityJson(DateTime(2026, 7, 27), steps: 6000),
        'bowelMovement': {'status': 'invalid', 'amount': 2, 'shape': 1},
      }),
    ];
    SharedPreferences.setMockInitialValues({legacyKey: original});
    final database = FakeIndexedDbDatabase();

    final result = await _service(database, migrationTime).migrate();

    expect(result.validCount, 1);
    expect(result.invalidCount, 2);
    expect(result.validCount + result.invalidCount, result.sourceCount);
    final quarantine = (await database.findAll(
      IndexedDbStoreNames.migrationQuarantine,
    )).map(IndexedDbQuarantinedRecord.fromRecord).toList();
    expect(quarantine, hasLength(2));
    expect(quarantine.map((record) => record.sourceIndex), [1, 2]);
    expect(quarantine.map((record) => record.errorCode), [
      'invalidJson',
      'invalidSchema',
    ]);
    expect(
      quarantine.every(
        (record) =>
            record.sourceSystem == 'shared_preferences' &&
            record.sourceKey == legacyKey &&
            record.migrationId == ActivityMigrationService.migrationId,
      ),
      isTrue,
    );
    expect(
      (await SharedPreferences.getInstance()).getStringList(legacyKey),
      original,
    );
  });

  test('completed migration is idempotent and deterministic', () async {
    final source = [
      jsonEncode(_activityJson(DateTime(2026, 7, 26), steps: 5000)),
      jsonEncode(
        _activityJson(
          DateTime(2026, 7, 26),
          steps: 6000,
          updatedAt: DateTime.utc(2026, 7, 26, 9),
        ),
      ),
    ];
    SharedPreferences.setMockInitialValues({legacyKey: source});
    final database = FakeIndexedDbDatabase();

    final first = await _service(database, migrationTime).migrate();
    final second = await _service(
      database,
      migrationTime.add(const Duration(hours: 1)),
    ).migrate();

    expect(second.alreadyCompleted, isTrue);
    expect(second.activityRecordIds, first.activityRecordIds);
    expect(
      await database.findAll(IndexedDbStoreNames.activityRecords),
      hasLength(2),
    );

    final independent = await _service(
      FakeIndexedDbDatabase(),
      migrationTime,
    ).migrate();
    expect(independent.activityRecordIds, first.activityRecordIds);
  });

  test('completed v3 metadata stays complete after v4 Store upgrade', () async {
    final database = FakeIndexedDbDatabase();
    final service = _service(database, migrationTime);
    await service.migrate();
    final metadata = _metadata(database).toRecord()
      ..['targetDatabaseVersion'] = 3;
    database.seed(
      IndexedDbStoreNames.migrationMetadata,
      ActivityMigrationService.migrationId,
      metadata,
    );

    final result = await service.migrate();

    expect(result.alreadyCompleted, isTrue);
    expect(await database.findAll(IndexedDbStoreNames.activityDrafts), isEmpty);
  });

  test('transaction failure remains incomplete and retries cleanly', () async {
    final source = [
      jsonEncode(_activityJson(DateTime(2026, 7, 26), steps: 5000)),
    ];
    SharedPreferences.setMockInitialValues({legacyKey: source});
    final database = FakeIndexedDbDatabase()..failOnTransactionNumber = 2;

    await expectLater(
      _service(database, migrationTime).migrate(),
      throwsA(isA<RepositoryException>()),
    );
    expect(
      await database.findAll(IndexedDbStoreNames.activityRecords),
      isEmpty,
    );
    expect(_metadata(database).status, IndexedDbMigrationStatus.failed);

    database.failOnTransactionNumber = null;
    final retried = await _service(
      database,
      migrationTime.add(const Duration(minutes: 1)),
    ).migrate();
    expect(retried.activityRecordIds, {'activity:2026-07-26'});
    expect(_metadata(database).status, IndexedDbMigrationStatus.completed);
    expect(
      (await SharedPreferences.getInstance()).getStringList(legacyKey),
      source,
    );
  });

  test('post-commit verification failure remains incomplete', () async {
    final source = [
      jsonEncode(_activityJson(DateTime(2026, 7, 26), steps: 5000)),
    ];
    SharedPreferences.setMockInitialValues({legacyKey: source});
    final database = _CorruptAfterCommitDatabase();

    await expectLater(
      _service(database, migrationTime).migrate(),
      throwsA(isA<RepositoryException>()),
    );

    expect(_metadata(database).status, IndexedDbMigrationStatus.failed);
    expect(
      await database.findAll(IndexedDbStoreNames.activityRecords),
      isNotEmpty,
    );
    expect(
      (await SharedPreferences.getInstance()).getStringList(legacyKey),
      source,
    );
  });

  test('does not take over an active migration lease', () async {
    final database = FakeIndexedDbDatabase();
    final metadata = IndexedDbMigrationMetadata(
      id: ActivityMigrationService.migrationId,
      status: IndexedDbMigrationStatus.writing,
      source: 'shared_preferences',
      targetDatabaseVersion: 3,
      attempt: 1,
      startedAt: migrationTime,
      updatedAt: migrationTime,
      ownerId: 'other-owner',
      leaseExpiresAt: migrationTime.add(const Duration(minutes: 1)),
    );
    database.seed(
      IndexedDbStoreNames.migrationMetadata,
      metadata.id,
      metadata.toRecord(),
    );

    await expectLater(
      _service(database, migrationTime).migrate(),
      throwsA(isA<RepositoryException>()),
    );
    expect(_metadata(database).ownerId, 'other-owner');
  });

  test('existing non-migration record is preserved on ID conflict', () async {
    SharedPreferences.setMockInitialValues({
      legacyKey: [
        jsonEncode(_activityJson(DateTime(2026, 7, 26), steps: 5000)),
      ],
    });
    final database = FakeIndexedDbDatabase();
    final existing = PersistedActivityRecord(
      id: 'activity:2026-07-26',
      localDate: '2026-07-26',
      createdAt: migrationTime,
      updatedAt: migrationTime,
      canonicalDate: '2026-07-26',
      recordKind: ActivityRecordKind.canonical,
      data: ActivityData.fromJson(
        _activityJson(DateTime(2026, 7, 26), steps: 9999),
      ),
    );
    database.seed(
      IndexedDbStoreNames.activityRecords,
      existing.id,
      existing.toRecord(),
    );

    await expectLater(
      _service(database, migrationTime).migrate(),
      throwsA(isA<RepositoryException>()),
    );

    final preserved = PersistedActivityRecord.fromRecord(
      (await database.findById(
        IndexedDbStoreNames.activityRecords,
        existing.id,
      ))!,
    );
    expect(preserved.data.measuredSteps, 9999);
    expect(_metadata(database).status, IndexedDbMigrationStatus.failed);
  });

  test('keeps v1 and unrelated v2 stores untouched', () async {
    SharedPreferences.setMockInitialValues({
      legacyKey: [
        jsonEncode(_activityJson(DateTime(2026, 7, 26), steps: 5000)),
      ],
    });
    final database = FakeIndexedDbDatabase();
    database.seed(IndexedDbStoreNames.morningFacts, 'legacy-v1', {
      'id': 'legacy-v1',
      'data': {'value': 1},
    });
    database.seed(IndexedDbStoreNames.statusRecords, 'status-v2', {
      'id': 'status-v2',
      'data': {'value': 2},
    });

    await _service(database, migrationTime).migrate();

    expect(
      await database.findById(IndexedDbStoreNames.morningFacts, 'legacy-v1'),
      isNotNull,
    );
    expect(
      await database.findById(IndexedDbStoreNames.statusRecords, 'status-v2'),
      isNotNull,
    );
  });

  test('does not switch production LocalActivityRepository', () async {
    final database = FakeIndexedDbDatabase();
    final data = ActivityData.fromJson(
      _activityJson(DateTime(2026, 7, 26), steps: 5000),
    );

    await const LocalActivityRepository().save(data);

    expect(
      await database.findAll(IndexedDbStoreNames.activityRecords),
      isEmpty,
    );
    expect(
      (await SharedPreferences.getInstance()).getStringList(legacyKey),
      hasLength(1),
    );
  });
}

ActivityMigrationService _service(
  FakeIndexedDbDatabase database,
  DateTime timestamp,
) {
  return ActivityMigrationService(
    database,
    now: () => timestamp,
    ownerId: 'test-owner',
  );
}

Map<String, dynamic> _activityJson(
  DateTime date, {
  required int steps,
  int carryOver = 0,
  int? officialSteps,
  BowelMovementRecord bowel = const BowelMovementRecord.unconfirmed(),
  DateTime? updatedAt,
  String? note,
}) {
  return ActivityData(
    date: date,
    measuredSteps: steps,
    carryOver: carryOver,
    officialSteps: officialSteps,
    plannedWork: 'planned',
    actualWork: 'actual',
    trainingStatus: ActivityTrainingStatus.completed,
    bowelMovement: bowel,
    note: note,
    createdAt: DateTime.utc(date.year, date.month, date.day, 6),
    updatedAt: updatedAt ?? DateTime.utc(date.year, date.month, date.day, 7),
  ).toJson();
}

IndexedDbMigrationMetadata _metadata(FakeIndexedDbDatabase database) {
  final stored = database.rawRecord(
    IndexedDbStoreNames.migrationMetadata,
    ActivityMigrationService.migrationId,
  );
  return IndexedDbMigrationMetadata.fromRecord(stored!);
}

class _CorruptAfterCommitDatabase extends FakeIndexedDbDatabase {
  var _activityFindAllCount = 0;

  @override
  Future<List<Map<String, Object?>>> findAll(String storeName) {
    if (storeName == IndexedDbStoreNames.activityRecords) {
      _activityFindAllCount++;
      if (_activityFindAllCount == 4) {
        seed(storeName, 'broken-after-commit', {
          'id': 'broken-after-commit',
          'recordVersion': 999,
        });
      }
    }
    return super.findAll(storeName);
  }
}
