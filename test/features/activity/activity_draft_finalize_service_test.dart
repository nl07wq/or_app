import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/models/activity_data.dart';
import 'package:or_app/core/state/app_initialization_state.dart';
import 'package:or_app/data/indexed_db/indexed_db_database_contract.dart';
import 'package:or_app/data/indexed_db/indexed_db_store_names.dart';
import 'package:or_app/features/activity/models/activity_draft.dart';
import 'package:or_app/features/activity/repository/indexed_db_activity_draft_repository.dart';
import 'package:or_app/features/activity/services/activity_draft_finalize_service.dart';
import 'package:or_app/features/operation_date/models/operation_local_date.dart';
import 'package:or_app/features/repositories/app_repository_container.dart';
import 'package:or_app/features/repositories/repository_exception.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../repositories/indexed_db/fake_indexed_db_database.dart';

void main() {
  late FakeIndexedDbDatabase database;
  late AppInitializationController controller;
  final now = DateTime.utc(2026, 7, 28, 12);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    database = FakeIndexedDbDatabase();
    controller = AppInitializationController()..markReady();
    AppRepositoryRegistry.beginStartup(controller: controller);
    AppRepositoryRegistry.install(AppRepositoryContainer.indexedDb(database));
    await AppRepositoryRegistry.container.operationState.createInitial(
      OperationLocalDate.parse('2026-07-28'),
    );
  });

  tearDown(AppRepositoryRegistry.resetForTesting);

  test('atomically saves the formal record and deletes its Draft', () async {
    final draft = _draft(now);
    await IndexedDbActivityDraftRepository(
      database,
      now: () => now,
    ).save(draft);

    final saved = await ActivityDraftFinalizeService(
      database,
      now: () => now.add(const Duration(minutes: 1)),
    ).finalize(draft: draft);

    expect(saved.digestiveEvents, hasLength(1));
    expect(await database.findAll(IndexedDbStoreNames.activityDrafts), isEmpty);
    expect(
      await database.findAll(IndexedDbStoreNames.activityRecords),
      hasLength(1),
    );
    expect(
      (await AppRepositoryRegistry.container.activity.findByDate(
        now,
      ))?.digestiveEvents?.single.relief,
      2,
    );
  });

  test('formal save failure leaves the existing Draft intact', () async {
    final draft = _draft(now);
    await IndexedDbActivityDraftRepository(
      database,
      now: () => now,
    ).save(draft);
    database.failNextTransactionWith = StateError('formal write failed');

    await expectLater(
      ActivityDraftFinalizeService(
        database,
        now: () => now,
      ).finalize(draft: draft),
      throwsA(
        isA<RepositoryException>().having(
          (error) => error.code,
          'code',
          RepositoryErrorCode.transactionFailed,
        ),
      ),
    );

    expect(
      await database.findAll(IndexedDbStoreNames.activityDrafts),
      hasLength(1),
    );
    expect(
      await database.findAll(IndexedDbStoreNames.activityRecords),
      isEmpty,
    );
  });

  test('atomically finalizes an explicit zero report', () async {
    final draft = ActivityDraft(
      localDate: '2026-07-28',
      measuredStepsInput: '5000',
      carryOverInput: '0',
      digestiveEvents: [
        ActivityDraftDigestiveEvent(
          id: 'digestive:2026-07-28:none',
          sequence: 1,
          amount: 0,
          recordedAt: now,
        ),
      ],
      createdAt: now,
      updatedAt: now,
    );
    await IndexedDbActivityDraftRepository(
      database,
      now: () => now,
    ).save(draft);

    final saved = await ActivityDraftFinalizeService(
      database,
      now: () => now.add(const Duration(minutes: 1)),
    ).finalize(draft: draft);

    expect(saved.digestiveEvents?.single.amount, 0);
    expect(saved.digestiveEvents?.single.shape, isNull);
    expect(saved.digestiveEvents?.single.relief, isNull);
    expect(await database.findAll(IndexedDbStoreNames.activityDrafts), isEmpty);
    final restored = await AppRepositoryRegistry.container.activity.findByDate(
      now,
    );
    expect(restored?.digestiveEvents?.single.amount, 0);
  });

  test('incomplete Event is rejected before either Store is changed', () async {
    final draft = ActivityDraft(
      localDate: '2026-07-28',
      measuredStepsInput: '5000',
      carryOverInput: '0',
      digestiveEvents: [
        ActivityDraftDigestiveEvent(
          id: 'digestive:2026-07-28:incomplete',
          sequence: 1,
          amount: 1,
          recordedAt: now,
        ),
      ],
      createdAt: now,
      updatedAt: now,
    );
    await IndexedDbActivityDraftRepository(
      database,
      now: () => now,
    ).save(draft);

    await expectLater(
      ActivityDraftFinalizeService(
        database,
        now: () => now,
      ).finalize(draft: draft),
      throwsA(
        isA<RepositoryException>().having(
          (error) => error.code,
          'code',
          RepositoryErrorCode.invalidRecord,
        ),
      ),
    );

    expect(
      await database.findAll(IndexedDbStoreNames.activityDrafts),
      hasLength(1),
    );
    expect(
      await database.findAll(IndexedDbStoreNames.activityRecords),
      isEmpty,
    );
  });

  test('Draft delete failure rolls back the formal record write', () async {
    final draft = _draft(now);
    await IndexedDbActivityDraftRepository(
      database,
      now: () => now,
    ).save(draft);
    final failingDatabase = _DeleteFailingDatabase(database);

    await expectLater(
      ActivityDraftFinalizeService(
        failingDatabase,
        now: () => now,
      ).finalize(draft: draft),
      throwsA(isA<RepositoryException>()),
    );

    expect(
      await database.findAll(IndexedDbStoreNames.activityDrafts),
      hasLength(1),
    );
    expect(
      await database.findAll(IndexedDbStoreNames.activityRecords),
      isEmpty,
    );
  });

  test(
    'same-date formal Record conflict preserves both existing data and Draft',
    () async {
      final draft = _draft(now);
      await IndexedDbActivityDraftRepository(
        database,
        now: () => now,
      ).save(draft);
      await AppRepositoryRegistry.container.activity.save(
        ActivityData(date: now, measuredSteps: 1234),
      );

      await expectLater(
        ActivityDraftFinalizeService(
          database,
          now: () => now.add(const Duration(minutes: 1)),
        ).finalize(draft: draft),
        throwsA(isA<RepositoryException>()),
      );

      expect(
        (await AppRepositoryRegistry.container.activity.findByDate(
          now,
        ))?.measuredSteps,
        1234,
      );
      expect(
        await database.findAll(IndexedDbStoreNames.activityDrafts),
        hasLength(1),
      );
    },
  );

  test('rejects finalization when the persisted Draft is missing', () async {
    final draft = _draft(now);
    await expectLater(
      ActivityDraftFinalizeService(database).finalize(draft: draft),
      throwsA(isA<RepositoryException>()),
    );
  });
}

