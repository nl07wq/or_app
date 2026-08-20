import '../../../data/indexed_db/indexed_db_database_contract.dart';
import '../../../data/indexed_db/indexed_db_store_names.dart';
import '../../repositories/repository_exception.dart';
import '../models/active_training_draft.dart';
import 'active_training_draft_repository.dart';

class IndexedDbActiveTrainingDraftRepository
    implements ActiveTrainingDraftRepository {
  final IndexedDbDatabase _database;

  const IndexedDbActiveTrainingDraftRepository(this._database);

  @override
  Future<void> save(ActiveTrainingDraft draft) async {
    try {
      await _database.runTransaction<void>(
        storeNames: const [IndexedDbStoreNames.activeTrainingDrafts],
        mode: IndexedDbTransactionMode.readWrite,
        action: (transaction) async {
          await transaction.put(
            IndexedDbStoreNames.activeTrainingDrafts,
            draft.toRecord(),
          );
          final readBack = await transaction.findById(
            IndexedDbStoreNames.activeTrainingDrafts,
            draft.id,
          );
          if (readBack == null || !_recordsEqual(draft.toRecord(), readBack)) {
            throw const FormatException(
              'Active Training Draft read-back failed.',
            );
          }
        },
      );
    } on RepositoryException {
      rethrow;
    } on FormatException catch (error) {
      throw RepositoryException(
        operation: 'activeTrainingDraft.save',
        code: RepositoryErrorCode.invalidRecord,
        cause: error,
      );
    } catch (error) {
      throw RepositoryException(
        operation: 'activeTrainingDraft.save',
        code: RepositoryErrorCode.transactionFailed,
        cause: error,
      );
    }
  }

  @override
  Future<ActiveTrainingDraft?> findByOperationDate(String operationDate) async {
    try {
      final value = await _database.findById(
        IndexedDbStoreNames.activeTrainingDrafts,
        ActiveTrainingDraft.draftId(operationDate),
      );
      return value == null ? null : ActiveTrainingDraft.fromRecord(value);
    } on RepositoryException {
      rethrow;
    } on FormatException catch (error) {
      throw RepositoryException(
        operation: 'activeTrainingDraft.findByOperationDate',
        code: RepositoryErrorCode.invalidRecord,
        cause: error,
      );
    } catch (error) {
      throw RepositoryException(
        operation: 'activeTrainingDraft.findByOperationDate',
        cause: error,
      );
    }
  }

  @override
  Future<void> deleteByOperationDate(String operationDate) async {
    try {
      await _database.deleteById(
        IndexedDbStoreNames.activeTrainingDrafts,
        ActiveTrainingDraft.draftId(operationDate),
      );
    } catch (error) {
      throw RepositoryException(
        operation: 'activeTrainingDraft.deleteByOperationDate',
        cause: error,
      );
    }
  }
}

bool _recordsEqual(Map<String, Object?> left, Map<String, Object?> right) {
  if (left.length != right.length) return false;
  for (final entry in left.entries) {
    if (!right.containsKey(entry.key) ||
        !_valuesEqual(entry.value, right[entry.key])) {
      return false;
    }
  }
  return true;
}

bool _valuesEqual(Object? left, Object? right) {
  if (left is Map && right is Map) {
    return _recordsEqual(
      Map<String, Object?>.from(left),
      Map<String, Object?>.from(right),
    );
  }
  if (left is List && right is List) {
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index++) {
      if (!_valuesEqual(left[index], right[index])) return false;
    }
    return true;
  }
  return left == right;
}
