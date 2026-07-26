import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/data/indexed_db/indexed_db_schema.dart';
import 'package:or_app/data/indexed_db/indexed_db_store_names.dart';

void main() {
  test('defines IndexedDB v2 canonical and compatibility stores', () {
    expect(IndexedDbSchema.databaseName, 'operation_reboot_db');
    expect(IndexedDbSchema.databaseVersion, 2);
    expect(IndexedDbSchema.keyPath, 'id');
    expect(
      IndexedDbStoreNames.canonical,
      containsAll([
        IndexedDbStoreNames.statusRecords,
        IndexedDbStoreNames.foodRecords,
        IndexedDbStoreNames.trainingRecords,
        IndexedDbStoreNames.activityRecords,
        IndexedDbStoreNames.dailyLogConfirmations,
        IndexedDbStoreNames.migrationMetadata,
        IndexedDbStoreNames.migrationQuarantine,
        IndexedDbStoreNames.customTrainingExercises,
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

    for (final storeName in [
      IndexedDbStoreNames.activityRecords,
      IndexedDbStoreNames.dailyLogConfirmations,
    ]) {
      expect(
        definitions[storeName]!.indexes
            .singleWhere(
              (index) => index.name == IndexedDbIndexNames.byLocalDate,
            )
            .unique,
        isTrue,
      );
    }

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
}
