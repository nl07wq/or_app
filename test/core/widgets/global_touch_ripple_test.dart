import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/services/touch_ripple_audio.dart';
import 'package:or_app/core/widgets/global_touch_ripple.dart';

void main() {
  test('ripple ring model staggers, expands, fades, and expires', () {
    expect(touchRippleRingProgress(Duration.zero, 0), 0);
    expect(touchRippleRingProgress(Duration.zero, 1), isNull);
    expect(touchRippleRingProgress(const Duration(milliseconds: 70), 1), 0);
    expect(
      touchRippleRingRadius(const Duration(milliseconds: 400), 0),
      greaterThan(touchRippleRingRadius(const Duration(milliseconds: 100), 0)!),
    );
    expect(
      touchRippleRingOpacity(const Duration(milliseconds: 700), 0),
      lessThan(touchRippleRingOpacity(const Duration(milliseconds: 100), 0)!),
    );
    expect(touchRippleRingProgress(touchRippleDuration, 0), isNull);
  });

  test('ripple event retention remains bounded and removes expired events', () {
    final events = List.generate(
      touchRippleMaximumActiveEvents,
      (index) => TouchRippleEvent(
        position: Offset(index.toDouble(), 0),
        startedAt: Duration(milliseconds: index),
      ),
    );
    final retained = boundedTouchRippleEvents(
      events,
      const TouchRippleEvent(
        position: Offset(99, 99),
        startedAt: Duration.zero,
      ),
    );
    expect(retained, hasLength(touchRippleMaximumActiveEvents));
    expect(retained.first.position, const Offset(1, 0));
    expect(retained.last.position, const Offset(99, 99));
    expect(
      touchRippleExpired(
        const TouchRippleEvent(position: Offset.zero, startedAt: Duration.zero),
        touchRippleDuration,
      ),
      isTrue,
    );
  });

  testWidgets('overlay observes pointer down without consuming the tap', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: GlobalTouchRipple(
          child: Center(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => taps++,
              child: const SizedBox(width: 120, height: 80),
            ),
          ),
        ),
      ),
    );

    await tester.tapAt(const Offset(400, 300));
    await tester.pump();
    expect(taps, 1);
    expect(
      find.byKey(const ValueKey('global-touch-ripple-overlay')),
      findsOneWidget,
    );
  });

  test('registered audio source is the supplied Low-Reverb asset only', () {
    expect(
      touchRippleAudioAssetUrl,
      'assets/assets/audio/touch/Water_Drop02-1(Low-Reverb).mp3',
    );
  });
}
