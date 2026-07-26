import '../../../data/indexed_db/indexed_db_database_contract.dart';
import '../../../data/indexed_db/indexed_db_store_names.dart';
import '../../repositories/repository_exception.dart';
import '../models/custom_training_exercise.dart';
import '../models/persisted_custom_training_exercise_record.dart';
import '../services/exercise_name_localization.dart';
import 'custom_training_exercise_id_generator.dart';
import 'custom_training_exercise_repository.dart';

class CustomTrainingExerciseReadIssue {
  final String? recordId;
  final String code;
  final String message;

  const CustomTrainingExerciseReadIssue({
    required this.recordId,
    required this.code,
    required this.message,
  });
}

class CustomTrainingExerciseReadResult {
  final List<PersistedCustomTrainingExerciseRecord> records;
  final List<CustomTrainingExerciseReadIssue> issues;

  CustomTrainingExerciseReadResult({
    required Iterable<PersistedCustomTrainingExerciseRecord> records,
    Iterable<CustomTrainingExerciseReadIssue> issues = const [],
  }) : records = List.unmodifiable(records),
       issues = List.unmodifiable(issues);

  bool get hasIssues => issues.isNotEmpty;
}

abstract interface class CustomTrainingExerciseAuditRepository {
  Future<CustomTrainingExerciseReadResult> findAllWithIssues();
}

