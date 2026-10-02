import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/schedule/pages/calendar_page.dart';

void main() {
  test('temperature range rail reserves numeric telemetry clearance', () {
    expect(weatherTemperatureRailWidth(296), 88);
    expect(weatherTemperatureRailWidth(366), 158);
    expect(weatherTemperatureRailWidth(620), 250);
    expect(weatherTemperatureRailWidth(320), 112);
  });

  test('forecast row opens daily detail only on a deliberate second tap', () {
    expect(weatherForecastRowOpensDetail(selected: false), isFalse);
    expect(weatherForecastRowOpensDetail(selected: true), isTrue);
  });

  test('solar progress is a daytime time marker only', () {
    expect(
      weatherSolarProgress(
        '2026-10-02T06:00',
        '2026-10-02T18:00',
        now: DateTime(2026, 10, 2, 12),
      ),
      closeTo(.5, .001),
    );
    expect(
      weatherSolarProgress(
        '2026-10-02T06:00',
        '2026-10-02T18:00',
        now: DateTime(2026, 10, 2, 4),
      ),
      isNull,
    );
  });

  test('solar trajectory uses exact circular semicircle geometry', () {
    final geometry = weatherSolarSemicircleGeometry(const Size(216, 124));
    final sunrise = weatherSolarSemicirclePoint(geometry, 0);
    final noon = weatherSolarSemicirclePoint(geometry, .5);
    final sunset = weatherSolarSemicirclePoint(geometry, 1);

    expect(geometry.radius, 108);
    expect(sunrise.dy, closeTo(geometry.center.dy, .001));
    expect(noon.dx, closeTo(geometry.center.dx, .001));
    expect(noon.dy, closeTo(geometry.center.dy - geometry.radius, .001));
    expect(sunset.dy, closeTo(geometry.center.dy, .001));
    for (final point in [sunrise, noon, sunset]) {
      expect(
        (point - geometry.center).distance,
        closeTo(geometry.radius, .001),
      );
    }
  });

  Future<void> pumpSurface(
    WidgetTester tester, {
    required ValueChanged<int> onSwipe,
    bool enabled = true,
  }) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 160,
            height: 72,
            child: WeatherSurfaceGesture(
              enabled: enabled,
              onSwipeLocation: onSwipe,
              child: const ColoredBox(
                key: ValueKey('weather-surface-gesture-child'),
                color: Colors.transparent,
              ),
            ),
          ),
        ),
      ),
    ),
  );

  testWidgets('inside-start horizontal location swipe owns its full drag', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final width in [320.0, 390.0, 900.0]) {
      final directions = <int>[];
      await tester.binding.setSurfaceSize(Size(width, 400));
      await pumpSurface(tester, onSwipe: directions.add);

      await tester.timedDrag(
        find.byKey(const ValueKey('weather-surface-gesture-child')),
        const Offset(-240, 0),
        const Duration(milliseconds: 180),
      );

      expect(directions, [1], reason: 'width $width');
      expect(tester.takeException(), isNull, reason: 'width $width');
    }
  });

  testWidgets(
    'small horizontal drags and vertical scroll do not switch location',
    (tester) async {
      final directions = <int>[];
      await pumpSurface(tester, onSwipe: directions.add);
      final surface = find.byKey(
        const ValueKey('weather-surface-gesture-child'),
      );

      await tester.timedDrag(
        surface,
        const Offset(-12, 0),
        const Duration(milliseconds: 400),
      );
      await tester.drag(surface, const Offset(0, -160));

      expect(directions, isEmpty);
    },
  );

  testWidgets('a single saved location does not claim a horizontal gesture', (
    tester,
  ) async {
    final directions = <int>[];
    await pumpSurface(tester, enabled: false, onSwipe: directions.add);

    await tester.drag(
      find.byKey(const ValueKey('weather-surface-gesture-child')),
      const Offset(180, 0),
    );

    expect(directions, isEmpty);
  });
}
