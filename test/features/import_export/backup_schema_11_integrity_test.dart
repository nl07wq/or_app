import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/models/activity_data.dart';
import 'package:or_app/core/models/cardio_entry.dart';
import 'package:or_app/core/models/cardio_entry_v2.dart';
import 'package:or_app/core/models/digestive_event.dart';
import 'package:or_app/core/models/morning_data.dart';
import 'package:or_app/core/models/training_equipment_snapshot.dart';
import 'package:or_app/core/models/training_exercise_v2.dart';
import 'package:or_app/core/models/training_session_v2.dart';
import 'package:or_app/core/models/training_set_v2.dart';
import 'package:or_app/core/models/work_type.dart';
import 'package:or_app/core/services/daily_state_restore_service.dart';
import 'package:or_app/core/state/app_initialization_state.dart';
import 'package:or_app/data/indexed_db/indexed_db_store_names.dart';
import 'package:or_app/features/activity/models/persisted_activity_record.dart';
import 'package:or_app/features/daily_aggregate/models/daily_aggregate_v1.dart';
import 'package:or_app/features/daily_log_confirmation/models/daily_log_confirmation_lifecycle.dart';
import 'package:or_app/features/daily_log_confirmation/models/persisted_daily_log_confirmation_record.dart';
import 'package:or_app/features/food/models/daily_meal_v2_models.dart';
import 'package:or_app/features/food/models/food_catalog_models.dart';
import 'package:or_app/features/food/models/food_provenance_models.dart';
import 'package:or_app/features/food/models/food_quantity_models.dart';
import 'package:or_app/features/food/models/nutrition_models.dart';
import 'package:or_app/features/food/models/persisted_daily_meal_v2_record.dart';
import 'package:or_app/features/food/models/recipe_models_v2.dart';
import 'package:or_app/features/import_export/models/backup_package.dart';
import 'package:or_app/features/import_export/services/backup_export_service.dart';
import 'package:or_app/features/import_export/services/backup_import_service.dart';
import 'package:or_app/features/import_export/services/backup_package_codec.dart';
import 'package:or_app/features/import_export/services/backup_store_registry.dart';
import 'package:or_app/features/legacy_archive/models/dns_archive_models.dart';
import 'package:or_app/features/operation_date/models/operation_local_date.dart';
import 'package:or_app/features/operation_date/models/operation_state.dart';
import 'package:or_app/features/operation_sync/models/operation_sync_history.dart';
import 'package:or_app/features/report_sync/models/morning_brief_record.dart';
import 'package:or_app/features/report_sync/models/daily_debrief_record.dart';
import 'package:or_app/features/report_sync/models/report_sync_envelope.dart';
import 'package:or_app/features/report_sync/models/report_sync_history.dart';
import 'package:or_app/features/repositories/app_repository_container.dart';
import 'package:or_app/features/status/models/persisted_status_record.dart';
import 'package:or_app/features/system/models/profile_model.dart';
import 'package:or_app/features/training/models/custom_training_exercise.dart';
import 'package:or_app/features/training/models/persisted_custom_training_exercise_record.dart';
import 'package:or_app/features/training/models/persisted_training_record.dart';

import '../../repositories/indexed_db/fake_indexed_db_database.dart';
import '../daily_log_confirmation/daily_log_confirmation_test_fixture.dart';

