import '../../../core/models/training_exercise.dart';
import '../../../core/models/training_session.dart';
import '../repository_record.dart';
import '../training_repository.dart';

class InMemoryTrainingRepository implements TrainingRepository {
  final Map<String, RepositoryRecord<TrainingSession>> _records = {};

  @override
  Future<List<RepositoryRecord<TrainingSession>>> findAll() async {
    return List.unmodifiable(_records.values);
  }

  @override
  Future<RepositoryRecord<TrainingSession>?> findById(String id) async {
    return _records[id];
  }

  @override
  Future<void> save(RepositoryRecord<TrainingSession> record) async {
    _records[record.id] = RepositoryRecord(
      id: record.id,
      value: _immutableSession(record.value),
    );
  }

  @override
  Future<void> delete(String id) async {
    _records.remove(id);
  }

  @override
  Future<void> clear() async {
    _records.clear();
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
}
