import 'dart:math' as math;

import 'package:flutter/material.dart';

enum ClockDialHourRing { inner, outer }

class ClockDialHourSelection {
  const ClockDialHourSelection({required this.hour, required this.ring});

  final int hour;
  final ClockDialHourRing ring;
}

/// Maps the dial's polar position to the nearest twelve-hour clock direction.
/// Direction zero is 12 o'clock, then progresses clockwise to 11 o'clock.
int clockDialDirectionForOffset(Offset offset) {
  final angle =
      (math.atan2(offset.dy, offset.dx) + math.pi / 2) % (math.pi * 2);
  return (angle / (math.pi * 2 / 12)).round() % 12;
}

/// Returns the continuous hand angle for a stable pointer position.
///
/// This is intentionally independent from the discrete clock values: the
/// instrument hand can follow a finger smoothly while the selected hour or
/// minute continues to snap to its formal sector.
double? clockDialHandAngleForOffset({
  required Offset offset,
  required double dialRadius,
}) {
  if (dialRadius <= 0 || offset.distance < dialRadius * .20) return null;
  return math.atan2(offset.dy, offset.dx);
}

ClockDialHourSelection? clockDialHourSelectionForOffset({
  required Offset offset,
  required double dialRadius,
  ClockDialHourRing? previousRing,
}) {
  final radius = offset.distance;
  if (dialRadius <= 0 || radius < dialRadius * .20) return null;
  final ratio = radius / dialRadius;
  final ring = _hourRingForRadius(ratio, previousRing);
  final direction = clockDialDirectionForOffset(offset);
  return ClockDialHourSelection(
    hour: ring == ClockDialHourRing.inner
        ? (direction == 0 ? 12 : direction)
        : (direction == 0 ? 0 : direction + 12),
    ring: ring,
  );
}

int? clockDialMinuteForOffset({
  required Offset offset,
  required double dialRadius,
}) {
  if (dialRadius <= 0 || offset.distance < dialRadius * .20) return null;
  return clockDialDirectionForOffset(offset) * 5;
}

ClockDialHourRing clockDialHourRingForHour(int hour) =>
    hour == 0 || hour >= 13 ? ClockDialHourRing.outer : ClockDialHourRing.inner;

ClockDialHourRing _hourRingForRadius(
  double ratio,
  ClockDialHourRing? previousRing,
) {
  // The visual rings sit at .78 and .52. These asymmetric thresholds give a
  // small dead-band around their midpoint so a resting finger cannot flicker.
  switch (previousRing) {
    case ClockDialHourRing.inner:
      return ratio > .67 ? ClockDialHourRing.outer : ClockDialHourRing.inner;
    case ClockDialHourRing.outer:
      return ratio < .63 ? ClockDialHourRing.inner : ClockDialHourRing.outer;
    case null:
      return ratio >= .65 ? ClockDialHourRing.outer : ClockDialHourRing.inner;
  }
}
