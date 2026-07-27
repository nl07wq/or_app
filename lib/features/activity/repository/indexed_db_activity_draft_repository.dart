import '../../../data/indexed_db/indexed_db_database_contract.dart';
import '../../../data/indexed_db/indexed_db_store_names.dart';
import '../../repositories/repository_exception.dart';
import '../models/activity_draft.dart';
import 'activity_draft_repository.dart';

class IndexedDbActivityDraftRepository implements ActivityDraftRepository {
  final IndexedDbDatabase _database;
  final DateTime Function() _now;

  IndexedDbActivityDraftRepository(this._database, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  @override
  Future<void> save(ActivityDraft draft) async {
    try {
      await _database.runTransaction<void>(
        storeNames: const [IndexedDbStoreNames.activityDrafts],
        mode: IndexedDbTransactionMode.readWrite,
        action: (transaction) async {
          final existingValue = await transaction.findById(
            IndexedDbStoreNames.activityDrafts,
            draft.id,
          );
          final existing = existingValue == null
              ? null
              : ActivityDraft.fromRecord(existingValue);
          final timestamp = _now().toUtc();
          final normalized = ActivityDraft(
            id: draft.id,
            localDate: draft.localDate,
            measuredStepsInput: draft.measuredStepsInput,
            carryOverInput: draft.carryOverInput,
            digestiveEvents: draft.digestiveEvents,
            createdAt: existing?.createdAt ?? draft.createdAt.toUtc(),
            updatedAt: timestamp,
          );
          await transaction.put(
            IndexedDbStoreNames.activityDrafts,
            normalized.toRecord(),
          );
        },
      );
    } on RepositoryException {
      rethrow;
    } on FormatException catch (error) {
      throw RepositoryException(
        operation: 'activityDraft.save',
        code: RepositoryErrorCode.invalidRecord,
        cause: error,
      );
    } catch (error) {
      throw RepositoryException(
        operation: 'activityDraft.save',
        code: RepositoryErrorCode.transactionFailed,
        cause: error,
      );
    }
  }

  @override
  Future<ActivityDraft?> findById(String id) async {
    try {
      final value = await _database.findById(
        IndexedDbStoreNames.activityDrafts,
        id,
      );
      return value == null ? null : ActivityDraft.fromRecord(value);
    } on RepositoryException {
      rethrow;
    } on FormatException catch (error) {
      throw RepositoryException(
        operation: 'activityDraft.findById',
        code: RepositoryErrorCode.invalidRecord,
        cause: error,
      );
    } catch (error) {
      throw RepositoryException(
        operation: 'activityDraft.findById',
        cause: error,
      );
    }
  }

  @override
  Future<ActivityDraft?> findByDate(DateTime date) {
    final localDate = _localDate(date);
    return findById(ActivityDraft.draftId(localDate));
  }

  @override
  Future<List<ActivityDraft>> findAll() async {
    try {
      final values = await _database.findAll(
        IndexedDbStoreNames.activityDrafts,
      );
      final drafts = [
        for (final value in values) ActivityDraft.fromRecord(value),
      ]..sort((first, second) => second.localDate.compareTo(first.localDate));
      return List.unmodifiable(drafts);
    } on RepositoryException {
      rethrow;
    } on FormatException catch (error) {
      throw RepositoryException(
        operation: 'activityDraft.findAll',
        code: RepositoryErrorCode.invalidRecord,
        cause: error,
      );
    } catch (error) {
      throw RepositoryException(
        operation: 'activityDraft.findAll',
        cause: error,
      );
    }
  }

  @override
  Future<void> deleteById(String id) async {
    try {
      await _database.deleteById(IndexedDbStoreNames.activityDrafts, id);
    } catch (error) {
      throw RepositoryException(
        operation: 'activityDraft.deleteById',
        cause: error,
      );
    }
  }

  @override
  Future<void> deleteByDate(DateTime date) {
    return deleteById(ActivityDraft.draftId(_localDate(date)));
  }

  @override
  Future<void> clear() async {
    try {
      await _database.clear(IndexedDbStoreNames.activityDrafts);
    } catch (error) {
      throw RepositoryException(operation: 'activityDraft.clear', cause: error);
    }
  }

  static String _localDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
