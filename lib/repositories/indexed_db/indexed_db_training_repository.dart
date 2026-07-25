import '../../core/models/training_exercise.dart';
import '../../core/models/training_session.dart';
import '../../data/indexed_db/indexed_db_database_contract.dart';
import '../../data/indexed_db/indexed_db_store_names.dart';
import '../../features/repositories/repository_exception.dart';
import '../../features/repositories/repository_record.dart';
import '../../features/repositories/training_repository.dart';

class IndexedDbTrainingRepository implements TrainingRepository {
  final IndexedDbDatabase _database;

  const IndexedDbTrainingRepository(this._database);

  @override
  Future<List<RepositoryRecord<TrainingSession>>> findAll() async {
    try {
      final records = await _database.findAll(IndexedDbStoreNames.trainings);
      return List.unmodifiable(records.map(_fromStoredRecord));
    } catch (error) {
      throw RepositoryException(operation: 'training.findAll', cause: error);
    }
  }

  @override
  Future<RepositoryRecord<TrainingSession>?> findById(String id) async {
    try {
      final record = await _database.findById(
        IndexedDbStoreNames.trainings,
        id,
      );
      return record == null ? null : _fromStoredRecord(record);
    } catch (error) {
      throw RepositoryException(operation: 'training.findById', cause: error);
    }
  }

  @override
  Future<void> save(RepositoryRecord<TrainingSession> record) async {
    try {
      await _database.put(IndexedDbStoreNames.trainings, {
        'id': record.id,
        'data': _copyMap(record.value.toJson()),
      });
    } catch (error) {
      throw RepositoryException(operation: 'training.save', cause: error);
    }
  }

  @override
  Future<void> delete(String id) async {
    try {
      await _database.deleteById(IndexedDbStoreNames.trainings, id);
    } catch (error) {
      throw RepositoryException(operation: 'training.delete', cause: error);
    }
  }

  @override
  Future<void> clear() async {
    try {
      await _database.clear(IndexedDbStoreNames.trainings);
    } catch (error) {
      throw RepositoryException(operation: 'training.clear', cause: error);
    }
  }

  RepositoryRecord<TrainingSession> _fromStoredRecord(
    Map<String, Object?> record,
  ) {
    final id = record['id'];
    final data = record['data'];
    if (id is! String || data is! Map) {
      throw const FormatException('Invalid Training stored record.');
    }

    final session = TrainingSession.fromJson(
      Map<String, dynamic>.from(_copyMap(Map<String, dynamic>.from(data))),
    );
    return RepositoryRecord(id: id, value: _immutableSession(session));
  }

  TrainingSession _immutableSession(TrainingSession session) {
    return TrainingSession(
      date: session.date,
      memo: session.memo,
      exercises: List.unmodifiable(
        session.exercises.map(
          (exercise) => TrainingExercise(
            exerciseName: exercise.exerciseName,
            order: exercise.order,
            sets: List.unmodifiable(exercise.sets),
            equipmentId: exercise.equipmentId,
          ),
        ),
      ),
      cardioEntries: session.cardioEntries,
    );
  }

  Map<String, Object?> _copyMap(Map source) {
    return {
      for (final entry in source.entries)
        entry.key.toString(): _copyValue(entry.value),
    };
  }

  Object? _copyValue(Object? value) {
    if (value is Map) return _copyMap(value);
    if (value is Iterable) return [for (final item in value) _copyValue(item)];
    return value;
  }
}
