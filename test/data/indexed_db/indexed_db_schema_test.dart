import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/data/indexed_db/indexed_db_schema.dart';
import 'package:or_app/data/indexed_db/indexed_db_store_names.dart';

void main() {
  test('defines IndexedDB v6 canonical, draft, and compatibility stores', () {
    expect(IndexedDbSchema.databaseName, 'operation_reboot_db');
    expect(IndexedDbSchema.databaseVersion, 6);
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
    expect(IndexedDbStoreNames.drafts, [IndexedDbStoreNames.activityDrafts]);
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
              name != IndexedDbStoreNames.operationState,
        )
        .toSet();
    final addedStores = IndexedDbSchema.storeDefinitions
        .map((definition) => definition.name)
        .where((name) => name != IndexedDbStoreNames.operationState)
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
        .where((name) => name != IndexedDbStoreNames.operationState)
        .toSet();
    final addedStores = IndexedDbSchema.storeDefinitions
        .map((definition) => definition.name)
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
              name != IndexedDbStoreNames.foodRecipeRecords,
        )
        .toSet();
    final added = IndexedDbSchema.storeDefinitions
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
}
