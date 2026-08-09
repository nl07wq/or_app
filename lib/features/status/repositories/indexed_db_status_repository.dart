import '../../../core/models/morning_data.dart';
import '../../../data/indexed_db/indexed_db_database_contract.dart';
import '../../../data/indexed_db/indexed_db_store_names.dart';
import '../../repositories/repository_exception.dart';
import '../models/persisted_status_record.dart';
import 'status_repository.dart';

class IndexedDbStatusRepository implements StatusRepository {
  final IndexedDbDatabase _database;
  final DateTime Function() _now;

  IndexedDbStatusRepository(this._database, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  @override
  Future<void> save(MorningData data) async {
    final localDate = PersistedStatusRecord.localDateFromSource(data.date);
    final id = PersistedStatusRecord.canonicalId(localDate);
    try {
      await _database.runTransaction<void>(
        storeNames: const [IndexedDbStoreNames.statusRecords],
        mode: IndexedDbTransactionMode.readWrite,
        action: (transaction) async {
          final existingValue = await transaction.findById(
            IndexedDbStoreNames.statusRecords,
            id,
          );
          final existing = existingValue == null
              ? null
              : PersistedStatusRecord.fromRecord(existingValue);
          final timestamp = _now().toUtc();
          final record = PersistedStatusRecord(
            id: id,
            localDate: localDate,
            createdAt: existing?.createdAt ?? timestamp,
            updatedAt: timestamp,
            canonicalDate: localDate,
            recordKind: StatusRecordKind.canonical,
            migrationSource: existing?.migrationSource,
            data: data,
          );
          await transaction.put(
            IndexedDbStoreNames.statusRecords,
            record.toRecord(),
          );
        },
      );
    } on RepositoryException {
      rethrow;
    } on FormatException catch (error) {
      throw RepositoryException(
        operation: 'status.save',
        code: RepositoryErrorCode.invalidRecord,
        cause: error,
      );
    } catch (error) {
      throw RepositoryException(
        operation: 'status.save',
        code: RepositoryErrorCode.transactionFailed,
        cause: error,
      );
    }
  }

  @override
  Future<MorningData?> findByLocalDate(String localDate) async {
    try {
      PersistedStatusRecord.validateLocalDate(localDate);
      final value = await _database.findById(
        IndexedDbStoreNames.statusRecords,
        PersistedStatusRecord.canonicalId(localDate),
      );
      if (value == null) return null;
      return PersistedStatusRecord.fromRecord(value).data;
    } on RepositoryException {
      rethrow;
    } on FormatException catch (error) {
      throw RepositoryException(
        operation: 'status.findByLocalDate',
        code: RepositoryErrorCode.invalidRecord,
        cause: error,
      );
    } catch (error) {
      throw RepositoryException(
        operation: 'status.findByLocalDate',
        cause: error,
      );
    }
  }

  @override
  Future<MorningData?> findLatest() async {
    final result = await findAllCanonical();
    if (result.hasIssues) {
      throw RepositoryException(
        operation: 'status.findLatest',
        code: RepositoryErrorCode.partialCorruption,
        cause: result.issues,
      );
    }
    return result.records.isEmpty ? null : result.records.first.data;
  }

  @override
  Future<StatusReadResult> getRange(String startDate, String endDate) async {
    PersistedStatusRecord.validateLocalDate(startDate);
    PersistedStatusRecord.validateLocalDate(endDate);
    if (startDate.compareTo(endDate) > 0) {
      throw ArgumentError('startDate must not be after endDate.');
    }
    final result = await _findAll(includeRevisions: false);
    final records =
        result.records
            .where(
              (record) =>
                  record.localDate.compareTo(startDate) >= 0 &&
                  record.localDate.compareTo(endDate) <= 0,
            )
            .toList()
          ..sort(
            (first, second) => first.localDate.compareTo(second.localDate),
          );
    return StatusReadResult(records: records, issues: result.issues);
  }

  @override
  Future<StatusReadResult> findAllCanonical() {
    return _findAll(includeRevisions: false);
  }

  @override
  Future<StatusReadResult> findAllIncludingRevisions() {
    return _findAll(includeRevisions: true);
  }

  Future<StatusReadResult> _findAll({required bool includeRevisions}) async {
    try {
      final stored = await _database.findAll(IndexedDbStoreNames.statusRecords);
      final records = <PersistedStatusRecord>[];
      final issues = <StatusReadIssue>[];
      for (final value in stored) {
        try {
          final record = PersistedStatusRecord.fromRecord(value);
          if (includeRevisions ||
              record.recordKind == StatusRecordKind.canonical) {
            records.add(record);
          }
        } catch (error) {
          issues.add(
            StatusReadIssue(
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
          return first.recordKind == StatusRecordKind.canonical ? -1 : 1;
        }
        return first.id.compareTo(second.id);
      });
      return StatusReadResult(records: records, issues: issues);
    } catch (error) {
      throw RepositoryException(
        operation: includeRevisions
            ? 'status.findAllIncludingRevisions'
            : 'status.findAllCanonical',
        cause: error,
      );
    }
  }

  @override
  Future<void> deleteByLocalDate(String localDate) async {
    try {
      PersistedStatusRecord.validateLocalDate(localDate);
      await _database.runTransaction<void>(
        storeNames: const [IndexedDbStoreNames.statusRecords],
        mode: IndexedDbTransactionMode.readWrite,
        action: (transaction) async {
          final stored = await transaction.findAll(
            IndexedDbStoreNames.statusRecords,
          );
          for (final value in stored) {
            final record = PersistedStatusRecord.fromRecord(value);
            if (record.localDate == localDate) {
              await transaction.deleteById(
                IndexedDbStoreNames.statusRecords,
                record.id,
              );
            }
          }
        },
      );
    } on RepositoryException {
      rethrow;
    } on FormatException catch (error) {
      throw RepositoryException(
        operation: 'status.deleteByLocalDate',
        code: RepositoryErrorCode.invalidRecord,
        cause: error,
      );
    } catch (error) {
      throw RepositoryException(
        operation: 'status.deleteByLocalDate',
        code: RepositoryErrorCode.transactionFailed,
        cause: error,
      );
    }
  }

  @override
  Future<void> clear() async {
    try {
      await _database.clear(IndexedDbStoreNames.statusRecords);
    } catch (error) {
      throw RepositoryException(operation: 'status.clear', cause: error);
    }
  }
}
