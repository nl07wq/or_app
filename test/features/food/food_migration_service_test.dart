import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/models/food_item.dart';
import 'package:or_app/core/models/meal_data.dart';
import 'package:or_app/core/repositories/food_repository.dart' as production;
import 'package:or_app/data/indexed_db/indexed_db_migration_metadata.dart';
import 'package:or_app/data/indexed_db/indexed_db_quarantined_record.dart';
import 'package:or_app/data/indexed_db/indexed_db_store_names.dart';
import 'package:or_app/features/food/migration/food_legacy_reader.dart';
import 'package:or_app/features/food/migration/food_migration_service.dart';
import 'package:or_app/features/food/models/persisted_food_record.dart';
import 'package:or_app/features/food/repository/indexed_db_food_repository.dart';
import 'package:or_app/features/repositories/repository_exception.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../repositories/indexed_db/fake_indexed_db_database.dart';

void main() {
  const legacyKey = FoodLegacyReader.sourceKey;
  final migrationTime = DateTime.parse('2026-07-26T00:00:00Z');

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('raw Reader separates records without changing source', () async {
    final valid = jsonEncode(_meal(id: 'valid').toJson());
    final invalidJson = '{invalid';
    final invalidSchema = jsonEncode({'id': 'invalid'});
    final original = [valid, invalidJson, invalidSchema];
    SharedPreferences.setMockInitialValues({legacyKey: original});

    final result = await FoodLegacyReader().read();

    expect(result.sourceCount, 3);
    expect(result.validRecords.single.data.id, 'valid');
    expect(result.invalidRecords.map((record) => record.errorCode), [
      'invalidJson',
      'invalidSchema',
    ]);
    expect(
      (await SharedPreferences.getInstance()).getStringList(legacyKey),
      original,
    );
  });

  test('migrates zero records and completes metadata', () async {
    final database = FakeIndexedDbDatabase();

    final result = await _service(database, migrationTime).migrate();

    expect(result.sourceCount, 0);
    expect(result.foodRecordIds, isEmpty);
    final metadata = _metadata(database);
    expect(metadata.status, IndexedDbMigrationStatus.completed);
    expect(metadata.targetDatabaseVersion, 5);
    expect(metadata.targetDigest, isNotNull);
    expect(metadata.validCounts['verifiedRecordCount'], 0);
  });

  test(
    'migrates complete Meal and Quick Water without recalculation',
    () async {
      final meal = _meal(
        id: 'meal-1',
        memo: 'memo',
        items: const [
          FoodItem(
            name: 'Rice',
            calories: 251,
            protein: 4.75,
            fat: 0.65,
            carbohydrate: 55.125,
            quantity: 2,
          ),
          FoodItem(
            name: 'Egg',
            calories: 79,
            protein: 7.2,
            fat: 5.4,
            carbohydrate: 1.1,
          ),
        ],
      );
      final water = _meal(
        id: 'water-1',
        mealType: 'Water',
        items: const [],
        waterMl: 333.3,
      );
      final original = [jsonEncode(meal.toJson()), jsonEncode(water.toJson())];
      SharedPreferences.setMockInitialValues({legacyKey: original});
      final database = FakeIndexedDbDatabase();

      final result = await _service(database, migrationTime).migrate();

      expect(result.validCount, 2);
      expect(result.writtenCount, 2);
      final repository = IndexedDbFoodRepository(database);
      final restored = await repository.findById('meal-1');
      expect(restored?.toJson(), meal.toJson());
      expect(restored?.items.map((item) => item.name), ['Rice', 'Egg']);
      expect(restored?.calories, meal.calories);
      expect(restored?.protein, meal.protein);
      expect(restored?.fat, meal.fat);
      expect(restored?.carbohydrate, meal.carbohydrate);
      expect((await repository.findById('water-1'))?.waterMl, 333.3);
      expect(
        (await SharedPreferences.getInstance()).getStringList(legacyKey),
        original,
      );
    },
  );

  test('keeps IDs, dates, same-day meals, and source order', () async {
    final source = [
      _meal(id: 'breakfast'),
      _meal(id: 'lunch', mealType: 'Lunch'),
      _meal(id: 'next-day', date: '2026-07-27'),
    ];
    SharedPreferences.setMockInitialValues({
      legacyKey: source.map((meal) => jsonEncode(meal.toJson())).toList(),
    });
    final database = FakeIndexedDbDatabase();

    final result = await _service(database, migrationTime).migrate();

    expect(result.foodRecordIds, {
      'food:breakfast',
      'food:lunch',
      'food:next-day',
    });
    final repository = IndexedDbFoodRepository(database);
    expect((await repository.findAll()).map((meal) => meal.id), [
      'breakfast',
      'lunch',
      'next-day',
    ]);
    expect(
      (await repository.findByLocalDate('2026-07-26')).map((meal) => meal.id),
      ['breakfast', 'lunch'],
    );
  });

  test(
    'identical Legacy duplicate ID is deterministic and deduplicated',
    () async {
      final raw = jsonEncode(_meal(id: 'same').toJson());
      SharedPreferences.setMockInitialValues({
        legacyKey: [raw, raw],
      });
      final database = FakeIndexedDbDatabase();

      final result = await _service(database, migrationTime).migrate();

      expect(result.validCount, 2);
      expect(result.conflictCount, 0);
      expect(result.writtenCount, 1);
      expect(result.foodRecordIds, {'food:same'});
    },
  );

  test('Legacy differing duplicate IDs are quarantined as conflicts', () async {
    final source = [
      jsonEncode(_meal(id: 'conflict', memo: 'first').toJson()),
      jsonEncode(_meal(id: 'conflict', memo: 'second').toJson()),
      jsonEncode(_meal(id: 'valid').toJson()),
    ];
    SharedPreferences.setMockInitialValues({legacyKey: source});
    final database = FakeIndexedDbDatabase();

    final result = await _service(database, migrationTime).migrate();

    expect(result.validCount, 1);
    expect(result.invalidCount, 0);
    expect(result.conflictCount, 2);
    expect(result.foodRecordIds, {'food:valid'});
    final quarantine = await _foodQuarantine(database);
    expect(quarantine, hasLength(2));
    expect(
      quarantine.map((record) => record.errorCode),
      everyElement('legacyIdConflict'),
    );
    expect(quarantine.map((record) => record.sourceIndex), [0, 1]);
    expect(_metadata(database).status, IndexedDbMigrationStatus.completed);
  });

  test('matching existing ID is preserved as an idempotent match', () async {
    final meal = _meal(id: 'existing');
    SharedPreferences.setMockInitialValues({
      legacyKey: [jsonEncode(meal.toJson())],
    });
    final database = FakeIndexedDbDatabase();
    final existing = PersistedFoodRecord(
      id: 'food:existing',
      localDate: '2026-07-26',
      createdAt: DateTime.parse('2026-07-20T00:00:00Z'),
      updatedAt: DateTime.parse('2026-07-20T00:00:00Z'),
      data: meal,
    );
    database.seed(
      IndexedDbStoreNames.foodRecords,
      existing.id,
      existing.toRecord(),
    );

    final result = await _service(database, migrationTime).migrate();

    expect(result.existingMatchCount, 1);
    expect(result.writtenCount, 0);
    final restored = PersistedFoodRecord.fromRecord(
      (await database.findById(IndexedDbStoreNames.foodRecords, existing.id))!,
    );
    expect(restored.createdAt, existing.createdAt);
  });

  test('different existing ID is quarantined and not completed', () async {
    final legacy = _meal(id: 'conflict', memo: 'legacy');
    SharedPreferences.setMockInitialValues({
      legacyKey: [
        jsonEncode(legacy.toJson()),
        jsonEncode(_meal(id: 'non-conflict').toJson()),
      ],
    });
    final database = FakeIndexedDbDatabase();
    final existing = PersistedFoodRecord(
      id: 'food:conflict',
      localDate: '2026-07-26',
      createdAt: migrationTime,
      updatedAt: migrationTime,
      data: _meal(id: 'conflict', memo: 'indexeddb'),
    );
    database.seed(
      IndexedDbStoreNames.foodRecords,
      existing.id,
      existing.toRecord(),
    );

    await expectLater(
      _service(database, migrationTime).migrate(),
      throwsA(isA<RepositoryException>()),
    );

    expect(_metadata(database).status, IndexedDbMigrationStatus.failed);
    expect(
      (await IndexedDbFoodRepository(database).findById('conflict'))?.memo,
      'indexeddb',
    );
    expect(
      await IndexedDbFoodRepository(database).findById('non-conflict'),
      isNotNull,
    );
    final quarantine = await _foodQuarantine(database);
    expect(quarantine.single.errorCode, 'targetIdConflict');
    expect(quarantine.single.errorMessage, contains('existingDigest='));
  });

  test(
    'invalid records are quarantined while valid records continue',
    () async {
      final original = [
        jsonEncode(_meal(id: 'valid').toJson()),
        '{broken',
        jsonEncode({
          ..._meal(id: 'bad').toJson(),
          'items': [
            {'name': 'missing nutrition'},
          ],
        }),
      ];
      SharedPreferences.setMockInitialValues({legacyKey: original});
      final database = FakeIndexedDbDatabase();

      final result = await _service(database, migrationTime).migrate();

      expect(result.validCount, 1);
      expect(result.invalidCount, 2);
      expect(result.conflictCount, 0);
      expect(
        result.validCount + result.invalidCount + result.conflictCount,
        result.sourceCount,
      );
      final quarantine = await _foodQuarantine(database);
      expect(quarantine.map((record) => record.errorCode), [
        'invalidJson',
        'invalidSchema',
      ]);
    },
  );

  test('completed Migration is idempotent with deterministic IDs', () async {
    final source = [
      jsonEncode(_meal(id: 'meal-1').toJson()),
      jsonEncode(_meal(id: 'meal-2').toJson()),
    ];
    SharedPreferences.setMockInitialValues({legacyKey: source});
    final database = FakeIndexedDbDatabase();

    final first = await _service(database, migrationTime).migrate();
    final second = await _service(
      database,
      migrationTime.add(const Duration(hours: 1)),
    ).migrate();

    expect(second.alreadyCompleted, isTrue);
    expect(second.foodRecordIds, first.foodRecordIds);
    expect(
      await database.findAll(IndexedDbStoreNames.foodRecords),
      hasLength(2),
    );
  });

  test('completed Migration permits normal FOOD Store changes', () async {
    final source = [
      jsonEncode(_meal(id: 'migrated').toJson()),
      jsonEncode(_meal(id: 'removed').toJson()),
    ];
    SharedPreferences.setMockInitialValues({legacyKey: source});
    final database = FakeIndexedDbDatabase();
    final service = _service(database, migrationTime);
    await service.migrate();

    await database.deleteById(IndexedDbStoreNames.foodRecords, 'food:removed');
    await IndexedDbFoodRepository(
      database,
      now: () => migrationTime.add(const Duration(days: 1)),
    ).update(_meal(id: 'migrated', memo: 'edited'));
    await IndexedDbFoodRepository(
      database,
      now: () => migrationTime.add(const Duration(days: 1)),
    ).save(_meal(id: 'new'));

    final result = await service.migrate();

    expect(result.alreadyCompleted, isTrue);
    expect(result.foodRecordIds, {'food:migrated', 'food:removed'});
  });

  test('completed Migration permits REPLACE ALL equivalent IDs', () async {
    SharedPreferences.setMockInitialValues({
      legacyKey: [jsonEncode(_meal(id: 'legacy').toJson())],
    });
    final database = FakeIndexedDbDatabase();
    final service = _service(database, migrationTime);
    await service.migrate();

    await database.clear(IndexedDbStoreNames.foodRecords);
    final replacement = PersistedFoodRecord(
      id: 'food:replacement',
      localDate: '2026-07-27',
      createdAt: migrationTime.add(const Duration(days: 1)),
      updatedAt: migrationTime.add(const Duration(days: 1)),
      data: _meal(id: 'replacement', date: '2026-07-27'),
    );
    await database.put(IndexedDbStoreNames.foodRecords, replacement.toRecord());

    expect((await service.migrate()).alreadyCompleted, isTrue);

    await database.clear(IndexedDbStoreNames.foodRecords);
    expect((await service.migrate()).alreadyCompleted, isTrue);
  });

  test('completed Migration rejects corrupted metadata', () async {
    final database = FakeIndexedDbDatabase();
    final service = _service(database, migrationTime);
    await service.migrate();
    final metadata = _metadata(database).toRecord()
      ..['targetDigest'] = 'not-a-digest';
    database.seed(
      IndexedDbStoreNames.migrationMetadata,
      FoodMigrationService.migrationId,
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

  test('completed Migration rejects mismatched ID and version', () async {
    for (final mutation in <void Function(Map<String, Object?>)>[
      (record) => record['id'] = 'wrong-migration-id',
      (record) => record['targetDatabaseVersion'] = 99,
    ]) {
      final database = FakeIndexedDbDatabase();
      final service = _service(database, migrationTime);
      await service.migrate();
      final metadata = _metadata(database).toRecord();
      mutation(metadata);
      database.seed(
        IndexedDbStoreNames.migrationMetadata,
        FoodMigrationService.migrationId,
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
      final database = FakeIndexedDbDatabase();
      final service = _service(database, migrationTime);
      await service.migrate();
      final metadata = _metadata(database).toRecord()
        ..['targetDatabaseVersion'] = 3;
      database.seed(
        IndexedDbStoreNames.migrationMetadata,
        FoodMigrationService.migrationId,
        metadata,
      );

      expect((await service.migrate()).alreadyCompleted, isTrue);
    },
  );

  test('completed Migration rejects quarantine mismatch', () async {
    SharedPreferences.setMockInitialValues({
      legacyKey: ['{broken'],
    });
    final database = FakeIndexedDbDatabase();
    final service = _service(database, migrationTime);
    final first = await service.migrate();
    expect(first.quarantineRecordIds, hasLength(1));
    await database.deleteById(
      IndexedDbStoreNames.migrationQuarantine,
      first.quarantineRecordIds.single,
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

  test('transaction failure remains incomplete and can retry', () async {
    final source = [jsonEncode(_meal(id: 'meal-1').toJson())];
    SharedPreferences.setMockInitialValues({legacyKey: source});
    final database = FakeIndexedDbDatabase()..failOnTransactionNumber = 2;

    await expectLater(
      _service(database, migrationTime).migrate(),
      throwsA(isA<RepositoryException>()),
    );
    expect(await database.findAll(IndexedDbStoreNames.foodRecords), isEmpty);
    expect(_metadata(database).status, IndexedDbMigrationStatus.failed);

    database.failOnTransactionNumber = null;
    final retried = await _service(
      database,
      migrationTime.add(const Duration(minutes: 1)),
    ).migrate();
    expect(retried.foodRecordIds, {'food:meal-1'});
    expect(_metadata(database).status, IndexedDbMigrationStatus.completed);
    expect(
      (await SharedPreferences.getInstance()).getStringList(legacyKey),
      source,
    );
  });

  test('post-commit verification failure remains incomplete', () async {
    final source = [jsonEncode(_meal(id: 'meal-1').toJson())];
    SharedPreferences.setMockInitialValues({legacyKey: source});
    final database = _CorruptAfterCommitDatabase();

    await expectLater(
      _service(database, migrationTime).migrate(),
      throwsA(isA<RepositoryException>()),
    );

    expect(_metadata(database).status, IndexedDbMigrationStatus.failed);
    expect(
      (await SharedPreferences.getInstance()).getStringList(legacyKey),
      source,
    );
  });

  test('initial Migration rejects a missing Record after commit', () async {
    final source = [jsonEncode(_meal(id: 'meal-1').toJson())];
    SharedPreferences.setMockInitialValues({legacyKey: source});
    final database = _RemoveFoodAfterCommitDatabase();

    await expectLater(
      _service(database, migrationTime).migrate(),
      throwsA(isA<RepositoryException>()),
    );

    expect(_metadata(database).status, IndexedDbMigrationStatus.failed);
  });

  test('initial Migration rejects a target digest mismatch', () async {
    final source = [jsonEncode(_meal(id: 'meal-1').toJson())];
    SharedPreferences.setMockInitialValues({legacyKey: source});
    final database = _CorruptFoodDigestDatabase();

    await expectLater(
      _service(database, migrationTime).migrate(),
      throwsA(isA<RepositoryException>()),
    );

    expect(_metadata(database).status, IndexedDbMigrationStatus.failed);
  });

  test('does not take over an active Migration lease', () async {
    final database = FakeIndexedDbDatabase();
    final metadata = IndexedDbMigrationMetadata(
      id: FoodMigrationService.migrationId,
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

  test('keeps existing v1, v2, and v3 Stores untouched', () async {
    SharedPreferences.setMockInitialValues({
      legacyKey: [jsonEncode(_meal(id: 'meal-1').toJson())],
    });
    final database = FakeIndexedDbDatabase();
    for (final entry in {
      IndexedDbStoreNames.morningFacts: 'v1',
      IndexedDbStoreNames.statusRecords: 'v2',
      IndexedDbStoreNames.activityRecords: 'v3',
    }.entries) {
      database.seed(entry.key, entry.value, {'id': entry.value});
    }

    await _service(database, migrationTime).migrate();

    expect(
      await database.findById(IndexedDbStoreNames.morningFacts, 'v1'),
      isNotNull,
    );
    expect(
      await database.findById(IndexedDbStoreNames.statusRecords, 'v2'),
      isNotNull,
    );
    expect(
      await database.findById(IndexedDbStoreNames.activityRecords, 'v3'),
      isNotNull,
    );
  });

  test('does not switch the production core FoodRepository', () async {
    final database = FakeIndexedDbDatabase();
    await production.FoodRepository.save(_meal(id: 'production'));

    expect(await database.findAll(IndexedDbStoreNames.foodRecords), isEmpty);
    expect(
      (await SharedPreferences.getInstance()).getStringList(legacyKey),
      hasLength(1),
    );
  });
}

FoodMigrationService _service(
  FakeIndexedDbDatabase database,
  DateTime timestamp,
) {
  return FoodMigrationService(
    database,
    now: () => timestamp,
    ownerId: 'test-owner',
  );
}

MealData _meal({
  required String id,
  String date = '2026-07-26',
  String mealType = 'Breakfast',
  String memo = '',
  List<FoodItem>? items,
  double? waterMl,
}) {
  return MealData(
    id: id,
    date: date,
    mealType: mealType,
    memo: memo,
    items:
        items ??
        const [
          FoodItem(
            name: 'Food',
            calories: 100,
            protein: 10.25,
            fat: 3.5,
            carbohydrate: 12.75,
            quantity: 2,
          ),
        ],
    waterMl: waterMl,
  );
}

IndexedDbMigrationMetadata _metadata(FakeIndexedDbDatabase database) {
  return IndexedDbMigrationMetadata.fromRecord(
    database.rawRecord(
      IndexedDbStoreNames.migrationMetadata,
      FoodMigrationService.migrationId,
    )!,
  );
}

Future<List<IndexedDbQuarantinedRecord>> _foodQuarantine(
  FakeIndexedDbDatabase database,
) async {
  return [
    for (final value in await database.findAll(
      IndexedDbStoreNames.migrationQuarantine,
    ))
      if (IndexedDbQuarantinedRecord.fromRecord(value).migrationId ==
          FoodMigrationService.migrationId)
        IndexedDbQuarantinedRecord.fromRecord(value),
  ];
}

class _CorruptAfterCommitDatabase extends FakeIndexedDbDatabase {
  var _foodFindAllCount = 0;

  @override
  Future<List<Map<String, Object?>>> findAll(String storeName) {
    if (storeName == IndexedDbStoreNames.foodRecords) {
      _foodFindAllCount++;
      if (_foodFindAllCount == 2) {
        seed(storeName, 'broken-after-commit', {
          'id': 'broken-after-commit',
          'recordVersion': 999,
        });
      }
    }
    return super.findAll(storeName);
  }
}

class _RemoveFoodAfterCommitDatabase extends FakeIndexedDbDatabase {
  var _foodFindAllCount = 0;

  @override
  Future<List<Map<String, Object?>>> findAll(String storeName) async {
    if (storeName == IndexedDbStoreNames.foodRecords) {
      _foodFindAllCount++;
      if (_foodFindAllCount == 2) {
        await deleteById(storeName, 'food:meal-1');
      }
    }
    return super.findAll(storeName);
  }
}

class _CorruptFoodDigestDatabase extends FakeIndexedDbDatabase {
  @override
  Future<void> put(String storeName, Map<String, Object?> record) {
    if (storeName == IndexedDbStoreNames.migrationMetadata &&
        record['id'] == FoodMigrationService.migrationId &&
        record['status'] == IndexedDbMigrationStatus.verifying.name) {
      return super.put(storeName, {...record, 'targetDigest': '00000000'});
    }
    return super.put(storeName, record);
  }
}
