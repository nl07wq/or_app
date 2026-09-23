import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'cat_run_v2_registration.dart';
import 'cat_run_v2_trace_data.dart';

enum CatRunV23Direction { leftToRight, rightToLeft }

/// V2.8 presentation timing only. V2.2's source timing remains frozen in
/// [CatRunV2Registration]; these holds apply solely to the 48px travel POC.
class CatRunV28Timing {
  CatRunV28Timing._();

  static const frameDurations = <Duration>[
    Duration(milliseconds: 90),
    Duration(milliseconds: 25),
    Duration(milliseconds: 25),
    Duration(milliseconds: 90),
    Duration(milliseconds: 88),
    Duration(milliseconds: 25),
    Duration(milliseconds: 30),
    Duration(milliseconds: 90),
    Duration(milliseconds: 88),
    Duration(milliseconds: 90),
  ];

  static final cycleDuration = frameDurations.fold<Duration>(
    Duration.zero,
    (total, duration) => total + duration,
  );

  static int frameAtCycleProgress(double progress) {
    final target =
        progress.clamp(0.0, 0.999999).toDouble() * cycleDuration.inMicroseconds;
    var elapsed = 0;
    for (var index = 0; index < frameDurations.length; index++) {
      elapsed += frameDurations[index].inMicroseconds;
      if (target < elapsed) return index;
    }
    return 0;
  }
}

/// Measured from registered geometry only. The frozen HIGH point arrays are
/// never edited by this audit or by the presentation layer.
class CatRunV24ScaleMetrics {
  const CatRunV24ScaleMetrics({
    required this.pose,
    required this.torsoLength,
    required this.torsoHeight,
    required this.headSpan,
    required this.chestHeight,
    required this.visualWidth,
    required this.visualHeight,
    required this.silhouetteArea,
  });

  final int pose;
  final double torsoLength;
  final double torsoHeight;
  final double headSpan;
  final double chestHeight;
  final double visualWidth;
  final double visualHeight;
  final double silhouetteArea;

  double get productionVisualHeight => visualHeight * CatRunV24Travel.catUnit;
}

/// Deterministic, presentation-only scale audit. The measured variations map
/// to the authored run phases (flight, gather, support), not a crop anomaly.
class CatRunV24ScaleAudit {
  CatRunV24ScaleAudit._();

  static final metrics = List<CatRunV24ScaleMetrics>.unmodifiable(
    catRunV2HighTraces.map(_measure),
  );

  /// The replacement Pose 01 source is area- and torso-registered with the
  /// cycle, so no presentation-scale correction is applied.
  static const uniformCorrections = <int, double>{
    1: 1,
    2: 1,
    3: 1,
    4: 1,
    5: 1,
    6: 1,
    7: 1,
    8: 1,
    9: 1,
    10: 1,
  };

  static double correctionFor(int pose) => uniformCorrections[pose]!;

  /// The source replacement removes the former extended-pose vertical dip.
  /// These stay explicit to keep the display transform deterministic.
  static const verticalProportionCorrections = <int, double>{
    1: 1,
    2: 1,
    3: 1,
    4: 1,
    5: 1,
    6: 1,
    7: 1,
    8: 1,
    9: 1,
    10: 1,
  };

  static double scaleXFor(int pose) => correctionFor(pose);

  static double scaleYFor(int pose) =>
      correctionFor(pose) * verticalProportionCorrections[pose]!;

  static List<Offset> correctedPoints(CatRunV2Trace trace) {
    final points = CatRunV2Registration.registeredPoints(trace);
    final scaleX = scaleXFor(trace.pose);
    final scaleY = scaleYFor(trace.pose);
    if (scaleX == 1 && scaleY == 1) return points;
    // Contact frames scale around their planted stance paw so the perceptual
    // body-mass correction cannot move the already registered ground contact.
    // Flight frames retain the torso anchor used by the registration audit.
    final anchor = CatRunV2Registration.stancePaw(trace) ?? _torsoAnchor(trace);
    return List<Offset>.unmodifiable(
      points.map(
        (point) => Offset(
          anchor.dx + ((point.dx - anchor.dx) * scaleX),
          anchor.dy + ((point.dy - anchor.dy) * scaleY),
        ),
      ),
    );
  }

