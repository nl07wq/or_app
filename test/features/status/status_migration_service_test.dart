import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/models/morning_data.dart';
import 'package:or_app/core/models/work_type.dart';
import 'package:or_app/core/repositories/morning_repository.dart';
import 'package:or_app/data/indexed_db/indexed_db_migration_metadata.dart';
import 'package:or_app/data/indexed_db/indexed_db_quarantined_record.dart';
import 'package:or_app/data/indexed_db/indexed_db_store_names.dart';
import 'package:or_app/features/repositories/repository_exception.dart';
import 'package:or_app/features/status/migration/status_legacy_reader.dart';
import 'package:or_app/features/status/migration/status_migration_service.dart';
import 'package:or_app/features/status/models/persisted_status_record.dart';
import 'package:or_app/features/status/repositories/indexed_db_status_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../repositories/indexed_db/fake_indexed_db_database.dart';

void main() {
  const legacyKey = StatusLegacyReader.sourceKey;
  final migrationTime = DateTime.parse('2026-07-26T00:00:00Z');

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'Legacy Reader separates records without changing SharedPreferences',
    () async {
      final valid = jsonEncode(_morning('2026-07-26T08:00:00', weight: 70));
      final invalidJson = '{not-json';
      final invalidSchema = jsonEncode({'date': '2026-07-26T09:00:00'});
      final original = [valid, invalidJson, invalidSchema];
      SharedPreferences.setMockInitialValues({legacyKey: original});

      final result = await StatusLegacyReader().read();

      expect(result.sourceCount, 3);
      expect(result.validRecords.single.sourceIndex, 0);
      expect(result.invalidRecords.map((record) => record.errorCode), [
        'invalidJson',
        'invalidSchema',
      ]);
      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getStringList(legacyKey), original);
    },
  );

  test('migrates an empty Legacy source and completes metadata', () async {
    final database = FakeIndexedDbDatabase();
    final result = await _service(database, migrationTime).migrate();

    expect(result.sourceCount, 0);
    expect(result.statusRecordIds, isEmpty);
    expect(result.quarantineRecordIds, isEmpty);
    final metadata = _metadata(database);
    expect(metadata.status, IndexedDbMigrationStatus.completed);
    expect(metadata.validCounts['canonical'], 0);
    expect(metadata.completedAt, migrationTime);
  });

  test(
    'migrates multiple dates and keeps same-day records as revisions',
    () async {
      final rawRecords = [
        jsonEncode(
          _morning('2026-07-25T08:00:00', weight: 69, memo: 'day one'),
        ),
        jsonEncode(
          _morning(
            '2026-07-26T08:00:00',
            weight: 70,
            bodyFat: 18,
            sleepHours: 7,
            sleepScore: 80,
            footPain: 2,
            memo: 'old',
          ),
        ),
        jsonEncode(
          _morning(
            '2026-07-26T10:00:00',
            weight: 71,
            bodyFat: 17.5,
            sleepHours: 7.5,
            sleepScore: 85,
            footPain: 1,
            memo: 'latest',
          ),
        ),
      ];
      SharedPreferences.setMockInitialValues({legacyKey: rawRecords});
      final database = FakeIndexedDbDatabase();

      final result = await _service(database, migrationTime).migrate();

      expect(result.sourceCount, 3);
      expect(result.validCount, 3);
      expect(result.invalidCount, 0);
      expect(result.canonicalCount, 2);
      expect(result.legacyRevisionCount, 1);
      expect(
        result.statusRecordIds,
        containsAll({
          'status:2026-07-25',
          'status:2026-07-26',
          'legacy-status:2026-07-26:0001',
        }),
      );

      final repository = IndexedDbStatusRepository(database);
      final canonical = await repository.findAllCanonical();
      expect(canonical.records, hasLength(2));
      expect((await repository.findByLocalDate('2026-07-26'))?.weight, 71);
      final all = await repository.findAllIncludingRevisions();
      expect(all.records, hasLength(3));
      final latest = all.records.singleWhere(
        (record) => record.id == 'status:2026-07-26',
      );
      expect(latest.data.bodyFat, 17.5);
      expect(latest.data.sleepHours, 7.5);
      expect(latest.data.sleepScore, 85);
      expect(latest.data.footPain, 1);
      expect(latest.data.workType, WorkType.work);
      expect(latest.data.workStart, '09:00');
      expect(latest.data.workEnd, '18:00');
      expect(latest.data.memo, 'latest');

      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getStringList(legacyKey), rawRecords);
    },
  );

  test(
    'uses the later array entry when source timestamps are identical',
    () async {
      SharedPreferences.setMockInitialValues({
        legacyKey: [
          jsonEncode(
            _morning('2026-07-26T08:00:00', weight: 70, memo: 'first'),
          ),
          jsonEncode(
            _morning('2026-07-26T08:00:00', weight: 71, memo: 'second'),
          ),
        ],
      });
      final database = FakeIndexedDbDatabase();

      await _service(database, migrationTime).migrate();

      final repository = IndexedDbStatusRepository(database);
      expect((await repository.findByLocalDate('2026-07-26'))?.memo, 'second');
      final revision = (await repository.findAllIncludingRevisions()).records
          .singleWhere(
            (record) => record.recordKind == StatusRecordKind.legacyRevision,
          );
      expect(revision.id, 'legacy-status:2026-07-26:0001');
      expect(revision.data.memo, 'first');
    },
  );

  test(
    'quarantines invalid JSON and schema while migrating valid records',
    () async {
      final rawRecords = [
        jsonEncode(_morning('2026-07-26T08:00:00', weight: 70)),
        '{broken-json',
        jsonEncode({
          ..._morning('2026-07-27T08:00:00', weight: 71),
          'workType': 'invalid',
        }),
      ];
      SharedPreferences.setMockInitialValues({legacyKey: rawRecords});
      final database = FakeIndexedDbDatabase();

      final result = await _service(database, migrationTime).migrate();

      expect(result.validCount, 1);
      expect(result.invalidCount, 2);
      expect(result.validCount + result.invalidCount, result.sourceCount);
      final stored = await database.findAll(
        IndexedDbStoreNames.migrationQuarantine,
      );
      final quarantined = stored
          .map(IndexedDbQuarantinedRecord.fromRecord)
          .toList();
      expect(quarantined, hasLength(2));
      expect(quarantined.map((record) => record.sourceIndex), [1, 2]);
      expect(quarantined.map((record) => record.errorCode), [
        'invalidJson',
        'invalidSchema',
      ]);
      expect(
        quarantined.every(
          (record) =>
              record.sourceSystem == 'shared_preferences' &&
              record.sourceKey == legacyKey &&
              record.migrationId == StatusMigrationService.migrationId,
        ),
        isTrue,
      );
    },
  );

  test(
    'completed migration is idempotent and keeps deterministic IDs',
    () async {
      final rawRecords = [
        jsonEncode(_morning('2026-07-26T08:00:00', weight: 70)),
        jsonEncode(_morning('2026-07-26T10:00:00', weight: 71)),
      ];
      SharedPreferences.setMockInitialValues({legacyKey: rawRecords});
      final firstDatabase = FakeIndexedDbDatabase();
      final firstService = _service(firstDatabase, migrationTime);

      final first = await firstService.migrate();
      final second = await _service(
        firstDatabase,
        migrationTime.add(const Duration(hours: 1)),
      ).migrate();

      expect(second.alreadyCompleted, isTrue);
      expect(second.statusRecordIds, first.statusRecordIds);
      expect(
        await firstDatabase.findAll(IndexedDbStoreNames.statusRecords),
        hasLength(2),
      );

      final secondDatabase = FakeIndexedDbDatabase();
      final independent = await _service(
        secondDatabase,
        migrationTime,
      ).migrate();
      expect(independent.statusRecordIds, first.statusRecordIds);
    },
  );

  test('completed Migration permits normal STATUS Store changes', () async {
    final rawRecords = [
      jsonEncode(_morning('2026-07-25T08:00:00', weight: 69)),
      jsonEncode(_morning('2026-07-26T08:00:00', weight: 70)),
    ];
    SharedPreferences.setMockInitialValues({legacyKey: rawRecords});
    final database = FakeIndexedDbDatabase();
    final service = _service(database, migrationTime);
    final first = await service.migrate();

    await database.deleteById(
      IndexedDbStoreNames.statusRecords,
      'status:2026-07-25',
    );
    await IndexedDbStatusRepository(
      database,
      now: () => migrationTime.add(const Duration(days: 1)),
    ).save(
      MorningData.fromJson(
        _morning('2026-07-26T08:00:00', weight: 71, memo: 'edited'),
      ),
    );

    final result = await service.migrate();

    expect(result.alreadyCompleted, isTrue);
    expect(result.statusRecordIds, first.statusRecordIds);
    expect(
      (await IndexedDbStatusRepository(
        database,
      ).findByLocalDate('2026-07-26'))?.memo,
      'edited',
    );
  });

  test(
    'completed Migration permits REPLACE ALL equivalent STATUS IDs',
    () async {
      SharedPreferences.setMockInitialValues({
        legacyKey: [jsonEncode(_morning('2026-07-26T08:00:00', weight: 70))],
      });
      final database = FakeIndexedDbDatabase();
      final service = _service(database, migrationTime);
      final first = await service.migrate();

      await database.clear(IndexedDbStoreNames.statusRecords);
      await IndexedDbStatusRepository(
        database,
        now: () => migrationTime.add(const Duration(days: 1)),
      ).save(MorningData.fromJson(_morning('2026-07-27T08:00:00', weight: 72)));

      final replaced = await service.migrate();
      expect(replaced.alreadyCompleted, isTrue);
      expect(replaced.statusRecordIds, first.statusRecordIds);

      await database.clear(IndexedDbStoreNames.statusRecords);
      expect((await service.migrate()).alreadyCompleted, isTrue);
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
      (record) {
        final expected = Map<String, Object?>.from(
          record['expectedRecordIds']! as Map,
        )..remove(IndexedDbStoreNames.statusRecords);
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
        )..[IndexedDbStoreNames.statusRecords] = ['not-a-status-record-id'];
        record['expectedRecordIds'] = expected;
      },
      (record) {
        final expected =
            Map<String, Object?>.from(record['expectedRecordIds']! as Map)
              ..[IndexedDbStoreNames.statusRecords] = [
                'status:2026-07-26',
                'status:2026-07-26',
              ];
        record['expectedRecordIds'] = expected;
      },
    ];

    for (final mutate in mutations) {
      final database = FakeIndexedDbDatabase();
      final service = _service(database, migrationTime);
      await service.migrate();
      final metadata = _metadata(database).toRecord();
      mutate(metadata);
      database.seed(
        IndexedDbStoreNames.migrationMetadata,
        StatusMigrationService.migrationId,
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
    }
  });

  test(
    'completed v3 Migration metadata remains valid after v4 upgrade',
    () async {
      SharedPreferences.setMockInitialValues({
        legacyKey: [jsonEncode(_morning('2026-07-26T08:00:00', weight: 70))],
      });
      final database = FakeIndexedDbDatabase();
      final service = _service(database, migrationTime);
      await service.migrate();
      final metadata = _metadata(database).toRecord()
        ..['targetDatabaseVersion'] = 3;
      database.seed(
        IndexedDbStoreNames.migrationMetadata,
        StatusMigrationService.migrationId,
        metadata,
      );

      expect((await service.migrate()).alreadyCompleted, isTrue);
    },
  );

  test(
    'completed Migration rejects missing or added STATUS quarantine',
    () async {
      SharedPreferences.setMockInitialValues({
        legacyKey: ['{broken'],
      });
      final missingDatabase = FakeIndexedDbDatabase();
      final missingService = _service(missingDatabase, migrationTime);
      final missingFirst = await missingService.migrate();
      await missingDatabase.deleteById(
        IndexedDbStoreNames.migrationQuarantine,
        missingFirst.quarantineRecordIds.single,
      );

      await expectLater(
        missingService.migrate(),
        throwsA(
          isA<RepositoryException>().having(
            (error) => error.code,
            'code',
            RepositoryErrorCode.verificationFailed,
          ),
        ),
      );

      final addedDatabase = FakeIndexedDbDatabase();
      final addedService = _service(addedDatabase, migrationTime);
      await addedService.migrate();
      final unexpected = IndexedDbQuarantinedRecord(
        id: 'quarantine:status:99999999',
        migrationId: StatusMigrationService.migrationId,
        sourceSystem: StatusLegacyReader.sourceSystem,
        sourceKey: legacyKey,
        sourceSection: legacyKey,
        sourceIndex: 99999999,
        rawPayload: 'unexpected',
        errorCode: 'invalidJson',
        errorMessage: 'unexpected',
        quarantinedAt: migrationTime,
      );
      await addedDatabase.put(
        IndexedDbStoreNames.migrationQuarantine,
        unexpected.toRecord(),
      );

      await expectLater(
        addedService.migrate(),
        throwsA(
          isA<RepositoryException>().having(
            (error) => error.code,
            'code',
            RepositoryErrorCode.verificationFailed,
          ),
        ),
      );
    },
  );

  test('transaction failure is not completed and can be retried', () async {
    final rawRecords = [
      jsonEncode(_morning('2026-07-26T08:00:00', weight: 70)),
    ];
    SharedPreferences.setMockInitialValues({legacyKey: rawRecords});
    final database = FakeIndexedDbDatabase()..failOnTransactionNumber = 2;

    await expectLater(
      _service(database, migrationTime).migrate(),
      throwsA(isA<RepositoryException>()),
    );
    expect(await database.findAll(IndexedDbStoreNames.statusRecords), isEmpty);
    expect(_metadata(database).status, IndexedDbMigrationStatus.failed);

    database.failOnTransactionNumber = null;
    final retried = await _service(
      database,
      migrationTime.add(const Duration(minutes: 1)),
    ).migrate();
    expect(retried.alreadyCompleted, isFalse);
    expect(retried.statusRecordIds, {'status:2026-07-26'});
    expect(_metadata(database).status, IndexedDbMigrationStatus.completed);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getStringList(legacyKey), rawRecords);
  });

  test('does not take over an active migration lease', () async {
    final database = FakeIndexedDbDatabase();
    final metadata = IndexedDbMigrationMetadata(
      id: StatusMigrationService.migrationId,
      status: IndexedDbMigrationStatus.writing,
      source: 'shared_preferences',
      targetDatabaseVersion: 2,
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
      throwsA(
        isA<RepositoryException>().having(
          (error) => error.code,
          'code',
          RepositoryErrorCode.migrationFailed,
        ),
      ),
    );
    expect(_metadata(database).ownerId, 'other-owner');
  });

  test('post-commit verification failure remains incomplete', () async {
    final rawRecords = [
      jsonEncode(_morning('2026-07-26T08:00:00', weight: 70)),
    ];
    SharedPreferences.setMockInitialValues({legacyKey: rawRecords});
    final database = _CorruptAfterCommitDatabase();

    await expectLater(
      _service(database, migrationTime).migrate(),
      throwsA(isA<RepositoryException>()),
    );

    expect(_metadata(database).status, IndexedDbMigrationStatus.failed);
    expect(
      await database.findAll(IndexedDbStoreNames.statusRecords),
      isNotEmpty,
    );
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getStringList(legacyKey), rawRecords);
  });

  test('keeps IndexedDB v1 compatibility stores untouched', () async {
    SharedPreferences.setMockInitialValues({
      legacyKey: [jsonEncode(_morning('2026-07-26T08:00:00', weight: 70))],
    });
    final database = FakeIndexedDbDatabase();
    database.seed(IndexedDbStoreNames.morningFacts, 'legacy-v1', {
      'id': 'legacy-v1',
      'data': {'weight': 99},
    });

    await _service(database, migrationTime).migrate();

    expect(
      await database.findById(IndexedDbStoreNames.morningFacts, 'legacy-v1'),
      isNotNull,
    );
    expect(await database.findAll(IndexedDbStoreNames.trainings), isEmpty);
  });

  test('does not switch the production Morning Repository', () async {
    final database = FakeIndexedDbDatabase();
    final data = MorningData.fromJson(
      _morning('2026-07-26T08:00:00', weight: 70),
    );

    await MorningRepository.save(data);

    expect(await database.findAll(IndexedDbStoreNames.statusRecords), isEmpty);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getStringList(legacyKey), hasLength(1));
  });
}

