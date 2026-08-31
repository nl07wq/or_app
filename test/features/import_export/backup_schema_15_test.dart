import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/state/app_initialization_state.dart';
import 'package:or_app/data/indexed_db/indexed_db_schema.dart';
import 'package:or_app/data/indexed_db/indexed_db_store_names.dart';
import 'package:or_app/features/food/models/food_meal_master_models.dart';
import 'package:or_app/features/food/models/food_quantity_models.dart';
import 'package:or_app/features/import_export/models/backup_package.dart';
import 'package:or_app/features/import_export/services/backup_export_service.dart';
import 'package:or_app/features/import_export/services/backup_import_service.dart';
import 'package:or_app/features/import_export/services/backup_package_codec.dart';
import 'package:or_app/features/operation_date/models/operation_local_date.dart';
import 'package:or_app/features/operation_date/models/operation_state.dart';

import '../../repositories/indexed_db/fake_indexed_db_database.dart';

void main() {
  test(
    'schema 15 Normal round-trip preserves Meal Master and existing stores',
    () async {
      final timestamp = DateTime.utc(2026, 9, 1);
      final source = FakeIndexedDbDatabase();
      source.seed(
        IndexedDbStoreNames.operationState,
        OperationState.canonicalId,
        OperationState(
          operationDate: OperationLocalDate.parse('2026-09-01'),
          createdAt: timestamp,
          updatedAt: timestamp,
        ).toRecord(),
      );
      source.seed(
        IndexedDbStoreNames.foodMealMasterRecords,
        _mealId,
        _meal(timestamp).toJson(),
      );

      final package = await BackupExportService(
        database: source,
        controller: AppInitializationController()..markReady(),
        clock: () => timestamp,
      ).create();
      expect(package.schemaVersion, 15);
      expect(package.databaseVersion, IndexedDbSchema.databaseVersion);
      expect(package.data[BackupSections.foodMealMasters], hasLength(1));

      final decoded = const BackupPackageCodec().decode(
        BackupExportService.encode(package),
      );
      final target = FakeIndexedDbDatabase();
      final controller = AppInitializationController()..markReady();
      final service = BackupImportService(
        database: target,
        controller: controller,
        restore: () async {},
      );
      final plan = await service.dryRun(decoded, BackupImportMode.replaceAll);
      final result = await service.execute(plan);
      expect(result.success, isTrue);
      expect(
        (await target.findAll(
          IndexedDbStoreNames.foodMealMasterRecords,
        )).single,
        _meal(timestamp).toJson(),
      );
      expect(
        await target.findAll(IndexedDbStoreNames.operationState),
        hasLength(1),
      );
    },
  );

  test(
    'schema 14 contract remains unchanged and contains no Meal section',
    () async {
      final timestamp = DateTime.utc(2026, 9, 1);
      final database = FakeIndexedDbDatabase();
      database.seed(
        IndexedDbStoreNames.operationState,
        OperationState.canonicalId,
        OperationState(
          operationDate: OperationLocalDate.parse('2026-09-01'),
          createdAt: timestamp,
          updatedAt: timestamp,
        ).toRecord(),
      );
      database.seed(
        IndexedDbStoreNames.foodMealMasterRecords,
        _mealId,
        _meal(timestamp).toJson(),
      );
      final bundle = await BackupExportService(
        database: database,
        controller: AppInitializationController()..markReady(),
        clock: () => timestamp,
      ).createV14Bundle();
      expect(bundle.normal.schemaVersion, 14);
      expect(bundle.normal.data.keys, BackupSections.schema14);
      expect(
        bundle.normal.data,
        isNot(contains(BackupSections.foodMealMasters)),
      );
    },
  );
}

FoodMealMaster _meal(DateTime timestamp) => FoodMealMaster(
  mealMasterId: _mealId,
  name: '朝食定番',
  components: [
    FoodMealMasterComponent(
      componentId: _componentId,
      componentType: FoodMealMasterComponentType.food,
      foodReferenceId: _foodId,
      quantity: FoodQuantityDefinition(value: 2, unit: FoodQuantityUnit.piece),
      sortOrder: 0,
    ),
  ],
  isArchived: false,
  createdAt: timestamp,
  updatedAt: timestamp,
);

const _mealId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const _componentId = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
const _foodId = '11111111-1111-4111-8111-111111111111';
