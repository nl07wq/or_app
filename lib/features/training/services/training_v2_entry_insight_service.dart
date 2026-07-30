import '../../../core/models/training_exercise_v2.dart';
import '../../../core/models/training_session_v2.dart';
import '../models/personal_record_result.dart';
import '../models/progression_result.dart';
import '../models/training_record_read_model.dart';
import 'training_exercise_identity.dart';
import 'training_v2_personal_record_service.dart';
import 'training_v2_progression_service.dart';
import 'training_v2_statistics_service.dart';

class TrainingV2EntryInsights {
  final ProgressionResult? progression;
  final TrainingV2Statistics statistics;
  final PersonalRecordResult? personalRecord;

  const TrainingV2EntryInsights({
    required this.progression,
    required this.statistics,
    required this.personalRecord,
  });
}

abstract final class TrainingV2EntryInsightService {
  static TrainingV2EntryInsights calculate({
    required Iterable<TrainingRecordReadModel> preferredRecords,
    required TrainingExerciseV2 currentExercise,
    required String sessionDate,
    TrainingRecordReadModel? targetRecord,
  }) {
    final identity = TrainingExerciseIdentity.v2(currentExercise);
    if (!identity.isValid) {
      return const TrainingV2EntryInsights(
        progression: null,
        statistics: TrainingV2Statistics.empty,
        personalRecord: null,
      );
    }
    final target = targetRecord ?? _previewRecord(sessionDate, currentExercise);
    final progression = TrainingV2ProgressionService.forRecord(
      preferredRecords: preferredRecords,
      targetRecord: target,
      identity: identity,
    );
    final personalRecord = TrainingV2PersonalRecordService.find(
      preferredRecords: preferredRecords,
      identity: identity,
    );
    return TrainingV2EntryInsights(
      progression: progression,
      statistics: TrainingV2StatisticsService.calculate(currentExercise),
      personalRecord: personalRecord == null
          ? null
          : PersonalRecordResult(
              highestWeight: personalRecord.weightKg,
              highestRepetitions: personalRecord.reps,
              status: PersonalRecordStatus.currentRecord,
            ),
    );
  }

  static TrainingRecordReadModel _previewRecord(
    String sessionDate,
    TrainingExerciseV2 exercise,
  ) {
    final timestamp = DateTime.tryParse(sessionDate) ?? DateTime.now();
    final localDate = sessionDate.substring(0, 10);
    return TrainingRecordReadModel.v2(
      id: 'training:entry-preview',
      localDate: localDate,
      createdAt: timestamp,
      updatedAt: timestamp,
      data: TrainingSessionV2(date: sessionDate, exercises: [exercise]),
    );
  }
}
