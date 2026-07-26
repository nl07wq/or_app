import '../../../core/models/daily_log_confirmation.dart';
import '../../../data/indexed_db/indexed_db_database_contract.dart';
import '../../../data/indexed_db/indexed_db_store_names.dart';
import '../../repositories/repository_exception.dart';
import '../models/persisted_daily_log_confirmation_record.dart';
import 'daily_log_confirmation_repository.dart';

class DailyLogConfirmationReadIssue {
  final String? recordId;
  final String code;
  final String message;

  const DailyLogConfirmationReadIssue({
    required this.recordId,
    required this.code,
    required this.message,
  });
}

class DailyLogConfirmationReadResult {
  final List<PersistedDailyLogConfirmationRecord> records;
  final List<DailyLogConfirmationReadIssue> issues;

  DailyLogConfirmationReadResult({
    required Iterable<PersistedDailyLogConfirmationRecord> records,
    Iterable<DailyLogConfirmationReadIssue> issues = const [],
  }) : records = List.unmodifiable(records),
       issues = List.unmodifiable(issues);

  bool get hasIssues => issues.isNotEmpty;
}

abstract interface class DailyLogConfirmationAuditRepository {
  Future<DailyLogConfirmationReadResult> findAllWithIssues();
}

class IndexedDbDailyLogConfirmationRepository
    implements DailyLogConfirmationStore, DailyLogConfirmationAuditRepository {
  final IndexedDbDatabase _database;
  final DateTime Function() _now;

  IndexedDbDailyLogConfirmationRepository(
    this._database, {
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  @override
  Future<void> save(DailyLogConfirmation confirmation) async {
    final copied = PersistedDailyLogConfirmationRecord.copyData(confirmation);
    final localDate = PersistedDailyLogConfirmationRecord.localDateFromDate(
      copied.date,
    );
    final id = PersistedDailyLogConfirmationRecord.canonicalId(localDate);
    try {
      await _database.runTransaction<void>(
        storeNames: const [IndexedDbStoreNames.dailyLogConfirmations],
        mode: IndexedDbTransactionMode.readWrite,
        action: (transaction) async {
          final existingValue = await transaction.findById(
            IndexedDbStoreNames.dailyLogConfirmations,
            id,
          );
          final existing = existingValue == null
              ? null
              : PersistedDailyLogConfirmationRecord.fromRecord(existingValue);
          final timestamp = _now().toUtc();
          await transaction.put(
            IndexedDbStoreNames.dailyLogConfirmations,
            PersistedDailyLogConfirmationRecord(
              id: id,
              localDate: localDate,
              createdAt: existing?.createdAt ?? timestamp,
              updatedAt: timestamp,
              migrationSource: existing?.migrationSource,
              data: copied,
            ).toRecord(),
          );
        },
      );
    } on RepositoryException {
      rethrow;
    } on UnsupportedDailyLogSnapshotVersionException catch (error) {
      throw RepositoryException(
        operation: 'dailyLogConfirmation.save',
        code: RepositoryErrorCode.unsupportedRecordVersion,
        cause: error,
      );
    } on FormatException catch (error) {
      throw RepositoryException(
        operation: 'dailyLogConfirmation.save',
        code: RepositoryErrorCode.invalidRecord,
        cause: error,
      );
    } catch (error) {
      throw RepositoryException(
        operation: 'dailyLogConfirmation.save',
        code: RepositoryErrorCode.transactionFailed,
        cause: error,
      );
    }
  }

  @override
  Future<DailyLogConfirmation?> findByLocalDate(String localDate) async {
    try {
      PersistedDailyLogConfirmationRecord.validateLocalDate(localDate);
      final value = await _database.findById(
        IndexedDbStoreNames.dailyLogConfirmations,
        PersistedDailyLogConfirmationRecord.canonicalId(localDate),
      );
      if (value == null) return null;
      return PersistedDailyLogConfirmationRecord.copyData(
        PersistedDailyLogConfirmationRecord.fromRecord(value).data,
      );
    } on UnsupportedDailyLogSnapshotVersionException catch (error) {
      throw RepositoryException(
        operation: 'dailyLogConfirmation.findByLocalDate',
        code: RepositoryErrorCode.unsupportedRecordVersion,
        cause: error,
      );
    } on FormatException catch (error) {
      throw RepositoryException(
        operation: 'dailyLogConfirmation.findByLocalDate',
        code: RepositoryErrorCode.invalidRecord,
        cause: error,
      );
    } catch (error) {
      throw RepositoryException(
        operation: 'dailyLogConfirmation.findByLocalDate',
        cause: error,
      );
    }
  }

  @override
  Future<DailyLogConfirmation?> findLatest() async {
    final records = await findAll();
    return records.isEmpty ? null : records.first;
  }

  @override
  Future<List<DailyLogConfirmation>> findAll() async {
    final result = await findAllWithIssues();
    if (result.hasIssues) {
      final unsupported = result.issues.any(
        (issue) => issue.code == 'unsupportedRecordVersion',
      );
      throw RepositoryException(
        operation: 'dailyLogConfirmation.findAll',
        code: unsupported
            ? RepositoryErrorCode.unsupportedRecordVersion
            : RepositoryErrorCode.partialCorruption,
        cause: result.issues,
      );
    }
    return List.unmodifiable(
      result.records.map(
        (record) => PersistedDailyLogConfirmationRecord.copyData(record.data),
      ),
    );
  }

  @override
  Future<DailyLogConfirmationReadResult> findAllWithIssues() async {
    try {
      final stored = await _database.findAll(
        IndexedDbStoreNames.dailyLogConfirmations,
      );
      final records = <PersistedDailyLogConfirmationRecord>[];
      final issues = <DailyLogConfirmationReadIssue>[];
      for (final value in stored) {
        try {
          records.add(PersistedDailyLogConfirmationRecord.fromRecord(value));
        } on UnsupportedDailyLogSnapshotVersionException catch (error) {
          issues.add(
            DailyLogConfirmationReadIssue(
              recordId: value['id'] is String ? value['id'] as String : null,
              code: 'unsupportedRecordVersion',
              message: error.toString(),
            ),
          );
        } catch (error) {
          issues.add(
            DailyLogConfirmationReadIssue(
              recordId: value['id'] is String ? value['id'] as String : null,
              code: 'invalidRecord',
              message: error.toString(),
            ),
          );
        }
      }
      records.sort((first, second) {
        final byDate = second.localDate.compareTo(first.localDate);
        return byDate != 0 ? byDate : first.id.compareTo(second.id);
      });
      return DailyLogConfirmationReadResult(records: records, issues: issues);
    } catch (error) {
      throw RepositoryException(
        operation: 'dailyLogConfirmation.findAll',
        cause: error,
      );
    }
  }

  @override
  Future<bool> isConfirmed(String localDate) async {
    return await findByLocalDate(localDate) != null;
  }

  @override
  Future<void> deleteByLocalDate(String localDate) async {
    try {
      PersistedDailyLogConfirmationRecord.validateLocalDate(localDate);
      await _database.deleteById(
        IndexedDbStoreNames.dailyLogConfirmations,
        PersistedDailyLogConfirmationRecord.canonicalId(localDate),
      );
    } on FormatException catch (error) {
      throw RepositoryException(
        operation: 'dailyLogConfirmation.deleteByLocalDate',
        code: RepositoryErrorCode.invalidRecord,
        cause: error,
      );
    } catch (error) {
      throw RepositoryException(
        operation: 'dailyLogConfirmation.deleteByLocalDate',
        cause: error,
      );
    }
  }

  @override
  Future<void> clear() async {
    try {
      await _database.clear(IndexedDbStoreNames.dailyLogConfirmations);
    } catch (error) {
      throw RepositoryException(
        operation: 'dailyLogConfirmation.clear',
        cause: error,
      );
    }
  }
}
