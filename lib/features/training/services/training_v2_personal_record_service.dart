import '../../../core/models/training_exercise_v2.dart';
import '../../../core/models/training_session_v2.dart';
import '../../../core/models/training_set_v2.dart';
import '../models/training_record_read_model.dart';
import 'training_exercise_identity.dart';
import 'training_v2_statistics_service.dart';

class TrainingV2PersonalRecord {
  final double weightKg;
  final int reps;
  final String localDate;
  final String recordId;
  final String? equipmentName;
  final int? rpe;
  final int? restAfterSeconds;
  final TrainingSessionGrade? sessionGrade;

  const TrainingV2PersonalRecord({
    required this.weightKg,
    required this.reps,
    required this.localDate,
    required this.recordId,
    required this.equipmentName,
    required this.rpe,
    required this.restAfterSeconds,
    required this.sessionGrade,
  });
}

abstract final class TrainingV2PersonalRecordService {
  static TrainingV2PersonalRecord? find({
    required Iterable<TrainingRecordReadModel> preferredRecords,
    required TrainingExerciseIdentity identity,
  }) {
    _Candidate? best;
    for (final record in preferredRecords) {
      final session = record.v2Data;
      if (session == null) continue;
      for (final exercise in session.exercises) {
        if (TrainingExerciseIdentity.v2(exercise) != identity) continue;
        final set = TrainingV2StatisticsService.calculate(exercise).heaviestSet;
        if (set == null) continue;
        final candidate = _Candidate(record, session, exercise, set);
        if (best == null ||
            TrainingV2StatisticsService.isHigherSet(set, best.set)) {
          best = candidate;
        }
      }
    }
    if (best == null) return null;
    return TrainingV2PersonalRecord(
      weightKg: best.set.weightKg,
      reps: best.set.reps,
      localDate: best.record.localDate,
      recordId: best.record.id,
      equipmentName: best.exercise.equipment?.name,
      rpe: best.set.rpe,
      restAfterSeconds: best.set.restAfterSeconds,
      sessionGrade: best.session.sessionGrade,
    );
  }
}

class _Candidate {
  final TrainingRecordReadModel record;
  final TrainingSessionV2 session;
  final TrainingExerciseV2 exercise;
  final TrainingSetV2 set;

  const _Candidate(this.record, this.session, this.exercise, this.set);
}
