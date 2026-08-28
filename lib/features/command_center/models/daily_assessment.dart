import '../../../core/models/morning_data.dart';
import '../../body_history/models/body_history_models.dart';

enum DailyWeightReferenceSource {
  measuredToday,
  sevenDayMean,
  fourteenDayMean,
  notAvailable,
}

class DailyWeightReference {
  const DailyWeightReference({
    required this.valueKg,
    required this.source,
    required this.sampleCount,
    required this.windowDays,
  });

  const DailyWeightReference.notAvailable()
    : valueKg = null,
      source = DailyWeightReferenceSource.notAvailable,
      sampleCount = 0,
      windowDays = 0;

  final double? valueKg;
  final DailyWeightReferenceSource source;
  final int sampleCount;
  final int windowDays;
}

enum DailyAssessmentLevel {
  support('SUPPORT', '今日の運用を積極的に支える要因'),
  stable('STABLE', '通常運用可能'),
  watch('WATCH', '監視対象'),
  adjust('ADJUST', '具体的な運用調整が必要'),
  limit('LIMIT', '明確な制約');

  const DailyAssessmentLevel(this.label, this.meaning);

  final String label;
  final String meaning;
}

enum DailyAssessmentModule {
  body('BODY'),
  recovery('RECOVERY'),
  condition('CONDITION'),
  workLoad('WORK LOAD'),
  nutrition('NUTRITION'),
  hydration('HYDRATION'),
  recentLoad('RECENT LOAD'),
  training('TRAINING');

  const DailyAssessmentModule(this.label);

  final String label;
}

enum DailyAssessmentMetric {
  weightTrend('Weight Trend'),
  sleepTime('Sleep Time'),
  sleepScore('Sleep Score'),
  plantarFasciitis('Plantar Fasciitis'),
  work('Work'),
  calorieBalance('Calorie Balance'),
  protein('Protein'),
  hydration('Hydration'),
  steps('Steps'),
  trainingReadiness('Training Readiness');

  const DailyAssessmentMetric(this.label);

  final String label;
}

class DailyAssessmentItem {
  const DailyAssessmentItem({
    required this.module,
    required this.metric,
    required this.rawValue,
    required this.specificAssessment,
    required this.level,
  });

  final DailyAssessmentModule module;
  final DailyAssessmentMetric metric;
  final Object? rawValue;
  final String specificAssessment;
  final DailyAssessmentLevel? level;

  bool get isAvailable => level != null;
}

class DailyAssessment {
  DailyAssessment({
    required this.operationDate,
    required Iterable<DailyAssessmentItem> assessments,
    required Iterable<String> primaryConstraints,
    required Iterable<String> availableResources,
    this.currentWeightReference = const DailyWeightReference.notAvailable(),
  }) : assessments = List.unmodifiable(assessments),
       primaryConstraints = List.unmodifiable(primaryConstraints),
       availableResources = List.unmodifiable(availableResources);

  final String operationDate;
  final List<DailyAssessmentItem> assessments;
  final List<String> primaryConstraints;
  final List<String> availableResources;
  final DailyWeightReference currentWeightReference;
}

class DailyAssessmentFacts {
  DailyAssessmentFacts({
    required this.operationDate,
    required this.currentStatus,
    required this.currentCalorieBalanceKcal,
    required this.currentProteinG,
    required this.currentHydrationMl,
    required this.currentOfficialSteps,
    required this.currentTrainingPerformed,
    this.currentStrengthTrainingPerformed = false,
    this.currentCardioPerformed = false,
    required Iterable<BodyHistoryDataPoint> weightHistory,
    this.trainingReadiness,
    this.currentWeightReference = const DailyWeightReference.notAvailable(),
  }) : weightHistory = List.unmodifiable(weightHistory);

  final String operationDate;
  final MorningData? currentStatus;
  final double? currentCalorieBalanceKcal;
  final double? currentProteinG;
  final double? currentHydrationMl;
  final int? currentOfficialSteps;
  final bool currentTrainingPerformed;
  final bool currentStrengthTrainingPerformed;
  final bool currentCardioPerformed;
  final List<BodyHistoryDataPoint> weightHistory;
  final TrainingReadinessFacts? trainingReadiness;
  final DailyWeightReference currentWeightReference;
}

enum TrainingReadinessIntervalBasis { hours, calendarDays }

class TrainingReadinessIntervalFact {
  const TrainingReadinessIntervalFact.hours(this.value)
    : basis = TrainingReadinessIntervalBasis.hours;

  const TrainingReadinessIntervalFact.calendarDays(this.value)
    : basis = TrainingReadinessIntervalBasis.calendarDays;

  final int value;
  final TrainingReadinessIntervalBasis basis;

  int get thresholdHours =>
      basis == TrainingReadinessIntervalBasis.hours ? value : value * 24;

  String get compactLabel =>
      basis == TrainingReadinessIntervalBasis.hours ? '${value}h' : '${value}d';
}

class TrainingReadinessFacts {
  TrainingReadinessFacts({
    required this.lastTraining,
    required this.last7DaysSessionCount,
    required this.currentWeekSessionCount,
    required this.consecutiveTrainingDays,
    required Iterable<TrainingReadinessIntervalFact> recentIntervals,
  }) : recentIntervals = List.unmodifiable(recentIntervals);

  final TrainingReadinessIntervalFact lastTraining;
  final int last7DaysSessionCount;
  final int currentWeekSessionCount;
  final int consecutiveTrainingDays;
  final List<TrainingReadinessIntervalFact> recentIntervals;
}
