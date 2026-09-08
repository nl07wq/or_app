enum DailyNutritionTargetStatus { low, onTrack, over, unavailable }

enum DailyNutritionAssessmentSeverity {
  unavailable,
  onTrack,
  slight,
  clear,
  large,
}

enum DailyNutritionAssessmentMetric { calories, protein, fat, carbohydrate }

class DailyNutritionTargetAssessment {
  const DailyNutritionTargetAssessment({
    required this.status,
    this.lowerBound,
    this.upperBound,
    this.actual,
    this.nominalTarget,
  });

  final DailyNutritionTargetStatus status;
  final double? lowerBound;
  final double? upperBound;
  final double? actual;
  final double? nominalTarget;

  double? get signedDelta =>
      actual == null || nominalTarget == null ? null : actual! - nominalTarget!;

  double get relativeDeviation => switch (status) {
    DailyNutritionTargetStatus.low
        when actual != null && lowerBound != null && lowerBound! > 0 =>
      ((lowerBound! - actual!) / lowerBound!).clamp(0, double.infinity),
    DailyNutritionTargetStatus.over
        when actual != null && upperBound != null && upperBound! > 0 =>
      ((actual! - upperBound!) / upperBound!).clamp(0, double.infinity),
    _ => 0,
  };

  DailyNutritionAssessmentSeverity get severity => switch (status) {
    DailyNutritionTargetStatus.unavailable =>
      DailyNutritionAssessmentSeverity.unavailable,
    DailyNutritionTargetStatus.onTrack =>
      DailyNutritionAssessmentSeverity.onTrack,
    _ when relativeDeviation <= .15 => DailyNutritionAssessmentSeverity.slight,
    _ when relativeDeviation <= .5 => DailyNutritionAssessmentSeverity.clear,
    _ => DailyNutritionAssessmentSeverity.large,
  };

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
  return _assessNutritionTarget(
    current,
    target * .9,
    target * 1.1,
    nominalTarget: target,
  );
}

DailyNutritionTargetAssessment assessRangedNutritionTarget(
  double current,
  double? minimum,
  double? maximum, {
  double? nominalTarget,
}) {
  if (minimum == null || maximum == null || minimum > maximum) {
    return const DailyNutritionTargetAssessment(
      status: DailyNutritionTargetStatus.unavailable,
    );
  }
  return _assessNutritionTarget(
    current,
    minimum,
    maximum,
    nominalTarget: nominalTarget ?? (minimum + maximum) / 2,
  );
}

DailyNutritionTargetAssessment _assessNutritionTarget(
  double current,
  double minimum,
  double maximum, {
  required double nominalTarget,
}) => DailyNutritionTargetAssessment(
  status: current < minimum
      ? DailyNutritionTargetStatus.low
      : current > maximum
      ? DailyNutritionTargetStatus.over
      : DailyNutritionTargetStatus.onTrack,
  lowerBound: minimum,
  upperBound: maximum,
  actual: current,
  nominalTarget: nominalTarget,
);

