import '../../../core/engine/activity_summary.dart';
import '../../activity/repository/activity_repository.dart';
import '../../activity/services/activity_summary_engine.dart';
import '../../food/models/food_nutrition_aggregate.dart';
import '../../food/models/food_unified_read_model.dart';
import '../../status/repositories/status_repository.dart';
import '../../training/repository/training_session_repository.dart';
import '../models/daily_aggregate_v1.dart';
import '../repository/daily_aggregate_repository.dart';

typedef DailyAggregateFoodReader =
    Future<List<FoodUnifiedReadModel>> Function(String localDate);

class DailyAggregateEngine {
  final StatusRepository _statusRepository;
  final DailyAggregateFoodReader _readFood;
  final ActivityRepository _activityRepository;
  final TrainingSessionRepository _trainingRepository;
  final DailyAggregateRepository _dailyAggregateRepository;
  final ActivitySummaryEngine _activitySummaryEngine;

  const DailyAggregateEngine({
    required StatusRepository statusRepository,
    required DailyAggregateFoodReader readFood,
    required ActivityRepository activityRepository,
    required TrainingSessionRepository trainingRepository,
    required DailyAggregateRepository dailyAggregateRepository,
    ActivitySummaryEngine activitySummaryEngine = const ActivitySummaryEngine(),
  }) : _statusRepository = statusRepository,
       _readFood = readFood,
       _activityRepository = activityRepository,
       _trainingRepository = trainingRepository,
       _dailyAggregateRepository = dailyAggregateRepository,
       _activitySummaryEngine = activitySummaryEngine;

  Future<DailyAggregateV1> build(
    String operationDate, {
    double? estimatedExpenditureKcal,
  }) async {
    final date = _parseOperationDate(operationDate);
    final previousDate = DateTime(date.year, date.month, date.day - 1);
    final status = await _statusRepository.findByLocalDate(operationDate);
    final foodRecords = await _readFood(operationDate);
    final activity = await _activityRepository.findByDate(date);
    final previousActivity = await _activityRepository.findByDate(previousDate);
    final trainingRecords = await _trainingRepository.findRecordsByLocalDate(
      operationDate,
    );
    final existing = await _dailyAggregateRepository.getByDate(operationDate);
    final legacy = existing?.sourceType == DailyAggregateSourceType.legacyDns
        ? existing
        : null;
    final food = FoodMixedDaySummary.fromRecords(foodRecords);
    final activitySummary = _activitySummaryEngine.generate(
      record: activity,
      previousCarryOver: previousActivity?.carryOver ?? 0,
    );

    final intakeCaloriesKcal =
        _complete(food.nutrition.calories) ?? legacy?.intakeCaloriesKcal;
    final expenditure =
        estimatedExpenditureKcal ?? legacy?.estimatedExpenditureKcal;
    final balance = intakeCaloriesKcal != null && expenditure != null
        ? intakeCaloriesKcal - expenditure
        : legacy?.estimatedCalorieBalanceKcal;

    return DailyAggregateV1(
      operationDate: operationDate,
      weightKg: status?.weight,
      bodyFatPercent: status?.bodyFat,
      sleepDurationMinutes: status?.sleepHours == null
          ? null
          : (status!.sleepHours! * 60).round(),
      sleepScore: status?.sleepScore,
      sleepType: status?.sleepType,
      plantarFasciitisLevel: status?.footPain,
      workStartTime: _text(status?.workStart),
      workEndTime: _text(status?.workEnd),
      workBreakMinutes: _durationMinutes(status?.workBreak),
      actualWorkMinutes: status == null
          ? null
          : (status.workHours * 60).round(),
      intakeCaloriesKcal: intakeCaloriesKcal,
      estimatedExpenditureKcal: expenditure,
      estimatedCalorieBalanceKcal: balance,
      proteinG: _complete(food.nutrition.protein),
      fatG: _complete(food.nutrition.fat),
      carbsG: _complete(food.nutrition.carbohydrate),
      hydrationMl: food.hydrationMl,
      officialSteps: _officialSteps(activitySummary),
      measuredSteps: activity?.rawSteps,
      trainingPerformed: trainingRecords.isNotEmpty,
      digestiveCount: activity?.digestiveEvents?.length,
      sourceType: DailyAggregateSourceType.records,
    );
  }

  static double? _complete(FoodNutritionValueAggregate value) =>
      value.completeness == FoodNutritionCompleteness.complete
      ? value.knownTotal
      : null;

  static int? _officialSteps(ActivitySummary summary) =>
      summary.calculationBasis?.officialSteps;

  static String? _text(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }

  static int? _durationMinutes(String? value) {
    final normalized = _text(value);
    if (normalized == null) return null;
    final match = RegExp(r'^(\d+):(\d{2})$').firstMatch(normalized);
    if (match == null) return null;
    final hours = int.parse(match.group(1)!);
    final minutes = int.parse(match.group(2)!);
    if (minutes > 59) return null;
    return hours * 60 + minutes;
  }

  static DateTime _parseOperationDate(String value) {
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
    if (match == null) {
      throw const FormatException('Invalid operationDate.');
    }
    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final day = int.parse(match.group(3)!);
    final parsed = DateTime(year, month, day);
    if (parsed.year != year || parsed.month != month || parsed.day != day) {
      throw const FormatException('Invalid operationDate.');
    }
    return parsed;
  }
}