void main() {
  final timestamp = DateTime.utc(2026, 8, 9, 12, 34, 56);

  test(
    'Schema 11 round trips every formal section without value loss',
    () async {
      final source = FakeIndexedDbDatabase();
      _seedCompleteSource(source, timestamp);
      final sourceController = AppInitializationController()..markReady();
      final exported = await BackupExportService(
        database: source,
        controller: sourceController,
        clock: () => timestamp,
      ).create();
      final decoded = const BackupPackageCodec().decode(
        BackupExportService.encode(exported),
      );

      expect(decoded.schemaVersion, 11);
      expect(decoded.includedSections, BackupSections.all.toSet());
      expect(decoded.data, hasLength(16));
      for (final section in BackupSections.all) {
        expect(decoded.data[section], hasLength(1), reason: section);
      }

      final target = FakeIndexedDbDatabase();
      final service = BackupImportService(
        database: target,
        controller: AppInitializationController()..markReady(),
        restore: () async {},
      );
      final plan = await service.dryRun(decoded, BackupImportMode.replaceAll);
      final result = await service.execute(plan);

      expect(result.success, isTrue);
      for (final section in BackupSections.all) {
        final stored = await target.findAll(
          BackupStoreRegistry.stores[section]!,
        );
        final comparable = section == BackupSections.profile
            ? [
                for (final record in stored)
                  ProfileModel.fromRecord(record).toBackupRecord(),
              ]
            : stored;
        expect(
          BackupStoreRegistry.validateAndSort(section, comparable),
          decoded.data[section],
          reason: section,
        );
      }

      final status = decoded.data[BackupSections.status]!.single;
      final statusData = status['data']! as Map<String, Object?>;
      expect(statusData['weight'], isNull);
      expect(statusData['bodyFat'], isNull);
      expect(statusData['sleepHours'], isNull);
      expect(statusData['sleepScore'], isNull);

      final activity = decoded.data[BackupSections.activity]!.single;
      final activityData = activity['data']! as Map<String, Object?>;
      expect(activityData['measuredSteps'], 0);
      expect(activityData['stepsEntered'], isTrue);
      expect(activityData['carryOver'], 0);
      expect(activityData['carryOverEntered'], isFalse);
      expect(activityData['actualWork'], '');
      expect((activityData['digestiveEvents']! as List), hasLength(2));

      final food = decoded.data[BackupSections.food]!.single;
      final foodData = food['data']! as Map<String, Object?>;
      expect(foodData['memo'], '');
      expect(foodData['waterMl'], 750.5);
      final items = foodData['items']! as List;
      expect(items.map((item) => (item as Map)['mealItemId']), [
        '55555555-5555-4555-8555-555555555552',
        '55555555-5555-4555-8555-555555555551',
      ]);
      expect(((items.first as Map)['nutritionConsumed'] as Map)['fat'], isNull);

      final training = decoded.data[BackupSections.training]!.single;
      final trainingData = training['data']! as Map<String, Object?>;
      expect(trainingData['sessionName'], isNull);
      final exercises = trainingData['exercises']! as List;
      expect(exercises.map((item) => (item as Map)['exerciseName']), [
        'Shoulder Press',
        'Face Pull',
      ]);
      expect(
        ((exercises.first as Map)['sets'] as List).map(
          (item) => (item as Map)['setNo'],
        ),
        [2, 1],
      );
      expect(
        ((exercises.first as Map)['equipment'] as Map)['catalogId'],
        'dumbbells',
      );
      expect(((exercises.first as Map)['nextTarget'] as Map)['targetReps'], [
        8,
        10,
      ]);
      final cardio = trainingData['cardioEntries']! as List;
      expect(cardio.map((item) => (item as Map)['type']), [
        'exerciseBike',
        'running',
      ]);
      expect((cardio.first as Map)['estimatedCaloriesKcal'], 33.88);
      expect((cardio.first as Map)['weightSnapshotKg'], 96.8);
      expect((cardio.first as Map)['calculationMethod'], 'metsAcsmV1');
      expect((cardio.first as Map)['calculationVersion'], 1);

      final confirmation = decoded.data[BackupSections.confirmations]!.single;
      expect(confirmation['recordVersion'], 2);
      expect(confirmation['revision'], 2);
      expect(confirmation['previousRevisions'], hasLength(1));
      expect((confirmation['data'] as Map)['estimatedTotalBurnKcal'], 2875.5);

      final aggregate =
          decoded.data[BackupSections.dailyAggregateRecords]!.single;
      expect(aggregate['estimatedCalorieBalanceKcal'], -250.25);
      expect(aggregate['trainingPerformed'], isFalse);
      expect(aggregate['digestiveEvents'], hasLength(2));
      expect(aggregate['conditionFactSummary'], ['first', 'second']);
    },
  );

  test(
    'REPLACE ALL rebuilds daily state while controller is initializing',
    () async {
      final source = FakeIndexedDbDatabase();
      _seedCompleteSource(source, timestamp);
      final sourceController = AppInitializationController()..markReady();
      final package = await BackupExportService(
        database: source,
        controller: sourceController,
        clock: () => timestamp,
      ).create();
      final target = FakeIndexedDbDatabase();
      final controller = AppInitializationController()..markReady();
      final modes = <PersistenceMode>[];
      controller.addListener(() => modes.add(controller.value.mode));
      AppRepositoryRegistry.beginStartup(controller: controller);
      AppRepositoryRegistry.install(AppRepositoryContainer.indexedDb(target));
      DailyStateRestoreService.resetForTesting();

      try {
        final service = BackupImportService(
          database: target,
          controller: controller,
        );
        final plan = await service.dryRun(package, BackupImportMode.replaceAll);

        final result = await service.execute(plan);

        expect(result.success, isTrue);
        expect(modes, [
          PersistenceMode.maintenance,
          PersistenceMode.initializing,
          PersistenceMode.indexedDbReadWrite,
        ]);
      } finally {
        DailyStateRestoreService.resetForTesting();
        AppRepositoryRegistry.resetForTesting();
      }
    },
  );

  test('post-commit failure restores the exact pre-restore database', () async {
    final database = FakeIndexedDbDatabase();
    final original = _customExercise(timestamp, suffix: '1');
    database.seed(
      IndexedDbStoreNames.customTrainingExercises,
      original['id']! as String,
      original,
    );
    final data = {
      for (final section in BackupSections.all)
        section: <Map<String, Object?>>[],
    };
    data[BackupSections.operationState] = [_operationState(timestamp)];
    data[BackupSections.profile] = [
      {
        'version': 1,
        'userName': null,
        'heightCm': null,
        'gender': null,
        'nationality': null,
      },
    ];
    final package = BackupExportService.buildPackage(
      exportId: 'rollback-package',
      exportedAt: timestamp,
      source: const BackupSource(platform: 'test'),
      data: data,
    );
    var restoreCalls = 0;
    final controller = AppInitializationController()..markReady();
    final modes = <PersistenceMode>[];
    final restoreModes = <PersistenceMode>[];
    controller.addListener(() => modes.add(controller.value.mode));
    final service = BackupImportService(
      database: database,
      controller: controller,
      restore: () async {
        restoreCalls++;
        restoreModes.add(controller.value.mode);
        if (restoreCalls == 1) throw StateError('post-commit restore failed');
      },
    );

    final plan = await service.dryRun(package, BackupImportMode.replaceAll);
    final result = await service.execute(plan);

    expect(result.success, isFalse);
    expect(restoreCalls, 2);
    expect(restoreModes, [
      PersistenceMode.initializing,
      PersistenceMode.initializing,
    ]);
    expect(modes, [
      PersistenceMode.maintenance,
      PersistenceMode.initializing,
      PersistenceMode.maintenance,
      PersistenceMode.initializing,
      PersistenceMode.indexedDbReadWrite,
    ]);
    expect(
      await database.findAll(IndexedDbStoreNames.customTrainingExercises),
      [original],
    );
    expect(await database.findAll(IndexedDbStoreNames.operationState), isEmpty);
    expect(controller.value.mode, PersistenceMode.indexedDbReadWrite);
  });
}

