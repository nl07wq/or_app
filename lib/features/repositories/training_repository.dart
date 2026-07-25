import '../../core/models/training_session.dart';
import 'repository_record.dart';

abstract interface class TrainingRepository {
  Future<List<RepositoryRecord<TrainingSession>>> findAll();

  Future<RepositoryRecord<TrainingSession>?> findById(String id);

  Future<void> save(RepositoryRecord<TrainingSession> record);

  Future<void> delete(String id);

  Future<void> clear();
}
