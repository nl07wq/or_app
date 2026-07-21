import '../../../core/engine/training_summary.dart';
import '../../../core/models/training_session.dart';

class TrainingSummaryService {
  const TrainingSummaryService._();

  static TrainingSummary? today(Iterable<TrainingSession> sessions) {
    final dailySessions = _todaySessions(sessions);

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

  static double todayCardioCalories(Iterable<TrainingSession> sessions) {
    return _todaySessions(sessions)
        .fold<double>(
          0,
          (total, session) =>
              total +
              session.cardioEntries.fold<double>(
                0,
                (sessionTotal, entry) =>
                    sessionTotal + (entry.estimatedCalories ?? 0),
              ),
        );
  }

  static List<TrainingSession> _todaySessions(
    Iterable<TrainingSession> sessions,
  ) {
    final now = DateTime.now();

    return sessions.where((session) {
      final date = DateTime.parse(session.date).toLocal();
      return date.year == now.year &&
          date.month == now.month &&
          date.day == now.day;
    }).toList(growable: false);
  }
}
