import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/state/app_initialization_state.dart';
import 'package:or_app/data/indexed_db/indexed_db_schema.dart';
import 'package:or_app/data/indexed_db/indexed_db_store_names.dart';
import 'package:or_app/features/food/models/food_meal_master_models.dart';
import 'package:or_app/features/food/models/food_quantity_models.dart';
import 'package:or_app/features/import_export/models/backup_package.dart';
import 'package:or_app/features/import_export/models/backup_audit_package.dart';
import 'package:or_app/features/import_export/services/backup_export_service.dart';
import 'package:or_app/features/import_export/services/backup_import_service.dart';
import 'package:or_app/features/import_export/services/backup_package_codec.dart';
import 'package:or_app/features/import_export/services/backup_v14_transform.dart';
import 'package:or_app/features/operation_date/models/operation_local_date.dart';
import 'package:or_app/features/operation_date/models/operation_state.dart';
import 'package:or_app/features/operation_sync/models/operation_sync_history.dart';

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

  test(
    'v13 sync history migrates through the v15 audit archive without loss',
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
      for (var index = 0; index < 12; index += 1) {
        final history = _history(timestamp, index);
        source.seed(
          IndexedDbStoreNames.operationSyncHistory,
          history.operationId,
          history.toRecord(),
        );
      }
      final sourceExporter = BackupExportService(
        database: source,
        controller: AppInitializationController()..markReady(),
        clock: () => timestamp,
      );
      final legacyV13 = await sourceExporter.createLegacyV13();
      expect(legacyV13.schemaVersion, 13);
      expect(
        legacyV13.data[BackupSections.operationSyncHistory],
        hasLength(12),
      );

      final currentDatabase = FakeIndexedDbDatabase();
      final currentController = AppInitializationController()..markReady();
      final currentImporter = BackupImportService(
        database: currentDatabase,
        controller: currentController,
        restore: () async {},
      );
      await currentImporter.execute(
        await currentImporter.dryRun(legacyV13, BackupImportMode.replaceAll),
      );
      expect(
        await currentDatabase.findAll(IndexedDbStoreNames.operationSyncHistory),
        hasLength(12),
      );

      final v15Bundle = await BackupExportService(
        database: currentDatabase,
        controller: currentController,
        clock: () => timestamp,
      ).createCurrentBundle();
      expect(
        v15Bundle.normal.data.containsKey(BackupSections.operationSyncHistory),
        isFalse,
      );
      expect(
        v15Bundle.audit.data[BackupAuditSections.operationSyncHistory],
        hasLength(12),
      );

      final restoredPackage = BackupV14Transform.hydratePackage(
        v15Bundle.normal,
        v15Bundle.audit,
      );
      final restoredDatabase = FakeIndexedDbDatabase();
      final restoredImporter = BackupImportService(
        database: restoredDatabase,
        controller: AppInitializationController()..markReady(),
        restore: () async {},
      );
      final result = await restoredImporter.execute(
        await restoredImporter.dryRun(
          restoredPackage,
          BackupImportMode.replaceAll,
        ),
      );
      expect(result.success, isTrue);
      final restored = await restoredDatabase.findAll(
        IndexedDbStoreNames.operationSyncHistory,
      );
      expect(restored, hasLength(12));
      expect(restored.map((record) => record['operationId']).toSet(), {
        for (var index = 0; index < 12; index += 1) 'operation-history-$index',
      });
    },
  );
}

OperationSyncHistory _history(DateTime timestamp, int index) =>
    OperationSyncHistory(
      operationId: 'operation-history-$index',
      packageId: 'package-$index',
      packageDigest:
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      sourceType: 'currentAppTransfer',
      transferMode: 'fullTransfer',
      startedAt: timestamp.subtract(const Duration(minutes: 1)),
      completedAt: timestamp,
      moduleIds: const ['status'],
      recordCount: 1,
      createCount: 1,
      noChangeCount: 0,
      conflictCount: 0,
      quarantineCount: 0,
      result: OperationSyncHistoryResult.success,
      isRecoveryExecution: false,
    );

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
