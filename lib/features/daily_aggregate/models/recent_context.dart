class RecentContextMetric {
  final double? average;
  final num? start;
  final num? end;
  final int validCount;

  const RecentContextMetric({
    required this.average,
    required this.start,
    required this.end,
    required this.validCount,
  });

  Map<String, Object?> toJson() => {
    'average': average,
    'start': start,
    'end': end,
    'validCount': validCount,
  };
}

class RecentContext {
  final String windowStart;
  final String windowEnd;
  final int requestedDays;
  final RecentContextMetric weightKg;
  final RecentContextMetric bodyFatPercent;
  final RecentContextMetric sleepDurationMinutes;
  final RecentContextMetric sleepScore;
  final RecentContextMetric plantarFasciitisLevel;
  final RecentContextMetric intakeCaloriesKcal;
  final RecentContextMetric proteinG;
  final RecentContextMetric estimatedExpenditureKcal;
  final RecentContextMetric estimatedCalorieBalanceKcal;
  final RecentContextMetric hydrationMl;
  final RecentContextMetric officialSteps;

  const RecentContext({
    required this.windowStart,
    required this.windowEnd,
    this.requestedDays = 7,
    required this.weightKg,
    required this.bodyFatPercent,
    required this.sleepDurationMinutes,
    required this.sleepScore,
    required this.plantarFasciitisLevel,
    required this.intakeCaloriesKcal,
    required this.proteinG,
    required this.estimatedExpenditureKcal,
    required this.estimatedCalorieBalanceKcal,
    required this.hydrationMl,
    required this.officialSteps,
  });

  Map<String, Object?> toJson() => {
    'windowStart': windowStart,
    'windowEnd': windowEnd,
    'requestedDays': requestedDays,
    'body': {
      'weightKg': weightKg.toJson(),
      'bodyFatPercent': bodyFatPercent.toJson(),
    },
    'recovery': {
      'sleepDurationMinutes': sleepDurationMinutes.toJson(),
      'sleepScore': sleepScore.toJson(),
    },
    'condition': {'plantarFasciitisLevel': plantarFasciitisLevel.toJson()},
    'nutrition': {
      'intakeCaloriesKcal': intakeCaloriesKcal.toJson(),
      'proteinG': proteinG.toJson(),
    },
    'energy': {
      'estimatedExpenditureKcal': estimatedExpenditureKcal.toJson(),
      'estimatedCalorieBalanceKcal': estimatedCalorieBalanceKcal.toJson(),
    },
    'hydration': {'hydrationMl': hydrationMl.toJson()},
    'activity': {'officialSteps': officialSteps.toJson()},
  };
}