StatusMigrationService _service(
  FakeIndexedDbDatabase database,
  DateTime timestamp,
) {
  return StatusMigrationService(
    database,
    now: () => timestamp,
    ownerId: 'test-owner',
  );
}

Map<String, dynamic> _morning(
  String date, {
  required double weight,
  double bodyFat = 18,
  double sleepHours = 7,
  int sleepScore = 80,
  int footPain = 2,
  String memo = '',
}) {
  return MorningData(
    date: date,
    weight: weight,
    bodyFat: bodyFat,
    sleepHours: sleepHours,
    sleepScore: sleepScore,
    footPain: footPain,
    workType: WorkType.work,
    workStart: '09:00',
    workEnd: '18:00',
    workBreak: '1:00',
    workHours: 8,
    memo: memo,
  ).toJson();
}

IndexedDbMigrationMetadata _metadata(FakeIndexedDbDatabase database) {
  final stored = database.rawRecord(
    IndexedDbStoreNames.migrationMetadata,
    StatusMigrationService.migrationId,
  );
  return IndexedDbMigrationMetadata.fromRecord(stored!);
}

class _CorruptAfterCommitDatabase extends FakeIndexedDbDatabase {
  var _statusFindAllCount = 0;

  @override
  Future<List<Map<String, Object?>>> findAll(String storeName) {
    if (storeName == IndexedDbStoreNames.statusRecords) {
      _statusFindAllCount++;
      if (_statusFindAllCount == 3) {
        seed(storeName, 'broken-after-commit', {
          'id': 'broken-after-commit',
          'recordVersion': 999,
        });
      }
    }
    return super.findAll(storeName);
  }
}
