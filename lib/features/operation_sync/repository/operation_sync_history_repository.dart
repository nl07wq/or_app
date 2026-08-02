import '../models/operation_sync_history.dart';

abstract interface class OperationSyncHistoryRepository {
  Future<OperationSyncHistory> create(OperationSyncHistory history);

  Future<OperationSyncHistory?> readById(String operationId);

  Future<List<OperationSyncHistory>> list();
}
