import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/data/indexed_db/indexed_db_database_contract.dart';
import 'package:or_app/data/indexed_db/indexed_db_migration_metadata.dart';
import 'package:or_app/data/indexed_db/indexed_db_quarantined_record.dart';
import 'package:or_app/data/indexed_db/indexed_db_store_names.dart';
import 'package:or_app/features/daily_log_confirmation/migration/daily_log_confirmation_legacy_reader.dart';
import 'package:or_app/features/daily_log_confirmation/migration/daily_log_confirmation_migration_service.dart';
import 'package:or_app/features/daily_log_confirmation/models/persisted_daily_log_confirmation_record.dart';
import 'package:or_app/features/daily_log_confirmation/repository/indexed_db_daily_log_confirmation_repository.dart';
import 'package:or_app/features/repositories/repository_exception.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../repositories/indexed_db/fake_indexed_db_database.dart';
import 'daily_log_confirmation_test_fixture.dart';

void main() {
  const legacyKey = DailyLogConfirmationLegacyReader.sourceKey;
  final migrationTime = DateTime.parse('2026-07-26T00:00:00Z');

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'raw Reader identifies missing Key without changing preferences',
    () async {
      final result = await DailyLogConfirmationLegacyReader().read();

      expect(result.sourceKeyPresent, isFalse);
      expect(result.sourceCount, 0);
      expect(
        (await SharedPreferences.getInstance()).containsKey(legacyKey),
        isFalse,
      );
    },
  );

  test('raw Reader separates valid and invalid StringList records', () async {
    final valid = jsonEncode(completeConfirmation().toJson());
    final invalidJson = '{invalid';
    final invalidSchema = jsonEncode({'date': '2026-07-26'});
    final original = [valid, invalidJson, invalidSchema];
    SharedPreferences.setMockInitialValues({legacyKey: original});

    final result = await DailyLogConfirmationLegacyReader().read();

    expect(result.sourceKeyPresent, isTrue);
    expect(result.sourceCount, 3);
    expect(
      result.validRecords.single.data.toJson(),
      completeConfirmation().toJson(),
    );
    expect(result.invalidRecords.map((record) => record.errorCode), [
      'invalidJson',
      'invalidSchema',
    ]);
    expect(
      (await SharedPreferences.getInstance()).getStringList(legacyKey),
      original,
    );
  });

  test('fixes localDate from raw text without UTC recalculation', () async {
    final raw = completeConfirmation().toJson()
      ..['date'] = '2026-07-26T00:30:00+09:00';
    SharedPreferences.setMockInitialValues({
      legacyKey: [jsonEncode(raw)],
    });
    final database = FakeIndexedDbDatabase();

    await _service(database, migrationTime).migrate();

    final envelope = PersistedDailyLogConfirmationRecord.fromRecord(
      (await database.findAll(
        IndexedDbStoreNames.dailyLogConfirmations,
      )).single,
    );
    expect(envelope.id, 'confirmation:2026-07-26');
    expect(envelope.localDate, '2026-07-26');
    expect(envelope.data.date, DateTime(2026, 7, 26));
  });

  test(
    'missing Legacy Key completes with explicit Metadata distinction',
    () async {
      final database = FakeIndexedDbDatabase();

      final result = await _service(database, migrationTime).migrate();

      expect(result.sourceKeyPresent, isFalse);
      expect(result.sourceCount, 0);
      final metadata = _metadata(database);
      expect(metadata.status, IndexedDbMigrationStatus.completed);
      expect(metadata.targetDatabaseVersion, 3);
      expect(metadata.sourceCounts['sourceKeyPresent'], 0);
      expect(metadata.sourceIdDigest, isNotNull);
      expect(metadata.targetIdDigest, isNotNull);
      expect(metadata.targetDigest, isNotNull);
    },
  );

  test('present empty Legacy List remains distinguishable', () async {
    SharedPreferences.setMockInitialValues({legacyKey: <String>[]});
    final database = FakeIndexedDbDatabase();

    final result = await _service(database, migrationTime).migrate();

    expect(result.sourceKeyPresent, isTrue);
    expect(result.sourceCount, 0);
    expect(_metadata(database).sourceCounts['sourceKeyPresent'], 1);
  });

  test(
    'migrates versionless complete Snapshot as Version 1 unchanged',
    () async {
      final confirmation = completeConfirmation();
      final original = [jsonEncode(confirmation.toJson())];
      SharedPreferences.setMockInitialValues({legacyKey: original});
      final database = FakeIndexedDbDatabase();

      final result = await _service(database, migrationTime).migrate();

      expect(result.validCount, 1);
      expect(result.writtenCount, 1);
      final envelope = PersistedDailyLogConfirmationRecord.fromRecord(
        (await database.findAll(
          IndexedDbStoreNames.dailyLogConfirmations,
        )).single,
      );
      expect(envelope.snapshotVersion, 1);
      expect(envelope.data.toJson(), confirmation.toJson());
      expect(envelope.data.morning?.weight, 88.25);
      expect(envelope.data.food?.protein, 165.5);
      expect(envelope.data.activity?.steps, 12345);
      expect(envelope.data.training?.setCount, 16);
      expect(
        (await SharedPreferences.getInstance()).getStringList(legacyKey),
        original,
      );
    },
  );

  test('migrates multiple dates and preserves latest-first reads', () async {
    final confirmations = [
      completeConfirmation(date: DateTime(2026, 7, 25)),
      completeConfirmation(date: DateTime(2026, 7, 27)),
      completeConfirmation(),
    ];
    SharedPreferences.setMockInitialValues({
      legacyKey: confirmations
          .map((confirmation) => jsonEncode(confirmation.toJson()))
          .toList(),
    });
    final database = FakeIndexedDbDatabase();

    final result = await _service(database, migrationTime).migrate();

    expect(result.confirmationRecordIds, {
      'confirmation:2026-07-25',
      'confirmation:2026-07-26',
      'confirmation:2026-07-27',
    });
    expect(
      (await IndexedDbDailyLogConfirmationRepository(
        database,
      ).findAll()).map((record) => record.date.day),
      [27, 26, 25],
    );
  });

  test(
    'same-date duplicate selects latest confirmedAt and quarantines revision',
    () async {
      final earlier = completeConfirmation(
        confirmedAt: DateTime(2026, 7, 26, 20),
        trainingName: 'Earlier',
      );
      final later = completeConfirmation(
        confirmedAt: DateTime(2026, 7, 26, 22),
        trainingName: 'Later',
      );
      SharedPreferences.setMockInitialValues({
        legacyKey: [jsonEncode(earlier.toJson()), jsonEncode(later.toJson())],
      });
      final database = FakeIndexedDbDatabase();

      final result = await _service(database, migrationTime).migrate();

      expect(result.validCount, 1);
      expect(result.conflictCount, 1);
      expect(
        (await IndexedDbDailyLogConfirmationRepository(
          database,
        ).findByLocalDate('2026-07-26'))?.training?.sessionName,
        'Later',
      );
      final quarantine = await _confirmationQuarantine(database);
      expect(quarantine.single.errorCode, 'legacySameDateRevision');
      expect(quarantine.single.sourceIndex, 0);
      expect(quarantine.single.rawPayload, jsonEncode(earlier.toJson()));
      expect(_metadata(database).status, IndexedDbMigrationStatus.completed);
    },
  );

  test('same confirmedAt uses later source position as canonical', () async {
    final timestamp = DateTime(2026, 7, 26, 22);
    final first = completeConfirmation(
      confirmedAt: timestamp,
      trainingName: 'First',
    );
    final second = completeConfirmation(
      confirmedAt: timestamp,
      trainingName: 'Second',
    );
    SharedPreferences.setMockInitialValues({
      legacyKey: [jsonEncode(first.toJson()), jsonEncode(second.toJson())],
    });
    final database = FakeIndexedDbDatabase();

    await _service(database, migrationTime).migrate();

    expect(
      (await IndexedDbDailyLogConfirmationRepository(
        database,
      ).findLatest())?.training?.sessionName,
      'Second',
    );
  });

  test('unsupported Version and malformed records are quarantined', () async {
    final unsupported = completeConfirmation().toJson()
      ..['snapshotVersion'] = 2;
    final invalidDate = completeConfirmation().toJson()
      ..['date'] = '2026-02-31';
    final original = [
      jsonEncode(completeConfirmation().toJson()),
      jsonEncode(unsupported),
      '{invalid',
      jsonEncode({'date': '2026-07-25'}),
      jsonEncode(invalidDate),
    ];
    SharedPreferences.setMockInitialValues({legacyKey: original});
    final database = FakeIndexedDbDatabase();

    final result = await _service(database, migrationTime).migrate();

    expect(result.validCount, 1);
    expect(result.invalidCount, 4);
    final quarantine = await _confirmationQuarantine(database);
    expect(
      quarantine.map((record) => record.errorCode),
      containsAll([
        'unsupportedSnapshotVersion',
        'invalidJson',
        'invalidSchema',
        'invalidDate',
      ]),
    );
    expect(_metadata(database).status, IndexedDbMigrationStatus.completed);
  });

  test('matching existing ID is treated as idempotent', () async {
    final confirmation = completeConfirmation();
    SharedPreferences.setMockInitialValues({
      legacyKey: [jsonEncode(confirmation.toJson())],
    });
    final database = FakeIndexedDbDatabase();
    final existing = PersistedDailyLogConfirmationRecord(
      id: 'confirmation:2026-07-26',
      localDate: '2026-07-26',
      createdAt: DateTime.utc(2026, 7, 20),
      updatedAt: DateTime.utc(2026, 7, 20),
      data: confirmation,
    );
    database.seed(
      IndexedDbStoreNames.dailyLogConfirmations,
      existing.id,
      existing.toRecord(),
    );

    final result = await _service(database, migrationTime).migrate();

    expect(result.existingMatchCount, 1);
    expect(result.writtenCount, 0);
    final restored = PersistedDailyLogConfirmationRecord.fromRecord(
      (await database.findById(
        IndexedDbStoreNames.dailyLogConfirmations,
        existing.id,
      ))!,
    );
    expect(restored.createdAt, existing.createdAt);
  });

  test(
    'different existing ID is quarantined without overwrite or completion',
    () async {
      final legacy = completeConfirmation(trainingName: 'Legacy');
      final other = completeConfirmation(
        date: DateTime(2026, 7, 27),
        trainingName: 'Other',
      );
      SharedPreferences.setMockInitialValues({
        legacyKey: [jsonEncode(legacy.toJson()), jsonEncode(other.toJson())],
      });
      final database = FakeIndexedDbDatabase();
      database.seed(
        IndexedDbStoreNames.dailyLogConfirmations,
        'confirmation:2026-07-26',
        PersistedDailyLogConfirmationRecord(
          id: 'confirmation:2026-07-26',
          localDate: '2026-07-26',
          createdAt: migrationTime,
          updatedAt: migrationTime,
          data: completeConfirmation(trainingName: 'IndexedDB'),
        ).toRecord(),
      );

      await expectLater(
        _service(database, migrationTime).migrate(),
        throwsA(isA<RepositoryException>()),
      );

      expect(_metadata(database).status, IndexedDbMigrationStatus.failed);
      final repository = IndexedDbDailyLogConfirmationRepository(database);
      expect(
        (await repository.findByLocalDate('2026-07-26'))?.training?.sessionName,
        'IndexedDB',
      );
      expect(await repository.findByLocalDate('2026-07-27'), isNotNull);
      final conflict = (await _confirmationQuarantine(database)).single;
      expect(conflict.errorCode, 'targetIdConflict');
      expect(conflict.conflictingRecordId, 'confirmation:2026-07-26');
      expect(conflict.existingPayloadDigest, isNotNull);
      expect(conflict.legacyPayloadDigest, isNotNull);
      expect(conflict.conflictType, 'targetIdConflict');
    },
  );

  test('completed Migration rerun verifies without duplicate writes', () async {
    SharedPreferences.setMockInitialValues({
      legacyKey: [jsonEncode(completeConfirmation().toJson())],
    });
    final database = FakeIndexedDbDatabase();
    final service = _service(database, migrationTime);

    final first = await service.migrate();
    final second = await service.migrate();

    expect(first.alreadyCompleted, isFalse);
    expect(second.alreadyCompleted, isTrue);
    expect(second.confirmationRecordIds, first.confirmationRecordIds);
    expect(
      await database.findAll(IndexedDbStoreNames.dailyLogConfirmations),
      hasLength(1),
    );
  });

  test('transaction failure stays incomplete and retry is clean', () async {
    final original = [jsonEncode(completeConfirmation().toJson())];
    SharedPreferences.setMockInitialValues({legacyKey: original});
    final database = FakeIndexedDbDatabase()..failOnTransactionNumber = 2;
    final service = _service(database, migrationTime);

    await expectLater(service.migrate(), throwsA(isA<RepositoryException>()));

    expect(_metadata(database).status, IndexedDbMigrationStatus.failed);
    expect(
      await database.findAll(IndexedDbStoreNames.dailyLogConfirmations),
      isEmpty,
    );
    database.failOnTransactionNumber = null;
    final retried = await service.migrate();
    expect(retried.validCount, 1);
    expect(
      await database.findAll(IndexedDbStoreNames.dailyLogConfirmations),
      hasLength(1),
    );
    expect(
      (await SharedPreferences.getInstance()).getStringList(legacyKey),
      original,
    );
  });

  test('post-commit verification failure never completes', () async {
    SharedPreferences.setMockInitialValues({
      legacyKey: [jsonEncode(completeConfirmation().toJson())],
    });
    final backing = FakeIndexedDbDatabase();
    final database = _CorruptAfterCommitDatabase(backing);
    final service = DailyLogConfirmationMigrationService(
      database,
      now: () => migrationTime,
      ownerId: 'test',
    );

    await expectLater(service.migrate(), throwsA(isA<RepositoryException>()));

    expect(_metadata(backing).status, IndexedDbMigrationStatus.failed);
    expect(
      await backing.findAll(IndexedDbStoreNames.dailyLogConfirmations),
      hasLength(1),
    );
  });

  test('migration leaves unrelated Stores unchanged', () async {
    SharedPreferences.setMockInitialValues({
      legacyKey: [jsonEncode(completeConfirmation().toJson())],
    });
    final database = FakeIndexedDbDatabase();
    database.seed(IndexedDbStoreNames.morningFacts, 'v1', {
      'id': 'v1',
      'data': const {},
    });
    database.seed(IndexedDbStoreNames.statusRecords, 'status', {
      'id': 'status',
    });

    await _service(database, migrationTime).migrate();

    expect(
      await database.findById(IndexedDbStoreNames.morningFacts, 'v1'),
      isNotNull,
    );
    expect(
      await database.findById(IndexedDbStoreNames.statusRecords, 'status'),
      isNotNull,
    );
  });
}

