import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/models/activity_data.dart';
import 'package:or_app/core/models/cardio_entry.dart';
import 'package:or_app/core/models/cardio_entry_v2.dart';
import 'package:or_app/core/models/daily_log_confirmation.dart';
import 'package:or_app/core/models/meal_data.dart';
import 'package:or_app/core/models/morning_data.dart';
import 'package:or_app/core/models/training_session.dart';
import 'package:or_app/core/models/training_session_v2.dart';
import 'package:or_app/core/models/work_type.dart';
import 'package:or_app/core/repositories/daily_log_confirmation_repository.dart';
import 'package:or_app/core/repositories/food_repository.dart';
import 'package:or_app/core/repositories/morning_repository.dart';
import 'package:or_app/core/repositories/training_repository.dart';
import 'package:or_app/core/services/startup_initialization_service.dart';
import 'package:or_app/core/state/app_initialization_state.dart';
import 'package:or_app/core/widgets/startup_gate.dart';
import 'package:or_app/data/indexed_db/indexed_db_migration_metadata.dart';
import 'package:or_app/data/indexed_db/indexed_db_store_names.dart';
import 'package:or_app/features/activity/repository/activity_repository.dart';
import 'package:or_app/features/repositories/app_repository_container.dart';
import 'package:or_app/features/repositories/repository_exception.dart';
import 'package:or_app/features/operation_date/models/operation_active_attempt.dart';
import 'package:or_app/features/operation_date/models/operation_local_date.dart';
import 'package:or_app/features/operation_date/models/operation_state.dart';
import 'package:or_app/features/status/migration/status_migration_service.dart';
import 'package:or_app/features/training/models/persisted_training_record.dart';
import 'package:or_app/features/training/migration/legacy_trainings_migration_service.dart';
import 'package:or_app/features/training/migration/training_record_lineage.dart';
import 'package:or_app/features/training/migration/training_record_shadow_migration_service.dart';
import 'package:or_app/features/training/migration/training_v2_migration_mapper.dart';
import 'package:or_app/features/training/services/exercise_catalog_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../repositories/indexed_db/fake_indexed_db_database.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppRepositoryRegistry.resetForTesting();
  });

  tearDown(AppRepositoryRegistry.resetForTesting);

  test(
    'runs all migrations in order and becomes ready after restore',
    () async {
      SharedPreferences.setMockInitialValues({'unrelated': 'keep'});
      final database = FakeIndexedDbDatabase();
      final controller = AppInitializationController();
      final stages = <InitializationStage>[];
      controller.addListener(() => stages.add(controller.value.currentStage));
      var restored = false;
      final service = StartupInitializationService(
        controller: controller,
        openDatabase: () async => database,
        restore: () async => restored = true,
        isWeb: true,
      );

      await service.initialize();

      expect(controller.value.mode, PersistenceMode.indexedDbReadWrite);
      expect(restored, isTrue);
      expect(stages.where((stage) => stage.name.startsWith('migrating')), [
        InitializationStage.migratingStatus,
        InitializationStage.migratingActivity,
        InitializationStage.migratingFood,
        InitializationStage.migratingTraining,
        InitializationStage.migratingTraining,
        InitializationStage.migratingTraining,
        InitializationStage.migratingCustomTrainingExercises,
        InitializationStage.migratingConfirmation,
      ]);
      final metadata = await database.findAll(
        IndexedDbStoreNames.migrationMetadata,
      );
      expect(metadata, hasLength(8));
      expect(
        (await SharedPreferences.getInstance()).getString('unrelated'),
        'keep',
      );
      expect(
        metadata.map(IndexedDbMigrationMetadata.fromRecord),
        everyElement(
          isA<IndexedDbMigrationMetadata>().having(
            (value) => value.status,
            'status',
            IndexedDbMigrationStatus.completed,
          ),
        ),
      );
      final operationState = await AppRepositoryRegistry
          .container
          .operationState
          .requireCurrent();
      expect(operationState.id, OperationState.canonicalId);
      expect(operationState.phase, OperationPhase.open);
      expect(controller.value.operationRecoveryRequired, isFalse);

      await MorningRepository.save(_morning());
      expect((await MorningRepository.getAll()).single.weight, 70);

      final first = await TrainingRepository.saveNewV2(_trainingV2('first'));
      final second = await TrainingRepository.saveNewV2(_trainingV2('second'));
      expect(first.id, isNot(second.id));
      expect(await TrainingRepository.getRecords(), hasLength(2));
      await TrainingRepository.updateV2ById(first.id, _trainingV2('updated'));
      expect(
        (await TrainingRepository.getRecords())
            .singleWhere((record) => record.id == first.id)
            .session
            .memo,
        'updated',
      );
      await TrainingRepository.deleteById(second.id);
      expect(await TrainingRepository.getRecords(), hasLength(1));
    },
  );

  test(
    'startup preserves in-flight operation state and reports recovery',
    () async {
      final database = FakeIndexedDbDatabase();
      final date = OperationLocalDate.parse('2026-07-31');
      final timestamp = DateTime.utc(2026, 7, 31, 1);
      database.seed(
        IndexedDbStoreNames.operationState,
        OperationState.canonicalId,
        OperationState(
          operationDate: date,
          phase: OperationPhase.finalizing,
          activeAttempt: OperationActiveAttempt(
            idempotencyKey: 'attempt-1',
            targetLocalDate: date,
            startedAt: timestamp,
          ),
          createdAt: timestamp,
          updatedAt: timestamp,
        ).toRecord(),
      );
      final controller = AppInitializationController();

      await StartupInitializationService(
        controller: controller,
        openDatabase: () async => database,
        restore: () async {},
        isWeb: true,
      ).initialize();

      expect(controller.value.mode, PersistenceMode.indexedDbReadWrite);
      expect(controller.value.operationRecoveryRequired, isTrue);
      expect(controller.value.operationPhase, OperationPhase.finalizing.name);
      expect(
        (await AppRepositoryRegistry.container.operationState.requireCurrent())
            .phase,
        OperationPhase.finalizing,
      );
    },
  );

  test('startup fails instead of repairing corrupt operation state', () async {
    final database = FakeIndexedDbDatabase();
    database.seed(IndexedDbStoreNames.operationState, 'wrong', {
      'id': 'wrong',
      'recordVersion': 1,
      'operationDate': '2026-07-31',
      'phase': 'open',
      'revision': 0,
      'lastFinalizedDate': null,
      'activeAttempt': null,
      'createdAt': '2026-07-31T00:00:00.000Z',
      'updatedAt': '2026-07-31T00:00:00.000Z',
    });
    final controller = AppInitializationController();

    await StartupInitializationService(
      controller: controller,
      openDatabase: () async => database,
      restore: () async {},
      isWeb: true,
    ).initialize();

    expect(controller.value.mode, PersistenceMode.failed);
    expect(controller.value.errorCode, RepositoryErrorCode.invalidRecord.name);
    expect(AppRepositoryRegistry.hasContainer, isFalse);
    expect(
      await database.findById(IndexedDbStoreNames.operationState, 'wrong'),
      isNotNull,
    );
  });

  test(
    'startup does not fall back to device date for corrupt confirmation',
    () async {
      final database = FakeIndexedDbDatabase();
      database.seed(
        IndexedDbStoreNames.dailyLogConfirmations,
        'confirmation:broken',
        {
          'id': 'confirmation:broken',
          'recordVersion': 1,
          'snapshotVersion': 1,
          'localDate': 'broken',
          'createdAt': '2026-07-31T00:00:00.000Z',
          'updatedAt': '2026-07-31T00:00:00.000Z',
          'data': <String, Object?>{},
        },
      );
      final controller = AppInitializationController();

      await StartupInitializationService(
        controller: controller,
        openDatabase: () async => database,
        restore: () async {},
        isWeb: true,
      ).initialize();

      expect(controller.value.mode, PersistenceMode.failed);
      expect(
        await database.findAll(IndexedDbStoreNames.operationState),
        isEmpty,
      );
      expect(AppRepositoryRegistry.hasContainer, isFalse);
    },
  );

  test('completed startup accepts a mixed v1 and v2 training store', () async {
    final database = FakeIndexedDbDatabase();
    final firstController = AppInitializationController();
    await StartupInitializationService(
      controller: firstController,
      openDatabase: () async => database,
      restore: () async {},
      isWeb: true,
    ).initialize();
    expect(firstController.value.mode, PersistenceMode.indexedDbReadWrite);

    await database.put(
      IndexedDbStoreNames.trainingRecords,
      PersistedTrainingRecord.v2(
        id: 'training:00112233-4455-4677-8899-aabbccddeeff',
        localDate: '2026-07-30',
        createdAt: DateTime.utc(2026, 7, 30, 9),
        updatedAt: DateTime.utc(2026, 7, 30, 10),
        data: TrainingSessionV2(
          date: '2026-07-30T18:00:00+09:00',
          sessionName: 'Read only',
        ),
      ).toRecord(),
    );

    final secondController = AppInitializationController();
    await StartupInitializationService(
      controller: secondController,
      openDatabase: () async => database,
      restore: () async {},
      isWeb: true,
    ).initialize();

    expect(secondController.value.mode, PersistenceMode.indexedDbReadWrite);
    expect(
      (await AppRepositoryRegistry.container.training.findAll())
          .single
          .recordVersion,
      2,
    );
  });

  test(
    'v2 facade snapshots same-date STATUS weight on save and edit',
    () async {
      final database = FakeIndexedDbDatabase();
      final controller = AppInitializationController();
      await StartupInitializationService(
        controller: controller,
        openDatabase: () async => database,
        restore: () async {},
        isWeb: true,
      ).initialize();
      await MorningRepository.save(_morningOn('2026-07-30', weight: 96.8));

      final saved = await TrainingRepository.saveNewV2(
        _trainingV2WithCardio(mets: 4, durationSeconds: 300),
      );
      final first = (await TrainingRepository.getReadModels())
          .singleWhere((record) => record.id == saved.id)
          .v2Data!
          .cardioEntries
          .single;
      expect(first.weightSnapshotKg, 96.8);
      expect(first.estimatedCaloriesKcal, closeTo(33.88, 1e-12));
      expect(first.calculationMethod, 'metsAcsmV1');
      expect(first.calculationVersion, 1);

      await MorningRepository.update(_morningOn('2026-07-30', weight: 120));
      await TrainingRepository.updateV2ById(
        saved.id,
        _trainingV2WithCardio(
          mets: 5,
          durationSeconds: 300,
          weightSnapshotKg: first.weightSnapshotKg,
        ),
      );
      final updated = (await TrainingRepository.getReadModels())
          .singleWhere((record) => record.id == saved.id)
          .v2Data!
          .cardioEntries
          .single;
      expect(updated.weightSnapshotKg, 96.8);
      expect(updated.estimatedCaloriesKcal, closeTo(42.35, 1e-12));

      await AppRepositoryRegistry.container.status.deleteByLocalDate(
        '2026-07-30',
      );
      final uncomputedRecord = await TrainingRepository.saveNewV2(
        _trainingV2WithCardio(mets: 4, durationSeconds: 300),
      );
      final uncomputed = (await TrainingRepository.getReadModels())
          .singleWhere((record) => record.id == uncomputedRecord.id)
          .v2Data!
          .cardioEntries
          .single;
      expect(uncomputed.mets, 4);
      expect(uncomputed.durationSeconds, 300);
      expect(uncomputed.weightSnapshotKg, isNull);
      expect(uncomputed.estimatedCaloriesKcal, isNull);
      expect(uncomputed.calculationMethod, isNull);
      expect(uncomputed.calculationVersion, isNull);
    },
  );

  for (final variant in ['unknown version', 'invalid v2']) {
    test('startup rejects a training record with $variant', () async {
      final database = FakeIndexedDbDatabase();
      await StartupInitializationService(
        controller: AppInitializationController(),
        openDatabase: () async => database,
        restore: () async {},
        isWeb: true,
      ).initialize();
      final persisted = PersistedTrainingRecord.v2(
        id: 'training:00112233-4455-4677-8899-aabbccddeeff',
        localDate: '2026-07-30',
        createdAt: DateTime.utc(2026, 7, 30, 9),
        updatedAt: DateTime.utc(2026, 7, 30, 10),
        data: TrainingSessionV2(date: '2026-07-30'),
      ).toRecord();
      if (variant == 'unknown version') {
        persisted['recordVersion'] = 99;
      } else {
        persisted['data'] = {
          ...Map<String, Object?>.from(persisted['data']! as Map),
          'cardioEntries': 'bad',
        };
      }
      await database.put(IndexedDbStoreNames.trainingRecords, persisted);
      final controller = AppInitializationController();

      await StartupInitializationService(
        controller: controller,
        openDatabase: () async => database,
        restore: () async {},
        isWeb: true,
      ).initialize();

      expect(controller.value.mode, PersistenceMode.failed);
      expect(controller.value.errorCode, 'partialCorruption');
    });
  }

  test('does not expose ready when database open fails', () async {
    final controller = AppInitializationController();
    final service = StartupInitializationService(
      controller: controller,
      openDatabase: () async => throw StateError('open failed'),
      restore: () async {},
      isWeb: true,
    );

    await service.initialize();

    expect(controller.value.mode, PersistenceMode.failed);
    expect(controller.value.errorCode, 'databaseOpenFailed');
    expect(AppRepositoryRegistry.hasContainer, isFalse);
  });

  test('retry can complete after an initial open failure', () async {
    final controller = AppInitializationController();
    final database = FakeIndexedDbDatabase();
    var attempts = 0;
    final service = StartupInitializationService(
      controller: controller,
      openDatabase: () async {
        attempts++;
        if (attempts == 1) throw StateError('open failed');
        return database;
      },
      restore: () async {},
      isWeb: true,
    );

    await service.initialize();
    expect(controller.value.mode, PersistenceMode.failed);

    await service.retry();

    expect(controller.value.mode, PersistenceMode.indexedDbReadWrite);
    expect(attempts, 2);
  });

  test(
    'restore failure never exposes ready or an IndexedDB container',
    () async {
      final controller = AppInitializationController();
      final service = StartupInitializationService(
        controller: controller,
        openDatabase: () async => FakeIndexedDbDatabase(),
        restore: () async => throw StateError('restore failed'),
        isWeb: true,
      );

      await service.initialize();

      expect(controller.value.mode, PersistenceMode.failed);
      expect(controller.value.errorCode, 'verificationFailed');
      expect(
        controller.value.currentStage,
        InitializationStage.restoringDailyState,
      );
      expect(AppRepositoryRegistry.hasContainer, isFalse);
    },
  );

  test('migration failure does not install production repositories', () async {
    final database = FakeIndexedDbDatabase()..failOnTransactionNumber = 1;
    final controller = AppInitializationController();
    final service = StartupInitializationService(
      controller: controller,
      openDatabase: () async => database,
      restore: () async {},
      isWeb: true,
    );

    await service.initialize();

    expect(controller.value.mode, PersistenceMode.failed);
    expect(controller.value.errorCode, 'migrationFailed');
    expect(
      controller.value.failedMigrationId,
      StatusMigrationService.migrationId,
    );
    expect(AppRepositoryRegistry.hasContainer, isFalse);
  });

  test(
    'shadow migration failure prevents legacy trainings migration',
    () async {
      final database = FakeIndexedDbDatabase();
      const sourceId = 'training:00112233-4455-4677-8899-aabbccddeeff';
      final timestamp = DateTime.utc(2026, 7, 26);
      final source = PersistedTrainingRecord(
        id: sourceId,
        localDate: '2026-07-26',
        createdAt: timestamp,
        updatedAt: timestamp,
        data: _training('source'),
      );
      final targetId = TrainingRecordLineage.shadowIdForV1(sourceId);
      final conflict = TrainingV2MigrationMapper.map(
        targetId: targetId,
        localDate: source.localDate,
        createdAt: timestamp,
        updatedAt: timestamp,
        migrationSource: TrainingRecordLineage.shadowSource(
          sourceRecordId: sourceId,
          sourceIndex: 0,
        ),
        source: _training('different'),
      );
      database.seed(
        IndexedDbStoreNames.trainingRecords,
        sourceId,
        source.toRecord(),
      );
      database.seed(
        IndexedDbStoreNames.trainingRecords,
        targetId,
        conflict.toRecord(),
      );
      database.seed(IndexedDbStoreNames.trainings, 'old', {
        'id': 'old',
        'data': _training('legacy store').toJson(),
      });
      final controller = AppInitializationController();

      await StartupInitializationService(
        controller: controller,
        openDatabase: () async => database,
        restore: () async {},
        isWeb: true,
      ).initialize();

      expect(controller.value.mode, PersistenceMode.failed);
      expect(
        controller.value.failedMigrationId,
        TrainingRecordShadowMigrationService.migrationId,
      );
      expect(
        await database.findById(
          IndexedDbStoreNames.migrationMetadata,
          LegacyTrainingsMigrationService.migrationId,
        ),
        isNull,
      );
      expect(
        await database.findById(IndexedDbStoreNames.trainings, 'old'),
        isNotNull,
      );
    },
  );

  test(
    'completed migrations are verified without increasing attempts',
    () async {
      final database = FakeIndexedDbDatabase();
      final first = StartupInitializationService(
        controller: AppInitializationController(),
        openDatabase: () async => database,
        restore: () async {},
        isWeb: true,
      );
      await first.initialize();
      final attemptsBefore = await _migrationAttempts(database);

      AppRepositoryRegistry.resetForTesting();
      final secondController = AppInitializationController();
      final second = StartupInitializationService(
        controller: secondController,
        openDatabase: () async => database,
        restore: () async {},
        isWeb: true,
      );
      await second.initialize();

      expect(secondController.value.mode, PersistenceMode.indexedDbReadWrite);
      expect(await _migrationAttempts(database), attemptsBefore);
    },
  );

  test(
    'active migration lease waits and rechecks completed metadata',
    () async {
      final database = FakeIndexedDbDatabase();
      final now = DateTime.now().toUtc();
      final active = IndexedDbMigrationMetadata(
        id: StatusMigrationService.migrationId,
        status: IndexedDbMigrationStatus.validating,
        source: 'shared_preferences',
        targetDatabaseVersion: 3,
        attempt: 1,
        startedAt: now,
        updatedAt: now,
        ownerId: 'other-tab',
        leaseExpiresAt: now.add(const Duration(minutes: 5)),
        expectedRecordIds: const {
          IndexedDbStoreNames.statusRecords: [],
          IndexedDbStoreNames.migrationQuarantine: [],
        },
        sourceDigest: '811c9dc5',
      );
      await database.put(
        IndexedDbStoreNames.migrationMetadata,
        active.toRecord(),
      );
      var waits = 0;
      final controller = AppInitializationController();
      final service = StartupInitializationService(
        controller: controller,
        openDatabase: () async => database,
        restore: () async {},
        isWeb: true,
        delay: (_) async {
          waits++;
          final completedAt = DateTime.now().toUtc();
          await database.put(
            IndexedDbStoreNames.migrationMetadata,
            active
                .copyWith(
                  status: IndexedDbMigrationStatus.completed,
                  updatedAt: completedAt,
                  completedAt: completedAt,
                  ownerId: null,
                  leaseExpiresAt: null,
                )
                .toRecord(),
          );
        },
      );

      await service.initialize();

      expect(waits, 1);
      expect(controller.value.mode, PersistenceMode.indexedDbReadWrite);
    },
  );

  test(
    'production facades and custom catalog persist only to IndexedDB',
    () async {
      final legacyValues = <String, Object>{
        'morning_records': <String>[],
        'meal_records': <String>[],
        'training_sessions': <String>[],
        'training_custom_exercises': <String>[],
        'activity_records': <String>[],
        'daily_log_confirmations': <String>[],
        'unrelated': 'keep',
      };
      SharedPreferences.setMockInitialValues(legacyValues);
      final database = FakeIndexedDbDatabase();
      final controller = AppInitializationController();
      final service = StartupInitializationService(
        controller: controller,
        openDatabase: () async => database,
        restore: () async {},
        isWeb: true,
      );
      await service.initialize();

      final morning = _morning();
      final meal = _meal();
      final activity = _activity();
      final training = _trainingV2('indexed');
      final confirmation = _confirmation();
      await MorningRepository.save(morning);
      await FoodRepository.save(meal);
      await const LocalActivityRepository().save(activity);
      final trainingRecord = await TrainingRepository.saveNewV2(training);
      await DailyLogConfirmationRepository.save(confirmation);
      await ExerciseCatalogService.registerCustom('Custom Press');

      AppRepositoryRegistry.install(AppRepositoryContainer.indexedDb(database));
      expect((await MorningRepository.getAll()).single.date, morning.date);
      expect((await FoodRepository.getAll()).single.id, meal.id);
      expect(
        (await const LocalActivityRepository().getAll()).single.id,
        activity.id,
      );
      expect(
        (await TrainingRepository.getRecords()).single.id,
        trainingRecord.id,
      );
      expect(
        (await DailyLogConfirmationRepository.getAll()).single.date,
        confirmation.date,
      );
      expect(
        (await AppRepositoryRegistry.container.customTrainingExercises
                .findAll())
            .single
            .name,
        'Custom Press',
      );
      expect(
        (await ExerciseCatalogService.load()).all,
        contains('Custom Press'),
      );

      final preferences = await SharedPreferences.getInstance();
      for (final key in legacyValues.keys) {
        expect(preferences.get(key), legacyValues[key], reason: key);
      }
    },
  );

  test('initializing, failed, and read-only modes reject all writes', () async {
    final controller = AppInitializationController();
    AppRepositoryRegistry.beginStartup(controller: controller);

    for (final mode in [
      PersistenceMode.initializing,
      PersistenceMode.maintenance,
      PersistenceMode.failed,
      PersistenceMode.legacyReadOnly,
    ]) {
      switch (mode) {
        case PersistenceMode.initializing:
          controller.updateStage(InitializationStage.openingDatabase);
        case PersistenceMode.failed:
          controller.markFailed(
            errorCode: 'testFailure',
            errorMessage: 'failure',
          );
        case PersistenceMode.legacyReadOnly:
          controller.markLegacyReadOnly();
        case PersistenceMode.maintenance:
          controller.markMaintenance();
        case PersistenceMode.indexedDbReadWrite:
          fail('ready is not a rejection mode');
      }

      await _expectAllWritesRejected();
    }
  });

  test('native startup restores legacy data in read-only mode', () async {
    final controller = AppInitializationController();
    var opened = false;
    var restored = false;
    final service = StartupInitializationService(
      controller: controller,
      openDatabase: () async {
        opened = true;
        return FakeIndexedDbDatabase();
      },
      restore: () async => restored = true,
      isWeb: false,
    );

    await service.initialize();

    expect(opened, isFalse);
    expect(restored, isTrue);
    expect(controller.value.mode, PersistenceMode.legacyReadOnly);
    expect(() => MorningRepository.save(_morning()), throwsA(anything));
  });

  test(
    'native read-only returns valid legacy records without mutation',
    () async {
      final morning = _morning();
      final meal = _meal();
      final activity = _activity();
      final training = _training('legacy');
      final confirmation = _confirmation();
      final initial = <String, Object>{
        'morning_records': <String>[jsonEncode(morning.toJson())],
        'meal_records': <String>[jsonEncode(meal.toJson())],
        'activity_records': <String>[jsonEncode(activity.toJson())],
        'training_sessions': <String>[jsonEncode(training.toJson())],
        'training_custom_exercises': <String>['Legacy Custom Press'],
        'daily_log_confirmations': <String>[jsonEncode(confirmation.toJson())],
      };
      SharedPreferences.setMockInitialValues(initial);
      final service = StartupInitializationService(
        controller: AppInitializationController(),
        restore: () async {},
        isWeb: false,
      );

      await service.initialize();

      expect((await MorningRepository.getAll()).single.date, morning.date);
      expect((await FoodRepository.getAll()).single.id, meal.id);
      expect(
        (await const LocalActivityRepository().getAll()).single.id,
        activity.id,
      );
      expect((await TrainingRepository.getAll()).single.memo, training.memo);
      expect(
        (await ExerciseCatalogService.load()).all,
        contains('Legacy Custom Press'),
      );
      expect(
        (await DailyLogConfirmationRepository.getAll()).single.date,
        confirmation.date,
      );
      final preferences = await SharedPreferences.getInstance();
      for (final entry in initial.entries) {
        expect(preferences.get(entry.key), entry.value, reason: entry.key);
      }
    },
  );

  test(
    'legacy read-only distinguishes corrupt records from no records',
    () async {
      SharedPreferences.setMockInitialValues({
        'morning_records': <String>[
          jsonEncode(_morning().toJson()),
          '{invalid json',
        ],
      });
      final controller = AppInitializationController();
      final service = StartupInitializationService(
        controller: controller,
        restore: () async {},
        isWeb: false,
      );

      await service.initialize();

      expect(controller.value.mode, PersistenceMode.legacyReadOnly);
      expect(controller.value.errorMessage, contains('1 legacy record'));
      expect(await MorningRepository.getAll(), hasLength(1));
    },
  );

  testWidgets('gate hides application until initialization is ready', (
    tester,
  ) async {
    final controller = AppInitializationController();
    final service = StartupInitializationService(
      controller: controller,
      openDatabase: () async => Completer<FakeIndexedDbDatabase>().future,
      restore: () async {},
      isWeb: true,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: StartupGate(
          service: service,
          child: const Text('DASHBOARD CONTENT'),
        ),
      ),
    );

    expect(find.text('INITIALIZING'), findsOneWidget);
    expect(find.text('DASHBOARD CONTENT'), findsNothing);

    controller.markReady();
    await tester.pump();

    expect(find.text('DASHBOARD CONTENT'), findsOneWidget);
  });

  testWidgets('legacy read-only gate shows a persistent read-only notice', (
    tester,
  ) async {
    final controller = AppInitializationController()..markLegacyReadOnly();
    final service = StartupInitializationService(
      controller: controller,
      restore: () async {},
      isWeb: false,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: StartupGate(
          service: service,
          child: const Text('DASHBOARD CONTENT'),
        ),
      ),
    );

    expect(find.textContaining('READ ONLY'), findsOneWidget);
    expect(find.text('DASHBOARD CONTENT'), findsOneWidget);
  });
}

