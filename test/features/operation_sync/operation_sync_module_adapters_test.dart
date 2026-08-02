import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/models/activity_data.dart';
import 'package:or_app/core/models/daily_log_confirmation.dart';
import 'package:or_app/core/models/morning_data.dart';
import 'package:or_app/core/models/training_exercise_v2.dart';
import 'package:or_app/core/models/training_session.dart';
import 'package:or_app/core/models/training_session_v2.dart';
import 'package:or_app/core/models/work_type.dart';
import 'package:or_app/data/indexed_db/indexed_db_database_contract.dart';
import 'package:or_app/data/indexed_db/indexed_db_store_names.dart';
import 'package:or_app/features/activity/models/persisted_activity_record.dart';
import 'package:or_app/features/daily_log_confirmation/models/persisted_daily_log_confirmation_record.dart';
import 'package:or_app/features/food/models/food_catalog_models.dart';
import 'package:or_app/features/food/models/food_provenance_models.dart';
import 'package:or_app/features/food/models/food_quantity_models.dart';
import 'package:or_app/features/food/models/nutrition_models.dart';
import 'package:or_app/features/food/models/recipe_models_v2.dart';
import 'package:or_app/features/operation_date/models/operation_local_date.dart';
import 'package:or_app/features/operation_date/models/operation_state.dart';
import 'package:or_app/features/operation_date/repository/indexed_db_operation_state_repository.dart';
import 'package:or_app/features/operation_sync/adapters/food_operation_sync_adapter.dart';
import 'package:or_app/features/operation_sync/adapters/status_operation_sync_adapter.dart';
import 'package:or_app/features/operation_sync/adapters/training_operation_sync_adapter.dart';
import 'package:or_app/features/operation_sync/models/operation_sync_issue.dart';
import 'package:or_app/features/operation_sync/models/operation_sync_state.dart';
import 'package:or_app/features/operation_sync/models/operation_transfer_package.dart';
import 'package:or_app/features/operation_sync/repository/indexed_db_operation_sync_history_repository.dart';
import 'package:or_app/features/operation_sync/repository/indexed_db_operation_sync_state_repository.dart';
import 'package:or_app/features/operation_sync/services/operation_sync_core_service.dart';
import 'package:or_app/features/operation_sync/services/operation_sync_production_registry.dart';
import 'package:or_app/features/operation_sync/services/operation_sync_record_envelope.dart';
import 'package:or_app/features/operation_sync/services/operation_sync_validator.dart';
import 'package:or_app/features/operation_sync/services/operation_transfer_codec.dart';
import 'package:or_app/features/operation_sync/services/operation_transfer_export_service.dart';
import 'package:or_app/features/status/models/persisted_status_record.dart';
import 'package:or_app/features/training/models/custom_training_exercise.dart';
import 'package:or_app/features/training/models/persisted_custom_training_exercise_record.dart';
import 'package:or_app/features/training/models/persisted_training_record.dart';

import '../../repositories/indexed_db/fake_indexed_db_database.dart';
import 'operation_transfer_test_fixture.dart';

