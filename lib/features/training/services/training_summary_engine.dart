import '../../../core/models/training_set.dart';
import '../models/training_history_summary.dart';
import '../models/training_summary.dart';
import 'personal_record_service.dart';
import 'progression_service.dart';
import 'statistics_service.dart';
import 'training_history_preview_service.dart';

class TrainingSummaryEngine {
  TrainingSummaryEngine._();

  static Future<TrainingSummary> summarize({
    required String exerciseName,
    required String? equipmentId,
    required Iterable<TrainingSet> currentSets,
  }) async {
    final sets = List<TrainingSet>.unmodifiable(currentSets);
    final historyFuture = TrainingHistoryPreviewService.load(exerciseName);
    final progressionFuture = ProgressionService.loadLatest(
      exerciseName: exerciseName,
      equipmentId: equipmentId,
    );
    final personalRecordFuture = PersonalRecordService.load(
      exerciseName: exerciseName,
      equipmentId: equipmentId,
      currentSets: sets,
    );

    final history = await historyFuture;
    final progression = await progressionFuture;
    final personalRecord = await personalRecordFuture;

    return TrainingSummary(
      historySummary: history == null
          ? null
          : TrainingHistorySummary(sets: history),
      progressionResult: progression,
      statisticsResult: StatisticsService.calculate(sets),
      personalRecordResult: personalRecord,
    );
  }
}
