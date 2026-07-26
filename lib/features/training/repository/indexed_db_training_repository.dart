import '../../../core/models/training_session.dart';
import '../../../data/indexed_db/indexed_db_database_contract.dart';
import '../../../data/indexed_db/indexed_db_store_names.dart';
import '../../repositories/repository_exception.dart';
import '../models/persisted_training_record.dart';
import 'training_record_id_generator.dart';
import 'training_session_repository.dart';

class TrainingReadIssue {
  final String? recordId;
  final String code;
  final String message;

  const TrainingReadIssue({
    required this.recordId,
    required this.code,
    required this.message,
  });
}

class TrainingReadResult {
  final List<PersistedTrainingRecord> records;
  final List<TrainingReadIssue> issues;

  TrainingReadResult({
    required Iterable<PersistedTrainingRecord> records,
    Iterable<TrainingReadIssue> issues = const [],
  }) : records = List.unmodifiable(records),
       issues = List.unmodifiable(issues);

  bool get hasIssues => issues.isNotEmpty;
}

abstract interface class TrainingAuditRepository {
  Future<TrainingReadResult> findAllWithIssues();
}

class IndexedDbTrainingSessionRepository
    implements TrainingSessionRepository, TrainingAuditRepository {
  final IndexedDbDatabase _database;
  final TrainingRecordIdGenerator _idGenerator;
  final DateTime Function() _now;

  IndexedDbTrainingSessionRepository(
    this._database, {
    TrainingRecordIdGenerator? idGenerator,
    DateTime Function()? now,
  }) : _idGenerator = idGenerator ?? TrainingRecordIdGenerator(),
       _now = now ?? DateTime.now;

  @override
  Future<TrainingRecord> saveNew(TrainingSession session) {
    return saveWithId(_idGenerator.generate(), session);
  }

  @override
  Future<TrainingRecord> saveWithId(String id, TrainingSession session) {
    return _put(id, session, operation: 'training.saveWithId');
  }

  @override
  Future<TrainingRecord> updateById(String id, TrainingSession session) async {
    final existing = await findById(id);
    if (existing == null) {
      throw RepositoryException(
        operation: 'training.updateById',
        code: RepositoryErrorCode.invalidRecord,
        cause: StateError('TRAINING record does not exist: $id'),
      );
    }
    return _put(id, session, operation: 'training.updateById');
  }

  Future<TrainingRecord> _put(
    String id,
    TrainingSession session, {
    required String operation,
  }) async {
    try {
      PersistedTrainingRecord.validateId(id);
      final copied = PersistedTrainingRecord.copySession(session);
      final localDate = PersistedTrainingRecord.localDateFromSession(copied);
      late PersistedTrainingRecord saved;
      await _database.runTransaction<void>(
        storeNames: const [IndexedDbStoreNames.trainingRecords],
        mode: IndexedDbTransactionMode.readWrite,
        action: (transaction) async {
          final existingValue = await transaction.findById(
            IndexedDbStoreNames.trainingRecords,
            id,
          );
          final existing = existingValue == null
              ? null
              : PersistedTrainingRecord.fromRecord(existingValue);
          final timestamp = _now().toUtc();
          saved = PersistedTrainingRecord(
            id: id,
            localDate: localDate,
            createdAt: existing?.createdAt ?? timestamp,
            updatedAt: timestamp,
            migrationSource: existing?.migrationSource,
            data: copied,
          );
          await transaction.put(
            IndexedDbStoreNames.trainingRecords,
            saved.toRecord(),
          );
        },
      );
      return TrainingRecord(
        id: saved.id,
        session: PersistedTrainingRecord.copySession(saved.data),
      );
    } on RepositoryException {
      rethrow;
    } on FormatException catch (error) {
      throw RepositoryException(
        operation: operation,
        code: RepositoryErrorCode.invalidRecord,
        cause: error,
      );
    } catch (error) {
      throw RepositoryException(
        operation: operation,
        code: RepositoryErrorCode.transactionFailed,
        cause: error,
      );
    }
  }

  @override
  Future<TrainingRecord?> findById(String id) async {
    try {
      PersistedTrainingRecord.validateId(id);
      final value = await _database.findById(
        IndexedDbStoreNames.trainingRecords,
        id,
      );
      if (value == null) return null;
      final record = PersistedTrainingRecord.fromRecord(value);
      return _toTrainingRecord(record);
    } on FormatException catch (error) {
      throw RepositoryException(
        operation: 'training.findById',
        code: RepositoryErrorCode.invalidRecord,
        cause: error,
      );
    } catch (error) {
      throw RepositoryException(operation: 'training.findById', cause: error);
    }
  }

  @override
  Future<List<TrainingRecord>> findAll() async {
    final result = await findAllWithIssues();
    if (result.hasIssues) {
      throw RepositoryException(
        operation: 'training.findAll',
        code: RepositoryErrorCode.partialCorruption,
        cause: result.issues,
      );
    }
    return List.unmodifiable(result.records.map(_toTrainingRecord));
  }

  @override
  Future<List<TrainingSession>> findAllSessions() async {
    final records = await findAll();
    return List.unmodifiable(records.map((record) => record.session));
  }

  @override
  Future<List<TrainingRecord>> findByLocalDate(String localDate) async {
    PersistedTrainingRecord.validateLocalDate(localDate);
    final records = await findAll();
    return List.unmodifiable(
      records.where(
        (record) =>
            PersistedTrainingRecord.localDateFromSession(record.session) ==
            localDate,
      ),
    );
  }

  @override
  Future<TrainingReadResult> findAllWithIssues() async {
    try {
      final stored = await _database.findAll(
        IndexedDbStoreNames.trainingRecords,
      );
      final records = <PersistedTrainingRecord>[];
      final issues = <TrainingReadIssue>[];
      for (final value in stored) {
        try {
          records.add(PersistedTrainingRecord.fromRecord(value));
        } catch (error) {
          issues.add(
            TrainingReadIssue(
              recordId: value['id'] is String ? value['id'] as String : null,
              code: 'invalidRecord',
              message: error.toString(),
            ),
          );
        }
      }
      records.sort((first, second) {
        final firstDate = DateTime.parse(first.data.date);
        final secondDate = DateTime.parse(second.data.date);
        final byDate = secondDate.compareTo(firstDate);
        return byDate != 0 ? byDate : first.id.compareTo(second.id);
      });
      return TrainingReadResult(records: records, issues: issues);
    } catch (error) {
      throw RepositoryException(operation: 'training.findAll', cause: error);
    }
  }

  @override
  Future<void> deleteById(String id) async {
    try {
      PersistedTrainingRecord.validateId(id);
      await _database.deleteById(IndexedDbStoreNames.trainingRecords, id);
    } catch (error) {
      throw RepositoryException(operation: 'training.deleteById', cause: error);
    }
  }

  @override
  Future<void> clear() async {
    try {
      await _database.clear(IndexedDbStoreNames.trainingRecords);
    } catch (error) {
      throw RepositoryException(operation: 'training.clear', cause: error);
    }
  }

  static TrainingRecord _toTrainingRecord(PersistedTrainingRecord record) {
    return TrainingRecord(
      id: record.id,
      session: PersistedTrainingRecord.copySession(record.data),
    );
  }
}
