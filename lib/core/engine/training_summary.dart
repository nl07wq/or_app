enum TrainingEnergyCalculationStatus { complete, partial, notCalculated }

class TrainingSummary {
  final bool completed;
  final int exerciseCount;
  final int setCount;
  final Duration? duration;
  final String? sessionName;
  final double? trainingCardioCaloriesKcal;
  final double? trainingStrengthCaloriesKcal;
  final double? trainingEstimatedCaloriesKcal;
  final int? computedCardioCount;
  final int? uncomputedCardioCount;
  final TrainingEnergyCalculationStatus? energyCalculationStatus;
  final TrainingEnergyCalculationStatus? totalEnergyCalculationStatus;
  final int? energyCalculationVersion;

  const TrainingSummary({
    required this.completed,
    required this.exerciseCount,
    required this.setCount,
    required this.duration,
    required this.sessionName,
    this.trainingCardioCaloriesKcal,
    this.trainingStrengthCaloriesKcal,
    this.trainingEstimatedCaloriesKcal,
    this.computedCardioCount,
    this.uncomputedCardioCount,
    this.energyCalculationStatus,
    this.totalEnergyCalculationStatus,
    this.energyCalculationVersion,
  });

  Map<String, dynamic> toJson() => {
    'completed': completed,
    'exerciseCount': exerciseCount,
    'setCount': setCount,
    'duration': duration?.inMicroseconds,
    'sessionName': sessionName,
    if (trainingCardioCaloriesKcal != null)
      'trainingCardioCaloriesKcal': trainingCardioCaloriesKcal,
    if (trainingStrengthCaloriesKcal != null)
      'trainingStrengthCaloriesKcal': trainingStrengthCaloriesKcal,
    if (trainingEstimatedCaloriesKcal != null)
      'trainingEstimatedCaloriesKcal': trainingEstimatedCaloriesKcal,
    if (computedCardioCount != null) 'computedCardioCount': computedCardioCount,
    if (uncomputedCardioCount != null)
      'uncomputedCardioCount': uncomputedCardioCount,
    if (energyCalculationStatus != null)
      'energyCalculationStatus': energyCalculationStatus!.name,
    if (totalEnergyCalculationStatus != null)
      'totalEnergyCalculationStatus': totalEnergyCalculationStatus!.name,
    if (energyCalculationVersion != null)
      'energyCalculationVersion': energyCalculationVersion,
  };

  factory TrainingSummary.fromJson(Map<String, dynamic> json) =>
      TrainingSummary(
        completed: json['completed'] as bool,
        exerciseCount: json['exerciseCount'] as int,
        setCount: json['setCount'] as int,
        duration: (json['duration'] as int?) == null
            ? null
            : Duration(microseconds: json['duration'] as int),
        sessionName: json['sessionName'] as String?,
        trainingCardioCaloriesKcal: (json['trainingCardioCaloriesKcal'] as num?)
            ?.toDouble(),
        trainingStrengthCaloriesKcal:
            (json['trainingStrengthCaloriesKcal'] as num?)?.toDouble(),
        trainingEstimatedCaloriesKcal:
            (json['trainingEstimatedCaloriesKcal'] as num?)?.toDouble(),
        computedCardioCount: (json['computedCardioCount'] as num?)?.toInt(),
        uncomputedCardioCount: (json['uncomputedCardioCount'] as num?)?.toInt(),
        energyCalculationStatus: _decodeEnergyStatus(
          json['energyCalculationStatus'],
        ),
        totalEnergyCalculationStatus: _decodeEnergyStatus(
          json['totalEnergyCalculationStatus'],
        ),
        energyCalculationVersion: (json['energyCalculationVersion'] as num?)
            ?.toInt(),
      );
}

TrainingEnergyCalculationStatus? _decodeEnergyStatus(Object? value) {
  if (value == null) return null;
  if (value is! String) {
    throw const FormatException('Invalid Training energy status.');
  }
  try {
    return TrainingEnergyCalculationStatus.values.byName(value);
  } on ArgumentError {
    throw FormatException('Unknown Training energy status: $value.');
  }
}
