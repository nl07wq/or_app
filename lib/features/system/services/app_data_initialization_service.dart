import '../../../data/indexed_db/indexed_db_database_contract.dart';
import '../../../data/indexed_db/indexed_db_store_names.dart';
import '../../operation_date/models/operation_local_date.dart';
import '../../operation_date/models/operation_state.dart';

class AppDataInitializationResult {
  const AppDataInitializationResult({
    required this.operationState,
    required this.clearedStoreCount,
  });

  final OperationState operationState;
  final int clearedStoreCount;
}

class AppDataInitializationService {
  AppDataInitializationService(this._database, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final IndexedDbDatabase _database;
  final DateTime Function() _clock;

  static const storesToClear = <String>[
    IndexedDbStoreNames.morningFacts,
    IndexedDbStoreNames.trainings,
    IndexedDbStoreNames.statusRecords,
    IndexedDbStoreNames.foodRecords,
    IndexedDbStoreNames.foodCatalogRecords,
    IndexedDbStoreNames.foodRecipeRecords,
    IndexedDbStoreNames.trainingRecords,
    IndexedDbStoreNames.activityRecords,
    IndexedDbStoreNames.activityDrafts,
    IndexedDbStoreNames.dailyLogConfirmations,
    IndexedDbStoreNames.migrationMetadata,
    IndexedDbStoreNames.migrationQuarantine,
    IndexedDbStoreNames.customTrainingExercises,
    IndexedDbStoreNames.operationSyncHistory,
    IndexedDbStoreNames.morningBriefRecords,
    IndexedDbStoreNames.dailyDebriefRecords,
    IndexedDbStoreNames.reportSyncHistory,
    IndexedDbStoreNames.legacyDailySummaryRecords,
    IndexedDbStoreNames.profileRecords,
  ];

  static const transactionStores = <String>[
    ...storesToClear,
    IndexedDbStoreNames.operationState,
  ];

  Future<AppDataInitializationResult> initialize() async {
    final timestamp = _clock().toUtc();
    final initialState = OperationState(
      operationDate: OperationLocalDate.fromDateTime(timestamp),
      createdAt: timestamp,
      updatedAt: timestamp,
    );

    return _database.runTransaction(
      storeNames: transactionStores,
      mode: IndexedDbTransactionMode.readWrite,
      action: (transaction) async {
        for (final storeName in storesToClear) {
          await transaction.clear(storeName);
        }
        await transaction.clear(IndexedDbStoreNames.operationState);
        await transaction.put(
          IndexedDbStoreNames.operationState,
          initialState.toRecord(),
        );

        for (final storeName in storesToClear) {
          final records = await transaction.findAll(storeName);
          if (records.isNotEmpty) {
            throw StateError(
              'App data initialization read-back failed: $storeName.',
            );
          }
        }
        final stateRecords = await transaction.findAll(
          IndexedDbStoreNames.operationState,
        );
        if (stateRecords.length != 1) {
          throw StateError(
            'App data initialization read-back failed: operation state.',
          );
        }
        final storedState = OperationState.fromRecord(stateRecords.single);
        if (!_recordsEqual(storedState.toRecord(), initialState.toRecord())) {
          throw StateError(
            'App data initialization read-back mismatch: operation state.',
          );
        }

        return AppDataInitializationResult(
          operationState: storedState,
          clearedStoreCount: storesToClear.length,
        );
      },
    );
  }

  bool _recordsEqual(Map<String, Object?> first, Map<String, Object?> second) {
    if (first.length != second.length) return false;
    for (final entry in first.entries) {
      if (second[entry.key] != entry.value) return false;
    }
    return true;
  }
}
