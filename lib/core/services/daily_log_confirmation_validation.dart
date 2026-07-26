import '../engine/activity_summary.dart';
import '../engine/food_summary.dart';
import '../engine/training_summary.dart';
import '../../features/morning/models/morning_fact.dart';

enum DailyLogModule { status, food, activity, training }

class DailyLogValidationResult {
  final bool statusValid;
  final bool foodValid;
  final bool activityValid;
  final bool trainingValid;
  final bool trainingRecorded;

  const DailyLogValidationResult({
    required this.statusValid,
    required this.foodValid,
    required this.activityValid,
    required this.trainingValid,
    required this.trainingRecorded,
  });

  bool get canFinalize =>
      statusValid && foodValid && activityValid && trainingValid;

  List<DailyLogModule> get invalidRequiredModules => [
    if (!statusValid) DailyLogModule.status,
    if (!foodValid) DailyLogModule.food,
    if (!activityValid) DailyLogModule.activity,
  ];

  List<DailyLogModule> get blockingModules => [
    ...invalidRequiredModules,
    if (!trainingValid) DailyLogModule.training,
  ];
}

abstract final class DailyLogConfirmationValidation {
  static DailyLogValidationResult validate({
    required MorningFact? morning,
    required FoodSummary? food,
    required ActivitySummary activity,
    required TrainingSummary? training,
  }) {
    return DailyLogValidationResult(
      statusValid: _isValidStatus(morning),
      foodValid: _isValidFood(food),
      activityValid: _isValidActivity(activity),
      trainingValid: _isValidTraining(training),
      trainingRecorded: training != null,
    );
  }

  static String moduleLabel(DailyLogModule module) => switch (module) {
    DailyLogModule.status => 'STATUS',
    DailyLogModule.food => 'FOOD',
    DailyLogModule.activity => 'ACTIVITY',
    DailyLogModule.training => 'TRAINING',
  };

  static bool _isValidStatus(MorningFact? morning) {
    if (morning == null) return false;

    return morning.weight.isFinite &&
        morning.bodyFat?.isFinite == true &&
        morning.sleepDuration >= Duration.zero &&
        morning.workHours.isFinite;
  }

  static bool _isValidFood(FoodSummary? food) {
    if (food == null || food.mealCount <= 0) return false;

    return food.calories.isFinite &&
        food.protein.isFinite &&
        food.fat.isFinite &&
        food.carbohydrates.isFinite &&
        food.hydrationMl.isFinite;
  }

  static bool _isValidActivity(ActivitySummary activity) {
    if (!activity.isRecorded || activity.officialSteps < 0) return false;

    final basis = activity.calculationBasis;
    final measuredSteps = basis?.rawSteps;
    final carryOver = basis?.currentCarryOver;
    final previousDeduction = basis?.previousCarryOverDeduction;
    final officialSteps = basis?.officialSteps;
    if (basis == null ||
        measuredSteps == null ||
        carryOver == null ||
        previousDeduction == null ||
        officialSteps == null ||
        measuredSteps < 0 ||
        carryOver < 0 ||
        previousDeduction < 0 ||
        officialSteps < 0) {
      return false;
    }

    return measuredSteps + carryOver - previousDeduction == officialSteps &&
        officialSteps == activity.officialSteps &&
        measuredSteps == activity.measuredSteps &&
        carryOver == activity.carryOver &&
        previousDeduction == activity.previousCarryOverDeduction;
  }

  static bool _isValidTraining(TrainingSummary? training) {
    if (training == null) return true;

    return training.completed &&
        training.exerciseCount >= 0 &&
        training.setCount >= 0 &&
        (training.duration == null || training.duration! >= Duration.zero);
  }
}
