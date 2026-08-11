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

  bool matches({
    required String existingKeyPath,
    required bool existingUnique,
    required bool existingMultiEntry,
  }) {
    return keyPath == existingKeyPath &&
        unique == existingUnique &&
        multiEntry == existingMultiEntry;
  }
}

class IndexedDbExistingIndexDefinition {
  final String keyPath;
  final bool unique;
  final bool multiEntry;

  const IndexedDbExistingIndexDefinition({
    required this.keyPath,
    required this.unique,
    required this.multiEntry,
  });
}

void reconcileIndexedDbStoreIndexes({
  required IndexedDbStoreDefinition desiredStore,
  required Map<String, IndexedDbExistingIndexDefinition> existingIndexes,
  required void Function(String indexName) deleteIndex,
  required void Function(IndexedDbIndexDefinition index) createIndex,
}) {
  for (final desired in desiredStore.indexes) {
    final existing = existingIndexes[desired.name];
    if (existing != null &&
        desired.matches(
          existingKeyPath: existing.keyPath,
          existingUnique: existing.unique,
          existingMultiEntry: existing.multiEntry,
        )) {
      continue;
    }
    if (existing != null) {
      deleteIndex(desired.name);
    }
    createIndex(desired);
  }
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
  static const byCompletedAt = 'by_completed_at';
  static const byResult = 'by_result';
  static const byImportedAt = 'by_imported_at';
  static const byOperationDate = 'by_operation_date';
  static const byExchangeType = 'by_exchange_type';
  static const bySourceType = 'by_source_type';
}

abstract final class IndexedDbSchema {
  static const databaseName = 'operation_reboot_db';
  static const databaseVersion = 12;
  static const oldestCompatibleDatabaseVersion = 3;
  static const keyPath = 'id';

  static bool supportsMigrationMetadataVersion(int version) =>
      version >= oldestCompatibleDatabaseVersion && version <= databaseVersion;

  static bool supportsBackupDatabaseVersion(int version) =>
      version >= oldestCompatibleDatabaseVersion && version <= databaseVersion;

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
      name: IndexedDbStoreNames.foodCatalogRecords,
      keyPath: 'foodId',
    ),
    IndexedDbStoreDefinition(
      name: IndexedDbStoreNames.foodRecipeRecords,
      keyPath: 'recipeId',
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
        ),
        IndexedDbIndexDefinition(
          name: IndexedDbIndexNames.byCanonicalDate,
          keyPath: 'canonicalDate',
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
    IndexedDbStoreDefinition(name: IndexedDbStoreNames.operationState),
    IndexedDbStoreDefinition(name: IndexedDbStoreNames.operationSyncState),
    IndexedDbStoreDefinition(
      name: IndexedDbStoreNames.operationSyncHistory,
      keyPath: 'operationId',
      indexes: [
        IndexedDbIndexDefinition(
          name: IndexedDbIndexNames.byCompletedAt,
          keyPath: 'completedAt',
        ),
        IndexedDbIndexDefinition(
          name: IndexedDbIndexNames.byResult,
          keyPath: 'result',
        ),
      ],
    ),
    IndexedDbStoreDefinition(
      name: IndexedDbStoreNames.morningBriefRecords,
      keyPath: 'localDate',
      indexes: [
        IndexedDbIndexDefinition(
          name: IndexedDbIndexNames.byImportedAt,
          keyPath: 'importedAt',
        ),
      ],
    ),
    IndexedDbStoreDefinition(
      name: IndexedDbStoreNames.dailyDebriefRecords,
      keyPath: 'localDate',
      indexes: [
        IndexedDbIndexDefinition(
          name: IndexedDbIndexNames.byImportedAt,
          keyPath: 'importedAt',
        ),
      ],
    ),
    IndexedDbStoreDefinition(
      name: IndexedDbStoreNames.reportSyncHistory,
      keyPath: 'exchangeId',
      indexes: [
        IndexedDbIndexDefinition(
          name: IndexedDbIndexNames.byOperationDate,
          keyPath: 'operationDate',
        ),
        IndexedDbIndexDefinition(
          name: IndexedDbIndexNames.byExchangeType,
          keyPath: 'exchangeType',
        ),
        IndexedDbIndexDefinition(
          name: IndexedDbIndexNames.byCompletedAt,
          keyPath: 'completedAt',
        ),
        IndexedDbIndexDefinition(
          name: IndexedDbIndexNames.byResult,
          keyPath: 'result',
        ),
      ],
    ),
    IndexedDbStoreDefinition(
      name: IndexedDbStoreNames.legacyDailySummaryRecords,
      keyPath: 'localDate',
      indexes: [
        IndexedDbIndexDefinition(
          name: IndexedDbIndexNames.byImportedAt,
          keyPath: 'importedAt',
        ),
        IndexedDbIndexDefinition(
          name: IndexedDbIndexNames.bySourceType,
          keyPath: 'sourceType',
        ),
      ],
    ),
    IndexedDbStoreDefinition(name: IndexedDbStoreNames.profileRecords),
    IndexedDbStoreDefinition(
      name: IndexedDbStoreNames.dailyAggregateRecords,
      keyPath: 'operationDate',
    ),
    IndexedDbStoreDefinition(
      name: IndexedDbStoreNames.activityDrafts,
      indexes: [
        IndexedDbIndexDefinition(
          name: IndexedDbIndexNames.byLocalDate,
          keyPath: 'localDate',
          unique: true,
        ),
      ],
    ),
    IndexedDbStoreDefinition(
      name: IndexedDbStoreNames.activeTrainingDrafts,
      indexes: [
        IndexedDbIndexDefinition(
          name: IndexedDbIndexNames.byOperationDate,
          keyPath: 'operationDate',
          unique: true,
        ),
      ],
    ),
  ];

  static const objectStores = IndexedDbStoreNames.all;
}