void _seedCompleteSource(FakeIndexedDbDatabase database, DateTime timestamp) {
  final records = _completeRecords(timestamp);
  for (final entry in records.entries) {
    final section = entry.key;
    final record = entry.value;
    database.seed(
      BackupStoreRegistry.stores[section]!,
      section == BackupSections.profile
          ? ProfileModel.recordId
          : BackupStoreRegistry.recordId(section, record),
      record,
    );
  }
}

Map<String, Map<String, Object?>> _completeRecords(DateTime timestamp) {
  final localDate = '2026-08-09';
  final status = PersistedStatusRecord(
    id: PersistedStatusRecord.canonicalId(localDate),
    localDate: localDate,
    createdAt: timestamp,
    updatedAt: timestamp,
    canonicalDate: localDate,
    recordKind: StatusRecordKind.canonical,
    data: MorningData(
      date: localDate,
      weight: null,
      bodyFat: null,
      sleepHours: null,
      sleepScore: null,
      sleepType: SleepType.nap,
      footPain: 0,
      condition: null,
      previousCarryoverConfirmed: false,
      workType: WorkType.work,
      workStart: '',
      workEnd: '',
      workBreak: '',
      workHours: 0,
      memo: '',
    ),
  ).toRecord();
  final activity = PersistedActivityRecord(
    id: PersistedActivityRecord.canonicalId(localDate),
    localDate: localDate,
    createdAt: timestamp,
    updatedAt: timestamp,
    canonicalDate: localDate,
    recordKind: ActivityRecordKind.canonical,
    data: ActivityData(
      date: DateTime(2026, 8, 9),
      measuredSteps: 0,
      stepsEntered: true,
      carryOver: 0,
      carryOverEntered: false,
      officialSteps: null,
      plannedWork: null,
      actualWork: '',
      trainingStatus: ActivityTrainingStatus.skipped,
      digestiveEvents: [
        DigestiveEvent(
          id: 'digestive:2026-08-09:1',
          sequence: 1,
          amount: 0,
          shape: null,
          relief: null,
          recordedAt: timestamp,
        ),
        DigestiveEvent(
          id: 'digestive:2026-08-09:2',
          sequence: 2,
          amount: 2,
          shape: 3,
          relief: 1,
          recordedAt: timestamp.add(const Duration(minutes: 1)),
        ),
      ],
      note: null,
      createdAt: timestamp,
      updatedAt: timestamp,
    ),
  ).toRecord();
  final meal = DailyMealV2(
    mealId: '44444444-4444-4444-8444-444444444444',
    localDate: localDate,
    mealType: DailyMealTypeV2.lunch,
    items: [
      _mealItem('55555555-5555-4555-8555-555555555552', 2, timestamp),
      _mealItem('55555555-5555-4555-8555-555555555551', 1, timestamp),
    ],
    memo: '',
    waterMl: 750.5,
    createdAt: timestamp,
    updatedAt: timestamp.add(const Duration(minutes: 2)),
  );
  final training = PersistedTrainingRecord.v2(
    id: 'training:00112233-4455-4677-8899-aabbccddeeff',
    localDate: localDate,
    createdAt: timestamp,
    updatedAt: timestamp,
    data: TrainingSessionV2(
      date: '${localDate}T18:00:00+09:00',
      sessionName: null,
      sessionGrade: TrainingSessionGrade.sPlus,
      memo: '',
      dynamicStretchCompleted: true,
      cooldownStretchCompleted: false,
      overallEvaluation: 'completed',
      exercises: [
        TrainingExerciseV2(
          exerciseName: 'Shoulder Press',
          order: 1,
          equipment: TrainingEquipmentSnapshot(
            catalogId: 'dumbbells',
            name: 'Dumbbells',
          ),
          sets: [
            TrainingSetV2(
              setNo: 2,
              setType: TrainingSetType.main,
              weightKg: 20.5,
              reps: 8,
              rpe: 9,
              restAfterSeconds: 0,
            ),
            TrainingSetV2(
              setNo: 1,
              setType: TrainingSetType.warmUp,
              weightKg: 0,
              reps: 10,
            ),
          ],
          evaluation: 'stable',
          nextTarget: TrainingNextTarget(
            targetWeightKg: 22.5,
            targetReps: const [8, 10],
            notes: 'next',
          ),
        ),
        TrainingExerciseV2(
          exerciseName: 'Face Pull',
          order: 2,
          sets: [
            TrainingSetV2(
              setNo: 1,
              setType: TrainingSetType.main,
              weightKg: 10,
              reps: 12,
            ),
          ],
        ),
      ],
      cardioEntries: [
        CardioEntryV2(
          purpose: CardioPurpose.warmUp,
          type: CardioType.exerciseBike,
          equipment: TrainingEquipmentSnapshot(name: 'Exercise Bike'),
          durationSeconds: 300,
          distanceKm: 0,
          mets: 4,
          averageHeartRateBpm: 100,
          maximumHeartRateBpm: 120,
          averageSpeedKmh: 0,
          estimatedCaloriesKcal: 33.88,
          weightSnapshotKg: 96.8,
          calculationMethod: 'metsAcsmV1',
          calculationVersion: 1,
          notes: 'warmup',
        ),
        CardioEntryV2(
          purpose: CardioPurpose.main,
          type: CardioType.running,
          durationSeconds: 600,
        ),
      ],
    ),
  ).toRecord();
  final initialConfirmation =
      PersistedDailyLogConfirmationRecord.initialFinalizedV2(
        id: 'confirmation:$localDate',
        localDate: localDate,
        data: completeConfirmation(
          date: DateTime(2026, 8, 9),
          confirmedAt: timestamp,
          trainingName: 'initial',
        ),
        timestamp: timestamp,
      );
  final reopened = PersistedDailyLogConfirmationRecord.reopenedFrom(
    existing: initialConfirmation,
    reopenedAt: timestamp.add(const Duration(hours: 1)),
  );
  final confirmation = PersistedDailyLogConfirmationRecord.refinalizedFrom(
    existing: reopened,
    data: completeConfirmation(
      date: DateTime(2026, 8, 9),
      confirmedAt: timestamp.add(const Duration(hours: 2)),
      trainingName: 're-finalized',
    ),
    sourceRecordVersions:
        const DailyLogConfirmationSourceRecordVersions.unknown(),
    refinalizedAt: timestamp.add(const Duration(hours: 2)),
  ).toRecord();
  const digest =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

  return {
    BackupSections.status: status,
    BackupSections.activity: activity,
    BackupSections.food: PersistedDailyMealV2Record.fromMeal(meal).toRecord(),
    BackupSections.training: training,
    BackupSections.confirmations: confirmation,
    BackupSections.customExercises: _customExercise(timestamp),
    BackupSections.operationState: _operationState(timestamp),
    BackupSections.foodCatalog: _catalog(timestamp).toJson(),
    BackupSections.foodRecipes: _recipe(timestamp).toJson(),
    BackupSections.operationSyncHistory: OperationSyncHistory(
      operationId: 'operation-1',
      packageId: 'package-1',
      packageDigest: digest,
      sourceType: 'currentAppTransfer',
      transferMode: 'fullTransfer',
      startedAt: timestamp.subtract(const Duration(minutes: 1)),
      completedAt: timestamp,
      moduleIds: const ['status', 'food'],
      recordCount: 2,
      createCount: 1,
      noChangeCount: 0,
      conflictCount: 0,
      quarantineCount: 1,
      result: OperationSyncHistoryResult.success,
      isRecoveryExecution: false,
    ).toRecord(),
    BackupSections.morningBriefRecords: MorningBriefRecord.v2(
      localDate: localDate,
      sourceType: 'status',
      sourceOperationDate: localDate,
      sourceRecordId: PersistedStatusRecord.canonicalId(localDate),
      sourceDigest: digest,
      responseDigest: digest,
      exchangeId: 'brief-exchange-1',
      generatedAt: timestamp,
      importedAt: timestamp,
      situationAnalysisV2: const MorningBriefSituationAnalysis(
        body: 'body',
        recovery: 'recovery',
        condition: 'condition',
        work: 'work',
        carryover: 'none',
        overall: 'overall',
        bodyDisplay: MorningBriefSectionDisplay(
          primaryText: 'primary',
          supportingText: null,
        ),
      ),
      operatingPolicy: 'policy',
      strategicResourceDecisionV2: const MorningBriefStrategicResourceDecision(
        decision: 'hold',
        targetResource: null,
        rationale: 'rationale',
        execution: 'execute',
      ),
      operationStatus: MorningBriefOperationStatus.yellow,
      commanderIntent: 'intent',
      actions: const [
        MorningBriefAction(actionId: 'a2', text: 'second', priority: 'P2'),
        MorningBriefAction(actionId: 'a1', text: 'first', priority: 'P1'),
      ],
      createdAt: timestamp,
      updatedAt: timestamp,
    ).toRecord(),
    BackupSections.dailyDebriefRecords: DailyDebriefRecord.initial(
      localDate: localDate,
      sources: DailyDebriefSources(
        dailyAggregate: DailyDebriefDailyAggregateReference(
          operationDate: localDate,
          sourceType: 'records',
          recordDigest: digest,
        ),
        confirmation: DailyDebriefConfirmationReference(
          recordId: 'confirmation:$localDate',
          recordVersion: 2,
          revision: 1,
          snapshotDigest: '1234abcd',
          recordDigest: digest,
        ),
        morningBrief: DailyDebriefMorningBriefReference(
          localDate: localDate,
          recordVersion: 2,
          responseDigest: digest,
          recordDigest: digest,
        ),
      ),
      analysis: DailyDebriefAnalysis(
        commanderIntentEvaluation: DailyDebriefCommanderIntentEvaluation(
          outcome: DailyDebriefCommanderIntentOutcome.partiallyAchieved,
          rationale: 'rationale',
          evidence: const ['fact'],
        ),
        domainEvaluations: DailyDebriefDomainEvaluations(
          body: null,
          recovery: 'recovery',
          condition: null,
          work: null,
          nutrition: 'nutrition',
          hydration: null,
          activity: 'activity',
          training: null,
        ),
        crossAnalysis: DailyDebriefCrossAnalysis(
          keyFactors: const ['factor'],
          interactions: const [],
          constraints: const [],
          resources: const [],
        ),
        executionEvaluation: DailyDebriefExecutionEvaluation(
          successes: const ['success'],
          adjustments: const [],
        ),
        nextDayHandoff: DailyDebriefNextDayHandoff(
          watchPoints: const ['watch'],
        ),
      ),
      responseDigest: digest,
      timestamp: timestamp,
    ).toRecord(),
    BackupSections.reportSyncHistory: ReportSyncHistory(
      exchangeId: 'report-exchange-1',
      exchangeType: ReportSyncExchangeType.food,
      direction: ReportSyncDirection.response,
      operationDate: localDate,
      requestId: 'request-1',
      requestDigest: digest,
      responseDigest: digest,
      startedAt: timestamp,
      completedAt: timestamp,
      result: ReportSyncHistoryResult.success,
      packageDigest: digest,
      receivedMealCount: 2,
      selectedMealCount: 1,
      importedMealCount: 1,
      conflictMealCount: 0,
      excludedMealCount: 1,
    ).toRecord(),
    BackupSections.legacyDailySummaryRecords: LegacyDailySummaryRecord(
      localDate: localDate,
      sourceRecordId: 'legacy-1',
      sourcePackageId: 'legacy-package-1',
      body: const {'weight': null, 'delta': -1.25},
      nutrition: const {'calories': 0, 'estimated': false},
      hydration: null,
      activity: const {
        'steps': 0,
        'events': [0, 2],
      },
      work: const {'memo': ''},
      operation: const {'status': 'yellow'},
      warnings: const [
        DnsWarning(
          code: DnsWarningCode.estimatedValue,
          message: 'warning',
          field: null,
        ),
      ],
      unmappedFragments: const ['second', 'first'],
      sourceTextDigest: digest,
      createdAt: timestamp,
      importedAt: timestamp,
    ).toRecord(),
    BackupSections.profile: ProfileModel.validated(
      userName: 'User',
      heightCm: 170.5,
      gender: ProfileGender.preferNotToSay,
      nationality: null,
    ).toRecord(now: timestamp),
    BackupSections.dailyAggregateRecords: DailyAggregateV1(
      operationDate: localDate,
      weightKg: null,
      bodyFatPercent: 0,
      sleepDurationMinutes: null,
      sleepScore: null,
      sleepType: SleepType.nap,
      plantarFasciitisLevel: 3,
      workStartTime: '',
      workEndTime: '18:00',
      workBreakMinutes: 0,
      actualWorkMinutes: 420,
      intakeCaloriesKcal: 1479.5,
      estimatedExpenditureKcal: 1729.75,
      estimatedCalorieBalanceKcal: -250.25,
      proteinG: 99.3,
      fatG: 57.9,
      carbsG: 149.1,
      hydrationMl: 3600,
      officialSteps: 0,
      measuredSteps: 7512,
      trainingPerformed: false,
      digestiveCount: 2,
      digestiveEvents: const [
        DailyAggregateDigestiveEventV1(amount: 0, shape: null, relief: null),
        DailyAggregateDigestiveEventV1(amount: 2, shape: 3, relief: 1),
      ],
      operationStatus: 'YELLOW',
      conditionFactSummary: const ['first', 'second'],
      sourceType: DailyAggregateSourceType.records,
    ).toJson(),
  };
}

