import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/models/daily_log_confirmation.dart';
import 'package:or_app/data/indexed_db/indexed_db_store_names.dart';
import 'package:or_app/features/daily_log_confirmation/models/persisted_daily_log_confirmation_record.dart';
import 'package:or_app/features/daily_log_confirmation/repository/indexed_db_daily_log_confirmation_repository.dart';
import 'package:or_app/features/repositories/repository_exception.dart';

import '../../repositories/indexed_db/fake_indexed_db_database.dart';
import 'daily_log_confirmation_test_fixture.dart';

void main() {
  late FakeIndexedDbDatabase database;
  late int clock;
  late IndexedDbDailyLogConfirmationRepository repository;

  setUp(() {
    database = FakeIndexedDbDatabase();
    clock = 0;
    repository = IndexedDbDailyLogConfirmationRepository(
      database,
      now: () => DateTime.utc(2026, 7, 26).add(Duration(hours: clock++)),
    );
  });

  test(
    'saves Snapshot under date ID and round-trips every Domain section',
    () async {
      final confirmation = completeConfirmation();

      await repository.save(confirmation);
      final restored = await repository.findByLocalDate('2026-07-26');
      final envelope = PersistedDailyLogConfirmationRecord.fromRecord(
        (await database.findById(
          IndexedDbStoreNames.dailyLogConfirmations,
          'confirmation:2026-07-26',
        ))!,
      );

      expect(envelope.snapshotVersion, 1);
      expect(envelope.recordVersion, 2);
      expect(envelope.revision, 1);
      expect(envelope.previousRevisions, isEmpty);
      expect(envelope.localDate, '2026-07-26');
      expect(restored?.toJson(), confirmation.toJson());
      expect(restored?.morning?.weight, 88.25);
      expect(restored?.food?.calories, 2345.75);
      expect(restored?.food?.hydrationMl, 2789.5);
      expect(restored?.activity?.steps, 12345);
      expect(restored?.activity?.calculationBasis?.rawSteps, 12000);
      expect(restored?.training?.exerciseCount, 4);
      expect(restored?.training?.duration, const Duration(minutes: 75));
      expect(restored?.estimatedTotalBurnKcal, 2875.5);
      expect(database.transactionCount, 1);
    },
  );

  test(
    'create-only save rejects different data and preserves the existing v2',
    () async {
      await repository.save(completeConfirmation());
      await expectLater(
        repository.save(completeConfirmation(trainingName: 'Updated')),
        throwsA(
          isA<RepositoryException>().having(
            (error) => error.code,
            'code',
            RepositoryErrorCode.invalidRecord,
          ),
        ),
      );

      final envelope = PersistedDailyLogConfirmationRecord.fromRecord(
        (await database.findById(
          IndexedDbStoreNames.dailyLogConfirmations,
          'confirmation:2026-07-26',
        ))!,
      );
      expect(envelope.createdAt, DateTime.utc(2026, 7, 26));
      expect(envelope.updatedAt, DateTime.utc(2026, 7, 26));
      expect(envelope.data.training?.sessionName, 'Push');
      expect(
        await database.findAll(IndexedDbStoreNames.dailyLogConfirmations),
        hasLength(1),
      );
    },
  );

  test('mixed v1 and v2 read keeps an existing v1 record unchanged', () async {
    final v1 = PersistedDailyLogConfirmationRecord(
      id: 'confirmation:2026-07-25',
      localDate: '2026-07-25',
      createdAt: DateTime.utc(2026, 7, 25),
      updatedAt: DateTime.utc(2026, 7, 25),
      data: completeConfirmation(date: DateTime(2026, 7, 25)),
    ).toRecord();
    database.seed(
      IndexedDbStoreNames.dailyLogConfirmations,
      'confirmation:2026-07-25',
      v1,
    );
    await repository.save(completeConfirmation());

    final all = await repository.findAllPersisted();
    final projection = await repository.findLifecycleProjection('2026-07-25');

    expect(all.map((record) => record.recordVersion), [2, 1]);
    expect(projection.isFinalized, isTrue);
    expect(projection.revision, 1);
    expect(
      await database.findById(
        IndexedDbStoreNames.dailyLogConfirmations,
        'confirmation:2026-07-25',
      ),
      v1,
    );
  });

  test(
    'keeps separate days and returns latest-first immutable lists',
    () async {
      await repository.save(completeConfirmation(date: DateTime(2026, 7, 25)));
      await repository.save(completeConfirmation(date: DateTime(2026, 7, 27)));
      await repository.save(completeConfirmation());

      final all = await repository.findAll();

      expect(all.map((record) => record.date.day), [27, 26, 25]);
      expect((await repository.findLatest())?.date.day, 27);
      expect(() => all.clear(), throwsUnsupportedError);
      expect(await repository.isConfirmed('2026-07-26'), isTrue);
      expect(await repository.isConfirmed('2026-07-24'), isFalse);
    },
  );

  test('snapshot remains fixed after caller-owned data changes', () async {
    final unconfirmedFields = <String>['plannedWork'];
    final confirmation = completeConfirmation(
      activityUnconfirmedFields: unconfirmedFields,
    );

    await repository.save(confirmation);
    unconfirmedFields.add('changed-after-save');

    final restored = await repository.findByLocalDate('2026-07-26');
    expect(restored?.activity?.unconfirmedFields, ['plannedWork']);
  });

  test('preserves null Snapshot sections without inference', () async {
    final confirmation = DailyLogConfirmation(
      date: DateTime(2026, 7, 26),
      confirmedAt: DateTime(2026, 7, 26, 22),
      morning: null,
      food: null,
      activity: null,
      training: null,
    );

    await repository.save(confirmation);
    final restored = await repository.findByLocalDate('2026-07-26');

    expect(restored?.toJson(), confirmation.toJson());
    expect(restored?.morning, isNull);
    expect(restored?.food, isNull);
    expect(restored?.activity, isNull);
    expect(restored?.training, isNull);
    expect(restored?.estimatedTotalBurnKcal, isNull);
  });

  test('old JSON without energy remains readable and round-trips', () {
    final json = completeConfirmation().toJson()
      ..remove('estimatedTotalBurnKcal');

    final restored = DailyLogConfirmation.fromJson(json);

    expect(restored.estimatedTotalBurnKcal, isNull);
    expect(restored.toJson().containsKey('estimatedTotalBurnKcal'), isFalse);
  });

  test('distinguishes missing, corrupt, and unsupported records', () async {
    expect(await repository.findByLocalDate('2026-07-26'), isNull);

    database.seed(
      IndexedDbStoreNames.dailyLogConfirmations,
      'confirmation:2026-07-26',
      {'id': 'confirmation:2026-07-26', 'recordVersion': 1},
    );
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

    final unsupported = PersistedDailyLogConfirmationRecord(
      id: 'confirmation:2026-07-27',
      localDate: '2026-07-27',
      createdAt: DateTime.utc(2026, 7, 27),
      updatedAt: DateTime.utc(2026, 7, 27),
      data: completeConfirmation(date: DateTime(2026, 7, 27)),
    ).toRecord()..['snapshotVersion'] = 2;
    database.seed(
      IndexedDbStoreNames.dailyLogConfirmations,
      'confirmation:2026-07-27',
      unsupported,
    );
    await expectLater(
      repository.findByLocalDate('2026-07-27'),
      throwsA(
        isA<RepositoryException>().having(
          (error) => error.code,
          'code',
          RepositoryErrorCode.unsupportedRecordVersion,
        ),
      ),
    );

    final audit = await repository.findAllWithIssues();
    expect(audit.records, isEmpty);
    expect(audit.issues.map((issue) => issue.code), [
      'invalidRecord',
      'unsupportedRecordVersion',
    ]);
  });

  test('delete and clear affect only Confirmation Store', () async {
    await repository.save(completeConfirmation());
    await repository.save(completeConfirmation(date: DateTime(2026, 7, 27)));
    database.seed(IndexedDbStoreNames.statusRecords, 'status', {
      'id': 'status',
    });

    await repository.deleteByLocalDate('2026-07-26');
    expect(await repository.findByLocalDate('2026-07-26'), isNull);
    expect(await repository.findAll(), hasLength(1));
    await repository.deleteByLocalDate('2026-07-24');

    await repository.clear();
    expect(await repository.findAll(), isEmpty);
    expect(
      await database.findById(IndexedDbStoreNames.statusRecords, 'status'),
      isNotNull,
    );
  });

  test('repository recreation reads committed data', () async {
    await repository.save(completeConfirmation());

    final recreated = IndexedDbDailyLogConfirmationRepository(database);

    expect(
      (await recreated.findByLocalDate('2026-07-26'))?.confirmedAt,
      DateTime(2026, 7, 26, 22, 30),
    );
  });

  test('transaction failure is not reported as a successful save', () async {
    database.failNextTransactionWith = StateError('failed');

    await expectLater(
      repository.save(completeConfirmation()),
      throwsA(
        isA<RepositoryException>().having(
          (error) => error.code,
          'code',
          RepositoryErrorCode.transactionFailed,
        ),
      ),
    );
    expect(
      await database.findAll(IndexedDbStoreNames.dailyLogConfirmations),
      isEmpty,
    );
  });
}
