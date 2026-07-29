import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/models/activity_data.dart';
import 'package:or_app/core/models/bowel_movement_record.dart';
import 'package:or_app/core/models/digestive_event.dart';
import 'package:or_app/data/indexed_db/indexed_db_store_names.dart';
import 'package:or_app/features/activity/models/persisted_activity_record.dart';
import 'package:or_app/features/activity/repository/indexed_db_activity_repository.dart';
import 'package:or_app/features/repositories/repository_exception.dart';

import '../../repositories/indexed_db/fake_indexed_db_database.dart';

void main() {
  late FakeIndexedDbDatabase database;
  late List<DateTime> timestamps;
  late IndexedDbActivityRepository repository;

  setUp(() {
    database = FakeIndexedDbDatabase();
    timestamps = [
      DateTime.parse('2026-07-26T00:00:00Z'),
      DateTime.parse('2026-07-26T01:00:00Z'),
      DateTime.parse('2026-07-26T02:00:00Z'),
      DateTime.parse('2026-07-26T03:00:00Z'),
      DateTime.parse('2026-07-26T04:00:00Z'),
    ];
    repository = IndexedDbActivityRepository(
      database,
      now: () => timestamps.removeAt(0),
    );
  });

  test(
    'saves and overwrites canonical while preserving envelope createdAt',
    () async {
      await repository.save(_activity(DateTime(2026, 7, 26), steps: 5000));
      var stored = PersistedActivityRecord.fromRecord(
        (await database.findAll(IndexedDbStoreNames.activityRecords)).single,
      );
      expect(stored.id, 'activity:2026-07-26');
      expect(stored.data.id, '2026-07-26');
      expect(stored.canonicalDate, '2026-07-26');
      expect(stored.createdAt, DateTime.parse('2026-07-26T00:00:00Z'));
      expect(stored.updatedAt, DateTime.parse('2026-07-26T00:00:00Z'));

      await repository.save(_activity(DateTime(2026, 7, 26), steps: 6000));
      stored = PersistedActivityRecord.fromRecord(
        (await database.findAll(IndexedDbStoreNames.activityRecords)).single,
      );
      expect(stored.data.measuredSteps, 6000);
      expect(stored.createdAt, DateTime.parse('2026-07-26T00:00:00Z'));
      expect(stored.updatedAt, DateTime.parse('2026-07-26T01:00:00Z'));
    },
  );

  test('keeps dates, sorts descending, and survives recreation', () async {
    await repository.save(_activity(DateTime(2026, 7, 25), steps: 4000));
    await repository.save(_activity(DateTime(2026, 7, 27), steps: 7000));

    final all = await repository.findAll();
    expect(all.map((record) => record.id), ['2026-07-27', '2026-07-25']);
    expect(() => all.clear(), throwsUnsupportedError);
    expect((await repository.findById('2026-07-25'))?.measuredSteps, 4000);
    expect(
      (await repository.findById('activity:2026-07-25'))?.measuredSteps,
      4000,
    );
    expect(
      (await repository.findByDate(DateTime(2026, 7, 27)))?.measuredSteps,
      7000,
    );

    final recreated = IndexedDbActivityRepository(database);
    expect(
      (await recreated.findByDate(DateTime(2026, 7, 25)))?.measuredSteps,
      4000,
    );
  });

  test('uses the previous local calendar date for Carry Over', () async {
    await repository.save(
      _activity(DateTime(2026, 7, 31), steps: 5000, carryOver: 1000),
    );
    await repository.save(
      _activity(DateTime(2026, 8, 1), steps: 6000, carryOver: 500),
    );
    expect(
      (await repository.findByDate(DateTime(2026, 8, 1)))?.officialSteps,
      5500,
    );

    await repository.save(
      _activity(DateTime(2026, 12, 31), steps: 7000, carryOver: 2000),
    );
    await repository.save(_activity(DateTime(2027, 1, 1), steps: 8000));
    expect(
      (await repository.findByDate(DateTime(2027, 1, 1)))?.officialSteps,
      6000,
    );
  });

  test('keeps no Carry Over and existing negative-value rejection', () async {
    await repository.save(_activity(DateTime(2026, 7, 26), steps: 5000));
    await repository.save(_activity(DateTime(2026, 7, 27), steps: 6000));
    expect(
      (await repository.findByDate(DateTime(2026, 7, 27)))?.officialSteps,
      6000,
    );
    expect(
      () => _activity(DateTime(2026, 7, 28), steps: 1, carryOver: -1),
      throwsArgumentError,
    );
  });

  test('preserves bowel states and fixes the saved local date', () async {
    await repository.save(
      _activity(
        DateTime(2026, 7, 26),
        steps: 5000,
        bowel: BowelMovementRecord.recorded(amount: 2, shape: 3),
      ),
    );
    await repository.save(
      _activity(
        DateTime(2026, 7, 27),
        steps: 5000,
        bowel: const BowelMovementRecord.unconfirmed(),
      ),
    );
    final recorded = await repository.findByDate(DateTime(2026, 7, 26));
    expect(recorded?.bowelMovement.status, BowelMovementStatus.recorded);
    expect(recorded?.bowelMovement.amount, 2);
    expect(recorded?.bowelMovement.shape, 3);
    expect(
      (await repository.findByDate(
        DateTime(2026, 7, 27),
      ))?.bowelMovement.status,
      BowelMovementStatus.unconfirmed,
    );
    final envelope = PersistedActivityRecord.fromRecord(
      (await database.findAll(
        IndexedDbStoreNames.activityRecords,
      )).firstWhere((value) => value['id'] == 'activity:2026-07-26'),
    );
    expect(envelope.localDate, '2026-07-26');
  });

  test('persists immutable digestive events across recreation', () async {
    final events = [
      DigestiveEvent(
        id: 'digestive:2026-07-26:1',
        sequence: 1,
        amount: 2,
        shape: 2,
        relief: 2,
        recordedAt: DateTime.utc(2026, 7, 26, 8),
      ),
    ];
    await repository.save(
      _activity(DateTime(2026, 7, 26), steps: 5000, digestiveEvents: events),
    );

    final recreated = IndexedDbActivityRepository(database);
    final restored = await recreated.findByDate(DateTime(2026, 7, 26));
    expect(restored?.digestiveEvents, events);
    expect(() => restored!.digestiveEvents!.clear(), throwsUnsupportedError);
    final envelope = PersistedActivityRecord.fromRecord(
      (await database.findAll(IndexedDbStoreNames.activityRecords)).single,
    );
    expect(envelope.recordVersion, 1);
  });

  test(
    'persists an explicit zero report without changing envelope version',
    () async {
      final event = DigestiveEvent(
        id: 'digestive:2026-07-26:none',
        sequence: 1,
        amount: 0,
        shape: null,
        relief: null,
        recordedAt: DateTime.utc(2026, 7, 26, 8),
      );
      await repository.save(
        _activity(DateTime(2026, 7, 26), steps: 5000, digestiveEvents: [event]),
      );

      final restored = await IndexedDbActivityRepository(
        database,
      ).findByDate(DateTime(2026, 7, 26));
      expect(restored?.digestiveEvents, [event]);
      final envelope = PersistedActivityRecord.fromRecord(
        (await database.findAll(IndexedDbStoreNames.activityRecords)).single,
      );
      expect(envelope.recordVersion, 1);

      await repository.save(
        _activity(
          DateTime(2026, 7, 26),
          steps: 5000,
          digestiveEvents: [event.copyWith(amount: 1, shape: 1, relief: 0)],
        ),
      );
      expect(
        (await repository.findByDate(
          DateTime(2026, 7, 26),
        ))?.digestiveEvents?.single.amount,
        1,
      );

      await repository.delete('2026-07-26');
      expect(await repository.findByDate(DateTime(2026, 7, 26)), isNull);
    },
  );

  test('canonical reads exclude revisions and audit includes them', () async {
    await repository.save(_activity(DateTime(2026, 7, 26), steps: 6000));
    final revision = _revision(
      date: DateTime(2026, 7, 26),
      sequence: 1,
      steps: 5000,
    );
    await database.put(
      IndexedDbStoreNames.activityRecords,
      revision.toRecord(),
    );

    expect(await repository.findAll(), hasLength(1));
    final audit = await repository.findAllIncludingRevisions();
    expect(audit.records, hasLength(2));
    expect(audit.records.map((record) => record.recordKind), [
      ActivityRecordKind.canonical,
      ActivityRecordKind.legacyRevision,
    ]);
  });

  test('rejects two canonical records for one local date', () async {
    final first = PersistedActivityRecord(
      id: 'activity:2026-07-26',
      localDate: '2026-07-26',
      createdAt: DateTime.utc(2026, 7, 26),
      updatedAt: DateTime.utc(2026, 7, 26),
      canonicalDate: '2026-07-26',
      recordKind: ActivityRecordKind.canonical,
      data: _activity(DateTime(2026, 7, 26), steps: 5000),
    );
    await database.put(IndexedDbStoreNames.activityRecords, first.toRecord());
    final conflicting = Map<String, Object?>.from(first.toRecord())
      ..['id'] = 'activity:conflict';

    await expectLater(
      database.put(IndexedDbStoreNames.activityRecords, conflicting),
      throwsStateError,
    );
  });

  test('delete, deleteByDate, and clear affect only Activity', () async {
    await repository.save(_activity(DateTime(2026, 7, 25), steps: 4000));
    await repository.save(_activity(DateTime(2026, 7, 26), steps: 5000));
    final revision = _revision(
      date: DateTime(2026, 7, 26),
      sequence: 1,
      steps: 3000,
    );
    await database.put(
      IndexedDbStoreNames.activityRecords,
      revision.toRecord(),
    );
    database.seed(IndexedDbStoreNames.statusRecords, 'unrelated', {
      'id': 'unrelated',
    });

    await repository.delete('2026-07-25');
    expect(await repository.findById('2026-07-25'), isNull);
    await repository.deleteByDate(DateTime(2026, 7, 26));
    expect((await repository.findAllIncludingRevisions()).records, isEmpty);

    await repository.save(_activity(DateTime(2026, 7, 27), steps: 6000));
    await repository.clear();
    expect(await repository.findAll(), isEmpty);
    expect(
      await database.findById(IndexedDbStoreNames.statusRecords, 'unrelated'),
      isNotNull,
    );
  });

  test('does not report a failed transaction as a successful save', () async {
    database.failNextTransactionWith = StateError('transaction failed');

    await expectLater(
      repository.save(_activity(DateTime(2026, 7, 26), steps: 5000)),
      throwsA(
        isA<RepositoryException>().having(
          (error) => error.code,
          'code',
          RepositoryErrorCode.transactionFailed,
        ),
      ),
    );
    expect(
      await database.findAll(IndexedDbStoreNames.activityRecords),
      isEmpty,
    );
  });

  test('surfaces invalid stored records instead of returning empty', () async {
    database.seed(IndexedDbStoreNames.activityRecords, 'broken', {
      'id': 'broken',
      'recordVersion': 999,
    });

    final audit = await repository.findAllIncludingRevisions();
    expect(audit.records, isEmpty);
    expect(audit.issues, hasLength(1));
    await expectLater(
      repository.findAll(),
      throwsA(
        isA<RepositoryException>().having(
          (error) => error.code,
          'code',
          RepositoryErrorCode.partialCorruption,
        ),
      ),
    );
  });

  test('surfaces a malformed digestive event as partial corruption', () async {
    final timestamp = DateTime.utc(2026, 7, 26);
    final envelope = PersistedActivityRecord(
      id: 'activity:2026-07-26',
      localDate: '2026-07-26',
      createdAt: timestamp,
      updatedAt: timestamp,
      canonicalDate: '2026-07-26',
      recordKind: ActivityRecordKind.canonical,
      data: _activity(
        DateTime(2026, 7, 26),
        steps: 5000,
        digestiveEvents: [
          DigestiveEvent(
            id: 'digestive:2026-07-26:1',
            sequence: 1,
            amount: 2,
            shape: 2,
            relief: 1,
            recordedAt: timestamp,
          ),
        ],
      ),
    ).toRecord();
    final data = Map<String, Object?>.from(envelope['data']! as Map);
    final event = Map<String, Object?>.from(
      (data['digestiveEvents']! as List).single as Map,
    )..['shape'] = 4;
    data['digestiveEvents'] = [event];
    envelope['data'] = data;
    database.seed(
      IndexedDbStoreNames.activityRecords,
      envelope['id']! as String,
      envelope,
    );

    await expectLater(
      repository.findAll(),
      throwsA(
        isA<RepositoryException>().having(
          (error) => error.code,
          'code',
          RepositoryErrorCode.partialCorruption,
        ),
      ),
    );
  });
}

ActivityData _activity(
  DateTime date, {
  required int steps,
  int carryOver = 0,
  BowelMovementRecord bowel = const BowelMovementRecord.unconfirmed(),
  Iterable<DigestiveEvent>? digestiveEvents,
}) {
  return ActivityData(
    date: date,
    measuredSteps: steps,
    carryOver: carryOver,
    bowelMovement: bowel,
    digestiveEvents: digestiveEvents,
    createdAt: DateTime.utc(date.year, date.month, date.day, 6),
    updatedAt: DateTime.utc(date.year, date.month, date.day, 7),
  );
}

PersistedActivityRecord _revision({
  required DateTime date,
  required int sequence,
  required int steps,
}) {
  final localDate = PersistedActivityRecord.localDateFromDate(date);
  return PersistedActivityRecord(
    id: PersistedActivityRecord.legacyRevisionId(localDate, sequence),
    localDate: localDate,
    createdAt: DateTime.utc(date.year, date.month, date.day),
    updatedAt: DateTime.utc(date.year, date.month, date.day),
    canonicalDate: null,
    recordKind: ActivityRecordKind.legacyRevision,
    data: _activity(date, steps: steps),
  );
}
