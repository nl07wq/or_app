import '../models/operation_sync_state.dart';

abstract interface class OperationSyncStateRepository {
  Future<OperationSyncState> requireCurrent();

  Future<OperationSyncState> initializeIfAbsent();

  Future<OperationSyncState> guardedUpdate({
    required int expectedRevision,
    required OperationSyncState next,
  });
}
