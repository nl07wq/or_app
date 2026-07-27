import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/services/startup_initialization_service.dart';
import 'package:or_app/core/state/app_initialization_state.dart';
import 'package:or_app/data/indexed_db/indexed_db_store_names.dart';
import 'package:or_app/features/activity/models/activity_draft.dart';
import 'package:or_app/features/activity/repository/indexed_db_activity_draft_repository.dart';
import 'package:or_app/features/repositories/app_repository_container.dart';
import 'package:or_app/features/repositories/repository_exception.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../repositories/indexed_db/fake_indexed_db_database.dart';

void main() {
  late FakeIndexedDbDatabase database;
  late IndexedDbActivityDraftRepository repository;
  final createdAt = DateTime.utc(2026, 7, 27, 8);
  final savedAt = DateTime.utc(2026, 7, 27, 9);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppRepositoryRegistry.resetForTesting();
    database = FakeIndexedDbDatabase();
    repository = IndexedDbActivityDraftRepository(database, now: () => savedAt);
  });

  tearDown(AppRepositoryRegistry.resetForTesting);

  ActivityDraft draft(
    String localDate, {
    String steps = '',
    List<ActivityDraftDigestiveEvent> events = const [],
  }) {
    return ActivityDraft(
      localDate: localDate,
      measuredStepsInput: steps,
      carryOverInput: '0',
      digestiveEvents: events,
      createdAt: createdAt,
      updatedAt: createdAt,
    );
  }

  test('saves and restores incomplete Draft input defensively', () async {
    final sourceEvents = <ActivityDraftDigestiveEvent>[
      ActivityDraftDigestiveEvent(
        id: 'event-1',
        sequence: 1,
        amount: 2,
        recordedAt: createdAt,
      ),
    ];
    await repository.save(
      draft('2026-07-27', steps: '12x', events: sourceEvents),
    );
    sourceEvents.clear();

    final restored = await repository.findByDate(DateTime(2026, 7, 27));
    expect(restored, isNotNull);
    expect(restored!.id, 'activity-draft:2026-07-27');
    expect(restored.measuredStepsInput, '12x');
    expect(restored.digestiveEvents.single.amount, 2);
    expect(restored.digestiveEvents.single.shape, isNull);
    expect(restored.digestiveEvents.single.relief, isNull);
    expect(restored.createdAt, createdAt);
    expect(restored.updatedAt, savedAt);
    expect(
      () => restored.digestiveEvents.add(
        ActivityDraftDigestiveEvent(
          id: 'event-2',
          sequence: 2,
          recordedAt: createdAt,
        ),
      ),
      throwsUnsupportedError,
    );
  });

  test('overwrites the same date while preserving createdAt', () async {
    await repository.save(draft('2026-07-27', steps: '100'));
    final laterRepository = IndexedDbActivityDraftRepository(
      database,
      now: () => savedAt.add(const Duration(hours: 1)),
    );
    await laterRepository.save(draft('2026-07-27', steps: '200'));

    final restored = await laterRepository.findById(
      'activity-draft:2026-07-27',
    );
    expect(restored!.measuredStepsInput, '200');
    expect(restored.createdAt, createdAt);
    expect(restored.updatedAt, savedAt.add(const Duration(hours: 1)));
    expect(
      await database.findAll(IndexedDbStoreNames.activityDrafts),
      hasLength(1),
    );
  });

  test('findAll is immutable, ordered, and survives recreation', () async {
    await repository.save(draft('2026-07-26'));
    await repository.save(draft('2026-07-27'));

    final recreated = IndexedDbActivityDraftRepository(database);
    final values = await recreated.findAll();
    expect(values.map((value) => value.localDate), [
      '2026-07-27',
      '2026-07-26',
    ]);
    expect(() => values.clear(), throwsUnsupportedError);
  });

  test('delete by ID, delete by date, and clear are idempotent', () async {
    await repository.save(draft('2026-07-25'));
    await repository.save(draft('2026-07-26'));
    await repository.deleteById('activity-draft:missing');
    await repository.deleteByDate(DateTime(2026, 7, 25));
    expect(await repository.findAll(), hasLength(1));

    await repository.clear();
    expect(await repository.findAll(), isEmpty);
  });

  test(
    'invalid stored record is reported and not converted to empty',
    () async {
      database.seed(IndexedDbStoreNames.activityDrafts, 'broken', {
        'id': 'broken',
      });

      await expectLater(
        repository.findAll(),
        throwsA(
          isA<RepositoryException>().having(
            (error) => error.code,
            'code',
            RepositoryErrorCode.invalidRecord,
          ),
        ),
      );
    },
  );

  test('invalid Digestive Event JSON is rejected', () async {
    database.seed(
      IndexedDbStoreNames.activityDrafts,
      'activity-draft:2026-07-27',
      {
        ...draft('2026-07-27').toRecord(),
        'digestiveEvents': ['not-an-object'],
      },
    );

    await expectLater(
      repository.findAll(),
      throwsA(
        isA<RepositoryException>().having(
          (error) => error.code,
          'code',
          RepositoryErrorCode.invalidRecord,
        ),
      ),
    );
  });

  test('unique localDate rejects a second Draft ID', () async {
    database.seed(IndexedDbStoreNames.activityDrafts, 'other-draft-id', {
      ...draft('2026-07-27').toRecord(),
      'id': 'other-draft-id',
    });

    await expectLater(
      repository.save(draft('2026-07-27')),
      throwsA(
        isA<RepositoryException>().having(
          (error) => error.code,
          'code',
          RepositoryErrorCode.transactionFailed,
        ),
      ),
    );
  });

  test('transaction failure rolls back Draft save', () async {
    database.failNextTransactionWith = StateError('write failed');

    await expectLater(
      repository.save(draft('2026-07-27')),
      throwsA(
        isA<RepositoryException>().having(
          (error) => error.code,
          'code',
          RepositoryErrorCode.transactionFailed,
        ),
      ),
    );
    expect(await repository.findAll(), isEmpty);
  });

  test('Startup accepts an empty Activity Draft Store', () async {
    final controller = await _initialize(database);

    expect(controller.value.mode, PersistenceMode.indexedDbReadWrite);
    expect(
      await AppRepositoryRegistry.container.activityDrafts.findAll(),
      isEmpty,
    );
  });

  test('Startup accepts and restores a valid Activity Draft', () async {
    final value = draft('2026-07-27', steps: '3456');
    database.seed(
      IndexedDbStoreNames.activityDrafts,
      value.id,
      value.toRecord(),
    );

    final controller = await _initialize(database);

    expect(controller.value.mode, PersistenceMode.indexedDbReadWrite);
    expect(
      (await AppRepositoryRegistry.container.activityDrafts.findAll())
          .single
          .measuredStepsInput,
      '3456',
    );
  });

  test('Startup fails when an Activity Draft is corrupted', () async {
    database.seed(IndexedDbStoreNames.activityDrafts, 'broken', {
      'id': 'broken',
    });

    final controller = await _initialize(database);

    expect(controller.value.mode, PersistenceMode.failed);
    expect(controller.value.errorCode, RepositoryErrorCode.invalidRecord.name);
    expect(AppRepositoryRegistry.hasContainer, isFalse);
  });

  test('rejects Shape values outside the formal 1 to 3 range', () {
    expect(
      () => ActivityDraftDigestiveEvent(
        id: 'digestive:2026-07-27:1',
        sequence: 1,
        amount: 2,
        shape: 4,
        relief: 1,
        recordedAt: DateTime.utc(2026, 7, 27, 8),
      ),
      throwsArgumentError,
    );
  });
}

Future<AppInitializationController> _initialize(
  FakeIndexedDbDatabase database,
) async {
  final controller = AppInitializationController();
  await StartupInitializationService(
    controller: controller,
    openDatabase: () async => database,
    restore: () async {},
    isWeb: true,
    delay: (_) async {},
  ).initialize();
  return controller;
}
