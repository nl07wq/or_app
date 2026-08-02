abstract final class IndexedDbStoreNames {
  // IndexedDB v1 compatibility stores. Do not delete or repurpose them.
  static const morningFacts = 'morning_facts';
  static const trainings = 'trainings';

  // IndexedDB v2 canonical stores.
  static const statusRecords = 'status_records';
  static const foodRecords = 'food_records';
  static const foodCatalogRecords = 'food_catalog_records';
  static const foodRecipeRecords = 'food_recipe_records';
  static const trainingRecords = 'training_records';
  static const activityRecords = 'activity_records';
  static const activityDrafts = 'activity_drafts';
  static const dailyLogConfirmations = 'daily_log_confirmations';
  static const migrationMetadata = 'migration_metadata';
  static const migrationQuarantine = 'migration_quarantine';
  static const customTrainingExercises = 'custom_training_exercises';
  static const operationState = 'operation_state';
  static const operationSyncState = 'operation_sync_state';
  static const operationSyncHistory = 'operation_sync_history';

  static const legacy = [morningFacts, trainings];

  static const canonical = [
    statusRecords,
    foodRecords,
    foodCatalogRecords,
    foodRecipeRecords,
    trainingRecords,
    activityRecords,
    dailyLogConfirmations,
    migrationMetadata,
    migrationQuarantine,
    customTrainingExercises,
    operationState,
    operationSyncState,
    operationSyncHistory,
  ];

  static const drafts = [activityDrafts];

  static const all = [...legacy, ...canonical, ...drafts];
}