String nutritionAssessmentComment(
  DailyNutritionAssessmentMetric metric,
  DailyNutritionTargetAssessment assessment,
) {
  if (assessment.status == DailyNutritionTargetStatus.unavailable) {
    return '目標データなし';
  }
  if (assessment.status == DailyNutritionTargetStatus.onTrack) {
    return switch (metric) {
      DailyNutritionAssessmentMetric.protein => '十分に確保',
      DailyNutritionAssessmentMetric.fat => '適正範囲',
      _ => '目標範囲内',
    };
  }
  final severity = assessment.severity;
  return switch ((metric, assessment.status, severity)) {
    (
      DailyNutritionAssessmentMetric.calories,
      DailyNutritionTargetStatus.low,
      DailyNutritionAssessmentSeverity.slight,
    ) =>
      '摂取やや少なめ',
    (
      DailyNutritionAssessmentMetric.calories,
      DailyNutritionTargetStatus.low,
      DailyNutritionAssessmentSeverity.clear,
    ) =>
      '摂取が目標未達',
    (
      DailyNutritionAssessmentMetric.calories,
      DailyNutritionTargetStatus.low,
      _,
    ) =>
      '摂取が大きく不足',
    (
      DailyNutritionAssessmentMetric.calories,
      DailyNutritionTargetStatus.over,
      DailyNutritionAssessmentSeverity.slight,
    ) =>
      '摂取やや多め',
    (
      DailyNutritionAssessmentMetric.calories,
      DailyNutritionTargetStatus.over,
      DailyNutritionAssessmentSeverity.clear,
    ) =>
      '摂取が目標を超過',
    (
      DailyNutritionAssessmentMetric.calories,
      DailyNutritionTargetStatus.over,
      _,
    ) =>
      '摂取が大きく超過',
    (
      DailyNutritionAssessmentMetric.protein,
      DailyNutritionTargetStatus.low,
      DailyNutritionAssessmentSeverity.slight,
    ) =>
      'たんぱく質やや不足',
    (
      DailyNutritionAssessmentMetric.protein,
      DailyNutritionTargetStatus.low,
      DailyNutritionAssessmentSeverity.clear,
    ) =>
      'たんぱく質が目標未達',
    (
      DailyNutritionAssessmentMetric.protein,
      DailyNutritionTargetStatus.low,
      _,
    ) =>
      'たんぱく質が大きく不足',
    (
      DailyNutritionAssessmentMetric.protein,
      DailyNutritionTargetStatus.over,
      DailyNutritionAssessmentSeverity.slight,
    ) =>
      'たんぱく質はやや多め',
    (
      DailyNutritionAssessmentMetric.protein,
      DailyNutritionTargetStatus.over,
      DailyNutritionAssessmentSeverity.clear,
    ) =>
      'たんぱく質は目標を超過',
    (
      DailyNutritionAssessmentMetric.protein,
      DailyNutritionTargetStatus.over,
      _,
    ) =>
      'たんぱく質が大きく超過',
    (
      DailyNutritionAssessmentMetric.fat,
      DailyNutritionTargetStatus.low,
      DailyNutritionAssessmentSeverity.slight,
    ) =>
      '脂質やや少なめ',
    (
      DailyNutritionAssessmentMetric.fat,
      DailyNutritionTargetStatus.low,
      DailyNutritionAssessmentSeverity.clear,
    ) =>
      '脂質が目標未達',
    (DailyNutritionAssessmentMetric.fat, DailyNutritionTargetStatus.low, _) =>
      '脂質が大きく不足',
    (
      DailyNutritionAssessmentMetric.fat,
      DailyNutritionTargetStatus.over,
      DailyNutritionAssessmentSeverity.slight,
    ) =>
      '脂質やや多め',
    (
      DailyNutritionAssessmentMetric.fat,
      DailyNutritionTargetStatus.over,
      DailyNutritionAssessmentSeverity.clear,
    ) =>
      '脂質が目標を超過',
    (DailyNutritionAssessmentMetric.fat, DailyNutritionTargetStatus.over, _) =>
      '脂質が大きく超過',
    (
      DailyNutritionAssessmentMetric.carbohydrate,
      DailyNutritionTargetStatus.low,
      DailyNutritionAssessmentSeverity.slight,
    ) =>
      '炭水化物やや少なめ',
    (
      DailyNutritionAssessmentMetric.carbohydrate,
      DailyNutritionTargetStatus.low,
      DailyNutritionAssessmentSeverity.clear,
    ) =>
      '炭水化物が目標未達',
    (
      DailyNutritionAssessmentMetric.carbohydrate,
      DailyNutritionTargetStatus.low,
      _,
    ) =>
      '炭水化物が大きく不足',
    (
      DailyNutritionAssessmentMetric.carbohydrate,
      DailyNutritionTargetStatus.over,
      DailyNutritionAssessmentSeverity.slight,
    ) =>
      '炭水化物やや多め',
    (
      DailyNutritionAssessmentMetric.carbohydrate,
      DailyNutritionTargetStatus.over,
      DailyNutritionAssessmentSeverity.clear,
    ) =>
      '炭水化物が目標を超過',
    (
      DailyNutritionAssessmentMetric.carbohydrate,
      DailyNutritionTargetStatus.over,
      _,
    ) =>
      '炭水化物が大きく超過',
    _ => '目標データなし',
  };
}
