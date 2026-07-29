import '../../../core/models/training_exercise_v2.dart';
import '../models/training_record_read_model.dart';
import 'training_exercise_identity.dart';
import 'training_v2_statistics_service.dart';

class TrainingV2PreviousResult {
  final TrainingRecordReadModel record;
  final TrainingExerciseV2 exercise;
  final TrainingV2Statistics statistics;

  const TrainingV2PreviousResult({
    required this.record,
    required this.exercise,
    required this.statistics,
  });
}

abstract final class TrainingV2PreviousService {
  static TrainingV2PreviousResult? find({
    required Iterable<TrainingRecordReadModel> preferredRecords,
    required TrainingRecordReadModel targetRecord,
    required TrainingExerciseIdentity identity,
  }) {
    TrainingV2PreviousResult? latest;
    for (final record in preferredRecords) {
      if (record.id == targetRecord.id || record.v2Data == null) continue;
      if (_compareRecordOrder(record, targetRecord) >= 0) continue;
      for (final exercise in record.v2Data!.exercises) {
        if (TrainingExerciseIdentity.v2(exercise) != identity) continue;
        final statistics = TrainingV2StatisticsService.calculate(exercise);
        if (statistics.mainSetCount == 0) continue;
        final candidate = TrainingV2PreviousResult(
          record: record,
          exercise: exercise,
          statistics: statistics,
        );
        if (latest == null || _compareRecordOrder(record, latest.record) > 0) {
          latest = candidate;
        }
      }
    }
    return latest;
  }

  static int _compareRecordOrder(
    TrainingRecordReadModel first,
    TrainingRecordReadModel second,
  ) {
    final byCreatedAt = first.createdAt.compareTo(second.createdAt);
    if (byCreatedAt != 0) return byCreatedAt;
    final firstSession = DateTime.tryParse(first.sessionDate);
    final secondSession = DateTime.tryParse(second.sessionDate);
    if (firstSession != null && secondSession != null) {
      final bySession = firstSession.compareTo(secondSession);
      if (bySession != 0) return bySession;
    }
    return first.id.compareTo(second.id);
  }
}
