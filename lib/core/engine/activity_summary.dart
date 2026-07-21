import '../models/activity_data.dart';

class ActivitySummary {
  /// Official daily steps. Existing Dashboard consumers continue using this.
  final int steps;
  final int measuredSteps;
  final int carryOver;
  final int previousCarryOverDeduction;
  final bool isRecorded;

  const ActivitySummary({
    required this.steps,
    required this.isRecorded,
    int? measuredSteps,
    this.carryOver = 0,
    this.previousCarryOverDeduction = 0,
  }) : measuredSteps = measuredSteps ?? steps,
       assert(
         steps ==
             (measuredSteps ?? steps) + carryOver - previousCarryOverDeduction,
       ),
       assert(steps >= 0),
       assert((measuredSteps ?? steps) >= 0),
       assert(carryOver >= 0),
       assert(previousCarryOverDeduction >= 0);

  const ActivitySummary.empty()
    : steps = 0,
      measuredSteps = 0,
      carryOver = 0,
      previousCarryOverDeduction = 0,
      isRecorded = false;

  int get officialSteps => steps;

  factory ActivitySummary.fromActivityData(
    ActivityData data, {
    int previousCarryOver = 0,
  }) => ActivitySummary(
    steps: data.officialStepsFor(previousCarryOver),
    measuredSteps: data.measuredSteps,
    carryOver: data.carryOver,
    previousCarryOverDeduction: previousCarryOver,
    isRecorded: true,
  );

  Map<String, dynamic> toJson() => {
    'steps': steps,
    'measuredSteps': measuredSteps,
    'carryOver': carryOver,
    'previousCarryOverDeduction': previousCarryOverDeduction,
    'officialSteps': officialSteps,
    'isRecorded': isRecorded,
  };

  factory ActivitySummary.fromJson(Map<String, dynamic> json) {
    final hasCurrentCarryOver = json.containsKey('carryOver');
    final legacySteps = ((json['officialSteps'] ?? json['steps']) as num)
        .toInt();
    final measuredSteps = hasCurrentCarryOver
        ? (json['measuredSteps'] as num?)?.toInt() ?? legacySteps
        // Do not reinterpret the former applied/recorded snapshot fields.
        : legacySteps;
    final carryOver = hasCurrentCarryOver
        ? (json['carryOver'] as num?)?.toInt() ?? 0
        : 0;
    final previousDeduction = hasCurrentCarryOver
        ? (json['previousCarryOverDeduction'] as num?)?.toInt() ?? 0
        : 0;

    return ActivitySummary(
      steps: hasCurrentCarryOver
          ? legacySteps
          : measuredSteps + carryOver - previousDeduction,
      measuredSteps: measuredSteps,
      carryOver: carryOver,
      previousCarryOverDeduction: previousDeduction,
      isRecorded: json['isRecorded'] as bool,
    );
  }
}
