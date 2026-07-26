import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/models/morning_data.dart';
import 'package:or_app/core/models/work_type.dart';
import 'package:or_app/data/indexed_db/indexed_db_store_names.dart';
import 'package:or_app/features/repositories/repository_exception.dart';
import 'package:or_app/features/status/models/persisted_status_record.dart';
import 'package:or_app/features/status/repositories/indexed_db_status_repository.dart';

import '../../repositories/indexed_db/fake_indexed_db_database.dart';

void main() {
  late FakeIndexedDbDatabase database;
  late List<DateTime> timestamps;
  late IndexedDbStatusRepository repository;

  setUp(() {
    database = FakeIndexedDbDatabase();
    timestamps = [
      DateTime.parse('2026-07-26T00:00:00Z'),
      DateTime.parse('2026-07-26T01:00:00Z'),
      DateTime.parse('2026-07-26T02:00:00Z'),
      DateTime.parse('2026-07-26T03:00:00Z'),
    ];
    repository = IndexedDbStatusRepository(
      database,
      now: () => timestamps.removeAt(0),
    );
  });

  test(
    'saves canonical records and preserves createdAt on same-day update',
    () async {
      await repository.save(_morning('2026-07-26T08:00:00', weight: 70));
      var result = await repository.findAllCanonical();
      expect(result.issues, isEmpty);
      expect(result.records, hasLength(1));
      expect(result.records.single.id, 'status:2026-07-26');
      expect(result.records.single.canonicalDate, '2026-07-26');
      expect(
        result.records.single.createdAt,
        DateTime.parse('2026-07-26T00:00:00Z'),
      );
      expect(
        result.records.single.updatedAt,
        DateTime.parse('2026-07-26T00:00:00Z'),
      );

      await repository.save(_morning('2026-07-26T20:00:00', weight: 71));
      result = await repository.findAllCanonical();
      expect(result.records, hasLength(1));
      expect(result.records.single.data.weight, 71);
      expect(
        result.records.single.createdAt,
        DateTime.parse('2026-07-26T00:00:00Z'),
      );
      expect(
        result.records.single.updatedAt,
        DateTime.parse('2026-07-26T01:00:00Z'),
      );
      expect((await repository.findByLocalDate('2026-07-26'))?.weight, 71);
    },
  );

  test('keeps other dates and finds latest canonical record', () async {
    await repository.save(_morning('2026-07-25T08:00:00', weight: 69));
    await repository.save(_morning('2026-07-27T08:00:00', weight: 72));

    final result = await repository.findAllCanonical();
    expect(result.records.map((record) => record.localDate), [
      '2026-07-27',
      '2026-07-25',
    ]);
    expect((await repository.findLatest())?.weight, 72);
    expect(() => result.records.clear(), throwsUnsupportedError);
    expect(() => result.values.clear(), throwsUnsupportedError);

    final recreated = IndexedDbStatusRepository(database);
    expect((await recreated.findByLocalDate('2026-07-25'))?.weight, 69);
  });

  test(
    'keeps the source local date instead of recalculating it from UTC',
    () async {
      await repository.save(_morning('2026-07-26T00:30:00+09:00', weight: 70));

      expect(
        (await repository.findAllCanonical()).records.single.id,
        'status:2026-07-26',
      );
    },
  );

  test(
    'excludes revisions from canonical reads and includes them for audit',
    () async {
      await repository.save(_morning('2026-07-26T10:00:00', weight: 71));
      final revision = PersistedStatusRecord(
        id: 'legacy-status:2026-07-26:0001',
        localDate: '2026-07-26',
        createdAt: DateTime.parse('2026-07-26T00:00:00Z'),
        updatedAt: DateTime.parse('2026-07-26T00:00:00Z'),
        canonicalDate: null,
        recordKind: StatusRecordKind.legacyRevision,
        data: _morning('2026-07-26T08:00:00', weight: 70),
      );
      database.seed(
        IndexedDbStoreNames.statusRecords,
        revision.id,
        revision.toRecord(),
      );

      expect((await repository.findAllCanonical()).records, hasLength(1));
      final audit = await repository.findAllIncludingRevisions();
      expect(audit.records, hasLength(2));
      expect(audit.records.map((record) => record.recordKind), [
        StatusRecordKind.canonical,
        StatusRecordKind.legacyRevision,
      ]);
    },
  );

  test(
    'delete removes the selected date and clear removes all records',
    () async {
      await repository.save(_morning('2026-07-25T08:00:00', weight: 69));
      await repository.save(_morning('2026-07-26T08:00:00', weight: 70));
      final revision = PersistedStatusRecord(
        id: 'legacy-status:2026-07-26:0001',
        localDate: '2026-07-26',
        createdAt: DateTime.parse('2026-07-26T00:00:00Z'),
        updatedAt: DateTime.parse('2026-07-26T00:00:00Z'),
        canonicalDate: null,
        recordKind: StatusRecordKind.legacyRevision,
        data: _morning('2026-07-26T07:00:00', weight: 68),
      );
      database.seed(
        IndexedDbStoreNames.statusRecords,
        revision.id,
        revision.toRecord(),
      );

      await repository.deleteByLocalDate('2026-07-26');
      final remaining = await repository.findAllIncludingRevisions();
      expect(remaining.records, hasLength(1));
      expect(remaining.records.single.localDate, '2026-07-25');

      await repository.clear();
      expect((await repository.findAllCanonical()).records, isEmpty);
    },
  );

  test('does not report a failed transaction as a successful save', () async {
    database.failNextTransactionWith = StateError('transaction failed');

    await expectLater(
      repository.save(_morning('2026-07-26T08:00:00', weight: 70)),
      throwsA(
        isA<RepositoryException>().having(
          (error) => error.code,
          'code',
          RepositoryErrorCode.transactionFailed,
        ),
      ),
    );
    expect(await database.findAll(IndexedDbStoreNames.statusRecords), isEmpty);
  });

  test(
    'returns valid records and issues separately for partial corruption',
    () async {
      await repository.save(_morning('2026-07-26T08:00:00', weight: 70));
      database.seed(IndexedDbStoreNames.statusRecords, 'broken', {
        'id': 'broken',
        'recordVersion': 999,
      });

      final result = await repository.findAllCanonical();
      expect(result.records, hasLength(1));
      expect(result.issues, hasLength(1));
      expect(result.issues.single.recordId, 'broken');
      await expectLater(
        repository.findLatest(),
        throwsA(
          isA<RepositoryException>().having(
            (error) => error.code,
            'code',
            RepositoryErrorCode.partialCorruption,
          ),
        ),
      );
    },
  );

  test('findByLocalDate surfaces an invalid canonical record', () async {
    database.seed(IndexedDbStoreNames.statusRecords, 'status:2026-07-26', {
      'id': 'status:2026-07-26',
      'recordVersion': 999,
    });

    await expectLater(
      repository.findByLocalDate('2026-07-26'),
      throwsA(
        isA<RepositoryException>().having(
          (error) => error.code,
          'code',
          RepositoryErrorCode.invalidRecord,
        ),
      ),
    );
  });
}

MorningData _morning(
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
  );
}
