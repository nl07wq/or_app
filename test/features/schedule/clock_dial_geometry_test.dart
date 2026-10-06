import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/schedule/clock_dial_geometry.dart';

void main() {
  const radius = 100.0;

  Offset at(int direction, double radiusFactor) {
    const directions = [
      Offset(0, -1),
      Offset(0.5, -0.8660254),
      Offset(0.8660254, -0.5),
      Offset(1, 0),
      Offset(0.8660254, 0.5),
      Offset(0.5, 0.8660254),
      Offset(0, 1),
      Offset(-0.5, 0.8660254),
      Offset(-0.8660254, 0.5),
      Offset(-1, 0),
      Offset(-0.8660254, -0.5),
      Offset(-0.5, -0.8660254),
    ];
    return directions[direction] * (radius * radiusFactor);
  }

  test('maps dual-ring top direction to distinct 12 and 00 values', () {
    final inner = clockDialHourSelectionForOffset(
      offset: at(0, .52),
      dialRadius: radius,
    );
    final outer = clockDialHourSelectionForOffset(
      offset: at(0, .78),
      dialRadius: radius,
    );

    expect(inner?.hour, 12);
    expect(inner?.ring, ClockDialHourRing.inner);
    expect(outer?.hour, 0);
    expect(outer?.ring, ClockDialHourRing.outer);
  });

  test('maps all twelve directions through each hour ring', () {
    for (var direction = 0; direction < 12; direction++) {
      final inner = clockDialHourSelectionForOffset(
        offset: at(direction, .52),
        dialRadius: radius,
      );
      final outer = clockDialHourSelectionForOffset(
        offset: at(direction, .78),
        dialRadius: radius,
      );
      expect(inner?.hour, direction == 0 ? 12 : direction);
      expect(outer?.hour, direction == 0 ? 0 : direction + 12);
    }
  });

  test('switches rings only after crossing the radial hysteresis boundary', () {
    final heldInner = clockDialHourSelectionForOffset(
      offset: at(3, .65),
      dialRadius: radius,
      previousRing: ClockDialHourRing.inner,
    );
    final movedOuter = clockDialHourSelectionForOffset(
      offset: at(3, .68),
      dialRadius: radius,
      previousRing: ClockDialHourRing.inner,
    );
    final heldOuter = clockDialHourSelectionForOffset(
      offset: at(9, .64),
      dialRadius: radius,
      previousRing: ClockDialHourRing.outer,
    );
    final movedInner = clockDialHourSelectionForOffset(
      offset: at(9, .62),
      dialRadius: radius,
      previousRing: ClockDialHourRing.outer,
    );

    expect(heldInner?.hour, 3);
    expect(movedOuter?.hour, 15);
    expect(heldOuter?.hour, 21);
    expect(movedInner?.hour, 9);
  });

  test('snaps minute drags to five-minute clock directions', () {
    expect(clockDialMinuteForOffset(offset: at(0, .78), dialRadius: radius), 0);
    expect(
      clockDialMinuteForOffset(offset: at(3, .78), dialRadius: radius),
      15,
    );
    expect(
      clockDialMinuteForOffset(offset: at(11, .78), dialRadius: radius),
      55,
    );
  });

  test('ignores unstable center positions and preserves ring authority', () {
    expect(
      clockDialHourSelectionForOffset(
        offset: const Offset(4, 0),
        dialRadius: radius,
      ),
      isNull,
    );
    expect(clockDialHourRingForHour(7), ClockDialHourRing.inner);
    expect(clockDialHourRingForHour(12), ClockDialHourRing.inner);
    expect(clockDialHourRingForHour(19), ClockDialHourRing.outer);
    expect(clockDialHourRingForHour(0), ClockDialHourRing.outer);
  });

  test('keeps a continuous hand angle separate from snapped values', () {
    expect(
      clockDialHandAngleForOffset(offset: at(0, .78), dialRadius: radius),
      closeTo(-1.5707963, .0001),
    );
    expect(
      clockDialHandAngleForOffset(offset: at(3, .78), dialRadius: radius),
      closeTo(0, .0001),
    );
    expect(
      clockDialHandAngleForOffset(
        offset: const Offset(4, 0),
        dialRadius: radius,
      ),
      isNull,
    );
  });
}
