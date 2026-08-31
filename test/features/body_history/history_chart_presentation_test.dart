import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/body_history/models/body_history_models.dart';
import 'package:or_app/features/body_history/services/body_history_chart_engine.dart';
import 'package:or_app/features/body_history/widgets/body_history_chart.dart';
import 'package:or_app/features/nutrition_history/models/nutrition_history_models.dart';
import 'package:or_app/features/nutrition_history/services/nutrition_history_chart_engine.dart';
import 'package:or_app/features/nutrition_history/widgets/nutrition_history_chart.dart';

void main() {
  for (final width in [320.0, 390.0, 900.0, 1280.0]) {
    testWidgets(
      'standard history charts fit ${width.toInt()}px without horizontal scroll',
      (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  Expanded(child: BodyHistoryChart(model: _bodyModel())),
                  Expanded(
                    child: NutritionHistoryChart(model: _nutritionModel()),
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pump();

        expect(find.byType(SingleChildScrollView), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    for (final periodCase in const [
      (BodyHistoryPeriod.threeMonths, 90, 5),
      (BodyHistoryPeriod.sixMonths, 180, 10),
      (BodyHistoryPeriod.oneYear, 365, 15),
    ]) {
      testWidgets(
        '${periodCase.$1.name} compressed charts fit '
        '${width.toInt()}px without scroll',
        (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  Expanded(
                    child: BodyHistoryChart(
                      model: _longBodyModel(
                        width,
                        periodCase.$1,
                        periodCase.$2,
                      ),
                    ),
                  ),
                  Expanded(
                    child: NutritionHistoryChart(
                      model: _longNutritionModel(
                        width,
                        periodCase.$1,
                        periodCase.$2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pump();

        expect(find.byType(SingleChildScrollView), findsNothing);
        expect(
          _longBodyModel(width, periodCase.$1, periodCase.$2)
              .displayBucketDays,
          periodCase.$3,
        );
        expect(
          _longNutritionModel(width, periodCase.$1, periodCase.$2)
              .displayBucketDays,
          periodCase.$3,
        );
        expect(tester.takeException(), isNull);
        },
      );
    }
  }
}

List<BodyHistoryDisplayPoint> _points() => [
  for (var day = 1; day <= 30; day++)
    BodyHistoryDisplayPoint(
      x: (day - 1).toDouble(),
      value: 90 + day / 10,
      startDate: '2026-08-${day.toString().padLeft(2, '0')}',
      endDate: '2026-08-${day.toString().padLeft(2, '0')}',
      measurementCount: 1,
    ),
];

BodyHistoryChartModel _bodyModel() => BodyHistoryChartModel(
  metric: BodyHistoryMetric.weight,
  period: BodyHistoryPeriod.oneMonth,
  granularity: BodyHistoryGranularity.daily,
  startDate: '2026-08-01',
  endDate: '2026-08-30',
  points: _points(),
  segments: [_points()],
  summary: null,
  axis: const BodyHistoryAxisRange(minimum: 88, maximum: 96, interval: 2),
);

NutritionHistoryChartModel _nutritionModel() => NutritionHistoryChartModel(
  metric: NutritionHistoryMetric.protein,
  period: BodyHistoryPeriod.oneMonth,
  granularity: BodyHistoryGranularity.daily,
  startDate: '2026-08-01',
  endDate: '2026-08-30',
  points: _points(),
  segments: [_points()],
  summary: null,
  axis: const BodyHistoryAxisRange(minimum: 80, maximum: 120, interval: 10),
);

BodyHistoryChartModel _longBodyModel(
  double width,
  BodyHistoryPeriod period,
  int dayCount,
) =>
    const BodyHistoryChartEngine().build(
      source: [
        for (var index = 0; index < dayCount; index += 1)
          BodyHistoryDataPoint(
            operationDate: _date(index),
            weightKg: 90 + index / 100,
            bodyFatPercent: 25 + index / 100,
            source: BodyHistorySource.status,
          ),
      ],
      metric: BodyHistoryMetric.weight,
      period: period,
      startDate: '2025-01-01',
      endDate: '2025-12-31',
      availablePlotWidth: width - BodyHistoryChart.yAxisWidth,
    );

NutritionHistoryChartModel _longNutritionModel(
  double width,
  BodyHistoryPeriod period,
  int dayCount,
) =>
    const NutritionHistoryChartEngine().build(
      source: [
        for (var index = 0; index < dayCount; index += 1)
          NutritionHistoryDataPoint(
            operationDate: _date(index),
            intakeCaloriesKcal: 1800 + index.toDouble(),
            estimatedExpenditureKcal: 2400 + index.toDouble(),
            estimatedCalorieBalanceKcal: -600 + index.toDouble(),
            proteinG: 120 + index / 10,
            fatG: 60 + index / 10,
            carbohydrateG: 220 + index / 10,
          ),
      ],
      metric: NutritionHistoryMetric.intakeCalories,
      period: period,
      startDate: '2025-01-01',
      endDate: '2025-12-31',
      availablePlotWidth: width - NutritionHistoryChart.yAxisWidth,
    );

String _date(int index) {
  final value = DateTime.utc(2025, 1, 1).add(Duration(days: index));
  return '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}