void main() {
  test('production registry contains every formal module adapter', () {
    final registry = OperationSyncProductionRegistry.create(
      FakeIndexedDbDatabase(),
    );

    expect(registry.adapters.map((adapter) => adapter.module), [
      'status',
      'activity',
      'training',
      'food',
      'confirmation',
    ]);
    expect(
      registry.adapters.every((adapter) => adapter.schemaVersion == '1.0'),
      isTrue,
    );
    expect(
      registry.storeNames,
      containsAll(<String>{
        IndexedDbStoreNames.statusRecords,
        IndexedDbStoreNames.activityRecords,
        IndexedDbStoreNames.trainingRecords,
        IndexedDbStoreNames.customTrainingExercises,
        IndexedDbStoreNames.foodRecords,
        IndexedDbStoreNames.foodCatalogRecords,
        IndexedDbStoreNames.foodRecipeRecords,
        IndexedDbStoreNames.dailyLogConfirmations,
      }),
    );
  });

  test(
    'STATUS adapter exports, creates, verifies, and detects conflicts',
    () async {
      final source = FakeIndexedDbDatabase();
      final target = FakeIndexedDbDatabase();
      final stored = _statusRecord(weight: 70);
      source.seed(
        IndexedDbStoreNames.statusRecords,
        stored['id']! as String,
        stored,
      );
      final sourceAdapter = StatusOperationSyncAdapter(source);
      final targetAdapter = StatusOperationSyncAdapter(target);
      final records = await sourceAdapter.exportRecords();
      final package = fixturePackage(
        sections: [fixtureSection(module: 'status', records: records)],
      );
      final context = OperationSyncInspectionContext(
        package: package,
        targetOperationState: null,
        pristineTarget: false,
      );

      expect(
        (await targetAdapter.inspect(records.single, context)).disposition,
        OperationSyncRecordDisposition.create,
      );
      await target.runTransaction<void>(
        storeNames: targetAdapter.storeNames,
        mode: IndexedDbTransactionMode.readWrite,
        action: (transaction) async {
          await targetAdapter.apply(transaction, records, context);
          expect(await targetAdapter.verify(transaction, records), isTrue);
        },
      );
      expect(
        (await targetAdapter.inspect(records.single, context)).disposition,
        OperationSyncRecordDisposition.noChange,
      );

      final timestampConflict = Map<String, Object?>.from(stored)
        ..['updatedAt'] = '2026-08-02T01:00:00.000Z';
      final timestampRecord = _transfer(
        'statusRecord',
        timestampConflict,
        localDate: '2026-08-02',
      );
      final timestampInspection = await targetAdapter.inspect(
        timestampRecord,
        _context('status', [timestampRecord]),
      );
      expect(
        timestampInspection.issues.single.code,
        OperationSyncIssueCode.canonicalConflict,
      );

      final domainConflict = _transfer(
        'statusRecord',
        _statusRecord(weight: 71),
        localDate: '2026-08-02',
      );
      final domainInspection = await targetAdapter.inspect(
        domainConflict,
        _context('status', [domainConflict]),
      );
      expect(
        domainInspection.issues.single.code,
        OperationSyncIssueCode.recordIdConflict,
      );
    },
  );

  test(
    'FOOD adapter blocks missing references and applies dependencies first',
    () async {
      final database = FakeIndexedDbDatabase();
      final adapter = FoodOperationSyncAdapter(database);
      final timestamp = DateTime.utc(2026, 8, 2);
      final catalog = _catalog(timestamp).toJson();
      final recipe = _recipe(timestamp).toJson();
      final catalogRecord = _transfer(
        'foodCatalog',
        catalog,
        localDate: '2026-08-02',
        idKey: 'foodId',
      );
      final recipeRecord = _transfer(
        'foodRecipe',
        recipe,
        localDate: '2026-08-02',
        idKey: 'recipeId',
      );

      final missing = await adapter.inspect(
        recipeRecord,
        _context('food', [recipeRecord]),
      );
      expect(missing.disposition, OperationSyncRecordDisposition.conflict);
      expect(
        missing.issues.single.code,
        OperationSyncIssueCode.referenceConflict,
      );

      final records = [recipeRecord, catalogRecord];
      final context = _context('food', records);
      expect(
        (await adapter.inspect(recipeRecord, context)).disposition,
        OperationSyncRecordDisposition.create,
      );
      await database.runTransaction<void>(
        storeNames: adapter.storeNames,
        mode: IndexedDbTransactionMode.readWrite,
        action: (transaction) async {
          await adapter.apply(transaction, records, context);
          expect(await adapter.verify(transaction, records), isTrue);
        },
      );
      expect(
        await database.findById(
          IndexedDbStoreNames.foodCatalogRecords,
          _catalog(timestamp).foodId,
        ),
        isNotNull,
      );
      expect(
        await database.findById(
          IndexedDbStoreNames.foodRecipeRecords,
          _recipe(timestamp).recipeId,
        ),
        isNotNull,
      );
    },
  );

  test('TRAINING adapter validates Custom Exercise dependencies', () async {
    final database = FakeIndexedDbDatabase();
    final adapter = TrainingOperationSyncAdapter(database);
    final trainingRecord = _transfer(
      'trainingRecord',
      _trainingV2Record(),
      localDate: '2026-08-02',
    );
    final customRecord = _transfer(
      'customTrainingExercise',
      _customExerciseRecord(),
      localDate: '2026-08-02',
    );

    final missing = await adapter.inspect(
      trainingRecord,
      _context('training', [trainingRecord]),
    );
    expect(missing.disposition, OperationSyncRecordDisposition.conflict);
    expect(
      missing.issues.single.code,
      OperationSyncIssueCode.referenceConflict,
    );

    final records = [trainingRecord, customRecord];
    final context = _context('training', records);
    expect(
      (await adapter.inspect(trainingRecord, context)).disposition,
      OperationSyncRecordDisposition.create,
    );
    await database.runTransaction<void>(
      storeNames: adapter.storeNames,
      mode: IndexedDbTransactionMode.readWrite,
      action: (transaction) async {
        await adapter.apply(transaction, records, context);
        expect(await adapter.verify(transaction, records), isTrue);
      },
    );
  });

  test(
    'ACTIVITY, TRAINING v1, and Confirmation export through adapters',
    () async {
      final database = FakeIndexedDbDatabase();
      final activity = _activityRecord();
      final confirmation = _confirmationRecord();
      final training = _trainingV1Record();
      database.seed(
        IndexedDbStoreNames.activityRecords,
        activity['id']! as String,
        activity,
      );
      database.seed(
        IndexedDbStoreNames.dailyLogConfirmations,
        confirmation['id']! as String,
        confirmation,
      );
      database.seed(
        IndexedDbStoreNames.trainingRecords,
        training['id']! as String,
        training,
      );
      final registry = OperationSyncProductionRegistry.create(database);

      expect(
        await registry.adapterFor('activity')!.exportRecords(),
        hasLength(1),
      );
      expect(
        await registry.adapterFor('confirmation')!.exportRecords(),
        hasLength(1),
      );
      expect(
        await registry.adapterFor('training')!.exportRecords(),
        hasLength(1),
      );
    },
  );

  test('export builds a five-section package with verified digests', () async {
    final database = FakeIndexedDbDatabase();
    final operationState = IndexedDbOperationStateRepository(
      database,
      now: () => DateTime.utc(2026, 8, 2),
    );
    await operationState.createInitial(OperationLocalDate.parse('2026-08-02'));
    final stored = _statusRecord(weight: 70);
    database.seed(
      IndexedDbStoreNames.statusRecords,
      stored['id']! as String,
      stored,
    );
    final registry = OperationSyncProductionRegistry.create(database);
    final service = OperationTransferExportService(
      registry: registry,
      operationStateRepository: operationState,
      clock: () => DateTime.utc(2026, 8, 2, 12),
    );

    final package = await service.createPackage(
      packageId: '11111111-1111-4111-8111-111111111111',
      sourceApplicationVersion: '1.0.0+1',
    );
    final decoded = const OperationTransferCodec().decode(
      const OperationTransferCodec().encode(package),
    );

    expect(decoded.sections.map((section) => section.module), [
      'status',
      'activity',
      'training',
      'food',
      'confirmation',
    ]);
    expect(decoded.manifest.sectionCount, 5);
    expect(decoded.manifest.recordCount, 1);
    expect(decoded.sections.first.records.single.recordId, 'status:2026-08-02');
    final preview = await OperationSyncValidator(
      registry,
      operationStateRepository: operationState,
    ).preview(decoded);
    expect(preview.canApply, isTrue);
    expect(preview.noChangeCount, 1);
    expect(
      preview.issues.any(
        (issue) => issue.code == OperationSyncIssueCode.adapterUnavailable,
      ),
      isFalse,
    );
  });

  test(
    'preview reports Operation State and finalized history conflicts',
    () async {
      final historicalDatabase = FakeIndexedDbDatabase();
      historicalDatabase.seed(
        IndexedDbStoreNames.operationState,
        OperationState.canonicalId,
        OperationState(
          operationDate: OperationLocalDate.parse('2026-08-02'),
          lastFinalizedDate: OperationLocalDate.parse('2026-08-01'),
          createdAt: DateTime.utc(2026, 8, 2),
          updatedAt: DateTime.utc(2026, 8, 2),
        ).toRecord(),
      );
      final historicalRecord = _transfer(
        'statusRecord',
        _statusRecord(weight: 70, localDate: '2026-08-01'),
        localDate: '2026-08-01',
      );
      final historicalPackage = fixturePackage(
        sections: [
          fixtureSection(module: 'status', records: [historicalRecord]),
        ],
      );
      final historicalPreview = await OperationSyncValidator(
        OperationSyncProductionRegistry.create(historicalDatabase),
        operationStateRepository: IndexedDbOperationStateRepository(
          historicalDatabase,
        ),
      ).preview(historicalPackage);
      expect(
        historicalPreview.issues.any(
          (issue) =>
              issue.code == OperationSyncIssueCode.historicalFinalizedConflict,
        ),
        isTrue,
      );

      final mismatchedDatabase = FakeIndexedDbDatabase();
      mismatchedDatabase.seed(
        IndexedDbStoreNames.operationState,
        OperationState.canonicalId,
        OperationState(
          operationDate: OperationLocalDate.parse('2026-08-03'),
          createdAt: DateTime.utc(2026, 8, 2),
          updatedAt: DateTime.utc(2026, 8, 2),
        ).toRecord(),
      );
      final existing = _statusRecord(weight: 70);
      mismatchedDatabase.seed(
        IndexedDbStoreNames.statusRecords,
        existing['id']! as String,
        existing,
      );
      final mismatchPreview =
          await OperationSyncValidator(
            OperationSyncProductionRegistry.create(mismatchedDatabase),
            operationStateRepository: IndexedDbOperationStateRepository(
              mismatchedDatabase,
            ),
          ).preview(
            fixturePackage(
              sections: [
                fixtureSection(
                  module: 'status',
                  records: [
                    _transfer(
                      'statusRecord',
                      existing,
                      localDate: '2026-08-02',
                    ),
                  ],
                ),
              ],
            ),
          );
      expect(
        mismatchPreview.issues.single.code,
        OperationSyncIssueCode.operationStateConflict,
      );
    },
  );

  test(
    'production core applies atomically and verifies every section',
    () async {
      final source = FakeIndexedDbDatabase();
      final target = FakeIndexedDbDatabase();
      final stored = _statusRecord(weight: 70);
      source.seed(
        IndexedDbStoreNames.statusRecords,
        stored['id']! as String,
        stored,
      );
      final records = await StatusOperationSyncAdapter(source).exportRecords();
      final package = fixturePackage(
        sections: [fixtureSection(module: 'status', records: records)],
      );
      final stateRepository = IndexedDbOperationSyncStateRepository(
        target,
        clock: () => DateTime.utc(2026, 8, 2, 10),
      );
      final historyRepository = IndexedDbOperationSyncHistoryRepository(target);
      final core = OperationSyncCoreService(
        codec: const OperationTransferCodec(),
        validator: OperationSyncValidator(
          OperationSyncProductionRegistry.create(target),
        ),
        stateRepository: stateRepository,
        historyRepository: historyRepository,
        database: target,
        clock: () => DateTime.utc(2026, 8, 2, 10),
      );

      final preview = await core.preview(
        const OperationTransferCodec().encode(package),
      );
      expect(preview.createCount, 1);
      await core.apply(package: package, preview: preview);

      expect(
        (await stateRepository.requireCurrent()).phase,
        OperationSyncPhase.completed,
      );
      expect(await historyRepository.list(), hasLength(1));
      expect(
        await target.findById(
          IndexedDbStoreNames.statusRecords,
          'status:2026-08-02',
        ),
        isNotNull,
      );
    },
  );

  test(
    'production core rolls back every module record on apply conflict',
    () async {
      final source = FakeIndexedDbDatabase();
      final target = FakeIndexedDbDatabase();
      for (final localDate in ['2026-08-02', '2026-08-03']) {
        final stored = _statusRecord(weight: 70, localDate: localDate);
        source.seed(
          IndexedDbStoreNames.statusRecords,
          stored['id']! as String,
          stored,
        );
      }
      final records = await StatusOperationSyncAdapter(source).exportRecords();
      final package = fixturePackage(
        sections: [fixtureSection(module: 'status', records: records)],
      );
      final stateRepository = IndexedDbOperationSyncStateRepository(
        target,
        clock: () => DateTime.utc(2026, 8, 2, 10),
      );
      final core = OperationSyncCoreService(
        codec: const OperationTransferCodec(),
        validator: OperationSyncValidator(
          OperationSyncProductionRegistry.create(target),
        ),
        stateRepository: stateRepository,
        historyRepository: IndexedDbOperationSyncHistoryRepository(target),
        database: target,
        clock: () => DateTime.utc(2026, 8, 2, 10),
      );
      final preview = await core.preview(
        const OperationTransferCodec().encode(package),
      );
      final concurrent = _statusRecord(weight: 99, localDate: '2026-08-03');
      target.seed(
        IndexedDbStoreNames.statusRecords,
        concurrent['id']! as String,
        concurrent,
      );

      await expectLater(
        core.apply(package: package, preview: preview),
        throwsA(isA<OperationSyncException>()),
      );
      expect(
        await target.findById(
          IndexedDbStoreNames.statusRecords,
          'status:2026-08-02',
        ),
        isNull,
      );
      expect(
        (await stateRepository.requireCurrent()).phase,
        OperationSyncPhase.recoveryRequired,
      );
    },
  );

  test(
    'pristine apply reconstructs Operation State in the atomic write',
    () async {
      final source = FakeIndexedDbDatabase();
      final sourceOperationState = IndexedDbOperationStateRepository(
        source,
        now: () => DateTime.utc(2026, 8, 2),
      );
      await sourceOperationState.createInitial(
        OperationLocalDate.parse('2026-08-02'),
      );
      final sourceRecord = _statusRecord(weight: 70);
      source.seed(
        IndexedDbStoreNames.statusRecords,
        sourceRecord['id']! as String,
        sourceRecord,
      );
      final sourceRegistry = OperationSyncProductionRegistry.create(source);
      final package =
          await OperationTransferExportService(
            registry: sourceRegistry,
            operationStateRepository: sourceOperationState,
            clock: () => DateTime.utc(2026, 8, 2, 12),
          ).createPackage(
            packageId: '77777777-7777-4777-8777-777777777777',
            sourceApplicationVersion: '1.0.0+1',
          );

      final target = FakeIndexedDbDatabase();
      final targetOperationState = IndexedDbOperationStateRepository(
        target,
        now: () => DateTime.utc(2026, 8, 5),
      );
      await targetOperationState.createInitial(
        OperationLocalDate.parse('2026-08-05'),
      );
      final syncState = IndexedDbOperationSyncStateRepository(target);
      final targetRegistry = OperationSyncProductionRegistry.create(target);
      final core = OperationSyncCoreService(
        codec: const OperationTransferCodec(),
        validator: OperationSyncValidator(
          targetRegistry,
          operationStateRepository: targetOperationState,
        ),
        stateRepository: syncState,
        historyRepository: IndexedDbOperationSyncHistoryRepository(target),
        database: target,
        clock: () => DateTime.utc(2026, 8, 5, 1),
      );

      final preview = await core.preview(
        const OperationTransferCodec().encode(package),
      );
      expect(preview.canApply, isTrue);
      await core.apply(package: package, preview: preview);

      final reconstructed = await targetOperationState.requireCurrent();
      expect(reconstructed.operationDate.value, '2026-08-02');
      expect(reconstructed.lastFinalizedDate, isNull);
      expect(reconstructed.phase, OperationPhase.open);
      expect(reconstructed.revision, 1);
    },
  );
}

