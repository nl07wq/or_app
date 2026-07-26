import 'package:or_app/core/engine/activity_summary.dart';
import 'package:or_app/core/engine/food_summary.dart';
import 'package:or_app/core/engine/training_summary.dart';
import 'package:or_app/core/models/activity_data.dart';
import 'package:or_app/core/models/bowel_movement_record.dart';
import 'package:or_app/core/models/daily_log_confirmation.dart';
import 'package:or_app/features/morning/models/morning_fact.dart';

DailyLogConfirmation completeConfirmation({
  DateTime? date,
  DateTime? confirmedAt,
  String trainingName = 'Push',
  List<String>? activityUnconfirmedFields,
}) {
  final targetDate = date ?? DateTime(2026, 7, 26);
  return DailyLogConfirmation(
    date: targetDate,
    confirmedAt:
        confirmedAt ??
        DateTime(targetDate.year, targetDate.month, targetDate.day, 22, 30),
    morning: MorningFact(
      date: targetDate,
      weight: 88.25,
      bodyFat: 24.75,
      sleepDuration: const Duration(hours: 7, minutes: 15),
      sleepScore: 82,
      workHours: 8.5,
      footPain: 3,
      condition: 4,
      previousCarryoverConfirmed: true,
      medications: const ['A', 'B'],
      freeNotes: 'Morning snapshot',
    ),
    food: const FoodSummary(
      calories: 2345.75,
      protein: 165.5,
      fat: 67.25,
      carbohydrates: 245.125,
      hydrationMl: 2789.5,
      mealCount: 4,
    ),
    activity: ActivitySummary(
      steps: 12345,
      measuredSteps: 12000,
      carryOver: 500,
      previousCarryOverDeduction: 155,
      isRecorded: true,
      recordId: '2026-07-26',
      date: targetDate,
      plannedWork: 'Office',
      actualWork: 'Office',
      trainingStatus: ActivityTrainingStatus.completed,
      bowelMovement: BowelMovementRecord.recorded(amount: 2, shape: 3),
      status: ActivitySummaryStatus.incomplete,
      unconfirmedFields: activityUnconfirmedFields ?? const [],
      warnings: const [
        ActivitySummaryWarning(ActivitySummaryWarningCode.carryOverUnconfirmed),
      ],
      calculationBasis: const ActivityCalculationBasis(
        rawSteps: 12000,
        currentCarryOver: 500,
        previousCarryOverDeduction: 155,
        officialSteps: 12345,
      ),
    ),
    training: TrainingSummary(
      completed: true,
      exerciseCount: 4,
      setCount: 16,
      duration: const Duration(minutes: 75),
      sessionName: trainingName,
    ),
  );
}
