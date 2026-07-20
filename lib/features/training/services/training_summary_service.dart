import '../../../core/engine/training_summary.dart';
import '../../../core/models/training_session.dart';

class TrainingSummaryService {
  const TrainingSummaryService._();

  static TrainingSummary? today(Iterable<TrainingSession> sessions) {
    final today = DateTime.now().toIso8601String().split('T').first;
    final dailySessions = sessions
        .where((session) => session.date.split('T').first == today)
        .toList();

    if (dailySessions.isEmpty) return null;

    final latestSession = dailySessions.last;

    return TrainingSummary(
      completed: true,
      exerciseCount: dailySessions.fold(
        0,
        (sum, session) => sum + session.exercises.length,
      ),
      setCount: dailySessions.fold(
        0,
        (sum, session) =>
            sum + session.exercises.fold(0, (setSum, exercise) => setSum + exercise.sets.length),
      ),
      duration: null,
      sessionName: latestSession.memo.isNotEmpty
          ? latestSession.memo
          : latestSession.exercises.isEmpty
          ? null
          : latestSession.exercises.first.exerciseName,
    );
  }
}
