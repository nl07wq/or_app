import '../../../data/indexed_db/indexed_db_database_contract.dart';
import '../../../data/indexed_db/indexed_db_store_names.dart';
import '../models/operation_sync_history.dart';
import '../models/operation_sync_issue.dart';
import '../services/operation_transfer_canonical_service.dart';
import 'operation_sync_history_repository.dart';

class IndexedDbOperationSyncHistoryRepository
    implements OperationSyncHistoryRepository {
  final IndexedDbDatabase _database;

  const IndexedDbOperationSyncHistoryRepository(this._database);

  @override
  Future<OperationSyncHistory> create(OperationSyncHistory history) {
    return _database.runTransaction(
      storeNames: const [IndexedDbStoreNames.operationSyncHistory],
      mode: IndexedDbTransactionMode.readWrite,
      action: (transaction) async {
        final existing = await transaction.findById(
          IndexedDbStoreNames.operationSyncHistory,
          history.operationId,
        );
        if (existing != null) {
          if (_equal(existing, history.toRecord())) return history;
          throw const OperationSyncException(
            OperationSyncIssueCode.operationStateConflict,
            'Operation Sync history is immutable.',
          );
        }
        final validated = OperationSyncHistory.fromRecord(history.toRecord());
        await transaction.put(
          IndexedDbStoreNames.operationSyncHistory,
          validated.toRecord(),
        );
        final stored = await transaction.findById(
          IndexedDbStoreNames.operationSyncHistory,
          history.operationId,
        );
        if (!_equal(stored, validated.toRecord())) {
          throw const OperationSyncException(
            OperationSyncIssueCode.integrityFailure,
            'Operation Sync history read-back verification failed.',
          );
        }
        return validated;
      },
    );
  }

  @override
  Future<OperationSyncHistory?> readById(String operationId) async {
    final record = await _database.findById(
      IndexedDbStoreNames.operationSyncHistory,
      operationId,
    );
    return record == null ? null : OperationSyncHistory.fromRecord(record);
  }

  @override
  Future<List<OperationSyncHistory>> list() async {
    final values = [
      for (final record in await _database.findAll(
        IndexedDbStoreNames.operationSyncHistory,
      ))
        OperationSyncHistory.fromRecord(record),
    ];
    values.sort((a, b) {
      final byDate = b.completedAt.compareTo(a.completedAt);
      return byDate != 0 ? byDate : a.operationId.compareTo(b.operationId);
    });
    return List.unmodifiable(values);
  }

  static bool _equal(
    Map<String, Object?>? first,
    Map<String, Object?> second,
  ) =>
      first != null &&
      OperationTransferCanonicalService.encode(first) ==
          OperationTransferCanonicalService.encode(second);
}
