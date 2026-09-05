enum DynamicTargetAvailability { available, partial, notAvailable }

enum DynamicTargetState {
  green,
  greenHigh,
  yellowLow,
  yellowHigh,
  redLow,
  redHigh,
  neutral,
}

enum BodyReferenceSourceType {
  measuredToday,
  sevenDayMean,
  fourteenDayMean,
  notAvailable,
}

enum TrainingAdjustmentSource { formalRecord, noneConfirmed }

class DerivedBodyReference {
  const DerivedBodyReference({
    required this.value,
    required this.sourceType,
    required this.sampleCount,
    required this.windowDays,
  });

  const DerivedBodyReference.notAvailable()
    : value = null,
      sourceType = BodyReferenceSourceType.notAvailable,
      sampleCount = 0,
      windowDays = 0;

  final double? value;
  final BodyReferenceSourceType sourceType;
  final int sampleCount;
  final int windowDays;

  bool get isAvailable => value != null;
}

class ReferenceBodyState {
  const ReferenceBodyState({
    required this.weight,
    required this.bodyFat,
    required this.leanMassKg,
  });

  final DerivedBodyReference weight;
  final DerivedBodyReference bodyFat;
  final double? leanMassKg;
}

class DynamicRangeTarget {
  const DynamicRangeTarget({
    required this.current,
    required this.low,
    required this.high,
    required this.availability,
    required this.state,
  });

  final double? current;
  final double? low;
  final double? high;
  final DynamicTargetAvailability availability;
  final DynamicTargetState state;
}

class DynamicWaterTarget {
  const DynamicWaterTarget({
    required this.current,
    required this.baseTargetMl,
    required this.stepsAdjustmentMl,
    required this.trainingAdjustmentMl,
    required this.cardioAdjustmentMl,
    required this.finalTargetMl,
    required this.availability,
    required this.state,
    required this.trainingAdjustmentSource,
  });

  final double? current;
  final double? baseTargetMl;
  final double stepsAdjustmentMl;
  final double trainingAdjustmentMl;
  final double cardioAdjustmentMl;
  final double? finalTargetMl;
  final DynamicTargetAvailability availability;
  final DynamicTargetState state;
  final TrainingAdjustmentSource trainingAdjustmentSource;
}

class DynamicDailyTargetResult {
  static const currentRuleVersion = 'DDT-v1';

  const DynamicDailyTargetResult({
    required this.ruleVersion,
    required this.referenceBody,
    required this.estimatedBaseBurnKcal,
    required this.estimatedTotalBurnKcal,
    required this.calories,
    required this.protein,
    required this.fat,
    required this.carbohydrate,
    required this.water,
  });

  final String ruleVersion;
  final ReferenceBodyState referenceBody;
  final double? estimatedBaseBurnKcal;
  final double? estimatedTotalBurnKcal;
  final DynamicRangeTarget calories;
  final DynamicRangeTarget protein;
  final DynamicRangeTarget fat;
  final DynamicRangeTarget carbohydrate;
  final DynamicWaterTarget water;

  bool get nutritionTargetsAvailable =>
      calories.availability == DynamicTargetAvailability.available &&
      protein.availability == DynamicTargetAvailability.available &&
      fat.availability == DynamicTargetAvailability.available &&
      carbohydrate.availability == DynamicTargetAvailability.available;
}

abstract final class DynamicDailyTargetPresentation {
  static int? caloriesTargetKcal(DynamicRangeTarget? target) =>
      _roundedMidpoint(target, 50);

  static int? proteinTargetG(DynamicRangeTarget? target) =>
      _roundedMidpoint(target, 5);

  static int? fatTargetG(DynamicRangeTarget? target) =>
      _roundedMidpoint(target, 1);

  static int? fatTargetMinG(DynamicRangeTarget? target) =>
      _roundTo(target?.low, 1);

  static int? fatTargetMaxG(DynamicRangeTarget? target) =>
      _roundTo(target?.high, 1);

  static int? carbohydrateTargetG(DynamicRangeTarget? target) =>
      _roundedMidpoint(target, 1);

  static int? waterTargetMl(DynamicWaterTarget? target) =>
      _roundTo(target?.finalTargetMl, 100);

  static int? _roundedMidpoint(DynamicRangeTarget? target, int increment) {
    final low = target?.low;
    final high = target?.high;
    if (low == null || high == null) return null;
    return _roundTo((low + high) / 2, increment);
  }

  static int? _roundTo(double? value, int increment) {
    if (value == null) return null;
    return (value / increment).round() * increment;
  }
}
