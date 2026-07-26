import '../../../core/models/activity_data.dart';
import '../../../data/indexed_db/indexed_db_database_contract.dart';
import '../../../data/indexed_db/indexed_db_store_names.dart';
import '../../repositories/repository_exception.dart';
import '../models/persisted_activity_record.dart';
import 'activity_repository.dart';

class ActivityReadIssue {
  final String? recordId;
  final String code;
  final String message;

  const ActivityReadIssue({
    required this.recordId,
    required this.code,
    required this.message,
  });
}

class ActivityReadResult {
  final List<PersistedActivityRecord> records;
  final List<ActivityReadIssue> issues;

  ActivityReadResult({
    required Iterable<PersistedActivityRecord> records,
    Iterable<ActivityReadIssue> issues = const [],
  }) : records = List.unmodifiable(records),
       issues = List.unmodifiable(issues);

  List<ActivityData> get values =>
      List.unmodifiable(records.map((record) => record.data));

  bool get hasIssues => issues.isNotEmpty;
}

abstract interface class ActivityAuditRepository {
  Future<ActivityReadResult> findAllIncludingRevisions();
}

class IndexedDbActivityRepository
    implements ActivityRepository, ActivityAuditRepository {
  final IndexedDbDatabase _database;
  final DateTime Function() _now;

  IndexedDbActivityRepository(this._database, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  @override
  Future<void> save(ActivityData data) async {
    final localDate = PersistedActivityRecord.localDateFromDate(data.date);
    final id = PersistedActivityRecord.canonicalId(localDate);
    try {
      await _database.runTransaction<void>(
        storeNames: const [IndexedDbStoreNames.activityRecords],
        mode: IndexedDbTransactionMode.readWrite,
        action: (transaction) async {
          final existingValue = await transaction.findById(
            IndexedDbStoreNames.activityRecords,
            id,
          );
          final existing = existingValue == null
              ? null
              : PersistedActivityRecord.fromRecord(existingValue);
          final previousDate = DateTime(
            data.date.year,
            data.date.month,
            data.date.day - 1,
          );
          final previousLocalDate = PersistedActivityRecord.localDateFromDate(
            previousDate,
          );
          final previousValue = await transaction.findById(
            IndexedDbStoreNames.activityRecords,
            PersistedActivityRecord.canonicalId(previousLocalDate),
          );
          final previous = previousValue == null
              ? null
              : PersistedActivityRecord.fromRecord(previousValue);
          final officialSteps = data.stepsEntered
              ? data.officialStepsFor(previous?.data.carryOver ?? 0)
              : null;
          final timestamp = _now();
          final normalized = data.copyWith(
            id: localDate,
            officialSteps: officialSteps,
            updatedAt: timestamp,
          );
          final record = PersistedActivityRecord(
            id: id,
            localDate: localDate,
            createdAt: existing?.createdAt ?? timestamp.toUtc(),
            updatedAt: timestamp.toUtc(),
            canonicalDate: localDate,
            recordKind: ActivityRecordKind.canonical,
            migrationSource: existing?.migrationSource,
            data: normalized,
          );
          await transaction.put(
            IndexedDbStoreNames.activityRecords,
            record.toRecord(),
          );
        },
      );
    } on RepositoryException {
      rethrow;
    } on FormatException catch (error) {
      throw RepositoryException(
        operation: 'activity.save',
        code: RepositoryErrorCode.invalidRecord,
        cause: error,
      );
    } catch (error) {
      throw RepositoryException(
        operation: 'activity.save',
        code: RepositoryErrorCode.transactionFailed,
        cause: error,
      );
    }
  }

  @override
  Future<ActivityData?> findById(String id) {
    final localDate = id.startsWith('activity:')
        ? id.substring('activity:'.length)
        : id;
    return _findByLocalDate(localDate, operation: 'activity.findById');
  }

  @override
  Future<ActivityData?> findByDate(DateTime date) {
    return _findByLocalDate(
      PersistedActivityRecord.localDateFromDate(date),
      operation: 'activity.findByDate',
    );
  }

  Future<ActivityData?> _findByLocalDate(
    String localDate, {
    required String operation,
  }) async {
    try {
      PersistedActivityRecord.validateLocalDate(localDate);
      final value = await _database.findById(
        IndexedDbStoreNames.activityRecords,
        PersistedActivityRecord.canonicalId(localDate),
      );
      if (value == null) return null;
      return PersistedActivityRecord.fromRecord(value).data;
    } on RepositoryException {
      rethrow;
    } on FormatException catch (error) {
      throw RepositoryException(
        operation: operation,
        code: RepositoryErrorCode.invalidRecord,
        cause: error,
      );
    } catch (error) {
      throw RepositoryException(operation: operation, cause: error);
    }
  }

  @override
  Future<List<ActivityData>> findAll() async {
    final result = await _findAll(includeRevisions: false);
    if (result.hasIssues) {
      throw RepositoryException(
        operation: 'activity.findAll',
        code: RepositoryErrorCode.partialCorruption,
        cause: result.issues,
      );
    }
    return result.values;
  }

  @override
  Future<List<ActivityData>> getAll() => findAll();

  @override
  Future<ActivityReadResult> findAllIncludingRevisions() {
    return _findAll(includeRevisions: true);
  }

  Future<ActivityReadResult> _findAll({required bool includeRevisions}) async {
    try {
      final stored = await _database.findAll(
        IndexedDbStoreNames.activityRecords,
      );
      final records = <PersistedActivityRecord>[];
      final issues = <ActivityReadIssue>[];
      for (final value in stored) {
        try {
          final record = PersistedActivityRecord.fromRecord(value);
          if (includeRevisions ||
              record.recordKind == ActivityRecordKind.canonical) {
            records.add(record);
          }
        } catch (error) {
          issues.add(
            ActivityReadIssue(
              recordId: value['id'] is String ? value['id'] as String : null,
              code: 'invalidRecord',
              message: error.toString(),
            ),
          );
        }
      }
      records.sort((first, second) {
        final byDate = second.localDate.compareTo(first.localDate);
        if (byDate != 0) return byDate;
        if (first.recordKind != second.recordKind) {
          return first.recordKind == ActivityRecordKind.canonical ? -1 : 1;
        }
        return first.id.compareTo(second.id);
      });
      return ActivityReadResult(records: records, issues: issues);
    } catch (error) {
      throw RepositoryException(
        operation: includeRevisions
            ? 'activity.findAllIncludingRevisions'
            : 'activity.findAll',
        cause: error,
      );
    }
  }

  @override
  Future<void> delete(String id) async {
    final localDate = id.startsWith('activity:')
        ? id.substring('activity:'.length)
        : id;
    try {
      PersistedActivityRecord.validateLocalDate(localDate);
      await _database.deleteById(
        IndexedDbStoreNames.activityRecords,
        PersistedActivityRecord.canonicalId(localDate),
      );
    } on FormatException catch (error) {
      throw RepositoryException(
        operation: 'activity.delete',
        code: RepositoryErrorCode.invalidRecord,
        cause: error,
      );
    } catch (error) {
      throw RepositoryException(operation: 'activity.delete', cause: error);
    }
  }

  @override
  Future<void> deleteByDate(DateTime date) async {
    final localDate = PersistedActivityRecord.localDateFromDate(date);
    try {
      await _database.runTransaction<void>(
        storeNames: const [IndexedDbStoreNames.activityRecords],
        mode: IndexedDbTransactionMode.readWrite,
        action: (transaction) async {
          final stored = await transaction.findAll(
            IndexedDbStoreNames.activityRecords,
          );
          for (final value in stored) {
            final record = PersistedActivityRecord.fromRecord(value);
            if (record.localDate == localDate) {
              await transaction.deleteById(
                IndexedDbStoreNames.activityRecords,
                record.id,
              );
            }
          }
        },
      );
    } catch (error) {
      throw RepositoryException(
        operation: 'activity.deleteByDate',
        code: RepositoryErrorCode.transactionFailed,
        cause: error,
      );
    }
  }

  @override
  Future<void> clear() async {
    try {
      await _database.clear(IndexedDbStoreNames.activityRecords);
    } catch (error) {
      throw RepositoryException(operation: 'activity.clear', cause: error);
    }
  }
}
