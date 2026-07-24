import '../../../core/models/training_set.dart';
import '../../../core/repositories/training_repository.dart';
import '../models/personal_record_result.dart';
import 'exercise_name_localization.dart';

class PersonalRecordService {
  PersonalRecordService._();

  static Future<PersonalRecordResult?> load({
    required String exerciseName,
    required String? equipmentId,
    required Iterable<TrainingSet> currentSets,
  }) async {
    final exerciseKey = exerciseIdentityKey(exerciseName);
    if (exerciseKey.isEmpty) return null;

    TrainingSet? historicalRecord;
    final sessions = await TrainingRepository.getAll();
    for (final session in sessions) {
      for (final exercise in session.exercises) {
        final isMatch =
            exerciseIdentityKey(exercise.exerciseName) == exerciseKey &&
            exercise.equipmentId == equipmentId;
        if (!isMatch) continue;

        for (final set in exercise.sets) {
          if (!_isCompleted(set)) continue;
          if (historicalRecord == null ||
              _isHigherRecord(set, historicalRecord)) {
            historicalRecord = set;
          }
        }
      }
    }

    if (historicalRecord == null) return null;

    TrainingSet? currentRecord;
    for (final set in currentSets) {
      if (!_isCompleted(set)) continue;
      if (currentRecord == null || _isHigherRecord(set, currentRecord)) {
        currentRecord = set;
      }
    }

    final isNewRecord =
        currentRecord != null &&
        _isHigherRecord(currentRecord, historicalRecord);
    final record = isNewRecord ? currentRecord : historicalRecord;
    return PersonalRecordResult(
      highestWeight: record.weight,
      highestRepetitions: record.reps,
      status: isNewRecord
          ? PersonalRecordStatus.newRecord
          : PersonalRecordStatus.currentRecord,
    );
  }

  static bool _isCompleted(TrainingSet set) {
    return set.weight.isFinite && set.weight >= 0 && set.reps > 0;
  }

  static bool _isHigherRecord(TrainingSet candidate, TrainingSet current) {
    return candidate.weight > current.weight ||
        candidate.weight == current.weight && candidate.reps > current.reps;
  }
}
