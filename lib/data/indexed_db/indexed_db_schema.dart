import 'indexed_db_store_names.dart';

class IndexedDbIndexDefinition {
  final String name;
  final String keyPath;
  final bool unique;
  final bool multiEntry;

  const IndexedDbIndexDefinition({
    required this.name,
    required this.keyPath,
    this.unique = false,
    this.multiEntry = false,
  });
}

class IndexedDbStoreDefinition {
  final String name;
  final String keyPath;
  final List<IndexedDbIndexDefinition> indexes;
  final bool legacy;

  const IndexedDbStoreDefinition({
    required this.name,
    this.keyPath = IndexedDbSchema.keyPath,
    this.indexes = const [],
    this.legacy = false,
  });
}

abstract final class IndexedDbIndexNames {
  static const byLocalDate = 'by_local_date';
  static const byCanonicalDate = 'by_canonical_date';
  static const byStatus = 'by_status';
  static const bySourceSection = 'by_source_section';
  static const byMigrationId = 'by_migration_id';
  static const byNormalizedName = 'by_normalized_name';
}

abstract final class IndexedDbSchema {
  static const databaseName = 'operation_reboot_db';
  static const databaseVersion = 2;
  static const keyPath = 'id';

  static const storeDefinitions = [
    IndexedDbStoreDefinition(
      name: IndexedDbStoreNames.morningFacts,
      legacy: true,
    ),
    IndexedDbStoreDefinition(name: IndexedDbStoreNames.trainings, legacy: true),
    IndexedDbStoreDefinition(
      name: IndexedDbStoreNames.statusRecords,
      indexes: [
        IndexedDbIndexDefinition(
          name: IndexedDbIndexNames.byLocalDate,
          keyPath: 'localDate',
        ),
        // Only canonical STATUS records contain canonicalDate. Legacy
        // revisions omit it, allowing one canonical record per local date.
        IndexedDbIndexDefinition(
          name: IndexedDbIndexNames.byCanonicalDate,
          keyPath: 'canonicalDate',
          unique: true,
        ),
      ],
    ),
    IndexedDbStoreDefinition(
      name: IndexedDbStoreNames.foodRecords,
      indexes: [
        IndexedDbIndexDefinition(
          name: IndexedDbIndexNames.byLocalDate,
          keyPath: 'localDate',
        ),
      ],
    ),
    IndexedDbStoreDefinition(
      name: IndexedDbStoreNames.trainingRecords,
      indexes: [
        IndexedDbIndexDefinition(
          name: IndexedDbIndexNames.byLocalDate,
          keyPath: 'localDate',
        ),
      ],
    ),
    IndexedDbStoreDefinition(
      name: IndexedDbStoreNames.activityRecords,
      indexes: [
        IndexedDbIndexDefinition(
          name: IndexedDbIndexNames.byLocalDate,
          keyPath: 'localDate',
          unique: true,
        ),
      ],
    ),
    IndexedDbStoreDefinition(
      name: IndexedDbStoreNames.dailyLogConfirmations,
      indexes: [
        IndexedDbIndexDefinition(
          name: IndexedDbIndexNames.byLocalDate,
          keyPath: 'localDate',
          unique: true,
        ),
      ],
    ),
    IndexedDbStoreDefinition(
      name: IndexedDbStoreNames.migrationMetadata,
      indexes: [
        IndexedDbIndexDefinition(
          name: IndexedDbIndexNames.byStatus,
          keyPath: 'status',
        ),
      ],
    ),
    IndexedDbStoreDefinition(
      name: IndexedDbStoreNames.migrationQuarantine,
      indexes: [
        IndexedDbIndexDefinition(
          name: IndexedDbIndexNames.bySourceSection,
          keyPath: 'sourceSection',
        ),
        IndexedDbIndexDefinition(
          name: IndexedDbIndexNames.byMigrationId,
          keyPath: 'migrationId',
        ),
      ],
    ),
    IndexedDbStoreDefinition(
      name: IndexedDbStoreNames.customTrainingExercises,
      indexes: [
        IndexedDbIndexDefinition(
          name: IndexedDbIndexNames.byNormalizedName,
          keyPath: 'normalizedName',
          unique: true,
        ),
      ],
    ),
  ];

  static const objectStores = IndexedDbStoreNames.all;
}