Future<Map<String, int>> _migrationAttempts(
  FakeIndexedDbDatabase database,
) async {
  return {
    for (final value in await database.findAll(
      IndexedDbStoreNames.migrationMetadata,
    ))
      value['id'] as String: value['attempt'] as int,
  };
}

Future<void> _expectAllWritesRejected() async {
  final operations = <Future<void> Function()>[
    () => MorningRepository.save(_morning()),
    () => FoodRepository.save(_meal()),
    () => const LocalActivityRepository().save(_activity()),
    () async {
      await TrainingRepository.saveNewV2(_trainingV2('rejected'));
    },
    () => DailyLogConfirmationRepository.save(_confirmation()),
    () => ExerciseCatalogService.registerCustom('Rejected Custom Exercise'),
  ];
  for (final operation in operations) {
    await expectLater(operation(), throwsA(anything));
  }
}

MorningData _morning() {
  return _morningOn('2026-07-26', weight: 70);
}

MorningData _morningOn(String localDate, {required double weight}) {
  return MorningData(
    date: '${localDate}T08:00:00',
    weight: weight,
    bodyFat: 20,
    sleepHours: 7,
    sleepScore: 80,
    footPain: 1,
    condition: 3,
    workType: WorkType.holiday,
    workStart: '',
    workEnd: '',
    workBreak: '',
    workHours: 0,
    memo: '',
  );
}

