import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/engine/activity_summary.dart';
import 'package:or_app/core/engine/digestive_summary.dart';
import 'package:or_app/core/engine/training_summary.dart';
import 'package:or_app/core/models/cardio_entry.dart';
import 'package:or_app/core/models/cardio_entry_v2.dart';
import 'package:or_app/core/models/food_item.dart';
import 'package:or_app/core/models/activity_data.dart';
import 'package:or_app/core/models/digestive_event.dart';
import 'package:or_app/core/models/meal_data.dart';
import 'package:or_app/core/models/morning_data.dart';
import 'package:or_app/core/models/training_session.dart';
import 'package:or_app/core/models/training_session_v2.dart';
import 'package:or_app/core/models/work_type.dart';
import 'package:or_app/core/state/app_initialization_state.dart';
import 'package:or_app/data/indexed_db/indexed_db_schema.dart';
import 'package:or_app/data/indexed_db/indexed_db_store_names.dart';
import 'package:or_app/features/daily_log_confirmation/models/persisted_daily_log_confirmation_record.dart';
import 'package:or_app/features/activity/models/activity_draft.dart';
import 'package:or_app/features/activity/models/persisted_activity_record.dart';
import 'package:or_app/features/food/models/persisted_food_record.dart';
import 'package:or_app/features/import_export/models/backup_package.dart';
import 'package:or_app/features/import_export/services/backup_export_service.dart';
import 'package:or_app/features/import_export/services/backup_canonical_codec.dart';
import 'package:or_app/features/import_export/services/backup_import_service.dart';
import 'package:or_app/features/import_export/services/backup_package_codec.dart';
import 'package:or_app/features/operation_date/models/operation_local_date.dart';
import 'package:or_app/features/operation_date/models/operation_state.dart';
import 'package:or_app/features/training/models/custom_training_exercise.dart';
import 'package:or_app/features/training/models/persisted_custom_training_exercise_record.dart';
import 'package:or_app/features/training/models/persisted_training_record.dart';
import 'package:or_app/features/training/migration/training_record_lineage.dart';
import 'package:or_app/features/training/migration/training_v2_migration_mapper.dart';
import 'package:or_app/features/training/repository/indexed_db_training_repository.dart';

import '../../repositories/indexed_db/fake_indexed_db_database.dart';
import '../daily_log_confirmation/daily_log_confirmation_test_fixture.dart';
import '../operation_date/operation_date_test_fixture.dart';

