import '../../body_history/models/body_history_models.dart';

enum NutritionHistoryMetric {
  intakeCalories('INTAKE CALORIES'),
  estimatedExpenditure('ESTIMATED EXPENDITURE'),
  calorieBalance('CALORIE BALANCE'),
  protein('PROTEIN'),
  fat('FAT'),
  carbohydrate('CARBOHYDRATE');

  const NutritionHistoryMetric(this.label);

  final String label;
  String get unit => switch (this) {
    NutritionHistoryMetric.intakeCalories ||
    NutritionHistoryMetric.estimatedExpenditure ||
    NutritionHistoryMetric.calorieBalance => 'kcal',
    NutritionHistoryMetric.protein ||
    NutritionHistoryMetric.fat ||
    NutritionHistoryMetric.carbohydrate => 'g',
  };
}

class NutritionHistoryDataPoint {
  final String operationDate;
  final double? intakeCaloriesKcal;
  final double? estimatedExpenditureKcal;
  final double? estimatedCalorieBalanceKcal;
  final double? proteinG;
  final double? fatG;
  final double? carbohydrateG;

  const NutritionHistoryDataPoint({
    required this.operationDate,
    required this.intakeCaloriesKcal,
    required this.estimatedExpenditureKcal,
    required this.estimatedCalorieBalanceKcal,
    this.proteinG,
    this.fatG,
    this.carbohydrateG,
  });

  double? valueFor(NutritionHistoryMetric metric) => switch (metric) {
    NutritionHistoryMetric.intakeCalories => intakeCaloriesKcal,
    NutritionHistoryMetric.estimatedExpenditure => estimatedExpenditureKcal,
    NutritionHistoryMetric.calorieBalance => estimatedCalorieBalanceKcal,
    NutritionHistoryMetric.protein => proteinG,
    NutritionHistoryMetric.fat => fatG,
    NutritionHistoryMetric.carbohydrate => carbohydrateG,
  };
}

class NutritionHistoryChartModel {
  final NutritionHistoryMetric metric;
  final BodyHistoryGranularity granularity;
  final String startDate;
  final String endDate;
  final List<BodyHistoryDisplayPoint> points;
  final List<List<BodyHistoryDisplayPoint>> segments;
  final int displayBucketDays;
  final NutritionHistorySummary? summary;
  final BodyHistoryAxisRange? axis;

  NutritionHistoryChartModel({
    required this.metric,
    required this.granularity,
    required this.startDate,
    required this.endDate,
    required Iterable<BodyHistoryDisplayPoint> points,
    required Iterable<List<BodyHistoryDisplayPoint>> segments,
    this.displayBucketDays = 1,
    required this.summary,
    required this.axis,
  }) : points = List.unmodifiable(points),
       segments = List.unmodifiable(
         segments.map(List<BodyHistoryDisplayPoint>.unmodifiable),
       );

  bool get showZeroLine => metric == NutritionHistoryMetric.calorieBalance;
}

class NutritionHistorySummary {
  final double maximum;
  final double minimum;
  final double average;
  final int measurementCount;

  const NutritionHistorySummary({
    required this.maximum,
    required this.minimum,
    required this.average,
    required this.measurementCount,
  });
}
