import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/state/app_initialization_state.dart';
import 'package:or_app/data/indexed_db/indexed_db_store_names.dart';
import 'package:or_app/features/food/models/food_catalog_models.dart';
import 'package:or_app/features/food/models/food_provenance_models.dart';
import 'package:or_app/features/food/models/food_quantity_models.dart';
import 'package:or_app/features/food/models/nutrition_models.dart';
import 'package:or_app/features/food/models/recipe_models_v2.dart';
import 'package:or_app/features/import_export/models/backup_package.dart';
import 'package:or_app/features/import_export/services/backup_export_service.dart';
import 'package:or_app/features/import_export/services/backup_import_service.dart';
import 'package:or_app/features/import_export/services/backup_package_codec.dart';
import 'package:or_app/features/operation_date/models/operation_local_date.dart';
import 'package:or_app/features/operation_date/models/operation_state.dart';

import '../../repositories/indexed_db/fake_indexed_db_database.dart';

void main() {
  final timestamp = DateTime.utc(2026, 8, 2);
  late FakeIndexedDbDatabase database;
  late AppInitializationController controller;

  setUp(() {
    database = FakeIndexedDbDatabase();
    controller = AppInitializationController()..markReady();
    database.seed(
      IndexedDbStoreNames.operationState,
      'current',
      _state(timestamp),
    );
    final catalog = _catalog(timestamp).toJson();
    final recipe = _recipe(timestamp).toJson();
    database.seed(
      IndexedDbStoreNames.foodCatalogRecords,
      catalog['foodId']! as String,
      catalog,
    );
    database.seed(
      IndexedDbStoreNames.foodRecipeRecords,
      recipe['recipeId']! as String,
      recipe,
    );
  });

  test('Current schema exports and decodes all formal sections', () async {
    final package = await BackupExportService(
      database: database,
      controller: controller,
      clock: () => timestamp,
    ).create();

    expect(package.schemaVersion, BackupPackage.currentSchemaVersion);
    expect(package.data.keys, BackupSections.schema15);
    expect(package.data[BackupSections.foodCatalog], hasLength(1));
    expect(package.data[BackupSections.foodRecipes], hasLength(1));
    final decoded = const BackupPackageCodec().decode(
      BackupExportService.encode(package),
    );
    expect(decoded.recordCounts[BackupSections.foodCatalog], 1);
    expect(decoded.recordCounts[BackupSections.foodRecipes], 1);
    final restored = FoodCatalogEntry.fromJson(
      decoded.data[BackupSections.foodCatalog]!.single,
    );
    expect(restored.recordVersion, 2);
    expect(restored.barcodeValue, '04901234567890');
    expect(restored.packageQuantity, 500);
  });

  test('Schema 2 REPLACE ALL clears newer Food v2 stores', () async {
    final package = BackupExportService.buildPackage(
      exportId: 'schema-2',
      exportedAt: timestamp,
      source: const BackupSource(platform: 'test'),
      schemaVersion: 2,
      data: {for (final section in BackupSections.schema2) section: []},
    );
    final service = BackupImportService(
      database: database,
      controller: controller,
      restore: () async {},
    );
    final plan = await service.dryRun(package, BackupImportMode.replaceAll);

    expect((await service.execute(plan)).success, isTrue);
    expect(
      await database.findAll(IndexedDbStoreNames.foodCatalogRecords),
      isEmpty,
    );
    expect(
      await database.findAll(IndexedDbStoreNames.foodRecipeRecords),
      isEmpty,
    );
  });

  test('Schema 4 MERGE ignores Food v2 timestamp-only differences', () async {
    final exported = await BackupExportService(
      database: database,
      controller: controller,
      clock: () => timestamp,
    ).create();
    final data = {
      for (final entry in exported.data.entries)
        entry.key: [
          for (final record in entry.value) Map<String, Object?>.from(record),
        ],
    };
    data[BackupSections.foodCatalog]!.single['updatedAt'] = timestamp
        .add(const Duration(hours: 1))
        .toIso8601String();
    final package = BackupExportService.buildPackage(
      exportId: 'timestamp-only',
      exportedAt: timestamp,
      source: const BackupSource(platform: 'test'),
      data: data,
    );
    final service = BackupImportService(
      database: database,
      controller: controller,
      restore: () async {},
    );

    final plan = await service.dryRun(package, BackupImportMode.merge);
    expect(plan.hasConflicts, isFalse);
    expect(plan.sections[BackupSections.foodCatalog]!.skip, 1);
  });
}

Map<String, Object?> _state(DateTime timestamp) => OperationState(
  operationDate: OperationLocalDate.parse('2026-08-02'),
  createdAt: timestamp,
  updatedAt: timestamp,
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
  barcodeValue: '04901234567890',
  barcodeFormat: FoodBarcodeFormat.ean13,
  packageQuantity: 500,
  packageUnit: FoodQuantityUnit.gram,
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
