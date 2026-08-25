import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/data/indexed_db/indexed_db_schema.dart';
import 'package:or_app/data/indexed_db/indexed_db_store_names.dart';

void main() {
  test('defines IndexedDB v14 canonical, draft, and compatibility stores', () {
    expect(IndexedDbSchema.databaseName, 'operation_reboot_db');
    expect(IndexedDbSchema.databaseVersion, 14);
    expect(IndexedDbSchema.keyPath, 'id');
    expect(
      IndexedDbStoreNames.canonical,
      containsAll([
        IndexedDbStoreNames.statusRecords,
        IndexedDbStoreNames.foodRecords,
        IndexedDbStoreNames.foodCatalogRecords,
        IndexedDbStoreNames.foodRecipeRecords,
        IndexedDbStoreNames.trainingRecords,
        IndexedDbStoreNames.activityRecords,
        IndexedDbStoreNames.dailyLogConfirmations,
        IndexedDbStoreNames.migrationMetadata,
        IndexedDbStoreNames.migrationQuarantine,
        IndexedDbStoreNames.customTrainingExercises,
        IndexedDbStoreNames.operationState,
        IndexedDbStoreNames.operationSyncState,
        IndexedDbStoreNames.operationSyncHistory,
        IndexedDbStoreNames.morningBriefRecords,
        IndexedDbStoreNames.dailyDebriefRecords,
        IndexedDbStoreNames.reportSyncHistory,
        IndexedDbStoreNames.trainingAnalysisReportRecords,
        IndexedDbStoreNames.periodicReportRecords,
        IndexedDbStoreNames.legacyDailySummaryRecords,
        IndexedDbStoreNames.profileRecords,
      ]),
    );
    expect(
      IndexedDbSchema.storeDefinitions
          .where((definition) => definition.legacy)
          .map((definition) => definition.name),
      IndexedDbStoreNames.legacy,
    );
    expect(
      IndexedDbSchema.storeDefinitions.map((definition) => definition.name),
      IndexedDbStoreNames.all,
    );
    expect(IndexedDbStoreNames.drafts, [
      IndexedDbStoreNames.activityDrafts,
      IndexedDbStoreNames.activeTrainingDrafts,
    ]);
  });

  test('defines date and migration indexes with required uniqueness', () {
    final definitions = {
      for (final definition in IndexedDbSchema.storeDefinitions)
        definition.name: definition,
    };

    final status = definitions[IndexedDbStoreNames.statusRecords]!;
    expect(
      status.indexes
          .singleWhere((index) => index.name == IndexedDbIndexNames.byLocalDate)
          .unique,
      isFalse,
    );
    expect(
      status.indexes
          .singleWhere(
            (index) => index.name == IndexedDbIndexNames.byCanonicalDate,
          )
          .unique,
      isTrue,
    );

    final activity = definitions[IndexedDbStoreNames.activityRecords]!;
    expect(
      activity.indexes
          .singleWhere((index) => index.name == IndexedDbIndexNames.byLocalDate)
          .unique,
      isFalse,
    );
    expect(
      activity.indexes
          .singleWhere(
            (index) => index.name == IndexedDbIndexNames.byCanonicalDate,
          )
          .unique,
      isTrue,
    );
    expect(
      definitions[IndexedDbStoreNames.dailyLogConfirmations]!.indexes
          .singleWhere((index) => index.name == IndexedDbIndexNames.byLocalDate)
          .unique,
      isTrue,
    );
    expect(
      definitions[IndexedDbStoreNames.activityDrafts]!.indexes
          .singleWhere((index) => index.name == IndexedDbIndexNames.byLocalDate)
          .unique,
      isTrue,
    );
    expect(
      definitions[IndexedDbStoreNames.activeTrainingDrafts]!.indexes
          .singleWhere(
            (index) => index.name == IndexedDbIndexNames.byOperationDate,
          )
          .unique,
      isTrue,
    );

    expect(
      definitions[IndexedDbStoreNames.foodRecords]!.indexes.single.name,
      IndexedDbIndexNames.byLocalDate,
    );
    expect(
      definitions[IndexedDbStoreNames.trainingRecords]!.indexes.single.unique,
      isFalse,
    );
    expect(
      definitions[IndexedDbStoreNames.migrationMetadata]!.indexes.single.name,
      IndexedDbIndexNames.byStatus,
    );
    expect(
      definitions[IndexedDbStoreNames.migrationQuarantine]!.indexes.map(
        (index) => index.name,
      ),
      containsAll([
        IndexedDbIndexNames.bySourceSection,
        IndexedDbIndexNames.byMigrationId,
      ]),
    );
  });

  test('v2 activity local-date index requires recreation for v3', () {
    final activity = IndexedDbSchema.storeDefinitions.singleWhere(
      (definition) => definition.name == IndexedDbStoreNames.activityRecords,
    );
    final localDate = activity.indexes.singleWhere(
      (index) => index.name == IndexedDbIndexNames.byLocalDate,
    );

    expect(
      localDate.matches(
        existingKeyPath: 'localDate',
        existingUnique: true,
        existingMultiEntry: false,
      ),
      isFalse,
    );
    expect(
      localDate.matches(
        existingKeyPath: 'localDate',
        existingUnique: false,
        existingMultiEntry: false,
      ),
      isTrue,
    );

    final canonicalDate = activity.indexes.singleWhere(
      (index) => index.name == IndexedDbIndexNames.byCanonicalDate,
    );
    expect(
      canonicalDate.matches(
        existingKeyPath: 'canonicalDate',
        existingUnique: true,
        existingMultiEntry: false,
      ),
      isTrue,
    );
  });

  test('v3 index reconciliation is idempotent for every current index', () {
    for (final store in IndexedDbSchema.storeDefinitions) {
      for (final index in store.indexes) {
        expect(
          index.matches(
            existingKeyPath: index.keyPath,
            existingUnique: index.unique,
            existingMultiEntry: index.multiEntry,
          ),
          isTrue,
          reason: '${store.name}.${index.name}',
        );
      }
    }
  });

  test('v2 to v3 upgrade keeps Activity records and reconciles indexes', () {
    final activity = IndexedDbSchema.storeDefinitions.singleWhere(
      (definition) => definition.name == IndexedDbStoreNames.activityRecords,
    );
    final records = <String, Map<String, Object?>>{
      'activity:2026-07-26': {
        'id': 'activity:2026-07-26',
        'localDate': '2026-07-26',
        'data': {'steps': 5000},
      },
    };
    final indexes = <String, IndexedDbExistingIndexDefinition>{
      IndexedDbIndexNames.byLocalDate: const IndexedDbExistingIndexDefinition(
        keyPath: 'localDate',
        unique: true,
        multiEntry: false,
      ),
    };
    var deleted = 0;
    var created = 0;

    void reconcile() {
      reconcileIndexedDbStoreIndexes(
        desiredStore: activity,
        existingIndexes: Map.unmodifiable(indexes),
        deleteIndex: (name) {
          deleted++;
          indexes.remove(name);
        },
        createIndex: (index) {
          created++;
          indexes[index.name] = IndexedDbExistingIndexDefinition(
            keyPath: index.keyPath,
            unique: index.unique,
            multiEntry: index.multiEntry,
          );
        },
      );
    }

    reconcile();

    expect(records, hasLength(1));
    expect(records.keys.single, 'activity:2026-07-26');
    expect(deleted, 1);
    expect(created, 2);
    expect(indexes[IndexedDbIndexNames.byLocalDate]?.unique, isFalse);
    expect(indexes[IndexedDbIndexNames.byCanonicalDate]?.unique, isTrue);

    deleted = 0;
    created = 0;
    reconcile();
    expect(deleted, 0);
    expect(created, 0);
    expect(records, hasLength(1));
  });

  test('v3 to v4 upgrade adds only the Activity Draft store', () {
    final v3Stores = IndexedDbStoreNames.all
        .where(
          (name) =>
              name != IndexedDbStoreNames.activityDrafts &&
              name != IndexedDbStoreNames.operationState &&
              name != IndexedDbStoreNames.foodCatalogRecords &&
              name != IndexedDbStoreNames.foodRecipeRecords &&
              name != IndexedDbStoreNames.operationSyncState &&
              name != IndexedDbStoreNames.operationSyncHistory &&
              name != IndexedDbStoreNames.morningBriefRecords &&
              name != IndexedDbStoreNames.dailyDebriefRecords &&
              name != IndexedDbStoreNames.reportSyncHistory,
        )
        .toSet();
    final addedStores = IndexedDbSchema.storeDefinitions
        .map((definition) => definition.name)
        .where((name) => name != IndexedDbStoreNames.operationState)
        .where((name) => name != IndexedDbStoreNames.foodCatalogRecords)
        .where((name) => name != IndexedDbStoreNames.foodRecipeRecords)
        .where((name) => name != IndexedDbStoreNames.operationSyncState)
        .where((name) => name != IndexedDbStoreNames.operationSyncHistory)
        .where((name) => name != IndexedDbStoreNames.morningBriefRecords)
        .where((name) => name != IndexedDbStoreNames.dailyDebriefRecords)
        .where((name) => name != IndexedDbStoreNames.reportSyncHistory)
        .where((name) => !v3Stores.contains(name))
        .toList();
    final draft = IndexedDbSchema.storeDefinitions.singleWhere(
      (definition) => definition.name == IndexedDbStoreNames.activityDrafts,
    );
    final existingRecord = <String, Object?>{
      'id': 'activity:2026-07-27',
      'localDate': '2026-07-27',
      'recordVersion': 1,
    };
    final beforeUpgrade = Map<String, Object?>.from(existingRecord);

    expect(addedStores, [IndexedDbStoreNames.activityDrafts]);
    expect(draft.keyPath, 'id');
    expect(draft.indexes, hasLength(1));
    expect(draft.indexes.single.name, IndexedDbIndexNames.byLocalDate);
    expect(draft.indexes.single.keyPath, 'localDate');
    expect(draft.indexes.single.unique, isTrue);
    expect(existingRecord, beforeUpgrade);
  });

  test('v4 to v5 upgrade adds only operation_state without indexes', () {
    final v4Stores = IndexedDbStoreNames.all
        .where(
          (name) =>
              name != IndexedDbStoreNames.operationState &&
              name != IndexedDbStoreNames.foodCatalogRecords &&
              name != IndexedDbStoreNames.foodRecipeRecords &&
              name != IndexedDbStoreNames.operationSyncState &&
              name != IndexedDbStoreNames.operationSyncHistory &&
              name != IndexedDbStoreNames.morningBriefRecords &&
              name != IndexedDbStoreNames.dailyDebriefRecords &&
              name != IndexedDbStoreNames.reportSyncHistory,
        )
        .toSet();
    final addedStores = IndexedDbSchema.storeDefinitions
        .map((definition) => definition.name)
        .where((name) => name != IndexedDbStoreNames.foodCatalogRecords)
        .where((name) => name != IndexedDbStoreNames.foodRecipeRecords)
        .where((name) => name != IndexedDbStoreNames.operationSyncState)
        .where((name) => name != IndexedDbStoreNames.operationSyncHistory)
        .where((name) => name != IndexedDbStoreNames.morningBriefRecords)
        .where((name) => name != IndexedDbStoreNames.dailyDebriefRecords)
        .where((name) => name != IndexedDbStoreNames.reportSyncHistory)
        .where((name) => !v4Stores.contains(name))
        .toList();
    final operationState = IndexedDbSchema.storeDefinitions.singleWhere(
      (definition) => definition.name == IndexedDbStoreNames.operationState,
    );
    final existingRecord = <String, Object?>{
      'id': 'activity:2026-07-31',
      'localDate': '2026-07-31',
      'recordVersion': 1,
    };
    final beforeUpgrade = Map<String, Object?>.from(existingRecord);

    expect(addedStores, [IndexedDbStoreNames.operationState]);
    expect(operationState.keyPath, 'id');
    expect(operationState.indexes, isEmpty);
    expect(existingRecord, beforeUpgrade);
  });

  test('v5 to v6 upgrade adds only Food Catalog and Recipe stores', () {
    final v5Stores = IndexedDbStoreNames.all
        .where(
          (name) =>
              name != IndexedDbStoreNames.foodCatalogRecords &&
              name != IndexedDbStoreNames.foodRecipeRecords &&
              name != IndexedDbStoreNames.operationSyncState &&
              name != IndexedDbStoreNames.operationSyncHistory &&
              name != IndexedDbStoreNames.morningBriefRecords &&
              name != IndexedDbStoreNames.dailyDebriefRecords &&
              name != IndexedDbStoreNames.reportSyncHistory,
        )
        .toSet();
    final added = IndexedDbSchema.storeDefinitions
        .where(
          (definition) =>
              definition.name != IndexedDbStoreNames.operationSyncState &&
              definition.name != IndexedDbStoreNames.operationSyncHistory &&
              definition.name != IndexedDbStoreNames.morningBriefRecords &&
              definition.name != IndexedDbStoreNames.dailyDebriefRecords &&
              definition.name != IndexedDbStoreNames.reportSyncHistory,
        )
        .where((definition) => !v5Stores.contains(definition.name))
        .toList();

    expect(added.map((definition) => definition.name), [
      IndexedDbStoreNames.foodCatalogRecords,
      IndexedDbStoreNames.foodRecipeRecords,
    ]);
    expect(added[0].keyPath, 'foodId');
    expect(added[1].keyPath, 'recipeId');
    expect(added.every((definition) => definition.indexes.isEmpty), isTrue);
  });

  test('v6 to v7 adds only Operation Sync state and history stores', () {
    final v6Stores = IndexedDbStoreNames.all
        .where(
          (name) =>
              name != IndexedDbStoreNames.operationSyncState &&
              name != IndexedDbStoreNames.operationSyncHistory &&
              name != IndexedDbStoreNames.morningBriefRecords &&
              name != IndexedDbStoreNames.dailyDebriefRecords &&
              name != IndexedDbStoreNames.reportSyncHistory,
        )
        .toSet();
    final added = IndexedDbSchema.storeDefinitions
        .where(
          (definition) =>
              definition.name != IndexedDbStoreNames.morningBriefRecords &&
              definition.name != IndexedDbStoreNames.dailyDebriefRecords &&
              definition.name != IndexedDbStoreNames.reportSyncHistory,
        )
        .where((definition) => !v6Stores.contains(definition.name))
        .toList();

    expect(added.map((definition) => definition.name), [
      IndexedDbStoreNames.operationSyncState,
      IndexedDbStoreNames.operationSyncHistory,
    ]);
    expect(added[0].keyPath, 'id');
    expect(added[0].indexes, isEmpty);
    expect(added[1].keyPath, 'operationId');
    expect(added[1].indexes.map((index) => index.name), [
      IndexedDbIndexNames.byCompletedAt,
      IndexedDbIndexNames.byResult,
    ]);
  });

  test('v7 to v8 adds only REPORT SYNC stores with required indexes', () {
    final added = IndexedDbSchema.storeDefinitions
        .where(
          (definition) => {
            IndexedDbStoreNames.morningBriefRecords,
            IndexedDbStoreNames.dailyDebriefRecords,
            IndexedDbStoreNames.reportSyncHistory,
          }.contains(definition.name),
        )
        .toList();

    expect(added.map((definition) => definition.name), [
      IndexedDbStoreNames.morningBriefRecords,
      IndexedDbStoreNames.dailyDebriefRecords,
      IndexedDbStoreNames.reportSyncHistory,
    ]);
    expect(added[0].keyPath, 'localDate');
    expect(added[1].keyPath, 'localDate');
    expect(added[0].indexes.single.name, IndexedDbIndexNames.byImportedAt);
    expect(added[1].indexes.single.name, IndexedDbIndexNames.byImportedAt);
    expect(added[2].keyPath, 'exchangeId');
    expect(added[2].indexes.map((index) => index.name), [
      IndexedDbIndexNames.byOperationDate,
      IndexedDbIndexNames.byExchangeType,
      IndexedDbIndexNames.byCompletedAt,
      IndexedDbIndexNames.byResult,
    ]);
  });

  test('v8 to v9 adds only Legacy Daily Summary with required indexes', () {
    final store = IndexedDbSchema.storeDefinitions.singleWhere(
      (definition) =>
          definition.name == IndexedDbStoreNames.legacyDailySummaryRecords,
    );
    expect(store.keyPath, 'localDate');
    expect(store.indexes.map((index) => index.name), [
      IndexedDbIndexNames.byImportedAt,
      IndexedDbIndexNames.bySourceType,
    ]);
  });

  test('v9 to v10 adds only the Profile store without indexes', () {
    final profile = IndexedDbSchema.storeDefinitions.singleWhere(
      (definition) => definition.name == IndexedDbStoreNames.profileRecords,
    );

    expect(profile.keyPath, 'id');
    expect(profile.indexes, isEmpty);
    expect(
      IndexedDbSchema.storeDefinitions.where(
        (definition) => definition.name == profile.name,
      ),
      hasLength(1),
    );
  });

  test('v11 to v12 adds only the Active Training Draft store', () {
    final v11Stores = IndexedDbStoreNames.all
        .where(
          (name) =>
              name != IndexedDbStoreNames.activeTrainingDrafts &&
              name != IndexedDbStoreNames.trainingAnalysisReportRecords,
        )
        .toSet();
    final added = IndexedDbSchema.storeDefinitions
        .where(
          (definition) =>
              definition.name !=
              IndexedDbStoreNames.trainingAnalysisReportRecords,
        )
        .where((definition) => !v11Stores.contains(definition.name))
        .toList();

    expect(added.map((definition) => definition.name), [
      IndexedDbStoreNames.activeTrainingDrafts,
    ]);
    expect(added.single.keyPath, 'id');
    expect(
      added.single.indexes.single.name,
      IndexedDbIndexNames.byOperationDate,
    );
    expect(added.single.indexes.single.keyPath, 'operationDate');
    expect(added.single.indexes.single.unique, isTrue);
  });

  test('v12 to v13 adds only the Training Analysis Report store', () {
    final v12Stores = IndexedDbStoreNames.all
        .where(
          (name) => name != IndexedDbStoreNames.trainingAnalysisReportRecords,
        )
        .toSet();
    final added = IndexedDbSchema.storeDefinitions
        .where((definition) => !v12Stores.contains(definition.name))
        .toList();
    final existingRecord = <String, Object?>{
      'id': 'training-v2:existing',
      'localDate': '2026-08-20',
      'recordVersion': 2,
    };
    final beforeUpgrade = Map<String, Object?>.from(existingRecord);

    expect(added.map((definition) => definition.name), [
      IndexedDbStoreNames.trainingAnalysisReportRecords,
    ]);
    expect(added.single.keyPath, 'targetRecordId');
    expect(added.single.indexes.map((index) => index.name), [
      IndexedDbIndexNames.byOperationDate,
      IndexedDbIndexNames.byImportedAt,
    ]);
    expect(existingRecord, beforeUpgrade);
  });

  test('v13 to v14 adds only the Periodic Report store', () {
    final v13Stores = IndexedDbStoreNames.all
        .where((name) => name != IndexedDbStoreNames.periodicReportRecords)
        .toSet();
    final added = IndexedDbSchema.storeDefinitions
        .where((definition) => !v13Stores.contains(definition.name))
        .toList();

    expect(added.map((definition) => definition.name), [
      IndexedDbStoreNames.periodicReportRecords,
    ]);
    expect(added.single.keyPath, 'id');
    expect(added.single.indexes.map((index) => index.name), [
      IndexedDbIndexNames.byReportType,
      IndexedDbIndexNames.byImportedAt,
    ]);
  });
}
