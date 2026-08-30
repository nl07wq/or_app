import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/body_history/models/body_history_models.dart';
import 'package:or_app/features/body_history/widgets/body_history_chart.dart';
import 'package:or_app/features/nutrition_history/models/nutrition_history_models.dart';
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
  granularity: BodyHistoryGranularity.daily,
  startDate: '2026-08-01',
  endDate: '2026-08-30',
  points: _points(),
  segments: [_points()],
  summary: null,
  axis: const BodyHistoryAxisRange(minimum: 80, maximum: 120, interval: 10),
);
