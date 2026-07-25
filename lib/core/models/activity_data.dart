import 'bowel_movement_record.dart';

enum ActivityTrainingStatus { unconfirmed, planned, completed, skipped }

class ActivityData {
  static const Object _unset = Object();

  final String id;
  final DateTime date;
  final int measuredSteps;
  final bool stepsEntered;

  /// Steps attributed to this calendar day after the date boundary.
  /// The same value is deducted from the following calendar day's record.
  final int carryOver;
  final bool carryOverEntered;
  final int? officialSteps;
  final String? plannedWork;
  final String? actualWork;
  final ActivityTrainingStatus trainingStatus;
  final BowelMovementRecord bowelMovement;
  final String? note;
  final DateTime createdAt;
  final DateTime updatedAt;

  ActivityData({
    String? id,
    required DateTime date,
    int? steps,
    int? measuredSteps,
    this.carryOver = 0,
    bool? stepsEntered,
    bool? carryOverEntered,
    this.officialSteps,
    this.plannedWork,
    this.actualWork,
    this.trainingStatus = ActivityTrainingStatus.unconfirmed,
    this.bowelMovement = const BowelMovementRecord.unconfirmed(),
    this.note,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : id = id ?? _dateId(date),
       date = DateTime(date.year, date.month, date.day),
       measuredSteps = measuredSteps ?? steps ?? 0,
       stepsEntered = stepsEntered ?? (measuredSteps != null || steps != null),
       carryOverEntered = carryOverEntered ?? true,
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? createdAt ?? DateTime.now() {
    if (steps != null && measuredSteps != null) {
      throw ArgumentError('Specify either steps or measuredSteps, not both.');
    }
    if (this.measuredSteps < 0 || carryOver < 0) {
      throw ArgumentError('Activity step values must not be negative.');
    }
  }

  int? get rawSteps => stepsEntered ? measuredSteps : null;

  int? get carryoverSteps => carryOverEntered ? carryOver : null;

  /// Calculates the official daily total once the prior calendar day is known.
  ///
  /// Carry Over is added to its own date and deducted only on the next date.
  int officialStepsFor(int previousCarryOver) {
    if (!stepsEntered) {
      throw StateError('Measured steps have not been entered.');
    }
    if (previousCarryOver < 0) {
      throw ArgumentError('Previous Carry Over must not be negative.');
    }

    final result = measuredSteps + carryOver - previousCarryOver;
    if (result < 0) {
      throw ArgumentError('Official steps must not be negative.');
    }
    return result;
  }

  ActivityData copyWith({
    String? id,
    DateTime? date,
    int? steps,
    int? measuredSteps,
    int? carryOver,
    bool? stepsEntered,
    bool? carryOverEntered,
    Object? officialSteps = _unset,
    Object? plannedWork = _unset,
    Object? actualWork = _unset,
    ActivityTrainingStatus? trainingStatus,
    BowelMovementRecord? bowelMovement,
    Object? note = _unset,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    if (steps != null && measuredSteps != null) {
      throw ArgumentError('Specify either steps or measuredSteps, not both.');
    }

    return ActivityData(
      id: id ?? this.id,
      date: date ?? this.date,
      measuredSteps: measuredSteps ?? steps ?? this.measuredSteps,
      carryOver: carryOver ?? this.carryOver,
      stepsEntered: stepsEntered ?? this.stepsEntered,
      carryOverEntered: carryOverEntered ?? this.carryOverEntered,
      officialSteps: officialSteps == _unset
          ? this.officialSteps
          : officialSteps as int?,
      plannedWork: plannedWork == _unset
          ? this.plannedWork
          : plannedWork as String?,
      actualWork: actualWork == _unset
          ? this.actualWork
          : actualWork as String?,
      trainingStatus: trainingStatus ?? this.trainingStatus,
      bowelMovement: bowelMovement ?? this.bowelMovement,
      note: note == _unset ? this.note : note as String?,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date.toIso8601String(),
    // Retained so older records remain safely readable as measured steps.
    'steps': measuredSteps,
    'measuredSteps': measuredSteps,
    'rawSteps': rawSteps,
    'stepsEntered': stepsEntered,
    'carryOver': carryOver,
    'carryoverSteps': carryoverSteps,
    'carryOverEntered': carryOverEntered,
    if (officialSteps != null) 'officialSteps': officialSteps,
    if (plannedWork != null) 'plannedWork': plannedWork,
    if (actualWork != null) 'actualWork': actualWork,
    'trainingStatus': trainingStatus.name,
    'bowelMovement': bowelMovement.toJson(),
    if (note != null) 'note': note,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory ActivityData.fromJson(Map<String, dynamic> json) {
    final hasCurrentCarryOver = json.containsKey('carryOver');
    final legacySteps = (json['steps'] as num?)?.toInt();
    final rawSteps = (json['rawSteps'] as num?)?.toInt();
    final measuredSteps = hasCurrentCarryOver
        ? rawSteps ?? (json['measuredSteps'] as num?)?.toInt() ?? legacySteps
        // The former applied/recorded fields had different semantics. Do not
        // infer a new Carry Over value from them.
        : legacySteps;

    if (measuredSteps == null) {
      throw const FormatException('Activity data is missing measured steps.');
    }

    return ActivityData(
      id: json['id'] as String?,
      date: DateTime.parse(json['date'] as String),
      measuredSteps: measuredSteps,
      stepsEntered:
          json['stepsEntered'] as bool? ??
          (json.containsKey('measuredSteps') || json.containsKey('steps')),
      carryOver: hasCurrentCarryOver
          ? (json['carryoverSteps'] as num?)?.toInt() ??
                (json['carryOver'] as num?)?.toInt() ??
                0
          : 0,
      carryOverEntered:
          json['carryOverEntered'] as bool? ?? hasCurrentCarryOver,
      officialSteps: (json['officialSteps'] as num?)?.toInt(),
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
      note: json['note'] as String?,
      createdAt:
          _optionalDate(json['createdAt']) ?? DateTime.parse(json['date']),
      updatedAt:
          _optionalDate(json['updatedAt']) ?? DateTime.parse(json['date']),
    );
  }

  /// Backward-compatible access to the device-measured step count.
  ///
  /// Official steps require the previous day's carry-over and must be
  /// calculated with [officialStepsFor].
  @Deprecated('Use measuredSteps or officialStepsFor(previousCarryOver).')
  int get steps => measuredSteps;

  static String _dateId(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  static DateTime? _optionalDate(Object? value) =>
      value is String ? DateTime.tryParse(value) : null;
}