  static CatRunV24ScaleMetrics _measure(CatRunV2Trace trace) {
    final points = CatRunV2Registration.registeredPoints(trace);
    final minX = points.map((point) => point.dx).reduce(math.min);
    final maxX = points.map((point) => point.dx).reduce(math.max);
    final minY = points.map((point) => point.dy).reduce(math.min);
    final maxY = points.map((point) => point.dy).reduce(math.max);
    final frame = CatRunV2Registration.registrationFor(trace.pose);
    final transform = CatRunV2Registration.transformFor(trace);
    final shoulder = transform.apply(frame.shoulder * (1 / 800));
    final pelvis = transform.apply(frame.pelvis * (1 / 800));
    final torsoAxis = pelvis - shoulder;
    final torsoLength = torsoAxis.distance;
    final headDirection = (shoulder - pelvis) / torsoLength;
    final torsoBand = points
        .where((point) {
          final relative = point - shoulder;
          final projection =
              ((relative.dx * torsoAxis.dx) + (relative.dy * torsoAxis.dy)) /
              (torsoLength * torsoLength);
          return projection >= .2 && projection <= .8;
        })
        .toList(growable: false);
    final perpendiculars = torsoBand
        .map(
          (point) =>
              ((point - shoulder).dx * -torsoAxis.dy +
                  (point - shoulder).dy * torsoAxis.dx) /
              torsoLength,
        )
        .toList(growable: false);
    perpendiculars.sort();
    final lowerTorsoBandIndex = (perpendiculars.length * .2).floor();
    final upperTorsoBandIndex = (perpendiculars.length * .8).floor();
    final chestHeight =
        perpendiculars[upperTorsoBandIndex] -
        perpendiculars[lowerTorsoBandIndex];
    final headSpan = points
        .where((point) {
          final relative = point - shoulder;
          final forward =
              (relative.dx * headDirection.dx) +
              (relative.dy * headDirection.dy);
          final lateral =
              (relative.dx * -headDirection.dy) +
              (relative.dy * headDirection.dx);
          return forward >= 0 &&
              forward <= torsoLength * .75 &&
              lateral.abs() <= torsoLength * .75;
        })
        .map((point) => (point - shoulder).distance)
        .reduce(math.max);
    var doubleArea = 0.0;
    for (var index = 0; index < points.length; index++) {
      final next = points[(index + 1) % points.length];
      doubleArea += (points[index].dx * next.dy) - (next.dx * points[index].dy);
    }
    return CatRunV24ScaleMetrics(
      pose: trace.pose,
      torsoLength: torsoLength,
      torsoHeight: chestHeight,
      headSpan: headSpan,
      chestHeight: chestHeight,
      visualWidth: maxX - minX,
      visualHeight: maxY - minY,
      silhouetteArea: doubleArea.abs() / 2,
    );
  }

  static Offset _torsoAnchor(CatRunV2Trace trace) {
    final frame = CatRunV2Registration.registrationFor(trace.pose);
    final sourceCenter = frame.torsoCenter * (1 / 800);
    return CatRunV2Registration.transformFor(trace).apply(sourceCenter);
  }
}

/// Root-only travel correction. It reweights horizontal progress across
/// existing direct frames; geometry and V2.2 frame timing remain untouched.
class CatRunV24Travel {
  CatRunV24Travel._();

  static const stageHeight = 48.0;
  static const catUnit = 110.0;
  static const offstagePadding = 96.0;
  static const crossingDuration = Duration(seconds: 3);
  static const stanceSpeedMultiplier = .08;
  static const _speedBlendMicroseconds = 6000;
  static final _weightedMilliseconds = _buildWeightedMilliseconds();

  static int frameAtTravelProgress(double progress) {
    final safeProgress = progress.clamp(0.0, 0.999999).toDouble();
    final elapsedMicroseconds = (crossingDuration.inMicroseconds * safeProgress)
        .round();
    final cycleMicroseconds = CatRunV28Timing.cycleDuration.inMicroseconds;
    return CatRunV28Timing.frameAtCycleProgress(
      (elapsedMicroseconds % cycleMicroseconds) / cycleMicroseconds,
    );
  }

  static bool isStanceFrame(int frameIndex) =>
      CatRunV2Registration.stancePaw(catRunV2HighTraces[frameIndex]) != null;

  static List<Offset> pointsAt(double progress) =>
      CatRunV24ScaleAudit.correctedPoints(
        catRunV2HighTraces[frameAtTravelProgress(progress)],
      );

  static double horizontalPosition({
    required double stageWidth,
    required double progress,
  }) {
    final safeProgress = progress.clamp(0.0, 1.0).toDouble();
    final rootProgress = _weightedProgress(safeProgress);
    return -offstagePadding +
        (stageWidth + (offstagePadding * 2)) * rootProgress;
  }

