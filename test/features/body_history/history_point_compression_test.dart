import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/body_history/models/body_history_models.dart';
import 'package:or_app/features/body_history/services/body_history_chart_engine.dart';
import 'package:or_app/features/body_history/widgets/body_history_chart.dart';
import 'package:or_app/features/nutrition_history/models/nutrition_history_models.dart';
import 'package:or_app/features/nutrition_history/services/nutrition_history_chart_engine.dart';
import 'package:or_app/features/nutrition_history/widgets/nutrition_history_chart.dart';

void main() {
  const bodyEngine = BodyHistoryChartEngine();
  const nutritionEngine = NutritionHistoryChartEngine();

  for (final specification in [
    (BodyHistoryPeriod.oneWeek, 7, 1),
    (BodyHistoryPeriod.fifteenDays, 15, 1),
    (BodyHistoryPeriod.oneMonth, 31, 1),
    (BodyHistoryPeriod.threeMonths, 90, 5),
    (BodyHistoryPeriod.sixMonths, 180, 10),
    (BodyHistoryPeriod.oneYear, 365, 15),
  ]) {
    test('${specification.$1.label} uses ${specification.$3}-day display buckets', () {
      final source = _bodyPoints(specification.$2);
      final model = bodyEngine.build(
        source: source,
        metric: BodyHistoryMetric.weight,
        period: specification.$1,
        startDate: source.first.operationDate,
        endDate: source.last.operationDate,
        availablePlotWidth: 268,
      );

      expect(model.displayBucketDays, specification.$3);
      expect(
        model.points.length,
        (specification.$2 / specification.$3).ceil(),
      );
      expect(model.summary?.measurementCount, specification.$2);
      expect(model.summary?.first, 90);
      expect(model.summary?.latest, 90 + specification.$2 - 1);
      expect(model.summary?.minimum, 90);
      expect(model.summary?.maximum, 90 + specification.$2 - 1);
      expect(model.points.first.value, 90 + specification.$3 - 1);
      expect(
        model.points.first.representativeDate,
        source[specification.$3 - 1].operationDate,
      );
    });
  }

  test('empty buckets create no point, interpolation, carry-forward, or zero', () {
    final model = bodyEngine.build(
      source: [
        _bodyPoint(DateTime.utc(2026, 1, 1), 90),
        _bodyPoint(DateTime.utc(2026, 1, 16), 93),
      ],
      metric: BodyHistoryMetric.weight,
      period: BodyHistoryPeriod.threeMonths,
      startDate: '2026-01-01',
      endDate: '2026-03-31',
      availablePlotWidth: 268,
    );

    expect(model.points, hasLength(2));
    expect(model.points.map((point) => point.value), [90, 93]);
    expect(model.segments, hasLength(2));
    expect(model.points.any((point) => point.value == 0), isFalse);
  });

  test('body fat uses the same five-day representative policy', () {
    final source = _bodyPoints(20);
    final model = bodyEngine.build(
      source: source,
      metric: BodyHistoryMetric.bodyFat,
      period: BodyHistoryPeriod.threeMonths,
      startDate: source.first.operationDate,
      endDate: '2026-03-31',
      availablePlotWidth: 268,
    );

    expect(model.displayBucketDays, 5);
    expect(model.points.map((point) => point.value), [24, 29, 34, 39]);
    expect(model.summary?.measurementCount, 20);
  });

  for (final metric in NutritionHistoryMetric.values) {
    test('${metric.name} uses shared compression without changing summary', () {
      final source = _nutritionPoints(90);
      final model = nutritionEngine.build(
        source: source,
        metric: metric,
        period: BodyHistoryPeriod.threeMonths,
        startDate: source.first.operationDate,
        endDate: source.last.operationDate,
        availablePlotWidth: 268,
      );

      expect(model.displayBucketDays, 5);
      expect(model.points, hasLength(18));
      expect(model.points.first.measurementCount, 5);
      expect(model.points.first.representativeDate, '2026-01-05');
      expect(model.summary?.measurementCount, 90);
      expect(model.summary?.minimum, _nutritionValue(metric, 0));
      expect(model.summary?.maximum, _nutritionValue(metric, 89));
    });
  }

  test('custom period derives bucket size from plot width', () {
    final source = _bodyPoints(365);
    final narrow = bodyEngine.build(
      source: source,
      metric: BodyHistoryMetric.weight,
      period: BodyHistoryPeriod.custom,
      startDate: source.first.operationDate,
      endDate: source.last.operationDate,
      availablePlotWidth: 268,
    );
    final wide = bodyEngine.build(
      source: source,
      metric: BodyHistoryMetric.weight,
      period: BodyHistoryPeriod.custom,
      startDate: source.first.operationDate,
      endDate: source.last.operationDate,
      availablePlotWidth: 1200,
    );

    expect(narrow.displayBucketDays, 34);
    expect(wide.displayBucketDays, 8);
    expect(narrow.points.length, lessThan(wide.points.length));
    expect(narrow.summary?.measurementCount, 365);
    expect(wide.summary?.measurementCount, 365);
  });

  test('compressed tooltip identifies range, representative, and records', () {
    final bodySource = _bodyPoints(5);
    final body = bodyEngine.build(
      source: bodySource,
      metric: BodyHistoryMetric.weight,
      period: BodyHistoryPeriod.threeMonths,
      startDate: '2026-01-01',
      endDate: '2026-03-31',
      availablePlotWidth: 268,
    );
    final nutritionSource = _nutritionPoints(5);
    final nutrition = nutritionEngine.build(
      source: nutritionSource,
      metric: NutritionHistoryMetric.protein,
      period: BodyHistoryPeriod.threeMonths,
      startDate: '2026-01-01',
      endDate: '2026-03-31',
      availablePlotWidth: 268,
    );

    final bodyText = bodyHistoryTooltipText(body, body.points.single);
    final nutritionText = nutritionHistoryTooltipText(
      nutrition,
      nutrition.points.single,
    );
    for (final text in [bodyText, nutritionText]) {
      expect(text, contains('2026-01-01 – 2026-01-05'));
      expect(text, contains('Representative: 2026-01-05'));
      expect(text, contains('Records: 5'));
    }
  });
}

