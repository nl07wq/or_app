import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'cat_run_v2_trace_data.dart';

enum CatRunV2LocomotionState {
  flight('FLIGHT'),
  approach('APPROACH'),
  foreContact('FORE CONTACT'),
  foreSupport('FORE SUPPORT'),
  gather('GATHER'),
  transition('TRANSITION'),
  rearContact('REAR CONTACT'),
  rearSupportPush('REAR SUPPORT / PUSH'),
  takeoff('TAKEOFF');

  const CatRunV2LocomotionState(this.label);
  final String label;
}

enum CatRunV2StancePaw { fore, hind }

/// Registration-only metadata recovered from source masks and stable torso
/// landmarks. HIGH contour points are never edited.
class CatRunV2FrameRegistration {
  const CatRunV2FrameRegistration({
    required this.pose,
    required this.sourceOrigin,
    required this.sourceExtent,
    required this.shoulder,
    required this.pelvis,
    required this.state,
    this.stancePaw,
  });

  final int pose;
  final Offset sourceOrigin;
  final double sourceExtent;
  final Offset shoulder;
  final Offset pelvis;
  final CatRunV2LocomotionState state;
  final CatRunV2StancePaw? stancePaw;

  Offset sourcePoint(Offset normalizedPoint) =>
      sourceOrigin + (normalizedPoint * sourceExtent);

  Offset get torsoCenter =>
      Offset((shoulder.dx + pelvis.dx) / 2, (shoulder.dy + pelvis.dy) / 2);

  Offset get torsoAxis => pelvis - shoulder;
}

class CatRunV2SimilarityTransform {
  const CatRunV2SimilarityTransform({
    required this.anchor,
    required this.uniformScale,
    required this.rotationRadians,
    required this.translation,
  });

  final Offset anchor;
  final double uniformScale;
  final double rotationRadians;
  final Offset translation;

  Offset apply(Offset point) {
    final local = point - anchor;
    final cosine = math.cos(rotationRadians) * uniformScale;
    final sine = math.sin(rotationRadians) * uniformScale;
    return Offset(
          (local.dx * cosine) - (local.dy * sine),
          (local.dx * sine) + (local.dy * cosine),
        ) +
        anchor +
        translation;
  }
}

class CatRunV2Registration {
  CatRunV2Registration._();

  static const sourceCanvas = Size(800, 260);
  static const commonTorsoAnchorX = .5;
  static const virtualGroundSourceY = 216.0;
  static const _sourceToCanvasScale = 1 / 800;
  static const _referenceTorsoLength = 135.0;
  static const _maximumRotationRadians = 2 * math.pi / 180;

  static const frames = <CatRunV2FrameRegistration>[
    CatRunV2FrameRegistration(
      pose: 1,
      sourceOrigin: Offset(163, 58),
      sourceExtent: 474,
      shoulder: Offset(502, 114),
      pelvis: Offset(358, 119),
      state: CatRunV2LocomotionState.flight,
    ),
    CatRunV2FrameRegistration(
      pose: 2,
      sourceOrigin: Offset(202, 45),
      sourceExtent: 395,
      shoulder: Offset(490, 112),
      pelvis: Offset(360, 108),
      state: CatRunV2LocomotionState.rearContact,
      stancePaw: CatRunV2StancePaw.hind,
    ),
    CatRunV2FrameRegistration(
      pose: 3,
      sourceOrigin: Offset(187, 57),
      sourceExtent: 424,
      shoulder: Offset(490, 116),
      pelvis: Offset(360, 118),
      state: CatRunV2LocomotionState.foreSupport,
      stancePaw: CatRunV2StancePaw.fore,
    ),
    CatRunV2FrameRegistration(
      pose: 4,
      sourceOrigin: Offset(187, 55),
      sourceExtent: 424,
      shoulder: Offset(488, 108),
      pelvis: Offset(360, 110),
      state: CatRunV2LocomotionState.gather,
    ),
    CatRunV2FrameRegistration(
      pose: 5,
      sourceOrigin: Offset(210, 59),
      sourceExtent: 379,
      shoulder: Offset(478, 120),
      pelvis: Offset(365, 120),
      state: CatRunV2LocomotionState.transition,
    ),
    CatRunV2FrameRegistration(
      pose: 6,
      sourceOrigin: Offset(181, 48),
      sourceExtent: 438,
      shoulder: Offset(488, 106),
      pelvis: Offset(352, 106),
      state: CatRunV2LocomotionState.foreContact,
      stancePaw: CatRunV2StancePaw.fore,
    ),
    CatRunV2FrameRegistration(
      pose: 7,
      sourceOrigin: Offset(167, 48),
      sourceExtent: 465,
      shoulder: Offset(490, 114),
      pelvis: Offset(355, 114),
      state: CatRunV2LocomotionState.rearSupportPush,
      stancePaw: CatRunV2StancePaw.hind,
    ),
    CatRunV2FrameRegistration(
      pose: 8,
      sourceOrigin: Offset(152, 50),
      sourceExtent: 496,
      shoulder: Offset(488, 106),
      pelvis: Offset(350, 108),
      state: CatRunV2LocomotionState.takeoff,
    ),
    CatRunV2FrameRegistration(
      pose: 9,
      sourceOrigin: Offset(134, 58),
      sourceExtent: 530,
      shoulder: Offset(490, 116),
      pelvis: Offset(352, 120),
      state: CatRunV2LocomotionState.flight,
    ),
    CatRunV2FrameRegistration(
      pose: 10,
      sourceOrigin: Offset(135, 61),
      sourceExtent: 528,
      shoulder: Offset(494, 110),
      pelvis: Offset(356, 114),
      state: CatRunV2LocomotionState.approach,
    ),
  ];

