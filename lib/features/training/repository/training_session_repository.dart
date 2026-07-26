import '../../../core/models/training_session.dart';
import '../models/persisted_training_record.dart';

abstract interface class TrainingSessionRepository {
  Future<TrainingRecord> saveNew(TrainingSession session);

  Future<TrainingRecord> saveWithId(String id, TrainingSession session);

  Future<TrainingRecord?> findById(String id);

  Future<List<TrainingRecord>> findAll();

  Future<List<TrainingRecord>> findByLocalDate(String localDate);

  Future<TrainingRecord> updateById(String id, TrainingSession session);

  Future<void> deleteById(String id);

  Future<void> clear();

  Future<List<TrainingSession>> findAllSessions();
}