void main() {
  late FakeIndexedDbDatabase database;
  late AppInitializationController controller;

  setUp(() {
    database = FakeIndexedDbDatabase();
    controller = AppInitializationController()..markReady();
    seedOperationState(database, '2026-08-01');
  });

  test(
    'exports deterministic Schema 8.0 package with all fifteen sections',
    () async {
      final package = await BackupExportService(
        database: database,
        controller: controller,
        clock: () => DateTime.utc(2026, 7, 26, 12),
      ).create(origin: 'https://example.test');

      expect(package.schema, BackupPackage.schemaName);
      expect(package.schemaVersion, 8);
      expect(package.databaseVersion, IndexedDbSchema.databaseVersion);
      expect(package.data.keys, containsAll(BackupSections.all));
      expect(package.data[BackupSections.operationState], hasLength(1));
      expect(package.recordCounts[BackupSections.operationState], 1);

      final decoded = const BackupPackageCodec().decode(
        BackupExportService.encode(package),
      );
      expect(decoded.digests.package, package.digests.package);
    },
  );

  test(
    'Schema 2.0 REPLACE ALL excludes and preserves operation_state',
    () async {
      final timestamp = DateTime.utc(2026, 7, 31);
      final state = OperationState(
        operationDate: OperationLocalDate.parse('2026-07-31'),
        createdAt: timestamp,
        updatedAt: timestamp,
      );
      database.seed(
        IndexedDbStoreNames.operationState,
        OperationState.canonicalId,
        state.toRecord(),
      );
      final package = BackupExportService.buildPackage(
        exportId: 'schema-2-preserve-state',
        exportedAt: timestamp,
        source: const BackupSource(platform: 'test'),
        schemaVersion: BackupPackage.previousSchemaVersion,
        data: {for (final section in BackupSections.schema2) section: []},
      );
      final service = BackupImportService(
        database: database,
        controller: controller,
        restore: () async {},
      );

      final decoded = const BackupPackageCodec().decode(
        BackupExportService.encode(package),
      );
      expect(decoded.schemaVersion, 2);
      expect(decoded.data.keys, BackupSections.schema2);
      expect(decoded.data.containsKey(BackupSections.operationState), isFalse);

      final plan = await service.dryRun(decoded, BackupImportMode.replaceAll);
      expect((await service.execute(plan)).success, isTrue);
      expect(package.data.containsKey('operation_state'), isFalse);
      expect(
        await database.findById(
          IndexedDbStoreNames.operationState,
          OperationState.canonicalId,
        ),
        state.toRecord(),
      );
    },
  );

  test('rejects changed section content and invalid package digest', () async {
    final package = await BackupExportService(
      database: database,
      controller: controller,
    ).create();
    final json =
        jsonDecode(BackupExportService.encode(package)) as Map<String, dynamic>;
    json['recordCounts']['status'] = 1;

    expect(
      () => const BackupPackageCodec().decode(jsonEncode(json)),
      throwsA(isA<BackupException>()),
    );
  });

  test('accepts UTF-8 BOM and rejects an empty file', () async {
    final package = await BackupExportService(
      database: database,
      controller: controller,
    ).create();
    final bytes = [
      0xef,
      0xbb,
      0xbf,
      ...utf8.encode(BackupExportService.encode(package)),
    ];

    expect(const BackupPackageCodec().decodeUtf8(bytes).schemaVersion, 8);
    expect(
      () => const BackupPackageCodec().decodeUtf8(const []),
      throwsA(
        isA<BackupException>().having(
          (error) => error.code,
          'code',
          'empty_file',
        ),
      ),
    );
  });

  test('Schema 2.0 accepts old Confirmation without energy field', () async {
    final legacySummary = DigestiveSummary.fromEvents(const []);
    final envelope = PersistedDailyLogConfirmationRecord(
      id: 'confirmation:2026-07-26',
      localDate: '2026-07-26',
      createdAt: DateTime.utc(2026, 7, 26),
      updatedAt: DateTime.utc(2026, 7, 26),
      data: completeConfirmation().copyWith(
        activity: ActivitySummary(
          steps: 1000,
          isRecorded: true,
          digestiveSummary: legacySummary,
        ),
      ),
    ).toRecord();
    final data = envelope['data']! as Map;
    data.remove('estimatedTotalBurnKcal');
    final activity = data['activity']! as Map;
    final digestive = activity['digestiveSummary']! as Map;
    digestive.remove('hasExplicitNoMovement');
    database.seed(
      IndexedDbStoreNames.dailyLogConfirmations,
      envelope['id']! as String,
      envelope,
    );

    final package = await BackupExportService(
      database: database,
      controller: controller,
    ).create();
    final decoded = const BackupPackageCodec().decode(
      BackupExportService.encode(package),
    );

    expect(
      (decoded.data[BackupSections.confirmations]!.single['data']! as Map)
          .containsKey('estimatedTotalBurnKcal'),
      isFalse,
    );
    final restored = PersistedDailyLogConfirmationRecord.fromRecord(
      decoded.data[BackupSections.confirmations]!.single,
    );
    expect(
      restored.data.activity?.digestiveSummary?.hasExplicitNoMovement,
      isFalse,
    );
  });

  test('Schema 2.0 exports and imports the energy Snapshot value', () async {
    final envelope = PersistedDailyLogConfirmationRecord(
      id: 'confirmation:2026-07-26',
      localDate: '2026-07-26',
      createdAt: DateTime.utc(2026, 7, 26),
      updatedAt: DateTime.utc(2026, 7, 26),
      data: completeConfirmation().copyWith(
        training: const TrainingSummary(
          completed: true,
          exerciseCount: 1,
          setCount: 1,
          duration: null,
          sessionName: 'Cardio',
          trainingCardioCaloriesKcal: 33.88,
          computedCardioCount: 1,
          uncomputedCardioCount: 0,
          energyCalculationStatus: TrainingEnergyCalculationStatus.complete,
          energyCalculationVersion: 1,
        ),
      ),
    ).toRecord();
    database.seed(
      IndexedDbStoreNames.dailyLogConfirmations,
      envelope['id']! as String,
      envelope,
    );
    final package = await BackupExportService(
      database: database,
      controller: controller,
    ).create();
    final restoredDatabase = FakeIndexedDbDatabase();
    final restoredController = AppInitializationController()..markReady();
    final importService = BackupImportService(
      database: restoredDatabase,
      controller: restoredController,
      restore: () async {},
    );

    final plan = await importService.dryRun(
      package,
      BackupImportMode.replaceAll,
    );
    final result = await importService.execute(plan);
    final restoredEnvelope = PersistedDailyLogConfirmationRecord.fromRecord(
      (await restoredDatabase.findById(
        IndexedDbStoreNames.dailyLogConfirmations,
        'confirmation:2026-07-26',
      ))!,
    );

    expect(result.success, isTrue);
    expect(restoredEnvelope.data.estimatedTotalBurnKcal, 2875.5);
    expect(restoredEnvelope.data.training?.trainingCardioCaloriesKcal, 33.88);
    expect(restoredEnvelope.data.training?.computedCardioCount, 1);
    expect(
      restoredEnvelope.data.training?.energyCalculationStatus,
      TrainingEnergyCalculationStatus.complete,
    );
    expect(restoredEnvelope.data.training?.energyCalculationVersion, 1);
  });

  test('Schema 2.0 preserves physical and multiplier FOOD Snapshots', () async {
    final timestamp = DateTime.utc(2026, 7, 26);
    final envelope = PersistedFoodRecord(
      id: 'food:meal-measured',
      localDate: '2026-07-26',
      createdAt: timestamp,
      updatedAt: timestamp,
      data: MealData(
        date: '2026-07-26',
        mealType: 'Lunch',
        items: const [
          FoodItem(
            name: 'Physical Chicken',
            calories: 165,
            protein: 31,
            fat: 3.6,
            carbohydrate: 0,
            amount: 250,
            baseAmount: 100,
            baseUnit: FoodBaseUnit.g,
          ),
          FoodItem(
            name: 'Multiplier Chicken',
            calories: 165,
            protein: 31,
            fat: 3.6,
            carbohydrate: 0,
            amount: 2.5,
            baseAmount: 100,
            baseUnit: FoodBaseUnit.g,
            amountMode: FoodAmountMode.baseMultiplier,
          ),
        ],
        memo: '',
        id: 'meal-measured',
      ),
    ).toRecord();
    database.seed(
      IndexedDbStoreNames.foodRecords,
      envelope['id']! as String,
      envelope,
    );
    final package = await BackupExportService(
      database: database,
      controller: controller,
    ).create();
    final restoredDatabase = FakeIndexedDbDatabase();
    final restoredController = AppInitializationController()..markReady();
    final service = BackupImportService(
      database: restoredDatabase,
      controller: restoredController,
      restore: () async {},
    );

    final plan = await service.dryRun(package, BackupImportMode.replaceAll);
    expect((await service.execute(plan)).success, isTrue);
    final restored = PersistedFoodRecord.fromRecord(
      (await restoredDatabase.findById(
        IndexedDbStoreNames.foodRecords,
        'food:meal-measured',
      ))!,
    );

    expect(package.schemaVersion, 8);
    expect(package.databaseVersion, 10);
    expect(restored.recordVersion, 1);
    final physical = restored.data.items.first;
    final multiplier = restored.data.items.last;
    expect(physical.amount, 250);
    expect(physical.amountMode, isNull);
    expect(physical.totalCalories, 412.5);
    expect(multiplier.amount, 2.5);
    expect(multiplier.baseAmount, 100);
    expect(multiplier.baseUnit, FoodBaseUnit.g);
    expect(multiplier.amountMode, FoodAmountMode.baseMultiplier);
    expect(multiplier.physicalAmount, 250);
    expect(multiplier.totalCalories, 412.5);
  });

  test(
    'Schema 2.0 accepts v3 packages and never replaces Activity Drafts',
    () async {
      final timestamp = DateTime.utc(2026, 7, 27, 8);
      final draft = ActivityDraft(
        localDate: '2026-07-27',
        measuredStepsInput: '1234',
        carryOverInput: '0',
        createdAt: timestamp,
        updatedAt: timestamp,
      );
      database.seed(
        IndexedDbStoreNames.activityDrafts,
        draft.id,
        draft.toRecord(),
      );
      final currentPackage = await BackupExportService(
        database: database,
        controller: controller,
      ).create();
      final package = BackupExportService.buildPackage(
        schemaVersion: BackupPackage.previousSchemaVersion,
        exportId: currentPackage.exportId,
        exportedAt: currentPackage.exportedAt,
        source: currentPackage.source,
        data: {
          for (final section in BackupSections.schema2)
            section: currentPackage.data[section]!,
        },
      );
      final json =
          jsonDecode(BackupExportService.encode(package))
              as Map<String, dynamic>;
      json['databaseVersion'] = 3;
      final sectionDigests = Map<String, dynamic>.from(json['digests'] as Map)
        ..remove('package');
      final digestPayload = Map<String, dynamic>.from(json)
        ..['digests'] = sectionDigests;
      (json['digests'] as Map<String, dynamic>)['package'] =
          BackupCanonicalCodec.digest(digestPayload);

      final decoded = const BackupPackageCodec().decode(jsonEncode(json));
      final service = BackupImportService(
        database: database,
        controller: controller,
        restore: () async {},
      );
      expect(decoded.databaseVersion, 3);
      expect(decoded.data.containsKey('activity_drafts'), isFalse);

      final mergePlan = await service.dryRun(decoded, BackupImportMode.merge);
      expect((await service.execute(mergePlan)).success, isTrue);
      expect(
        await database.findById(IndexedDbStoreNames.activityDrafts, draft.id),
        isNotNull,
      );

      final replacePlan = await service.dryRun(
        decoded,
        BackupImportMode.replaceAll,
      );
      expect((await service.execute(replacePlan)).success, isTrue);
      expect(
        await database.findById(IndexedDbStoreNames.activityDrafts, draft.id),
        isNotNull,
      );
    },
  );

  test('Schema 2.0 exports and imports Training record v2 unchanged', () async {
    final timestamp = DateTime.utc(2026, 7, 29, 9);
    final envelope = PersistedTrainingRecord.v2(
      id: 'training:00112233-4455-4677-8899-aabbccddeeff',
      localDate: '2026-07-29',
      createdAt: timestamp,
      updatedAt: timestamp,
      data: TrainingSessionV2(
        date: '2026-07-29T18:00:00+09:00',
        sessionName: 'Upper Body',
        sessionGrade: TrainingSessionGrade.sMinus,
        dynamicStretchCompleted: true,
        cooldownStretchCompleted: false,
        overallEvaluation: 'Complete',
        cardioEntries: [
          CardioEntryV2(
            purpose: CardioPurpose.main,
            type: CardioType.running,
            durationSeconds: 300,
            mets: 4,
            weightSnapshotKg: 96.8,
            estimatedCaloriesKcal: 33.88,
            calculationMethod: 'metsAcsmV1',
            calculationVersion: 1,
          ),
        ],
      ),
    ).toRecord();
    database.seed(
      IndexedDbStoreNames.trainingRecords,
      envelope['id']! as String,
      envelope,
    );
    final package = await BackupExportService(
      database: database,
      controller: controller,
    ).create();
    final restoredDatabase = FakeIndexedDbDatabase();
    final service = BackupImportService(
      database: restoredDatabase,
      controller: AppInitializationController()..markReady(),
      restore: () async {},
    );

    final plan = await service.dryRun(
      const BackupPackageCodec().decode(BackupExportService.encode(package)),
      BackupImportMode.replaceAll,
    );
    expect((await service.execute(plan)).success, isTrue);
    final restoredEnvelope = await restoredDatabase.findById(
      IndexedDbStoreNames.trainingRecords,
      envelope['id']! as String,
    );

    expect(package.schemaVersion, 8);
    expect(package.databaseVersion, 10);
    expect(restoredEnvelope, envelope);
    final restored = PersistedTrainingRecord.fromRecord(restoredEnvelope!);
    expect(restored.recordVersion, 2);
    expect(restored.dataV2.sessionName, 'Upper Body');
    expect(restored.dataV2.sessionGrade, TrainingSessionGrade.sMinus);
    final cardio = restored.dataV2.cardioEntries.single;
    expect(cardio.weightSnapshotKg, 96.8);
    expect(cardio.estimatedCaloriesKcal, 33.88);
    expect(cardio.calculationMethod, 'metsAcsmV1');
    expect(cardio.calculationVersion, 1);
  });

  test('Schema 2.0 preserves v1 shadow lineage and preferred read', () async {
    final timestamp = DateTime.utc(2026, 7, 29, 9);
    const sourceId = 'training:00112233-4455-4677-8899-aabbccddeeff';
    final source = PersistedTrainingRecord(
      id: sourceId,
      localDate: '2026-07-29',
      createdAt: timestamp,
      updatedAt: timestamp,
      data: TrainingSession(
        date: '2026-07-29T18:00:00+09:00',
        memo: 'legacy',
        exercises: const [],
      ),
    );
    final shadow = TrainingV2MigrationMapper.map(
      targetId: TrainingRecordLineage.shadowIdForV1(sourceId),
      localDate: source.localDate,
      createdAt: source.createdAt,
      updatedAt: source.updatedAt,
      migrationSource: TrainingRecordLineage.shadowSource(
        sourceRecordId: sourceId,
        sourceIndex: 0,
      ),
      source: source.data,
    );
    database.seed(
      IndexedDbStoreNames.trainingRecords,
      source.id,
      source.toRecord(),
    );
    database.seed(
      IndexedDbStoreNames.trainingRecords,
      shadow.id,
      shadow.toRecord(),
    );

    final package = await BackupExportService(
      database: database,
      controller: controller,
    ).create();
    final restoredDatabase = FakeIndexedDbDatabase();
    final service = BackupImportService(
      database: restoredDatabase,
      controller: AppInitializationController()..markReady(),
      restore: () async {},
    );
    final plan = await service.dryRun(
      const BackupPackageCodec().decode(BackupExportService.encode(package)),
      BackupImportMode.replaceAll,
    );
    expect((await service.execute(plan)).success, isTrue);

    expect(
      await restoredDatabase.findById(
        IndexedDbStoreNames.trainingRecords,
        source.id,
      ),
      source.toRecord(),
    );
    expect(
      await restoredDatabase.findById(
        IndexedDbStoreNames.trainingRecords,
        shadow.id,
      ),
      shadow.toRecord(),
    );
    final repository = IndexedDbTrainingSessionRepository(restoredDatabase);
    expect(await repository.findAllRecords(), hasLength(1));
    expect((await repository.findAllRecords()).single.id, shadow.id);
    expect(await repository.findAllRecordsIncludingSuperseded(), hasLength(2));
  });

  test('Schema 2.0 rejects unknown Training record versions', () async {
    final timestamp = DateTime.utc(2026, 7, 29, 9).toIso8601String();
    database.seed(
      IndexedDbStoreNames.trainingRecords,
      'training:00112233-4455-4677-8899-aabbccddeeff',
      {
        'id': 'training:00112233-4455-4677-8899-aabbccddeeff',
        'recordVersion': 3,
        'localDate': '2026-07-29',
        'createdAt': timestamp,
        'updatedAt': timestamp,
        'data': const {
          'date': '2026-07-29',
          'exercises': <Object?>[],
          'cardioEntries': <Object?>[],
        },
      },
    );

    await expectLater(
      BackupExportService(database: database, controller: controller).create(),
      throwsA(isA<FormatException>()),
    );
  });

  test(
    'Schema 2.0 round trips digestive events and preserves Activity Drafts',
    () async {
      final timestamp = DateTime.utc(2026, 7, 27, 8);
      final activity = PersistedActivityRecord(
        id: 'activity:2026-07-27',
        localDate: '2026-07-27',
        createdAt: timestamp,
        updatedAt: timestamp,
        canonicalDate: '2026-07-27',
        recordKind: ActivityRecordKind.canonical,
        data: ActivityData(
          date: DateTime(2026, 7, 27),
          measuredSteps: 1000,
          digestiveEvents: [
            DigestiveEvent(
              id: 'digestive:2026-07-27:none',
              sequence: 1,
              amount: 0,
              shape: null,
              relief: null,
              recordedAt: timestamp,
            ),
          ],
          createdAt: timestamp,
          updatedAt: timestamp,
        ),
      );
      final draft = ActivityDraft(
        localDate: '2026-07-27',
        createdAt: timestamp,
        updatedAt: timestamp,
      );
      database.seed(
        IndexedDbStoreNames.activityRecords,
        activity.id,
        activity.toRecord(),
      );
      database.seed(
        IndexedDbStoreNames.activityDrafts,
        draft.id,
        draft.toRecord(),
      );
      final confirmation = PersistedDailyLogConfirmationRecord(
        id: 'confirmation:2026-07-27',
        localDate: '2026-07-27',
        createdAt: timestamp,
        updatedAt: timestamp,
        data: completeConfirmation().copyWith(
          date: DateTime(2026, 7, 27),
          confirmedAt: timestamp,
          activity: ActivitySummary(
            steps: 1000,
            isRecorded: true,
            digestiveSummary: DigestiveSummary.fromEvents([
              DigestiveEvent(
                id: 'digestive:2026-07-27:none',
                sequence: 1,
                amount: 0,
                shape: null,
                relief: null,
                recordedAt: timestamp,
              ),
            ]),
          ),
        ),
      );
      database.seed(
        IndexedDbStoreNames.dailyLogConfirmations,
        confirmation.id,
        confirmation.toRecord(),
      );
      final currentPackage = await BackupExportService(
        database: database,
        controller: controller,
      ).create();
      final package = BackupExportService.buildPackage(
        schemaVersion: BackupPackage.previousSchemaVersion,
        exportId: currentPackage.exportId,
        exportedAt: currentPackage.exportedAt,
        source: currentPackage.source,
        data: {
          for (final section in BackupSections.schema2)
            section: currentPackage.data[section]!,
        },
      );
      final restoredDatabase = FakeIndexedDbDatabase()
        ..seed(IndexedDbStoreNames.activityDrafts, draft.id, draft.toRecord());
      final service = BackupImportService(
        database: restoredDatabase,
        controller: AppInitializationController()..markReady(),
        restore: () async {},
      );

      final mergePlan = await service.dryRun(
        const BackupPackageCodec().decode(BackupExportService.encode(package)),
        BackupImportMode.merge,
      );
      expect((await service.execute(mergePlan)).success, isTrue);

      final plan = await service.dryRun(
        const BackupPackageCodec().decode(BackupExportService.encode(package)),
        BackupImportMode.replaceAll,
      );
      expect((await service.execute(plan)).success, isTrue);
      final restored = PersistedActivityRecord.fromRecord(
        (await restoredDatabase.findById(
          IndexedDbStoreNames.activityRecords,
          activity.id,
        ))!,
      );

      expect(package.schemaVersion, 2);
      expect(restored.recordVersion, 1);
      expect(restored.data.digestiveEvents?.single.sequence, 1);
      expect(restored.data.digestiveEvents?.single.amount, 0);
      expect(restored.data.digestiveEvents?.single.shape, isNull);
      expect(restored.data.digestiveEvents?.single.relief, isNull);
      expect(restored.data.digestiveEvents?.single.recordedAt, timestamp);
      final restoredConfirmation =
          PersistedDailyLogConfirmationRecord.fromRecord(
            (await restoredDatabase.findById(
              IndexedDbStoreNames.dailyLogConfirmations,
              confirmation.id,
            ))!,
          );
      expect(
        restoredConfirmation
            .data
            .activity
            ?.digestiveSummary
            ?.hasExplicitNoMovement,
        isTrue,
      );
      expect(
        await restoredDatabase.findById(
          IndexedDbStoreNames.activityDrafts,
          draft.id,
        ),
        isNotNull,
      );
      expect(package.data.containsKey('activity_drafts'), isFalse);
    },
  );

  test('Schema 1.0 converts STATUS and TRAINING only using exportedAt', () {
    final exportedAt = DateTime.utc(2026, 1, 2, 3, 4, 5);
    final morning = MorningData(
      date: '2026-01-02T07:00:00.000',
      weight: 70,
      bodyFat: 15,
      sleepHours: 7,
      sleepScore: 80,
      footPain: 2,
      workType: WorkType.work,
      workStart: '',
      workEnd: '',
      workBreak: '',
      workHours: 0,
      memo: '',
    );
    final training = TrainingSession(
      date: '2026-01-02T18:00:00.000',
      memo: '',
      exercises: const [],
    );
    final package = const BackupPackageCodec().decode(
      jsonEncode({
        'schemaVersion': '1.0',
        'exportedAt': exportedAt.toIso8601String(),
        'morningFact': [morning.toJson()],
        'training': [training.toJson()],
        'metadata': <String, Object?>{},
      }),
    );

    expect(package.includedSections, {
      BackupSections.status,
      BackupSections.training,
    });
    expect(package.permitsReplaceAll, isFalse);
    expect(
      package.data[BackupSections.status]!.single['createdAt'],
      exportedAt.toIso8601String(),
    );
    expect(
      package.data[BackupSections.training]!.single['updatedAt'],
      exportedAt.toIso8601String(),
    );
    expect(
      package.data[BackupSections.training]!.single['id'],
      startsWith('legacy-training:'),
    );
  });

  test(
    'Schema 1.0 refuses REPLACE ALL and preserves absent sections',
    () async {
      final package = const BackupPackageCodec().decode(
        jsonEncode({
          'schemaVersion': '1.0',
          'exportedAt': DateTime.utc(2026, 1, 2).toIso8601String(),
          'morningFact': <Object?>[],
          'training': <Object?>[],
        }),
      );
      final service = BackupImportService(
        database: database,
        controller: controller,
        restore: () async {},
      );

      expect(
        () => service.dryRun(package, BackupImportMode.replaceAll),
        throwsA(
          isA<BackupException>().having(
            (error) => error.code,
            'code',
            'legacy_replace_forbidden',
          ),
        ),
      );
    },
  );

  test('MERGE adds missing envelope and repeats idempotently', () async {
    final record = _customRecord(
      'custom-exercise:00000000-0000-4000-8000-000000000001',
    );
    final package = BackupExportService.buildPackage(
      schemaVersion: BackupPackage.previousSchemaVersion,
      exportId: '00000000-0000-4000-8000-000000000002',
      exportedAt: DateTime.utc(2026, 7, 26),
      source: const BackupSource(platform: 'web'),
      data: {
        for (final section in BackupSections.all)
          section: section == BackupSections.customExercises ? [record] : [],
      },
    );
    final service = BackupImportService(
      database: database,
      controller: controller,
      restore: () async {},
    );
    final firstPlan = await service.dryRun(package, BackupImportMode.merge);
    expect(firstPlan.sections[BackupSections.customExercises]!.add, 1);
    expect((await service.execute(firstPlan)).success, isTrue);

    final secondPlan = await service.dryRun(package, BackupImportMode.merge);
    expect(secondPlan.sections[BackupSections.customExercises]!.skip, 1);
    expect(secondPlan.sections[BackupSections.customExercises]!.add, 0);
  });

  test('MERGE conflict never starts a write transaction', () async {
    final id = 'custom-exercise:00000000-0000-4000-8000-000000000005';
    final existing = _customRecord(id);
    database.seed(IndexedDbStoreNames.customTrainingExercises, id, existing);
    final changed = Map<String, Object?>.from(existing)
      ..['updatedAt'] = DateTime.utc(2026, 7, 27).toIso8601String();
    final package = BackupExportService.buildPackage(
      schemaVersion: BackupPackage.previousSchemaVersion,
      exportId: '00000000-0000-4000-8000-000000000006',
      exportedAt: DateTime.utc(2026, 7, 27),
      source: const BackupSource(platform: 'web'),
      data: {
        for (final section in BackupSections.all)
          section: section == BackupSections.customExercises ? [changed] : [],
      },
    );
    final service = BackupImportService(
      database: database,
      controller: controller,
      restore: () async {},
    );

    final plan = await service.dryRun(package, BackupImportMode.merge);

    expect(plan.hasConflicts, isTrue);
    expect((await service.execute(plan)).errorCode, 'import_conflict');
    expect(database.transactionCount, 0);
  });

  test(
    'maintenance mode is active only while approved import executes',
    () async {
      final package = BackupExportService.buildPackage(
        schemaVersion: BackupPackage.previousSchemaVersion,
        exportId: '00000000-0000-4000-8000-000000000007',
        exportedAt: DateTime.utc(2026, 7, 27),
        source: const BackupSource(platform: 'web'),
        data: {for (final section in BackupSections.all) section: []},
      );
      var modeDuringRestore = PersistenceMode.failed;
      final service = BackupImportService(
        database: database,
        controller: controller,
        restore: () async {
          modeDuringRestore = controller.value.mode;
        },
      );
      final plan = await service.dryRun(package, BackupImportMode.replaceAll);
      expect(controller.value.mode, PersistenceMode.indexedDbReadWrite);

      final result = await service.execute(plan);

      expect(result.success, isTrue);
      expect(modeDuringRestore, PersistenceMode.maintenance);
      expect(controller.value.mode, PersistenceMode.indexedDbReadWrite);
    },
  );

  test(
    'failed REPLACE ALL transaction rolls back and returns ready mode',
    () async {
      final existing = _customRecord(
        'custom-exercise:00000000-0000-4000-8000-000000000003',
      );
      database.seed(
        IndexedDbStoreNames.customTrainingExercises,
        existing['id'] as String,
        existing,
      );
      final package = BackupExportService.buildPackage(
        schemaVersion: BackupPackage.previousSchemaVersion,
        exportId: '00000000-0000-4000-8000-000000000004',
        exportedAt: DateTime.utc(2026, 7, 26),
        source: const BackupSource(platform: 'web'),
        data: {for (final section in BackupSections.all) section: []},
      );
      final service = BackupImportService(
        database: database,
        controller: controller,
        restore: () async {},
      );
      final plan = await service.dryRun(package, BackupImportMode.replaceAll);
      database.failNextTransactionWith = StateError('write failed');

      final result = await service.execute(plan);

      expect(result.success, isFalse);
      expect(controller.value.mode, PersistenceMode.indexedDbReadWrite);
      expect(
        await database.findAll(IndexedDbStoreNames.customTrainingExercises),
        hasLength(1),
      );
    },
  );
}

Map<String, Object?> _customRecord(String id) {
  final timestamp = DateTime.utc(2026, 7, 26);
  return PersistedCustomTrainingExerciseRecord(
    id: id,
    normalizedName: 'testexercise',
    createdAt: timestamp,
    updatedAt: timestamp,
    data: CustomTrainingExercise(id: id, name: 'Test Exercise'),
  ).toRecord();
}
