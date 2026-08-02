import '../../../data/indexed_db/indexed_db_database_contract.dart';
import '../../../data/indexed_db/indexed_db_store_names.dart';
import '../models/operation_sync_issue.dart';
import '../models/operation_sync_state.dart';
import '../services/operation_transfer_canonical_service.dart';
import 'operation_sync_state_repository.dart';

class IndexedDbOperationSyncStateRepository
    implements OperationSyncStateRepository {
  final IndexedDbDatabase _database;
  final DateTime Function() _clock;

  IndexedDbOperationSyncStateRepository(
    this._database, {
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  @override
  Future<OperationSyncState> requireCurrent() async {
    final record = await _database.findById(
      IndexedDbStoreNames.operationSyncState,
      OperationSyncState.canonicalId,
    );
    if (record == null) {
      throw const OperationSyncException(
        OperationSyncIssueCode.operationStateConflict,
        'Operation Sync State is not initialized.',
      );
    }
    return OperationSyncState.fromRecord(record);
  }

  @override
  Future<OperationSyncState> initializeIfAbsent() {
    return _database.runTransaction(
      storeNames: const [IndexedDbStoreNames.operationSyncState],
      mode: IndexedDbTransactionMode.readWrite,
      action: (transaction) async {
        final existing = await transaction.findById(
          IndexedDbStoreNames.operationSyncState,
          OperationSyncState.canonicalId,
        );
        if (existing != null) return OperationSyncState.fromRecord(existing);
        final initial = OperationSyncState(
          revision: 0,
          phase: OperationSyncPhase.idle,
          updatedAt: _clock().toUtc(),
        );
        await transaction.put(
          IndexedDbStoreNames.operationSyncState,
          initial.toRecord(),
        );
        final stored = await transaction.findById(
          IndexedDbStoreNames.operationSyncState,
          OperationSyncState.canonicalId,
        );
        if (!_recordsEqual(stored, initial.toRecord())) {
          throw const OperationSyncException(
            OperationSyncIssueCode.integrityFailure,
            'Operation Sync State read-back verification failed.',
          );
        }
        return initial;
      },
    );
  }

  @override
  Future<OperationSyncState> guardedUpdate({
    required int expectedRevision,
    required OperationSyncState next,
  }) {
    return _database.runTransaction(
      storeNames: const [IndexedDbStoreNames.operationSyncState],
      mode: IndexedDbTransactionMode.readWrite,
      action: (transaction) async {
        final raw = await transaction.findById(
          IndexedDbStoreNames.operationSyncState,
          OperationSyncState.canonicalId,
        );
        if (raw == null) {
          throw const OperationSyncException(
            OperationSyncIssueCode.operationStateConflict,
            'Operation Sync State is not initialized.',
          );
        }
        final current = OperationSyncState.fromRecord(raw);
        if (current.revision != expectedRevision) {
          throw const OperationSyncException(
            OperationSyncIssueCode.operationStateConflict,
            'Operation Sync State revision does not match.',
          );
        }
        if (_sameUpdateContent(current, next)) return current;
        if (next.updatedAt.isBefore(current.updatedAt)) {
          throw const OperationSyncException(
            OperationSyncIssueCode.operationStateConflict,
            'Operation Sync State timestamp moved backwards.',
          );
        }
        final persisted = next.copyWith(revision: current.revision + 1);
        final validated = OperationSyncState.fromRecord(persisted.toRecord());
        await transaction.put(
          IndexedDbStoreNames.operationSyncState,
          validated.toRecord(),
        );
        final stored = await transaction.findById(
          IndexedDbStoreNames.operationSyncState,
          OperationSyncState.canonicalId,
        );
        if (!_recordsEqual(stored, validated.toRecord())) {
          throw const OperationSyncException(
            OperationSyncIssueCode.integrityFailure,
            'Operation Sync State read-back verification failed.',
          );
        }
        return validated;
      },
    );
  }

  static bool _sameUpdateContent(
    OperationSyncState first,
    OperationSyncState second,
  ) {
    final left = first.toRecord()
      ..remove('revision')
      ..remove('updatedAt');
    final right = second.toRecord()
      ..remove('revision')
      ..remove('updatedAt');
    return _recordsEqual(left, right);
  }

  static bool _recordsEqual(
    Map<String, Object?>? first,
    Map<String, Object?> second,
  ) {
    return first != null &&
        OperationTransferCanonicalService.encode(first) ==
            OperationTransferCanonicalService.encode(second);
  }
}