Map<String, Object?> _operationState(DateTime timestamp) => OperationState(
  operationDate: OperationLocalDate.parse('2026-08-09'),
  createdAt: timestamp,
  updatedAt: timestamp,
).toRecord();

Map<String, Object?> _customExercise(
  DateTime timestamp, {
  String suffix = '0',
}) {
  final id = 'custom-exercise:00000000-0000-4000-8000-00000000000$suffix';
  return PersistedCustomTrainingExerciseRecord(
    id: id,
    normalizedName: suffix == '0' ? 'facepull' : 'originalexercise',
    createdAt: timestamp,
    updatedAt: timestamp,
    data: CustomTrainingExercise(
      id: id,
      name: suffix == '0' ? 'Face Pull' : 'Original Exercise',
    ),
  ).toRecord();
}

FoodDataProvenance _provenance(DateTime timestamp) => FoodDataProvenance(
  sourceType: FoodProvenanceSourceType.userInput,
  sourceName: null,
  sourceReference: 'reference',
  capturedAt: timestamp,
  sourceUpdatedAt: null,
  notes: '',
);

DailyMealItemSnapshot _mealItem(String id, int order, DateTime timestamp) =>
    DailyMealItemSnapshot(
      mealItemId: id,
      foodReferenceId: '11111111-1111-4111-8111-111111111111',
      nameSnapshot: order == 1 ? 'Rice' : 'Chicken',
      category: order == 1 ? FoodCatalogCategory.ingredient : null,
      quantity: FoodQuantityDefinition(
        value: order == 1 ? 100 : 1,
        unit: order == 1 ? FoodQuantityUnit.gram : FoodQuantityUnit.serving,
      ),
      nutritionPerBase: NutritionSnapshot(
        calories: order == 1 ? 156 : 165,
        protein: order == 1 ? 2.5 : 31,
        fat: null,
        carbohydrate: order == 1 ? 35.6 : 0,
      ),
      nutritionConsumed: NutritionSnapshot(
        calories: order == 1 ? 156 : 0,
        protein: order == 1 ? 2.5 : 0,
        fat: null,
        carbohydrate: order == 1 ? 35.6 : 0,
      ),
      provenanceSnapshot: _provenance(timestamp),
      nutritionStatusSnapshot: NutritionStatus.declared,
      sortOrder: order,
    );

