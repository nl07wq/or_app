enum DailyNutritionTargetStatus { low, onTrack, over, unavailable }

class DailyNutritionTargetAssessment {
  const DailyNutritionTargetAssessment({
    required this.status,
    this.lowerBound,
    this.upperBound,
  });

  final DailyNutritionTargetStatus status;
  final double? lowerBound;
  final double? upperBound;

  String get badgeLabel => switch (status) {
    DailyNutritionTargetStatus.low => 'LOW',
    DailyNutritionTargetStatus.onTrack => 'ON TRACK',
    DailyNutritionTargetStatus.over => 'OVER',
    DailyNutritionTargetStatus.unavailable => '目標なし',
  };
}

DailyNutritionTargetAssessment assessSingleNutritionTarget(
  double current,
  double? target,
) {
  if (target == null || target <= 0) {
    return const DailyNutritionTargetAssessment(
      status: DailyNutritionTargetStatus.unavailable,
    );
  }
  return _assessNutritionTarget(current, target * .9, target * 1.1);
}

DailyNutritionTargetAssessment assessRangedNutritionTarget(
  double current,
  double? minimum,
  double? maximum,
) {
  if (minimum == null || maximum == null || minimum > maximum) {
    return const DailyNutritionTargetAssessment(
      status: DailyNutritionTargetStatus.unavailable,
    );
  }
  return _assessNutritionTarget(current, minimum, maximum);
}

DailyNutritionTargetAssessment _assessNutritionTarget(
  double current,
  double minimum,
  double maximum,
) => DailyNutritionTargetAssessment(
  status: current < minimum
      ? DailyNutritionTargetStatus.low
      : current > maximum
      ? DailyNutritionTargetStatus.over
      : DailyNutritionTargetStatus.onTrack,
  lowerBound: minimum,
  upperBound: maximum,
);
