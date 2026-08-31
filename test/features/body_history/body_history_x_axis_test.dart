import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/body_history/models/body_history_models.dart';
import 'package:or_app/features/body_history/services/body_history_chart_engine.dart';
import 'package:or_app/features/body_history/services/body_history_x_axis.dart';

void main() {
  const engine = BodyHistoryChartEngine();
  const xAxis = BodyHistoryXAxis();

  test('missing dates retain their calendar distance', () {
    final model = engine.build(
      source: const [
        BodyHistoryDataPoint(
          operationDate: '2026-08-01',
          weightKg: 90,
          bodyFatPercent: null,
          source: BodyHistorySource.status,
        ),
        BodyHistoryDataPoint(
          operationDate: '2026-08-04',
          weightKg: 91,
          bodyFatPercent: null,
          source: BodyHistorySource.status,
        ),
      ],
      metric: BodyHistoryMetric.weight,
      period: BodyHistoryPeriod.oneMonth,
      startDate: '2026-08-01',
      endDate: '2026-08-07',
    );

    expect(model.points.map((point) => point.x), [0, 3]);
  });

  test('wide one-week axis uses daily compact labels', () {
    final ticks = xAxis.ticks(
      startDate: '2026-08-01',
      endDate: '2026-08-07',
      granularity: BodyHistoryGranularity.daily,
      availablePlotWidth: 800,
    );

    expect(ticks.map((tick) => tick.label), [
      '8/1',
      '2',
      '3',
      '4',
      '5',
      '6',
      '7',
    ]);
  });

  test('one-month axis preserves interior preset ticks', () {
    final ticks = xAxis.ticks(
      startDate: '2026-08-01',
      endDate: '2026-08-30',
      granularity: BodyHistoryGranularity.daily,
      availablePlotWidth: 200,
    );

    expect(ticks.map((tick) => tick.label), [
      '8/1',
      '5',
      '10',
      '15',
      '20',
      '25',
      '30',
    ]);
  });

  test('month boundary restores the compact month prefix', () {
    final ticks = xAxis.ticks(
      startDate: '2026-08-25',
      endDate: '2026-09-15',
      granularity: BodyHistoryGranularity.daily,
      availablePlotWidth: 800,
    );

    expect(ticks.map((tick) => tick.label), [
      '8/25',
      '30',
      '9/1',
      '5',
      '10',
      '15',
    ]);
  });

  test('one-week axis keeps every calendar day at narrow width', () {
    final ticks = xAxis.ticks(
      startDate: '2026-08-01',
      endDate: '2026-08-07',
      granularity: BodyHistoryGranularity.daily,
      availablePlotWidth: 192,
    );

    expect(ticks.map((tick) => tick.label), [
      '8/1',
      '2',
      '3',
      '4',
      '5',
      '6',
      '7',
    ]);
  });

  test('one-week label count is viewport independent', () {
    final narrow = xAxis.ticks(
      startDate: '2026-08-01',
      endDate: '2026-08-07',
      granularity: BodyHistoryGranularity.daily,
      availablePlotWidth: 192,
    );
    final wide = xAxis.ticks(
      startDate: '2026-08-01',
      endDate: '2026-08-07',
      granularity: BodyHistoryGranularity.daily,
      availablePlotWidth: 800,
    );

    expect(wide.map((tick) => tick.label), narrow.map((tick) => tick.label));
  });

  test('three-month axis preserves internal month days 1, 15 and 25', () {
    final ticks = xAxis.ticks(
      startDate: '2026-08-01',
      endDate: '2026-10-31',
      granularity: BodyHistoryGranularity.daily,
      availablePlotWidth: 900,
    );
    expect(ticks.map((tick) => tick.label), [
      '8/1',
      '15',
      '25',
      '9/1',
      '15',
      '25',
      '10/1',
      '15',
      '31',
    ]);
    expect(ticks.map((tick) => tick.label), isNot(contains('5')));
  });

  test('six-month axis preserves internal month starts and midpoints', () {
    final ticks = xAxis.ticks(
      startDate: '2026-01-01',
      endDate: '2026-06-30',
      granularity: BodyHistoryGranularity.daily,
      availablePlotWidth: 900,
    );
    expect(ticks.map((tick) => tick.label), [
      '1/1',
      '15',
      '2/1',
      '15',
      '3/1',
      '15',
      '4/1',
      '15',
      '5/1',
      '15',
      '6/1',
      '15',
      '30',
    ]);
  });

  test('one-year axis preserves month starts and retains boundaries', () {
    final ticks = xAxis.ticks(
      startDate: '2025-09-01',
      endDate: '2026-08-31',
      granularity: BodyHistoryGranularity.daily,
      availablePlotWidth: 900,
    );
    expect(ticks.first.x, 0);
    expect(ticks.last.x, 364);
    expect(
      ticks.map((tick) => tick.label),
      containsAll(['9/1', '10/1', '11/1', '12/1', '2026/1/1', '8/1']),
    );
  });

  test('start boundary suppresses a nearby lower-priority preset tick', () {
    final ticks = xAxis.ticks(
      startDate: '2026-07-31',
      endDate: '2026-08-30',
      granularity: BodyHistoryGranularity.daily,
      availablePlotWidth: 200,
    );

    expect(ticks.first.label, '7/31');
    expect(ticks.last.label, '30');
    expect(ticks.map((tick) => tick.label), isNot(contains('8/1')));
    expect(ticks.map((tick) => tick.label), containsAll(['8/5', '10', '15']));
  });

  test('end boundary suppresses only its nearby preset tick', () {
    final ticks = xAxis.ticks(
      startDate: '2026-08-01',
      endDate: '2026-08-31',
      granularity: BodyHistoryGranularity.daily,
      availablePlotWidth: 200,
    );

    expect(ticks.last.label, '31');
    expect(ticks.map((tick) => tick.label), isNot(contains('30')));
    expect(
      ticks.map((tick) => tick.label),
      containsAll(['5', '10', '15', '20', '25']),
    );
  });

  test('boundary suppression preserves unrelated three-month ticks', () {
    final ticks = xAxis.ticks(
      startDate: '2026-07-31',
      endDate: '2026-10-31',
      granularity: BodyHistoryGranularity.daily,
      availablePlotWidth: 192,
    );

    expect(ticks.first.label, '7/31');
    expect(ticks.map((tick) => tick.label), isNot(contains('8/1')));
    expect(
      ticks.map((tick) => tick.label),
      containsAll(['8/15', '25', '9/1', '15', '10/1']),
    );
  });

  test('six-month start suppresses only a nearby 15-day preset tick', () {
    final ticks = xAxis.ticks(
      startDate: '2026-01-12',
      endDate: '2026-07-12',
      granularity: BodyHistoryGranularity.daily,
      availablePlotWidth: 390,
    );

    expect(ticks.first.label, '1/12');
    expect(ticks.map((tick) => tick.x), isNot(contains(3)));
    expect(ticks.map((tick) => tick.label), containsAll(['2/1', '15', '3/1']));
  });

  test('calendar preset ticks are viewport independent', () {
    List<String> labels(double width) => xAxis
        .ticks(
          startDate: '2026-08-01',
          endDate: '2026-08-30',
          granularity: BodyHistoryGranularity.daily,
          availablePlotWidth: width,
        )
        .map((tick) => tick.label)
        .toList();

    expect(labels(192), labels(1280));
  });
}