class _CorruptAfterCommitDatabase implements IndexedDbDatabase {
  final FakeIndexedDbDatabase _delegate;
  var _transactionCount = 0;
  var _corruptReads = false;

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
    if (_corruptReads &&
        storeName == IndexedDbStoreNames.dailyLogConfirmations &&
        records.isNotEmpty) {
      final data = records.first['data']! as Map<String, Object?>;
      data['confirmedAt'] = '2026-07-26T00:00:00';
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
      _corruptReads = true;
    }
    return result;
  }
}

DailyLogConfirmationMigrationService _service(
  FakeIndexedDbDatabase database,
  DateTime migrationTime,
) {
  return DailyLogConfirmationMigrationService(
    database,
    now: () => migrationTime,
    ownerId: 'test',
  );
}

IndexedDbMigrationMetadata _metadata(FakeIndexedDbDatabase database) {
  return IndexedDbMigrationMetadata.fromRecord(
    database.rawRecord(
      IndexedDbStoreNames.migrationMetadata,
      DailyLogConfirmationMigrationService.migrationId,
    )!,
  );
}

Future<List<IndexedDbQuarantinedRecord>> _confirmationQuarantine(
  FakeIndexedDbDatabase database,
) async {
  return (await database.findAll(IndexedDbStoreNames.migrationQuarantine))
      .map(IndexedDbQuarantinedRecord.fromRecord)
      .where(
        (record) =>
            record.migrationId ==
            DailyLogConfirmationMigrationService.migrationId,
      )
      .toList();
}
