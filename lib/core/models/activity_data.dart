class ActivityData {
  final DateTime date;
  final int measuredSteps;

  /// Steps attributed to this calendar day after the date boundary.
  /// The same value is deducted from the following calendar day's record.
  final int carryOver;

  ActivityData({
    required DateTime date,
    int? steps,
    int? measuredSteps,
    this.carryOver = 0,
  }) : date = DateTime(date.year, date.month, date.day),
       measuredSteps = measuredSteps ?? steps ?? 0 {
    if (steps != null && measuredSteps != null) {
      throw ArgumentError('Specify either steps or measuredSteps, not both.');
    }
    if (steps == null && measuredSteps == null) {
      throw ArgumentError('measuredSteps is required.');
    }
    if (this.measuredSteps < 0 || carryOver < 0) {
      throw ArgumentError('Activity step values must not be negative.');
    }
  }

  /// Calculates the official daily total once the prior calendar day is known.
  ///
  /// Carry Over is added to its own date and deducted only on the next date.
  int officialStepsFor(int previousCarryOver) {
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
    DateTime? date,
    int? steps,
    int? measuredSteps,
    int? carryOver,
  }) {
    if (steps != null && measuredSteps != null) {
      throw ArgumentError('Specify either steps or measuredSteps, not both.');
    }

    return ActivityData(
      date: date ?? this.date,
      measuredSteps: measuredSteps ?? steps ?? this.measuredSteps,
      carryOver: carryOver ?? this.carryOver,
    );
  }

  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String(),
    // Retained so older records remain safely readable as measured steps.
    'steps': measuredSteps,
    'measuredSteps': measuredSteps,
    'carryOver': carryOver,
  };

  factory ActivityData.fromJson(Map<String, dynamic> json) {
    final hasCurrentCarryOver = json.containsKey('carryOver');
    final legacySteps = (json['steps'] as num?)?.toInt();
    final measuredSteps = hasCurrentCarryOver
        ? (json['measuredSteps'] as num?)?.toInt() ?? legacySteps
        // The former applied/recorded fields had different semantics. Do not
        // infer a new Carry Over value from them.
        : legacySteps;

    if (measuredSteps == null) {
      throw const FormatException('Activity data is missing measured steps.');
    }

    return ActivityData(
      date: DateTime.parse(json['date'] as String),
      measuredSteps: measuredSteps,
      carryOver: hasCurrentCarryOver
          ? (json['carryOver'] as num?)?.toInt() ?? 0
          : 0,
    );
  }

  /// Backward-compatible access to the device-measured step count.
  ///
  /// Official steps require the previous day's carry-over and must be
  /// calculated with [officialStepsFor].
  @Deprecated('Use measuredSteps or officialStepsFor(previousCarryOver).')
  int get steps => measuredSteps;
}