List<BodyHistoryDataPoint> _bodyPoints(int count) => [
  for (var index = 0; index < count; index += 1)
    _bodyPoint(
      DateTime.utc(2026, 1, 1).add(Duration(days: index)),
      90 + index.toDouble(),
    ),
];

BodyHistoryDataPoint _bodyPoint(DateTime date, double weight) =>
    BodyHistoryDataPoint(
      operationDate: _format(date),
      weightKg: weight,
      bodyFatPercent: weight - 70,
      source: BodyHistorySource.status,
    );

List<NutritionHistoryDataPoint> _nutritionPoints(int count) => [
  for (var index = 0; index < count; index += 1)
    NutritionHistoryDataPoint(
      operationDate: _format(
        DateTime.utc(2026, 1, 1).add(Duration(days: index)),
      ),
      intakeCaloriesKcal: _nutritionValue(
        NutritionHistoryMetric.intakeCalories,
        index,
      ),
      estimatedExpenditureKcal: _nutritionValue(
        NutritionHistoryMetric.estimatedExpenditure,
        index,
      ),
      estimatedCalorieBalanceKcal: _nutritionValue(
        NutritionHistoryMetric.calorieBalance,
        index,
      ),
      proteinG: _nutritionValue(NutritionHistoryMetric.protein, index),
      fatG: _nutritionValue(NutritionHistoryMetric.fat, index),
      carbohydrateG: _nutritionValue(
        NutritionHistoryMetric.carbohydrate,
        index,
      ),
    ),
];

double _nutritionValue(NutritionHistoryMetric metric, int index) =>
    switch (metric) {
      NutritionHistoryMetric.intakeCalories => 1500 + index.toDouble(),
      NutritionHistoryMetric.estimatedExpenditure => 2200 + index.toDouble(),
      NutritionHistoryMetric.calorieBalance => -700 + index.toDouble(),
      NutritionHistoryMetric.protein => 100 + index.toDouble(),
      NutritionHistoryMetric.fat => 50 + index.toDouble(),
      NutritionHistoryMetric.carbohydrate => 180 + index.toDouble(),
    };

String _format(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';
