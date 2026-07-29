import '../../../core/models/training_session.dart';
import '../../../data/indexed_db/indexed_db_database_contract.dart';
import '../../../data/indexed_db/indexed_db_store_names.dart';
import '../../repositories/repository_exception.dart';
import '../migration/training_record_lineage.dart';
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
    final existing = await findRecordById(id);
    if (existing == null) {
      throw RepositoryException(
        operation: 'training.updateById',
        code: RepositoryErrorCode.invalidRecord,
        cause: StateError('TRAINING record does not exist: $id'),
      );
    }
    _requireEditable(existing, operation: 'training.updateById');
    return _put(id, session, operation: 'training.updateById');
  }

  Future<TrainingRecord> _put(
    String id,
    TrainingSession session, {
    required String operation,
  }) async {
    try {
      if (TrainingRecordReadModel.isReadOnlyProjection(session)) {
        throw RepositoryException(
          operation: operation,
          code: RepositoryErrorCode.invalidRecord,
          cause: StateError(
            'TRAINING v2 compatibility projection is read-only.',
          ),
        );
      }
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
          if (existing != null) {
            final superseded = await _isSupersededInTransaction(
              transaction,
              existing,
            );
            _requireEditable(
              _toReadModel(existing, isSuperseded: superseded),
              operation: operation,
            );
          }
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
      return TrainingRecord.fromReadModel(_toReadModel(saved));
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
    final record = await findRecordById(id);
    return record == null ? null : TrainingRecord.fromReadModel(record);
  }

  @override
  Future<TrainingRecordReadModel?> findRecordById(String id) async {
    try {
      PersistedTrainingRecord.validateId(id);
      final value = await _database.findById(
        IndexedDbStoreNames.trainingRecords,
        id,
      );
      if (value == null) return null;
      final record = PersistedTrainingRecord.fromRecord(value);
      final superseded = await _isSuperseded(record);
      return _toReadModel(record, isSuperseded: superseded);
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
    final records = await findAllRecords();
    return List.unmodifiable(records.map(TrainingRecord.fromReadModel));
  }

  @override
  Future<List<TrainingRecordReadModel>> findAllRecords() async {
    final result = await _readAllWithIssues();
    if (result.hasIssues) {
      throw RepositoryException(
        operation: 'training.findAll',
        code: RepositoryErrorCode.partialCorruption,
        cause: result.issues,
      );
    }
    final models = _toReadModelsWithLineage(result.records);
    return List.unmodifiable(
      models.where((record) => record is! _SupersededTrainingRecordReadModel),
    );
  }

  Future<List<TrainingRecordReadModel>>
  findAllRecordsIncludingSuperseded() async {
    final result = await _readAllWithIssues();
    if (result.hasIssues) {
      throw RepositoryException(
        operation: 'training.findAllIncludingSuperseded',
        code: RepositoryErrorCode.partialCorruption,
        cause: result.issues,
      );
    }
    return List.unmodifiable(_toReadModelsWithLineage(result.records));
  }

  @override
  Future<List<TrainingSession>> findAllSessions() async {
    final records = await findAllRecordsIncludingSuperseded();
    return List.unmodifiable(
      records
          .where((record) => record.recordVersion == 1)
          .map((record) => PersistedTrainingRecord.copySession(record.v1Data!)),
    );
  }

  @override
  Future<List<TrainingRecord>> findByLocalDate(String localDate) async {
    final records = await findRecordsByLocalDate(localDate);
    return List.unmodifiable(records.map(TrainingRecord.fromReadModel));
  }

  @override
  Future<List<TrainingRecordReadModel>> findRecordsByLocalDate(
    String localDate,
  ) async {
    PersistedTrainingRecord.validateLocalDate(localDate);
    final records = await findAllRecords();
    return List.unmodifiable(
      records.where((record) => record.localDate == localDate),
    );
  }

  @override
  Future<TrainingReadResult> findAllWithIssues() async {
    final result = await _readAllWithIssues();
    final superseded = _supersededSourceIds(result.records);
    return TrainingReadResult(
      records: result.records.where(
        (record) => !superseded.contains(record.id),
      ),
      issues: result.issues,
    );
  }

  Future<TrainingReadResult> findAllWithIssuesIncludingSuperseded() {
    return _readAllWithIssues();
  }

  Future<TrainingReadResult> _readAllWithIssues() async {
    try {
      final stored = await _database.findAll(
        IndexedDbStoreNames.trainingRecords,
      );
      final records = <PersistedTrainingRecord>[];
      final issues = <TrainingReadIssue>[];
      for (final value in stored) {
        try {
          final record = PersistedTrainingRecord.fromRecord(value);
          if (!TrainingRecordLineage.hasValidKnownLineage(record)) {
            throw const FormatException(
              'TRAINING migration lineage is inconsistent.',
            );
          }
          records.add(record);
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
        final firstDate =
            DateTime.tryParse(first.sessionDate) ??
            DateTime.tryParse(first.localDate) ??
            first.createdAt;
        final secondDate =
            DateTime.tryParse(second.sessionDate) ??
            DateTime.tryParse(second.localDate) ??
            second.createdAt;
        final byDate = secondDate.compareTo(firstDate);
        if (byDate != 0) return byDate;
        final byUpdatedAt = second.updatedAt.compareTo(first.updatedAt);
        return byUpdatedAt != 0 ? byUpdatedAt : first.id.compareTo(second.id);
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
      final record = await findRecordById(id);
      if (record != null) {
        _requireEditable(record, operation: 'training.deleteById');
      }
      await _database.deleteById(IndexedDbStoreNames.trainingRecords, id);
    } on RepositoryException {
      rethrow;
    } catch (error) {
      throw RepositoryException(operation: 'training.deleteById', cause: error);
    }
  }

  @override
  Future<void> clear() async {
    try {
      final records = await findAllRecords();
      if (records.any((record) => !record.isEditable)) {
        throw StateError('TRAINING v2 records are read-only.');
      }
      await _database.clear(IndexedDbStoreNames.trainingRecords);
    } on RepositoryException {
      rethrow;
    } catch (error) {
      throw RepositoryException(operation: 'training.clear', cause: error);
    }
  }

  static TrainingRecordReadModel _toReadModel(
    PersistedTrainingRecord record, {
    bool isSuperseded = false,
  }) {
    final source = record.migrationSource?.toJson();
    if (record.recordVersion == 1) {
      if (isSuperseded) {
        return _SupersededTrainingRecordReadModel(
          id: record.id,
          localDate: record.localDate,
          createdAt: record.createdAt,
          updatedAt: record.updatedAt,
          migrationSource: source,
          data: record.data,
        );
      }
      return TrainingRecordReadModel.v1(
        id: record.id,
        localDate: record.localDate,
        createdAt: record.createdAt,
        updatedAt: record.updatedAt,
        migrationSource: source,
        data: record.data,
      );
    }
    return TrainingRecordReadModel.v2(
      id: record.id,
      localDate: record.localDate,
      createdAt: record.createdAt,
      updatedAt: record.updatedAt,
      migrationSource: source,
      data: record.dataV2,
    );
  }

  static List<TrainingRecordReadModel> _toReadModelsWithLineage(
    Iterable<PersistedTrainingRecord> records,
  ) {
    final values = records.toList();
    final superseded = _supersededSourceIds(values);
    return [
      for (final record in values)
        _toReadModel(record, isSuperseded: superseded.contains(record.id)),
    ];
  }

  static Set<String> _supersededSourceIds(
    Iterable<PersistedTrainingRecord> records,
  ) {
    final sourceIds = <String>{};
    for (final record in records) {
      final sourceId = TrainingRecordLineage.supersededV1Id(record);
      if (sourceId != null) {
        sourceIds.add(sourceId);
      }
    }
    return sourceIds;
  }

  Future<bool> _isSuperseded(PersistedTrainingRecord record) async {
    if (record.recordVersion != 1) return false;
    final targetId = TrainingRecordLineage.shadowIdForV1(record.id);
    final value = await _database.findById(
      IndexedDbStoreNames.trainingRecords,
      targetId,
    );
    if (value == null) return false;
    try {
      return TrainingRecordLineage.isShadowOf(
        PersistedTrainingRecord.fromRecord(value),
        record.id,
      );
    } catch (_) {
      return false;
    }
  }

  static Future<bool> _isSupersededInTransaction(
    IndexedDbTransaction transaction,
    PersistedTrainingRecord record,
  ) async {
    if (record.recordVersion != 1) return false;
    final value = await transaction.findById(
      IndexedDbStoreNames.trainingRecords,
      TrainingRecordLineage.shadowIdForV1(record.id),
    );
    if (value == null) return false;
    try {
      return TrainingRecordLineage.isShadowOf(
        PersistedTrainingRecord.fromRecord(value),
        record.id,
      );
    } catch (_) {
      return false;
    }
  }

  static void _requireEditable(
    TrainingRecordReadModel record, {
    required String operation,
  }) {
    if (!record.isEditable) {
      throw RepositoryException(
        operation: operation,
        code: RepositoryErrorCode.invalidRecord,
        cause: StateError(
          'TRAINING recordVersion ${record.recordVersion} is read-only.',
        ),
      );
    }
  }
}

class _SupersededTrainingRecordReadModel extends TrainingRecordReadModel {
  _SupersededTrainingRecordReadModel({
    required super.id,
    required super.localDate,
    required super.createdAt,
    required super.updatedAt,
    required super.migrationSource,
    required super.data,
  }) : super.v1();

  @override
  bool get isEditable => false;
}
