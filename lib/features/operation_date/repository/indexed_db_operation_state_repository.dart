import '../../../data/indexed_db/indexed_db_database_contract.dart';
import '../../../data/indexed_db/indexed_db_store_names.dart';
import '../../repositories/repository_exception.dart';
import '../models/operation_local_date.dart';
import '../models/operation_state.dart';
import 'operation_state_repository.dart';

class IndexedDbOperationStateRepository implements OperationStateRepository {
  final IndexedDbDatabase _database;
  final DateTime Function() _now;

  IndexedDbOperationStateRepository(this._database, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  @override
  Future<OperationState?> findCurrent() async {
    try {
      final records = await _database.findAll(
        IndexedDbStoreNames.operationState,
      );
      return _decodeSingle(records, allowEmpty: true);
    } on RepositoryException {
      rethrow;
    } on FormatException catch (error) {
      throw _failure(
        'operationState.findCurrent',
        RepositoryErrorCode.invalidRecord,
        error,
      );
    } catch (error) {
      throw _failure('operationState.findCurrent', null, error);
    }
  }

  @override
  Future<OperationState> requireCurrent() async {
    final state = await findCurrent();
    if (state == null) {
      throw _failure(
        'operationState.requireCurrent',
        RepositoryErrorCode.verificationFailed,
        StateError('Operation state is missing.'),
      );
    }
    return state;
  }

  @override
  Future<OperationState> createInitial(OperationLocalDate operationDate) async {
    try {
      return await _database.runTransaction<OperationState>(
        storeNames: const [IndexedDbStoreNames.operationState],
        mode: IndexedDbTransactionMode.readWrite,
        action: (transaction) async {
          final existing = await transaction.findAll(
            IndexedDbStoreNames.operationState,
          );
          if (existing.isNotEmpty) {
            throw StateError('Operation state already exists.');
          }
          final timestamp = _now().toUtc();
          final state = OperationState(
            operationDate: operationDate,
            createdAt: timestamp,
            updatedAt: timestamp,
          );
          await transaction.put(
            IndexedDbStoreNames.operationState,
            state.toRecord(),
          );
          return _verifyReadBack(transaction, state);
        },
      );
    } on RepositoryException {
      rethrow;
    } on FormatException catch (error) {
      throw _failure(
        'operationState.createInitial',
        RepositoryErrorCode.invalidRecord,
        error,
      );
    } catch (error) {
      throw _failure(
        'operationState.createInitial',
        RepositoryErrorCode.transactionFailed,
        error,
      );
    }
  }

  @override
  Future<OperationState> save(
    OperationState state, {
    required int expectedRevision,
  }) {
    return compareAndSaveRevision(state, expectedRevision: expectedRevision);
  }

  @override
  Future<OperationState> compareAndSaveRevision(
    OperationState state, {
    required int expectedRevision,
  }) async {
    try {
      return await _database.runTransaction<OperationState>(
        storeNames: const [IndexedDbStoreNames.operationState],
        mode: IndexedDbTransactionMode.readWrite,
        action: (transaction) async {
          final records = await transaction.findAll(
            IndexedDbStoreNames.operationState,
          );
          final current = _decodeSingle(records, allowEmpty: false)!;
          if (current.revision != expectedRevision) {
            throw OperationStateRevisionConflictException(
              expectedRevision: expectedRevision,
              actualRevision: current.revision,
            );
          }
          if (current.hasSameMutableContent(state)) {
            return current;
          }
          final next = OperationState(
            operationDate: state.operationDate,
            phase: state.phase,
            revision: current.revision + 1,
            lastFinalizedDate: state.lastFinalizedDate,
            activeAttempt: state.activeAttempt,
            createdAt: current.createdAt,
            updatedAt: _nextTimestamp(current.updatedAt),
          );
          await transaction.put(
            IndexedDbStoreNames.operationState,
            next.toRecord(),
          );
          return _verifyReadBack(transaction, next);
        },
      );
    } on OperationStateRevisionConflictException {
      rethrow;
    } on RepositoryException {
      rethrow;
    } on FormatException catch (error) {
      throw _failure(
        'operationState.save',
        RepositoryErrorCode.invalidRecord,
        error,
      );
    } catch (error) {
      throw _failure(
        'operationState.save',
        RepositoryErrorCode.transactionFailed,
        error,
      );
    }
  }

  @override
  Future<OperationState> validateCurrent() async => requireCurrent();

  OperationState? _decodeSingle(
    List<Map<String, Object?>> records, {
    required bool allowEmpty,
  }) {
    if (records.isEmpty) {
      if (allowEmpty) return null;
      throw const FormatException('Operation state is missing.');
    }
    if (records.length != 1) {
      throw const FormatException('Multiple operation state records exist.');
    }
    return OperationState.fromRecord(records.single);
  }

  Future<OperationState> _verifyReadBack(
    IndexedDbTransaction transaction,
    OperationState expected,
  ) async {
    final stored = await transaction.findById(
      IndexedDbStoreNames.operationState,
      OperationState.canonicalId,
    );
    if (stored == null) {
      throw const FormatException('Operation state read-back is missing.');
    }
    final actual = OperationState.fromRecord(stored);
    if (!_recordsEqual(expected.toRecord(), actual.toRecord())) {
      throw const FormatException('Operation state read-back mismatch.');
    }
    final all = await transaction.findAll(IndexedDbStoreNames.operationState);
    _decodeSingle(all, allowEmpty: false);
    return actual;
  }

  DateTime _nextTimestamp(DateTime current) {
    final now = _now().toUtc();
    return now.isAfter(current)
        ? now
        : current.add(const Duration(microseconds: 1));
  }

  bool _recordsEqual(Map<String, Object?> first, Map<String, Object?> second) {
    if (first.length != second.length) return false;
    for (final entry in first.entries) {
      final other = second[entry.key];
      if (entry.value is Map && other is Map) {
        if (!_recordsEqual(
          Map<String, Object?>.from(entry.value! as Map),
          Map<String, Object?>.from(other),
        )) {
          return false;
        }
      } else if (entry.value != other) {
        return false;
      }
    }
    return true;
  }

  RepositoryException _failure(
    String operation,
    RepositoryErrorCode? code,
    Object cause,
  ) {
    return RepositoryException(
      operation: operation,
      code: code ?? RepositoryErrorCode.unknown,
      cause: cause,
    );
  }
}
