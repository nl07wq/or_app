import '../../../core/models/training_set.dart';
import '../../../core/repositories/training_repository.dart';

class TrainingHistoryPreviewService {
  TrainingHistoryPreviewService._();

  static Future<List<TrainingSet>?> load(String exerciseName) async {
    final normalizedName = exerciseName.trim().toLowerCase();
    if (normalizedName.isEmpty) return null;

    final sessions = await TrainingRepository.getAll();
    for (final session in sessions) {
      for (final exercise in session.exercises) {
        if (exercise.exerciseName.trim().toLowerCase() != normalizedName) {
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
