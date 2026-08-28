import '../engine/activity_summary.dart';
import '../engine/food_summary.dart';
import '../engine/training_summary.dart';
import '../../features/morning/models/morning_fact.dart';

enum DailyLogModule { status, food, activity, training }

enum DailyLogCompletenessState { notRecorded, incomplete, complete }

class DailyLogModuleCompleteness {
  final DailyLogCompletenessState state;
  final List<String> missingRequirements;

  const DailyLogModuleCompleteness({
    required this.state,
    this.missingRequirements = const [],
  });

  bool get isComplete => state == DailyLogCompletenessState.complete;
}

class DailyLogValidationResult {
  final bool statusValid;
  final bool foodValid;
  final bool activityValid;
  final bool trainingValid;
  final bool trainingRecorded;
  final DailyLogModuleCompleteness statusCompleteness;
  final DailyLogModuleCompleteness foodCompleteness;
  final DailyLogModuleCompleteness activityCompleteness;

  const DailyLogValidationResult({
    required this.statusValid,
    required this.foodValid,
    required this.activityValid,
    required this.trainingValid,
    required this.trainingRecorded,
    required this.statusCompleteness,
    required this.foodCompleteness,
    required this.activityCompleteness,
  });

  bool get canFinalize => statusValid && foodValid && activityValid;

  List<DailyLogModule> get invalidRequiredModules => [
    if (!statusValid) DailyLogModule.status,
    if (!foodValid) DailyLogModule.food,
    if (!activityValid) DailyLogModule.activity,
  ];

  List<DailyLogModule> get blockingModules => invalidRequiredModules;
}

abstract final class DailyLogConfirmationValidation {
  static DailyLogValidationResult validate({
    required MorningFact? morning,
    required FoodSummary? food,
    required ActivitySummary activity,
    required TrainingSummary? training,
  }) {
    final statusCompleteness = _statusCompleteness(morning);
    final foodCompleteness = _foodCompleteness(food);
    final activityCompleteness = _activityCompleteness(activity);
    return DailyLogValidationResult(
      statusValid: statusCompleteness.isComplete,
      foodValid: foodCompleteness.isComplete,
      activityValid: activityCompleteness.isComplete,
      trainingValid: _isValidTraining(training),
      trainingRecorded: training != null,
      statusCompleteness: statusCompleteness,
      foodCompleteness: foodCompleteness,
      activityCompleteness: activityCompleteness,
    );
  }

  static String moduleLabel(DailyLogModule module) => switch (module) {
    DailyLogModule.status => 'STATUS',
    DailyLogModule.food => 'FOOD',
    DailyLogModule.activity => 'ACTIVITY',
    DailyLogModule.training => 'TRAINING',
  };

  static DailyLogModuleCompleteness _statusCompleteness(MorningFact? morning) {
    if (morning == null) {
      return const DailyLogModuleCompleteness(
        state: DailyLogCompletenessState.notRecorded,
        missingRequirements: ['STATUS'],
      );
    }

    final valid =
        (morning.weight == null ||
            (morning.weight!.isFinite &&
                morning.weight! >= 40 &&
                morning.weight! <= 180)) &&
        (morning.bodyFat == null ||
            (morning.bodyFat!.isFinite &&
                morning.bodyFat! >= 0 &&
                morning.bodyFat! <= 60)) &&
        (morning.sleepDuration == null ||
            (morning.sleepDuration! >= Duration.zero &&
                morning.sleepDuration! < const Duration(hours: 24))) &&
        (morning.sleepScore == null ||
            (morning.sleepScore! >= 0 && morning.sleepScore! <= 100)) &&
        morning.workHours.isFinite;
    return DailyLogModuleCompleteness(
      state: valid
          ? DailyLogCompletenessState.complete
          : DailyLogCompletenessState.incomplete,
      missingRequirements: valid ? const [] : const ['STATUS'],
    );
  }

  static DailyLogModuleCompleteness _foodCompleteness(FoodSummary? food) {
    final foodRecorded = food != null && food.mealCount > 0;
    final waterRecorded = food?.waterRecorded == true;
    final missing = [if (!foodRecorded) 'FOOD', if (!waterRecorded) 'WATER'];
    if (food == null || (!foodRecorded && !waterRecorded)) {
      return DailyLogModuleCompleteness(
        state: DailyLogCompletenessState.notRecorded,
        missingRequirements: missing,
      );
    }
    final valid =
        food.calories.isFinite &&
        food.protein.isFinite &&
        food.fat.isFinite &&
        food.carbohydrates.isFinite &&
        food.hydrationMl.isFinite &&
        food.hydrationMl >= 0;
    return DailyLogModuleCompleteness(
      state: valid && missing.isEmpty
          ? DailyLogCompletenessState.complete
          : DailyLogCompletenessState.incomplete,
      missingRequirements: valid && missing.isEmpty
          ? const []
          : missing.isEmpty
          ? const ['FOOD']
          : missing,
    );
  }

  static DailyLogModuleCompleteness _activityCompleteness(
    ActivitySummary activity,
  ) {
    final stepsRecorded =
        activity.isRecorded && activity.calculationBasis?.rawSteps != null;
    final digestive = activity.digestiveSummary;
    final digestiveRecorded =
        activity.isRecorded &&
        digestive != null &&
        (digestive.eventCount > 0 || digestive.hasExplicitNoMovement);
    final missing = [
      if (!stepsRecorded) 'STEPS',
      if (!digestiveRecorded) 'DIGESTIVE',
    ];
    if (!activity.isRecorded) {
      return DailyLogModuleCompleteness(
        state: DailyLogCompletenessState.notRecorded,
        missingRequirements: missing,
      );
    }
    if (activity.officialSteps < 0) {
      return const DailyLogModuleCompleteness(
        state: DailyLogCompletenessState.incomplete,
        missingRequirements: ['STEPS'],
      );
    }

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
      return DailyLogModuleCompleteness(
        state: DailyLogCompletenessState.incomplete,
        missingRequirements: missing.isEmpty ? const ['STEPS'] : missing,
      );
    }

    final valid =
        measuredSteps + carryOver - previousDeduction == officialSteps &&
        officialSteps == activity.officialSteps &&
        measuredSteps == activity.measuredSteps &&
        carryOver == activity.carryOver &&
        previousDeduction == activity.previousCarryOverDeduction;
    return DailyLogModuleCompleteness(
      state: valid && missing.isEmpty
          ? DailyLogCompletenessState.complete
          : DailyLogCompletenessState.incomplete,
      missingRequirements: valid && missing.isEmpty
          ? const []
          : missing.isEmpty
          ? const ['STEPS']
          : missing,
    );
  }

  static bool _isValidTraining(TrainingSummary? training) {
    if (training == null) return true;

    return training.completed &&
        training.exerciseCount >= 0 &&
        training.setCount >= 0 &&
        (training.duration == null || training.duration! >= Duration.zero);
  }
}
