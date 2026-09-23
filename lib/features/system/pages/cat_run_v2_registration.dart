import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'cat_run_v2_trace_data.dart';

/// Registration-only metadata recovered from the development source masks.
///
/// The HIGH contour points remain untouched. Each point is first returned to
/// its source-mask coordinate, then mapped with one uniform scale into the
/// common 800 px source canvas. This removes per-frame crop normalization
/// while retaining the source-defined extension, compression, and height.
class CatRunV2FrameRegistration {
  const CatRunV2FrameRegistration({
    required this.pose,
    required this.sourceOrigin,
    required this.sourceExtent,
  });

  final int pose;
  final Offset sourceOrigin;
  final double sourceExtent;

  Offset sourcePoint(Offset normalizedPoint) =>
      sourceOrigin + (normalizedPoint * sourceExtent);
}

class CatRunV2Registration {
  CatRunV2Registration._();

  static const sourceCanvas = Size(800, 260);
  static const commonTorsoAnchor = Offset(400, 130);
  static const virtualGroundSourceY = 216.0;
  static const _sourceToCanvasScale = 1 / 800;

  static const frames = <CatRunV2FrameRegistration>[
    CatRunV2FrameRegistration(
      pose: 1,
      sourceOrigin: Offset(186, 65),
      sourceExtent: 428,
    ),
    CatRunV2FrameRegistration(
      pose: 2,
      sourceOrigin: Offset(202, 45),
      sourceExtent: 395,
    ),
    CatRunV2FrameRegistration(
      pose: 3,
      sourceOrigin: Offset(187, 57),
      sourceExtent: 424,
    ),
    CatRunV2FrameRegistration(
      pose: 4,
      sourceOrigin: Offset(187, 55),
      sourceExtent: 424,
    ),
    CatRunV2FrameRegistration(
      pose: 5,
      sourceOrigin: Offset(210, 59),
      sourceExtent: 379,
    ),
    CatRunV2FrameRegistration(
      pose: 6,
      sourceOrigin: Offset(181, 48),
      sourceExtent: 438,
    ),
    CatRunV2FrameRegistration(
      pose: 7,
      sourceOrigin: Offset(167, 48),
      sourceExtent: 465,
    ),
    CatRunV2FrameRegistration(
      pose: 8,
      sourceOrigin: Offset(152, 50),
      sourceExtent: 496,
    ),
    CatRunV2FrameRegistration(
      pose: 9,
      sourceOrigin: Offset(134, 58),
      sourceExtent: 530,
    ),
    CatRunV2FrameRegistration(
      pose: 10,
      sourceOrigin: Offset(135, 61),
      sourceExtent: 528,
    ),
  ];

  static CatRunV2FrameRegistration registrationFor(int pose) =>
      frames.singleWhere((frame) => frame.pose == pose);

  /// Returns a new presentation list; [trace.points] itself is never changed.
  static List<Offset> registeredPoints(CatRunV2Trace trace) {
    final frame = registrationFor(trace.pose);
    return List<Offset>.unmodifiable(
      trace.points.map((point) {
        final sourcePoint = frame.sourcePoint(point);
        final relativeToTorso = sourcePoint - commonTorsoAnchor;
        return (commonTorsoAnchor + relativeToTorso) * _sourceToCanvasScale;
      }),
    );
  }

  static double get virtualGround =>
      virtualGroundSourceY * _sourceToCanvasScale;

  /// Symmetric nearest-contour distance. It samples existing HIGH vertices
  /// only; it does not resample, morph, or alter any displayed geometry.
  static double visualDisplacement(CatRunV2Trace from, CatRunV2Trace to) {
    final first = registeredPoints(from);
    final second = registeredPoints(to);
    return (_meanNearest(first, second) + _meanNearest(second, first)) / 2;
  }

  static final frameDisplacements = List<double>.unmodifiable(
    List<double>.generate(
      catRunV2HighTraces.length,
      (index) => visualDisplacement(
        catRunV2HighTraces[index],
        catRunV2HighTraces[(index + 1) % catRunV2HighTraces.length],
      ),
    ),
  );

  /// Calibrated from adjacent registered-frame displacement. Larger source
  /// changes receive longer holds; no intermediate geometry is generated.
  static final frameDurations = List<Duration>.unmodifiable(() {
    final mean =
        frameDisplacements.reduce((a, b) => a + b) / frameDisplacements.length;
    return frameDisplacements
        .map(
          (displacement) => Duration(
            milliseconds: (90 * (displacement / mean)).clamp(65, 125).round(),
          ),
        )
        .toList(growable: false);
  }());

  static final cycleDuration = frameDurations.fold<Duration>(
    Duration.zero,
    (total, duration) => total + duration,
  );

  static int frameAtCycleProgress(double progress) {
    final target = progress.clamp(0.0, 0.999999) * cycleDuration.inMicroseconds;
    var elapsed = 0;
    for (var index = 0; index < frameDurations.length; index++) {
      elapsed += frameDurations[index].inMicroseconds;
      if (target < elapsed) {
        return index;
      }
    }
    return 0;
  }

  static double _meanNearest(List<Offset> source, List<Offset> target) =>
      source
          .map(
            (point) => target
                .map((candidate) => (candidate - point).distance)
                .reduce(math.min),
          )
          .reduce((sum, distance) => sum + distance) /
      source.length;
}
