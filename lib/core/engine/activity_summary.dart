import '../models/activity_data.dart';
import '../models/bowel_movement_record.dart';

enum ActivitySummaryStatus { unrecorded, incomplete, confirmed }

enum ActivitySummaryWarningCode {
  stepsUnconfirmed,
  carryOverUnconfirmed,
  workUnconfirmed,
  trainingUnconfirmed,
  bowelUnconfirmed,
  officialStepsInvalid,
}

class ActivitySummaryWarning {
  final ActivitySummaryWarningCode code;

  const ActivitySummaryWarning(this.code);

  Map<String, dynamic> toJson() => {'code': code.name};

  factory ActivitySummaryWarning.fromJson(Map<String, dynamic> json) =>
      ActivitySummaryWarning(
        ActivitySummaryWarningCode.values.firstWhere(
          (value) => value.name == json['code'],
        ),
      );
}

class ActivityCalculationBasis {
  final int? rawSteps;
  final int? currentCarryOver;
  final int previousCarryOverDeduction;
  final int? officialSteps;

  const ActivityCalculationBasis({
    required this.rawSteps,
    required this.currentCarryOver,
    required this.previousCarryOverDeduction,
    required this.officialSteps,
  });

  int? get netCarryOver => currentCarryOver == null
      ? null
      : currentCarryOver! - previousCarryOverDeduction;

  Map<String, dynamic> toJson() => {
    'rawSteps': rawSteps,
    'currentCarryOver': currentCarryOver,
    'previousCarryOverDeduction': previousCarryOverDeduction,
    'officialSteps': officialSteps,
  };

  factory ActivityCalculationBasis.fromJson(Map<String, dynamic> json) =>
      ActivityCalculationBasis(
        rawSteps: (json['rawSteps'] as num?)?.toInt(),
        currentCarryOver: (json['currentCarryOver'] as num?)?.toInt(),
        previousCarryOverDeduction:
            (json['previousCarryOverDeduction'] as num?)?.toInt() ?? 0,
        officialSteps: (json['officialSteps'] as num?)?.toInt(),
      );
}

class ActivitySummary {
  /// Official daily steps. Existing Dashboard consumers continue using this.
  final int steps;
  final int measuredSteps;
  final int carryOver;
  final int previousCarryOverDeduction;
  final bool isRecorded;
  final String? recordId;
  final DateTime? date;
  final String? plannedWork;
  final String? actualWork;
  final ActivityTrainingStatus trainingStatus;
  final BowelMovementRecord bowelMovement;
  final ActivitySummaryStatus status;
  final List<String> unconfirmedFields;
  final List<ActivitySummaryWarning> warnings;
  final ActivityCalculationBasis? calculationBasis;

  const ActivitySummary({
    required this.steps,
    required this.isRecorded,
    int? measuredSteps,
    this.carryOver = 0,
    this.previousCarryOverDeduction = 0,
    this.recordId,
    this.date,
    this.plannedWork,
    this.actualWork,
    this.trainingStatus = ActivityTrainingStatus.unconfirmed,
    this.bowelMovement = const BowelMovementRecord.unconfirmed(),
    this.status = ActivitySummaryStatus.confirmed,
    this.unconfirmedFields = const [],
    this.warnings = const [],
    this.calculationBasis,
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
      isRecorded = false,
      recordId = null,
      date = null,
      plannedWork = null,
      actualWork = null,
      trainingStatus = ActivityTrainingStatus.unconfirmed,
      bowelMovement = const BowelMovementRecord.unconfirmed(),
      status = ActivitySummaryStatus.unrecorded,
      unconfirmedFields = const [],
      warnings = const [],
      calculationBasis = null;

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
    recordId: data.id,
    date: data.date,
    plannedWork: data.plannedWork,
    actualWork: data.actualWork,
    trainingStatus: data.trainingStatus,
    bowelMovement: data.bowelMovement,
    calculationBasis: ActivityCalculationBasis(
      rawSteps: data.rawSteps,
      currentCarryOver: data.carryoverSteps,
      previousCarryOverDeduction: previousCarryOver,
      officialSteps: data.officialStepsFor(previousCarryOver),
    ),
  );

  Map<String, dynamic> toJson() => {
    'steps': steps,
    'measuredSteps': measuredSteps,
    'carryOver': carryOver,
    'previousCarryOverDeduction': previousCarryOverDeduction,
    'officialSteps': officialSteps,
    'isRecorded': isRecorded,
    if (recordId != null) 'recordId': recordId,
    if (date != null) 'date': date!.toIso8601String(),
    if (plannedWork != null) 'plannedWork': plannedWork,
    if (actualWork != null) 'actualWork': actualWork,
    'trainingStatus': trainingStatus.name,
    'bowelMovement': bowelMovement.toJson(),
    'status': status.name,
    'unconfirmedFields': unconfirmedFields,
    'warnings': warnings.map((warning) => warning.toJson()).toList(),
    if (calculationBasis != null)
      'calculationBasis': calculationBasis!.toJson(),
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
      recordId: json['recordId'] as String?,
      date: json['date'] == null
          ? null
          : DateTime.parse(json['date'] as String),
      plannedWork: json['plannedWork'] as String?,
      actualWork: json['actualWork'] as String?,
      trainingStatus: ActivityTrainingStatus.values.firstWhere(
        (value) => value.name == json['trainingStatus'],
        orElse: () => ActivityTrainingStatus.unconfirmed,
      ),
      bowelMovement: json['bowelMovement'] is Map
          ? BowelMovementRecord.fromJson(
              Map<String, dynamic>.from(json['bowelMovement'] as Map),
            )
          : const BowelMovementRecord.unconfirmed(),
      status: ActivitySummaryStatus.values.firstWhere(
        (value) => value.name == json['status'],
        orElse: () => json['isRecorded'] == true
            ? ActivitySummaryStatus.confirmed
            : ActivitySummaryStatus.unrecorded,
      ),
      unconfirmedFields: List<String>.unmodifiable(
        (json['unconfirmedFields'] as List? ?? const []).cast<String>(),
      ),
      warnings: List<ActivitySummaryWarning>.unmodifiable(
        (json['warnings'] as List? ?? const []).map(
          (warning) => ActivitySummaryWarning.fromJson(
            Map<String, dynamic>.from(warning as Map),
          ),
        ),
      ),
      calculationBasis: json['calculationBasis'] is Map
          ? ActivityCalculationBasis.fromJson(
              Map<String, dynamic>.from(json['calculationBasis'] as Map),
            )
          : null,
    );
  }
}
