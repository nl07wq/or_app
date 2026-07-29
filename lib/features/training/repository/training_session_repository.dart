import '../../../core/models/training_session.dart';
import '../../../core/models/training_session_v2.dart';
import '../models/persisted_training_record.dart';
import '../models/training_record_read_model.dart';

abstract interface class TrainingSessionRepository {
  Future<TrainingRecord> saveNew(TrainingSession session);

  Future<TrainingRecord> saveNewV2(TrainingSessionV2 session);

  Future<TrainingRecord> saveWithId(String id, TrainingSession session);

  Future<TrainingRecord?> findById(String id);

  Future<List<TrainingRecord>> findAll();

  Future<List<TrainingRecord>> findByLocalDate(String localDate);

  Future<TrainingRecordReadModel?> findRecordById(String id);

  Future<List<TrainingRecordReadModel>> findAllRecords();

  Future<List<TrainingRecordReadModel>> findRecordsByLocalDate(
    String localDate,
  );

  Future<TrainingRecord> updateById(String id, TrainingSession session);

  Future<TrainingRecord> updateV2ById(String id, TrainingSessionV2 session);

  Future<void> deleteById(String id);

  Future<void> clear();

  Future<List<TrainingSession>> findAllSessions();
}