FoodCatalogEntry _catalog(DateTime timestamp) => FoodCatalogEntry(
  foodId: '11111111-1111-4111-8111-111111111111',
  name: 'Rice',
  category: FoodCatalogCategory.ingredient,
  brand: null,
  baseQuantity: FoodQuantityDefinition(value: 100, unit: FoodQuantityUnit.gram),
  nutrition: NutritionSnapshot(
    calories: 156,
    protein: 2.5,
    fat: null,
    carbohydrate: 35.6,
  ),
  nutritionStatus: NutritionStatus.declared,
  provenance: _provenance(timestamp),
  isArchived: false,
  memo: '',
  createdAt: timestamp,
  updatedAt: timestamp,
);

FoodRecipeDefinition _recipe(DateTime timestamp) => FoodRecipeDefinition(
  recipeId: '22222222-2222-4222-8222-222222222222',
  name: 'Rice Bowl',
  ingredients: [
    RecipeIngredientV2(
      ingredientId: '33333333-3333-4333-8333-333333333333',
      foodReferenceId: _catalog(timestamp).foodId,
      nameSnapshot: 'Rice',
      quantity: FoodQuantityDefinition(value: 100, unit: FoodQuantityUnit.gram),
      nutritionSnapshot: NutritionSnapshot(calories: 156, carbohydrate: 35.6),
      nutritionStatus: NutritionStatus.declared,
      provenanceSnapshot: _provenance(timestamp),
      sortOrder: 0,
    ),
  ],
  yieldQuantity: FoodQuantityDefinition(
    value: 1,
    unit: FoodQuantityUnit.serving,
  ),
  nutrition: NutritionSnapshot(calories: 156, carbohydrate: 35.6),
  nutritionStatus: NutritionStatus.calculated,
  provenance: _provenance(timestamp),
  isArchived: false,
  memo: null,
  createdAt: timestamp,
  updatedAt: timestamp,
);
