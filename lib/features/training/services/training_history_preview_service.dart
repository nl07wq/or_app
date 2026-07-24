import '../../../core/models/training_set.dart';
import '../../../core/repositories/training_repository.dart';
import 'exercise_name_localization.dart';

class TrainingHistoryPreviewService {
  TrainingHistoryPreviewService._();

  static Future<List<TrainingSet>?> load(String exerciseName) async {
    final identityKey = exerciseIdentityKey(exerciseName);
    if (identityKey.isEmpty) return null;

    final sessions = await TrainingRepository.getAll();
    for (final session in sessions) {
      for (final exercise in session.exercises) {
        if (exerciseIdentityKey(exercise.exerciseName) != identityKey) {
          continue;
        }

        final sets = List<TrainingSet>.from(exercise.sets)
          ..sort((first, second) => first.setNo.compareTo(second.setNo));
        return List.unmodifiable(sets);
      }
    }

    return null;
  }
}