OperationSyncInspectionContext _context(
  String module,
  List<OperationTransferRecord> records,
) => OperationSyncInspectionContext(
  package: fixturePackage(
    sections: [fixtureSection(module: module, records: records)],
  ),
  targetOperationState: null,
  pristineTarget: false,
);

OperationTransferRecord _transfer(
  String recordType,
  Map<String, Object?> record, {
  required String localDate,
  String idKey = 'id',
}) => OperationSyncRecordEnvelope.transferRecord(
  recordType: recordType,
  record: record,
  recordId: record[idKey]! as String,
  recordVersion: record['recordVersion']! as int,
  localDate: localDate,
);

Map<String, Object?> _statusRecord({
  required double weight,
  String localDate = '2026-08-02',
}) => PersistedStatusRecord(
  id: 'status:$localDate',
  localDate: localDate,
  createdAt: DateTime.utc(2026, 8, 2),
  updatedAt: DateTime.utc(2026, 8, 2),
  canonicalDate: localDate,
  recordKind: StatusRecordKind.canonical,
  data: MorningData(
    date: '${localDate}T08:00:00',
    weight: weight,
    bodyFat: 18,
    sleepHours: 7,
    sleepScore: 80,
    footPain: 2,
    workType: WorkType.work,
    workStart: '09:00',
    workEnd: '18:00',
    workBreak: '1:00',
    workHours: 8,
    memo: '',
  ),
).toRecord();

