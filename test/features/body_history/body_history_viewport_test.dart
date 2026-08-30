import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/body_history/models/body_history_models.dart';
import 'package:or_app/features/body_history/services/body_history_chart_engine.dart';

void main() {
  const engine = BodyHistoryChartEngine();

  test('one-month search uses the valid data range as viewport', () {
    final model = engine.build(
      source: _dailyPoints(DateTime.utc(2026, 8, 1), 8),
      metric: BodyHistoryMetric.weight,
      period: BodyHistoryPeriod.oneMonth,
      startDate: '2026-07-10',
      endDate: '2026-08-10',
      availablePlotWidth: 268,
    );

    expect(model.startDate, '2026-08-01');
    expect(model.endDate, '2026-08-08');
    expect(model.granularity, BodyHistoryGranularity.daily);
  });

  test('one-year search with the same sparse data keeps the same viewport', () {
    final model = engine.build(
      source: _dailyPoints(DateTime.utc(2026, 8, 1), 8),
      metric: BodyHistoryMetric.weight,
      period: BodyHistoryPeriod.oneYear,
      startDate: '2025-08-10',
      endDate: '2026-08-10',
      availablePlotWidth: 268,
    );

    expect(model.startDate, '2026-08-01');
    expect(model.endDate, '2026-08-08');
    expect(model.granularity, BodyHistoryGranularity.daily);
  });

  test('missing dates retain their elapsed-day distance inside viewport', () {
    final model = engine.build(
      source: [_point('2026-08-01', 90), _point('2026-08-04', 91)],
      metric: BodyHistoryMetric.weight,
      period: BodyHistoryPeriod.oneMonth,
      startDate: '2026-07-10',
      endDate: '2026-08-10',
      availablePlotWidth: 268,
    );

    expect(model.points.map((point) => point.x), [0, 3]);
  });

  test('thirty daily records remain daily and may use horizontal scroll', () {
    final model = engine.build(
      source: _dailyPoints(DateTime.utc(2026, 7, 1), 30),
      metric: BodyHistoryMetric.weight,
      period: BodyHistoryPeriod.oneMonth,
      startDate: '2026-07-01',
      endDate: '2026-07-30',
      availablePlotWidth: 268,
    );

    expect(model.granularity, BodyHistoryGranularity.daily);
    expect(
      engine.chartWidth(pointCount: model.points.length, availableWidth: 268),
      greaterThan(268),
    );
  });

  test('365 daily records use fifteen-day display buckets', () {
    final model = engine.build(
      source: _dailyPoints(DateTime.utc(2025, 8, 10), 365),
      metric: BodyHistoryMetric.weight,
      period: BodyHistoryPeriod.oneYear,
      startDate: '2025-08-10',
      endDate: '2026-08-09',
      availablePlotWidth: 268,
    );

    expect(model.granularity, BodyHistoryGranularity.daily);
    expect(model.displayBucketDays, 15);
    expect(model.points, hasLength(25));
    expect(model.points.first.value, 91.4);
    expect(model.points.first.representativeDate, '2025-08-24');
    expect(model.points.first.measurementCount, 15);
    expect(model.summary?.measurementCount, 365);
  });

  test('three-year sparse records are not forced to monthly averages', () {
    final dates = [
      '2023-08-01',
      '2023-12-01',
      '2024-04-01',
      '2024-08-01',
      '2024-12-01',
      '2025-04-01',
      '2025-08-01',
      '2026-08-01',
    ];
    final model = engine.build(
      source: [
        for (var index = 0; index < dates.length; index++)
          _point(dates[index], 90.0 + index),
      ],
      metric: BodyHistoryMetric.weight,
      period: BodyHistoryPeriod.custom,
      startDate: '2023-08-01',
      endDate: '2026-08-01',
      availablePlotWidth: 268,
    );

    expect(model.granularity, BodyHistoryGranularity.daily);
    expect(model.startDate, dates.first);
    expect(model.endDate, dates.last);
  });

  test('Y axis prevents exaggeration and expands for large changes', () {
    final small = engine.axisFor(BodyHistoryMetric.weight, const [96.8, 97.2]);
    final large = engine.axisFor(BodyHistoryMetric.weight, const [80, 100]);

    expect(small.maximum - small.minimum, greaterThanOrEqualTo(5));
    expect(large.minimum, lessThan(80));
    expect(large.maximum, greaterThan(100));
  });
}

List<BodyHistoryDataPoint> _dailyPoints(DateTime start, int count) => [
  for (var index = 0; index < count; index++)
    _point(_format(start.add(Duration(days: index))), 90 + index / 10),
];

BodyHistoryDataPoint _point(String date, double weight) => BodyHistoryDataPoint(
  operationDate: date,
  weightKg: weight,
  bodyFatPercent: weight / 5,
  source: BodyHistorySource.status,
);

String _format(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';