class IndexedDbCustomTrainingExerciseRepository
    implements
        CustomTrainingExerciseRepository,
        CustomTrainingExerciseAuditRepository {
  final IndexedDbDatabase _database;
  final CustomTrainingExerciseIdGenerator _idGenerator;
  final DateTime Function() _now;

  IndexedDbCustomTrainingExerciseRepository(
    this._database, {
    CustomTrainingExerciseIdGenerator? idGenerator,
    DateTime Function()? now,
  }) : _idGenerator = idGenerator ?? CustomTrainingExerciseIdGenerator(),
       _now = now ?? DateTime.now;

  @override
  Future<CustomTrainingExercise> create(String name) async {
    final trimmedName = _validateName(name);
    final id = _idGenerator.generate();
    return _write(
      id: id,
      name: trimmedName,
      operation: 'customTrainingExercise.create',
      requireExisting: false,
    );
  }

  @override
  Future<CustomTrainingExercise> updateById(String id, String name) {
    return _write(
      id: id,
      name: _validateName(name),
      operation: 'customTrainingExercise.updateById',
      requireExisting: true,
    );
  }

  Future<CustomTrainingExercise> _write({
    required String id,
    required String name,
    required String operation,
    required bool requireExisting,
  }) async {
    try {
      PersistedCustomTrainingExerciseRecord.validateId(id);
      final normalizedName = exerciseIdentityKey(name);
      late PersistedCustomTrainingExerciseRecord saved;
      await _database.runTransaction<void>(
        storeNames: const [IndexedDbStoreNames.customTrainingExercises],
        mode: IndexedDbTransactionMode.readWrite,
        action: (transaction) async {
          final existingValue = await transaction.findById(
            IndexedDbStoreNames.customTrainingExercises,
            id,
          );
          final existing = existingValue == null
              ? null
              : PersistedCustomTrainingExerciseRecord.fromRecord(existingValue);
          if (!requireExisting && existing != null) {
            throw _CustomTrainingExerciseWriteRejected(
              'Custom Training Exercise record already exists: $id',
            );
          }
          if (requireExisting && existing == null) {
            throw _CustomTrainingExerciseWriteRejected(
              'Custom Training Exercise record does not exist: $id',
            );
          }
          final stored = await transaction.findAll(
            IndexedDbStoreNames.customTrainingExercises,
          );
          for (final value in stored) {
            final record = PersistedCustomTrainingExerciseRecord.fromRecord(
              value,
            );
            if (record.id != id && record.normalizedName == normalizedName) {
              throw _CustomTrainingExerciseWriteRejected(
                'Custom Training Exercise normalized name already exists: '
                '$normalizedName',
              );
            }
          }
          final requestedTimestamp = _now().toUtc();
          final timestamp =
              existing != null &&
                  !requestedTimestamp.isAfter(existing.updatedAt)
              ? existing.updatedAt.add(const Duration(microseconds: 1))
              : requestedTimestamp;
          saved = PersistedCustomTrainingExerciseRecord(
            id: id,
            normalizedName: normalizedName,
            createdAt: existing?.createdAt ?? timestamp,
            updatedAt: timestamp,
            migrationSource: existing?.migrationSource,
            data: CustomTrainingExercise(id: id, name: name),
          );
          await transaction.put(
            IndexedDbStoreNames.customTrainingExercises,
            saved.toRecord(),
          );
        },
      );
      return saved.data;
    } on RepositoryException {
      rethrow;
    } on FormatException catch (error) {
      throw RepositoryException(
        operation: operation,
        code: RepositoryErrorCode.invalidRecord,
        cause: error,
      );
    } on _CustomTrainingExerciseWriteRejected catch (error) {
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
  Future<CustomTrainingExercise?> findById(String id) async {
    try {
      PersistedCustomTrainingExerciseRecord.validateId(id);
      final value = await _database.findById(
        IndexedDbStoreNames.customTrainingExercises,
        id,
      );
      return value == null
          ? null
          : PersistedCustomTrainingExerciseRecord.fromRecord(value).data;
    } on FormatException catch (error) {
      throw RepositoryException(
        operation: 'customTrainingExercise.findById',
        code: RepositoryErrorCode.invalidRecord,
        cause: error,
      );
    } catch (error) {
      throw RepositoryException(
        operation: 'customTrainingExercise.findById',
        cause: error,
      );
    }
  }

  @override
  Future<List<CustomTrainingExercise>> findAll() async {
    final result = await findAllWithIssues();
    if (result.hasIssues) {
      throw RepositoryException(
        operation: 'customTrainingExercise.findAll',
        code: RepositoryErrorCode.partialCorruption,
        cause: result.issues,
      );
    }
    return List.unmodifiable(result.records.map((record) => record.data));
  }

  @override
  Future<CustomTrainingExerciseReadResult> findAllWithIssues() async {
    try {
      final stored = await _database.findAll(
        IndexedDbStoreNames.customTrainingExercises,
      );
      final records = <PersistedCustomTrainingExerciseRecord>[];
      final issues = <CustomTrainingExerciseReadIssue>[];
      for (final value in stored) {
        try {
          records.add(PersistedCustomTrainingExerciseRecord.fromRecord(value));
        } catch (error) {
          issues.add(
            CustomTrainingExerciseReadIssue(
              recordId: value['id'] is String ? value['id'] as String : null,
              code: 'invalidRecord',
              message: error.toString(),
            ),
          );
        }
      }
      records.sort(
        (first, second) => first.data.name.toLowerCase().compareTo(
          second.data.name.toLowerCase(),
        ),
      );
      return CustomTrainingExerciseReadResult(records: records, issues: issues);
    } catch (error) {
      throw RepositoryException(
        operation: 'customTrainingExercise.findAll',
        cause: error,
      );
    }
  }

  @override
  Future<void> deleteById(String id) async {
    try {
      PersistedCustomTrainingExerciseRecord.validateId(id);
      await _database.deleteById(
        IndexedDbStoreNames.customTrainingExercises,
        id,
      );
    } catch (error) {
      throw RepositoryException(
        operation: 'customTrainingExercise.deleteById',
        cause: error,
      );
    }
  }

  @override
  Future<void> clear() async {
    try {
      await _database.clear(IndexedDbStoreNames.customTrainingExercises);
    } catch (error) {
      throw RepositoryException(
        operation: 'customTrainingExercise.clear',
        cause: error,
      );
    }
  }

  static String _validateName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw const FormatException(
        'Custom Training Exercise name cannot be empty.',
      );
    }
    return trimmed;
  }
}

class _CustomTrainingExerciseWriteRejected implements Exception {
  final String message;

  const _CustomTrainingExerciseWriteRejected(this.message);

  @override
  String toString() => message;
}
