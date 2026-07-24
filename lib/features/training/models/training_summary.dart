import 'personal_record_result.dart';
import 'progression_result.dart';
import 'statistics_result.dart';
import 'training_history_summary.dart';

class TrainingSummary {
  final TrainingHistorySummary? historySummary;
  final ProgressionResult? progressionResult;
  final StatisticsResult statisticsResult;
  final PersonalRecordResult? personalRecordResult;

  const TrainingSummary({
    required this.historySummary,
    required this.progressionResult,
    required this.statisticsResult,
    required this.personalRecordResult,
  });
}
