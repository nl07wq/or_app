import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/schedule/pages/calendar_page.dart';

void main() {
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