TrainingSession _training(String memo) {
  return TrainingSession(
    date: '2026-07-26T18:00:00',
    memo: memo,
    exercises: const [],
  );
}

TrainingSessionV2 _trainingV2(String memo) {
  return TrainingSessionV2(date: '2026-07-30T12:00:00', memo: memo);
}

TrainingSessionV2 _trainingV2WithCardio({
  required double mets,
  required int durationSeconds,
  double? weightSnapshotKg,
}) {
  return TrainingSessionV2(
    date: '2026-07-30T12:00:00',
    cardioEntries: [
      CardioEntryV2(
        purpose: CardioPurpose.main,
        type: CardioType.running,
        durationSeconds: durationSeconds,
        mets: mets,
        weightSnapshotKg: weightSnapshotKg,
      ),
    ],
  );
}

MealData _meal() {
  return const MealData(
    date: '2026-07-26T12:00:00',
    mealType: 'Lunch',
    items: [],
    memo: '',
    id: 'meal-1',
  );
}

ActivityData _activity() {
  return ActivityData(date: DateTime(2026, 7, 26), measuredSteps: 5000);
}

DailyLogConfirmation _confirmation() {
  return DailyLogConfirmation(
    date: DateTime(2026, 7, 26),
    confirmedAt: DateTime(2026, 7, 26, 23),
    morning: null,
    food: null,
    activity: null,
    training: null,
  );
}