FoodDataProvenance _provenance(DateTime timestamp) => FoodDataProvenance(
  sourceType: FoodProvenanceSourceType.userInput,
  capturedAt: timestamp,
);

FoodCatalogEntry _catalog(DateTime timestamp) => FoodCatalogEntry(
  foodId: '11111111-1111-4111-8111-111111111111',
  name: 'Rice',
  category: FoodCatalogCategory.ingredient,
  baseQuantity: FoodQuantityDefinition(value: 100, unit: FoodQuantityUnit.gram),
  nutrition: NutritionSnapshot(calories: 100),
  nutritionStatus: NutritionStatus.declared,
  provenance: _provenance(timestamp),
  isArchived: false,
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
      nutritionSnapshot: NutritionSnapshot(calories: 100),
      nutritionStatus: NutritionStatus.declared,
      provenanceSnapshot: _provenance(timestamp),
      sortOrder: 0,
    ),
  ],
  yieldQuantity: FoodQuantityDefinition(
    value: 1,
    unit: FoodQuantityUnit.serving,
  ),
  nutrition: NutritionSnapshot(calories: 100),
  nutritionStatus: NutritionStatus.calculated,
  provenance: _provenance(timestamp),
  isArchived: false,
  createdAt: timestamp,
  updatedAt: timestamp,
);