ActivityDraft _draft(DateTime now) => ActivityDraft(
  localDate: '2026-07-28',
  measuredStepsInput: '5000',
  carryOverInput: '200',
  digestiveEvents: [
    ActivityDraftDigestiveEvent(
      id: 'digestive:2026-07-28:1',
      sequence: 1,
      amount: 2,
      shape: 2,
      relief: 2,
      recordedAt: now,
    ),
  ],
  createdAt: now,
  updatedAt: now,
);

class _DeleteFailingDatabase implements IndexedDbDatabase {
  final IndexedDbDatabase delegate;

  const _DeleteFailingDatabase(this.delegate);

  @override
  int get schemaVersion => delegate.schemaVersion;

  @override
  Future<void> clear(String storeName) => delegate.clear(storeName);

  @override
  Future<void> deleteById(String storeName, String id) =>
      delegate.deleteById(storeName, id);

  @override
  Future<List<Map<String, Object?>>> findAll(String storeName) =>
      delegate.findAll(storeName);

  @override
  Future<Map<String, Object?>?> findById(String storeName, String id) =>
      delegate.findById(storeName, id);

  @override
  Future<void> put(String storeName, Map<String, Object?> record) =>
      delegate.put(storeName, record);

  @override
  Future<T> runTransaction<T>({
    required Iterable<String> storeNames,
    required IndexedDbTransactionMode mode,
    required Future<T> Function(IndexedDbTransaction transaction) action,
  }) {
    return delegate.runTransaction(
      storeNames: storeNames,
      mode: mode,
      action: (transaction) => action(_DeleteFailingTransaction(transaction)),
    );
  }
}

class _DeleteFailingTransaction implements IndexedDbTransaction {
  final IndexedDbTransaction delegate;

  const _DeleteFailingTransaction(this.delegate);

  @override
  Future<void> clear(String storeName) => delegate.clear(storeName);

  @override
  Future<void> deleteById(String storeName, String id) {
    if (storeName == IndexedDbStoreNames.activityDrafts) {
      throw StateError('Draft delete failed');
    }
    return delegate.deleteById(storeName, id);
  }

  @override
  Future<List<Map<String, Object?>>> findAll(String storeName) =>
      delegate.findAll(storeName);

  @override
  Future<Map<String, Object?>?> findById(String storeName, String id) =>
      delegate.findById(storeName, id);

  @override
  Future<void> put(String storeName, Map<String, Object?> record) =>
      delegate.put(storeName, record);
}