  static CatRunV2FrameRegistration registrationFor(int pose) =>
      frames.singleWhere((frame) => frame.pose == pose);

  static double get virtualGround =>
      virtualGroundSourceY * _sourceToCanvasScale;

  static CatRunV2SimilarityTransform transformFor(CatRunV2Trace trace) {
    final base = _baseFor(trace);
    return CatRunV2SimilarityTransform(
      anchor: base.anchor,
      uniformScale: base.uniformScale,
      rotationRadians: base.rotationRadians,
      translation: Offset(base.translation.dx, _verticalTranslationFor(trace)),
    );
  }

  /// Returns presentation geometry only; [trace.points] remains immutable.
  static List<Offset> registeredPoints(CatRunV2Trace trace) {
    final frame = registrationFor(trace.pose);
    final transform = transformFor(trace);
    return List<Offset>.unmodifiable(
      trace.points.map(
        (point) =>
            transform.apply(frame.sourcePoint(point) * _sourceToCanvasScale),
      ),
    );
  }

  static Offset? stancePaw(CatRunV2Trace trace) {
    final stance = registrationFor(trace.pose).stancePaw;
    if (stance == null) {
      return null;
    }
    final basePaw = _stancePawAtBase(trace, stance);
    return basePaw + Offset(0, _verticalTranslationFor(trace));
  }

  static CatRunV2SimilarityTransform _baseFor(CatRunV2Trace trace) {
    final frame = registrationFor(trace.pose);
    final center = frame.torsoCenter * _sourceToCanvasScale;
    final axis = frame.torsoAxis;
    final rotation =
        (_wrapRadians(math.pi - math.atan2(axis.dy, axis.dx)) * .18)
            .clamp(-_maximumRotationRadians, _maximumRotationRadians)
            .toDouble();
    final uniformScale = math
        .pow(_referenceTorsoLength / axis.distance, .12)
        .toDouble()
        .clamp(.97, 1.03)
        .toDouble();
    return CatRunV2SimilarityTransform(
      anchor: center,
      uniformScale: uniformScale,
      rotationRadians: rotation,
      translation: Offset(commonTorsoAnchorX - center.dx, 0),
    );
  }

  static List<Offset> _rawCanvasPoints(CatRunV2Trace trace) {
    final frame = registrationFor(trace.pose);
    return trace.points
        .map((point) => frame.sourcePoint(point) * _sourceToCanvasScale)
        .toList(growable: false);
  }

  static Offset _stancePawAtBase(
    CatRunV2Trace trace,
    CatRunV2StancePaw stance,
  ) {
    final torsoX =
        registrationFor(trace.pose).torsoCenter.dx * _sourceToCanvasScale;
    final candidates = _rawCanvasPoints(trace).where(
      (point) => stance == CatRunV2StancePaw.fore
          ? point.dx >= torsoX
          : point.dx <= torsoX,
    );
    final paw = candidates.reduce(
      (lowest, point) => point.dy > lowest.dy ? point : lowest,
    );
    return _baseFor(trace).apply(paw);
  }

  static final _contactVerticalOffsets = Map<int, double>.unmodifiable({
    for (final trace in catRunV2HighTraces)
      if (registrationFor(trace.pose).stancePaw != null)
        trace.pose: _contactVerticalOffset(trace),
  });

  static double _contactVerticalOffset(CatRunV2Trace trace) =>
      virtualGround -
      _stancePawAtBase(trace, registrationFor(trace.pose).stancePaw!).dy;

  /// Non-contact frames preserve their source vertical pose and receive only a
  /// continuous interpolation of neighbouring contact-registration offsets.
  static double _verticalTranslationFor(CatRunV2Trace trace) {
    final direct = _contactVerticalOffsets[trace.pose];
    if (direct != null) {
      return direct;
    }
    final pose = trace.pose;
    final contactPoses = _contactVerticalOffsets.keys.toList()..sort();
    var previous = contactPoses.last - catRunV2HighTraces.length;
    var next = contactPoses.first;
    for (final candidate in contactPoses) {
      if (candidate < pose) {
        previous = candidate;
      }
      if (candidate > pose) {
        next = candidate;
        break;
      }
    }
    if (next <= previous) {
      next += catRunV2HighTraces.length;
    }
    final normalizedPose = pose <= previous
        ? pose + catRunV2HighTraces.length
        : pose;
    final t = (normalizedPose - previous) / (next - previous);
    final start = _contactVerticalOffsets[_wrapPose(previous)]!;
    final end = _contactVerticalOffsets[_wrapPose(next)]!;
    return start + ((end - start) * t);
  }

  static int _wrapPose(int pose) =>
      ((pose - 1) % catRunV2HighTraces.length) + 1;

  static double _wrapRadians(double angle) {
    var result = angle;
    while (result > math.pi) {
      result -= 2 * math.pi;
    }
    while (result < -math.pi) {
      result += 2 * math.pi;
    }
    return result;
  }

  /// Symmetric nearest-contour distance, using existing HIGH vertices only.
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

  /// Narrow semantic timing baseline; displacement does not drive holds.
  static const frameDurations = <Duration>[
    Duration(milliseconds: 86),
    Duration(milliseconds: 90),
    Duration(milliseconds: 90),
    Duration(milliseconds: 88),
    Duration(milliseconds: 88),
    Duration(milliseconds: 90),
    Duration(milliseconds: 92),
    Duration(milliseconds: 88),
    Duration(milliseconds: 86),
    Duration(milliseconds: 88),
  ];

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
