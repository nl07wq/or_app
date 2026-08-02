import '../../../data/indexed_db/indexed_db_database_contract.dart';
import '../adapters/activity_operation_sync_adapter.dart';
import '../adapters/confirmation_operation_sync_adapter.dart';
import '../adapters/food_operation_sync_adapter.dart';
import '../adapters/status_operation_sync_adapter.dart';
import '../adapters/training_operation_sync_adapter.dart';
import 'operation_sync_validator.dart';

abstract final class OperationSyncProductionRegistry {
  static OperationTransferAdapterRegistry create(IndexedDbDatabase database) =>
      OperationTransferAdapterRegistry(
        adapters: [
          StatusOperationSyncAdapter(database),
          ActivityOperationSyncAdapter(database),
          TrainingOperationSyncAdapter(database),
          FoodOperationSyncAdapter(database),
          ConfirmationOperationSyncAdapter(database),
        ],
      );
}
