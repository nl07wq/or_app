import '../../../core/models/daily_log_confirmation.dart';
import '../../../data/indexed_db/indexed_db_database_contract.dart';
import '../../../data/indexed_db/indexed_db_store_names.dart';
import '../../import_export/services/backup_canonical_codec.dart';
import '../../repositories/repository_exception.dart';
import '../models/daily_log_confirmation_lifecycle_projection.dart';
import '../models/daily_log_confirmation_lifecycle.dart';
import '../models/persisted_daily_log_confirmation_record.dart';
import 'daily_log_confirmation_repository.dart';

class _DailyLogConfirmationVerificationException implements Exception {
  final String message;

  const _DailyLogConfirmationVerificationException(this.message);

  @override
  String toString() => message;
}

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
    implements
        DailyLogConfirmationStore,
        DailyLogConfirmationLifecycleStore,
        DailyLogConfirmationAuditRepository {
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
      final timestamp = _now().toUtc();
      await createV2(
        PersistedDailyLogConfirmationRecord.initialFinalizedV2(
          id: id,
          localDate: localDate,
          data: copied,
          timestamp: timestamp,
        ),
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
      final record = await findPersistedByLocalDate(localDate);
      if (record == null) return null;
      return PersistedDailyLogConfirmationRecord.copyData(record.data);
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
    } on RepositoryException {
      rethrow;
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
  Future<PersistedDailyLogConfirmationRecord?> findPersistedByLocalDate(
    String localDate,
  ) async {
    try {
      PersistedDailyLogConfirmationRecord.validateLocalDate(localDate);
      final value = await _database.findById(
        IndexedDbStoreNames.dailyLogConfirmations,
        PersistedDailyLogConfirmationRecord.canonicalId(localDate),
      );
      return value == null
          ? null
          : PersistedDailyLogConfirmationRecord.fromRecord(value);
    } on UnsupportedDailyLogSnapshotVersionException catch (error) {
      throw RepositoryException(
        operation: 'dailyLogConfirmation.findPersistedByLocalDate',
        code: RepositoryErrorCode.unsupportedRecordVersion,
        cause: error,
      );
    } on FormatException catch (error) {
      throw RepositoryException(
        operation: 'dailyLogConfirmation.findPersistedByLocalDate',
        code: RepositoryErrorCode.invalidRecord,
        cause: error,
      );
    } on RepositoryException {
      rethrow;
    } catch (error) {
      throw RepositoryException(
        operation: 'dailyLogConfirmation.findPersistedByLocalDate',
        cause: error,
      );
    }
  }

  @override
  Future<List<PersistedDailyLogConfirmationRecord>> findAllPersisted() async {
    final result = await findAllWithIssues();
    if (result.hasIssues) {
      final unsupported = result.issues.any(
        (issue) => issue.code == 'unsupportedRecordVersion',
      );
      throw RepositoryException(
        operation: 'dailyLogConfirmation.findAllPersisted',
        code: unsupported
            ? RepositoryErrorCode.unsupportedRecordVersion
            : RepositoryErrorCode.partialCorruption,
        cause: result.issues,
      );
    }
    return List.unmodifiable(result.records);
  }

  @override
  Future<DailyLogConfirmationLifecycleProjection> findLifecycleProjection(
    String localDate,
  ) async => DailyLogConfirmationLifecycleProjection.fromRecord(
    await findPersistedByLocalDate(localDate),
  );

  @override
  Future<PersistedDailyLogConfirmationRecord> updateLifecycleWithReadBack({
    required IndexedDbTransaction transaction,
    required String id,
    required int expectedRevision,
    required DailyLogConfirmationLifecycleStatus expectedLifecycle,
    required PersistedDailyLogConfirmationRecord replacement,
  }) async {
    if (replacement.id != id ||
        replacement.recordVersion !=
            PersistedDailyLogConfirmationRecord.currentRecordVersion) {
      throw const FormatException(
        'Daily Log Confirmation lifecycle replacement identity is invalid.',
      );
    }
    final existingValue = await transaction.findById(
      IndexedDbStoreNames.dailyLogConfirmations,
      id,
    );
    if (existingValue == null) {
      throw StateError('Daily Log Confirmation lifecycle target is missing.');
    }
    final existing = PersistedDailyLogConfirmationRecord.fromRecord(
      existingValue,
    );
    if (existing.projectedRevision != expectedRevision ||
        existing.projectedLifecycleStatus != expectedLifecycle) {
      throw StateError(
        'Daily Log Confirmation lifecycle precondition changed.',
      );
    }
    final serialized = replacement.toRecord();
    await transaction.put(
      IndexedDbStoreNames.dailyLogConfirmations,
      serialized,
    );
    final readBackValue = await transaction.findById(
      IndexedDbStoreNames.dailyLogConfirmations,
      id,
    );
    if (readBackValue == null) {
      throw const DailyLogConfirmationLifecycleReadBackException(
        'Daily Log Confirmation lifecycle read-back is missing.',
      );
    }
    final readBack = PersistedDailyLogConfirmationRecord.fromRecord(
      readBackValue,
    );
    if (BackupCanonicalCodec.encode(readBack.toRecord()) !=
        BackupCanonicalCodec.encode(serialized)) {
      throw const DailyLogConfirmationLifecycleReadBackException(
        'Daily Log Confirmation lifecycle read-back does not match.',
      );
    }
    return readBack;
  }

  @override
  Future<void> createV2(PersistedDailyLogConfirmationRecord record) async {
    if (record.recordVersion !=
        PersistedDailyLogConfirmationRecord.currentRecordVersion) {
      throw const RepositoryException(
        operation: 'dailyLogConfirmation.createV2',
        code: RepositoryErrorCode.unsupportedRecordVersion,
        cause: 'Only Daily Log Confirmation v2 can be saved.',
      );
    }
    final serialized = record.toRecord();
    try {
      await _database.runTransaction<void>(
        storeNames: const [IndexedDbStoreNames.dailyLogConfirmations],
        mode: IndexedDbTransactionMode.readWrite,
        action: (transaction) async {
          final existingValue = await transaction.findById(
            IndexedDbStoreNames.dailyLogConfirmations,
            record.id,
          );
          if (existingValue != null) {
            final existing = PersistedDailyLogConfirmationRecord.fromRecord(
              existingValue,
            );
            if (existing.projectedSnapshotDigest == record.snapshotDigest) {
              return;
            }
            throw const FormatException(
              'Daily Log Confirmation already exists with different data.',
            );
          }
          await transaction.put(
            IndexedDbStoreNames.dailyLogConfirmations,
            serialized,
          );
          final readBack = await transaction.findById(
            IndexedDbStoreNames.dailyLogConfirmations,
            record.id,
          );
          if (readBack == null) {
            throw const _DailyLogConfirmationVerificationException(
              'Daily Log Confirmation v2 read-back is missing.',
            );
          }
          final verified = PersistedDailyLogConfirmationRecord.fromRecord(
            readBack,
          );
          if (verified.recordVersion !=
                  PersistedDailyLogConfirmationRecord.currentRecordVersion ||
              BackupCanonicalCodec.encode(verified.toRecord()) !=
                  BackupCanonicalCodec.encode(serialized)) {
            throw const _DailyLogConfirmationVerificationException(
              'Daily Log Confirmation v2 read-back does not match.',
            );
          }
        },
      );
    } on RepositoryException {
      rethrow;
    } on UnsupportedDailyLogSnapshotVersionException catch (error) {
      throw RepositoryException(
        operation: 'dailyLogConfirmation.createV2',
        code: RepositoryErrorCode.unsupportedRecordVersion,
        cause: error,
      );
    } on FormatException catch (error) {
      throw RepositoryException(
        operation: 'dailyLogConfirmation.createV2',
        code: RepositoryErrorCode.invalidRecord,
        cause: error,
      );
    } on _DailyLogConfirmationVerificationException catch (error) {
      throw RepositoryException(
        operation: 'dailyLogConfirmation.createV2',
        code: RepositoryErrorCode.verificationFailed,
        cause: error,
      );
    } catch (error) {
      throw RepositoryException(
        operation: 'dailyLogConfirmation.createV2',
        code: RepositoryErrorCode.transactionFailed,
        cause: error,
      );
    }
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