  static double stancePawWorldDrift({
    required int frameIndex,
    required double stageWidth,
    required CatRunV23Direction direction,
  }) {
    if (!isStanceFrame(frameIndex)) return 0;
    final start = _frameStartMicroseconds(frameIndex);
    final end =
        start + CatRunV28Timing.frameDurations[frameIndex].inMicroseconds;
    final startProgress = start / crossingDuration.inMicroseconds;
    final endProgress = end / crossingDuration.inMicroseconds;
    final before = horizontalPosition(
      stageWidth: stageWidth,
      progress: startProgress,
    );
    final after = horizontalPosition(
      stageWidth: stageWidth,
      progress: endProgress,
    );
    final signedDrift = after - before;
    return direction == CatRunV23Direction.leftToRight
        ? signedDrift.abs()
        : signedDrift.abs();
  }

  static double uncorrectedStancePawWorldDrift({
    required int frameIndex,
    required double stageWidth,
  }) {
    if (!isStanceFrame(frameIndex)) return 0;
    return (stageWidth + (offstagePadding * 2)) *
        CatRunV28Timing.frameDurations[frameIndex].inMicroseconds /
        crossingDuration.inMicroseconds;
  }

  static double _weightedProgress(double progress) {
    if (progress <= 0) return 0;
    if (progress >= 1) return 1;
    final totalMicros = crossingDuration.inMicroseconds;
    final elapsed = (totalMicros * progress).round();
    return _weightedMicroseconds(elapsed) / _weightedMicroseconds(totalMicros);
  }

  static double _weightedMicroseconds(int elapsedMicroseconds) {
    final wholeMilliseconds = elapsedMicroseconds ~/ 1000;
    var weighted = _weightedMilliseconds[wholeMilliseconds];
    final remainder = elapsedMicroseconds % 1000;
    if (remainder > 0) {
      weighted +=
          _speedWeightAt((wholeMilliseconds * 1000) + (remainder ~/ 2)) *
          remainder;
    }
    return weighted;
  }

  static List<double> _buildWeightedMilliseconds() {
    final values = <double>[0];
    var total = 0.0;
    for (
      var millisecond = 0;
      millisecond < crossingDuration.inMilliseconds;
      millisecond++
    ) {
      total += _speedWeightAt((millisecond * 1000) + 500) * 1000;
      values.add(total);
    }
    return List<double>.unmodifiable(values);
  }

  /// Smoothstep blending keeps root position and velocity continuous at
  /// flight/contact acquisition and release without altering any frame path.
  static double _speedWeightAt(int elapsedMicroseconds) {
    final cycleMicroseconds = CatRunV28Timing.cycleDuration.inMicroseconds;
    final inCycle = elapsedMicroseconds % cycleMicroseconds;
    var frameStart = 0;
    for (var index = 0; index < catRunV2HighTraces.length; index++) {
      final duration = CatRunV28Timing.frameDurations[index].inMicroseconds;
      final frameEnd = frameStart + duration;
      if (inCycle < frameEnd) {
        final local = inCycle - frameStart;
        final current = _frameWeight(index);
        if (local < _speedBlendMicroseconds) {
          final previous = _frameWeight(
            (index - 1 + catRunV2HighTraces.length) % catRunV2HighTraces.length,
          );
          return _lerp(
            previous,
            current,
            _smoothStep(
              (local + _speedBlendMicroseconds) / (_speedBlendMicroseconds * 2),
            ),
          );
        }
        if (local > duration - _speedBlendMicroseconds) {
          return _lerp(
            current,
            _frameWeight((index + 1) % catRunV2HighTraces.length),
            _smoothStep(
              (local - (duration - _speedBlendMicroseconds)) /
                  (_speedBlendMicroseconds * 2),
            ),
          );
        }
        return current;
      }
      frameStart = frameEnd;
    }
    return _frameWeight(0);
  }

  static double _frameWeight(int frameIndex) =>
      isStanceFrame(frameIndex) ? stanceSpeedMultiplier : 1.0;

  static double _smoothStep(double value) {
    final t = value.clamp(0.0, 1.0).toDouble();
    return t * t * (3 - (2 * t));
  }

  static double _lerp(double from, double to, double t) =>
      from + ((to - from) * t);

  static int _frameStartMicroseconds(int frameIndex) => CatRunV28Timing
      .frameDurations
      .take(frameIndex)
      .fold(0, (total, duration) => total + duration.inMicroseconds);
}