Map<String, Object?> _trainingV2Record() => PersistedTrainingRecord.v2(
  id: 'training:44444444-4444-4444-8444-444444444444',
  localDate: '2026-08-02',
  createdAt: DateTime.utc(2026, 8, 2),
  updatedAt: DateTime.utc(2026, 8, 2),
  data: TrainingSessionV2(
    date: '2026-08-02T08:00:00.000Z',
    exercises: [TrainingExerciseV2(exerciseName: 'My Lift', order: 1)],
  ),
).toRecord();

Map<String, Object?> _customExerciseRecord() =>
    PersistedCustomTrainingExerciseRecord(
      id: 'custom-exercise:55555555-5555-4555-8555-555555555555',
      normalizedName: 'mylift',
      createdAt: DateTime.utc(2026, 8, 2),
      updatedAt: DateTime.utc(2026, 8, 2),
      data: const CustomTrainingExercise(
        id: 'custom-exercise:55555555-5555-4555-8555-555555555555',
        name: 'My Lift',
      ),
    ).toRecord();

Map<String, Object?> _activityRecord() {
  final data = ActivityData(
    date: DateTime(2026, 8, 2),
    measuredSteps: 1000,
    createdAt: DateTime.utc(2026, 8, 2),
    updatedAt: DateTime.utc(2026, 8, 2),
  );
  return PersistedActivityRecord(
    id: 'activity:2026-08-02',
    localDate: '2026-08-02',
    createdAt: DateTime.utc(2026, 8, 2),
    updatedAt: DateTime.utc(2026, 8, 2),
    canonicalDate: '2026-08-02',
    recordKind: ActivityRecordKind.canonical,
    data: data,
  ).toRecord();
}

Map<String, Object?> _confirmationRecord() =>
    PersistedDailyLogConfirmationRecord(
      id: 'confirmation:2026-08-02',
      localDate: '2026-08-02',
      createdAt: DateTime.utc(2026, 8, 2),
      updatedAt: DateTime.utc(2026, 8, 2),
      data: DailyLogConfirmation(
        date: DateTime(2026, 8, 2),
        confirmedAt: DateTime.utc(2026, 8, 2, 23),
        morning: null,
        food: null,
        activity: null,
        training: null,
      ),
    ).toRecord();

Map<String, Object?> _trainingV1Record() => PersistedTrainingRecord(
  id: 'training:66666666-6666-4666-8666-666666666666',
  localDate: '2026-08-02',
  createdAt: DateTime.utc(2026, 8, 2),
  updatedAt: DateTime.utc(2026, 8, 2),
  data: TrainingSession(
    date: '2026-08-02T08:00:00.000Z',
    memo: '',
    exercises: const [],
  ),
).toRecord();
