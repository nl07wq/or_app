import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'cat_trace_decomposition_poc.dart';

/// Sandbox-only articulated walk data built from the frozen TRACE MEDIUM C.
///
/// Visible paths are always clipped from C/C'.  The rectangular clips only add
/// hidden overlap at joints; they never replace the exposed traced contour.
class CatTraceMotionPoc {
  CatTraceMotionPoc() : decomposition = CatTraceDecomposition.medium();

  static const cycleDuration = Duration(milliseconds: 1300);
  final CatTraceDecomposition decomposition;

  late final Path _original = decomposition.originalPath();
  late final Map<CatTraceMotionSegment, Path> _neutralSegments = {
    for (final segment in CatTraceMotionSegment.values)
      segment: Path.combine(
        PathOperation.intersect,
        _original,
        Path()..addRect(segment.zone),
      ),
  };

  Path originalPath() => _original;

  /// Animation-capable neutral reconstruction, formed only from clipped C.
  /// The accepted C' neutral remains the animation architecture's source of
  /// truth. Segment clips are only substituted when a pose is articulated.
  Path canonicalNeutralPath() => decomposition.reconstructedPath();

  Map<CatTraceMotionSegment, Path> pathsFor(CatTraceMotionSample sample) {
    final upperForeNear = _rotate(
      _neutralSegments[CatTraceMotionSegment.foreNearUpper]!,
      CatTraceMotionSegment.foreNearUpper.pivot,
      sample.foreNearUpper,
    );
    final upperForeFar = _rotate(
      _neutralSegments[CatTraceMotionSegment.foreFarUpper]!,
      CatTraceMotionSegment.foreFarUpper.pivot,
      sample.foreFarUpper,
    );
    final upperHindNear = _rotate(
      _neutralSegments[CatTraceMotionSegment.hindNearUpper]!,
      CatTraceMotionSegment.hindNearUpper.pivot,
      sample.hindNearUpper,
    );
    final upperHindFar = _rotate(
      _neutralSegments[CatTraceMotionSegment.hindFarUpper]!,
      CatTraceMotionSegment.hindFarUpper.pivot,
      sample.hindFarUpper,
    );
    final tailRoot = _rotate(
      _neutralSegments[CatTraceMotionSegment.tailRoot]!,
      CatTraceMotionSegment.tailRoot.pivot,
      sample.tailRoot,
    );

    return {
      CatTraceMotionSegment.foreNearUpper: upperForeNear,
      CatTraceMotionSegment.foreNearLower: _rotateAroundChain(
        _neutralSegments[CatTraceMotionSegment.foreNearLower]!,
        root: CatTraceMotionSegment.foreNearUpper.pivot,
        rootDegrees: sample.foreNearUpper,
        joint: _rotatedPoint(
          const Offset(.125, .360),
          CatTraceMotionSegment.foreNearUpper.pivot,
          sample.foreNearUpper,
        ),
        jointDegrees: sample.foreNearLower,
      ),
      CatTraceMotionSegment.foreFarUpper: upperForeFar,
      CatTraceMotionSegment.foreFarLower: _rotateAroundChain(
        _neutralSegments[CatTraceMotionSegment.foreFarLower]!,
        root: CatTraceMotionSegment.foreFarUpper.pivot,
        rootDegrees: sample.foreFarUpper,
        joint: _rotatedPoint(
          const Offset(.280, .350),
          CatTraceMotionSegment.foreFarUpper.pivot,
          sample.foreFarUpper,
        ),
        jointDegrees: sample.foreFarLower,
      ),
      CatTraceMotionSegment.hindNearUpper: upperHindNear,
      CatTraceMotionSegment.hindNearLower: _rotateAroundChain(
        _neutralSegments[CatTraceMotionSegment.hindNearLower]!,
        root: CatTraceMotionSegment.hindNearUpper.pivot,
        rootDegrees: sample.hindNearUpper,
        joint: _rotatedPoint(
          const Offset(.750, .350),
          CatTraceMotionSegment.hindNearUpper.pivot,
          sample.hindNearUpper,
        ),
        jointDegrees: sample.hindNearLower,
      ),
      CatTraceMotionSegment.hindFarUpper: upperHindFar,
      CatTraceMotionSegment.hindFarLower: _rotateAroundChain(
        _neutralSegments[CatTraceMotionSegment.hindFarLower]!,
        root: CatTraceMotionSegment.hindFarUpper.pivot,
        rootDegrees: sample.hindFarUpper,
        joint: _rotatedPoint(
          const Offset(.505, .355),
          CatTraceMotionSegment.hindFarUpper.pivot,
          sample.hindFarUpper,
        ),
        jointDegrees: sample.hindFarLower,
      ),
      CatTraceMotionSegment.tailRoot: tailRoot,
      CatTraceMotionSegment.tailMid: _rotateAroundChain(
        _neutralSegments[CatTraceMotionSegment.tailMid]!,
        root: CatTraceMotionSegment.tailRoot.pivot,
        rootDegrees: sample.tailRoot,
        joint: _rotatedPoint(
          const Offset(.800, .225),
          CatTraceMotionSegment.tailRoot.pivot,
          sample.tailRoot,
        ),
        jointDegrees: sample.tailMid,
      ),
      CatTraceMotionSegment.tailTip: _rotateTailTip(sample),
      CatTraceMotionSegment.torso: _transformTorso(sample),
      CatTraceMotionSegment.headNeck: _translate(
        _neutralSegments[CatTraceMotionSegment.headNeck]!,
        Offset(0, sample.headOffsetY),
      ),
    };
  }

  Path _rotateTailTip(CatTraceMotionSample sample) {
    final rootPivot = CatTraceMotionSegment.tailRoot.pivot;
    final midPivot = _rotatedPoint(
      const Offset(.800, .225),
      rootPivot,
      sample.tailRoot,
    );
    final tipPivotBase = _rotatedPoint(
      const Offset(.895, .215),
      rootPivot,
      sample.tailRoot,
    );
    final tipPivot = _rotatedPoint(tipPivotBase, midPivot, sample.tailMid);
    var path = _rotate(
      _neutralSegments[CatTraceMotionSegment.tailTip]!,
      rootPivot,
      sample.tailRoot,
    );
    path = _rotate(path, midPivot, sample.tailMid);
    return _rotate(path, tipPivot, sample.tailTip);
  }

  Path _transformTorso(CatTraceMotionSample sample) => _translate(
    _rotate(
      _neutralSegments[CatTraceMotionSegment.torso]!,
      CatTraceMotionSegment.torso.pivot,
      sample.torsoPitch,
    ),
    Offset(0, sample.torsoOffsetY),
  );

  static Path _rotate(Path path, Offset pivot, double degrees) {
    if (degrees == 0) return path;
    final radians = degrees * math.pi / 180;
    final cosine = math.cos(radians);
    final sine = math.sin(radians);
    return path.transform(
      Float64List.fromList([
        cosine,
        sine,
        0,
        0,
        -sine,
        cosine,
        0,
        0,
        0,
        0,
        1,
        0,
        pivot.dx - cosine * pivot.dx + sine * pivot.dy,
        pivot.dy - sine * pivot.dx - cosine * pivot.dy,
        0,
        1,
      ]),
    );
  }

  static Path _translate(Path path, Offset offset) => path.transform(
    Float64List.fromList([
      1,
      0,
      0,
      0,
      0,
      1,
      0,
      0,
      0,
      0,
      1,
      0,
      offset.dx,
      offset.dy,
      0,
      1,
    ]),
  );

  static Path _rotateAroundChain(
    Path path, {
    required Offset root,
    required double rootDegrees,
    required Offset joint,
    required double jointDegrees,
  }) => _rotate(_rotate(path, root, rootDegrees), joint, jointDegrees);

  static Offset _rotatedPoint(Offset point, Offset pivot, double degrees) {
    final radians = degrees * math.pi / 180;
    final cosine = math.cos(radians);
    final sine = math.sin(radians);
    final relative = point - pivot;
    return Offset(
      pivot.dx + relative.dx * cosine - relative.dy * sine,
      pivot.dy + relative.dx * sine + relative.dy * cosine,
    );
  }
}

/// Components map to plausible future movement units, without redrawing C.
enum CatTraceMotionSegment {
  headNeck(Rect.fromLTRB(0, 0, .285, .365), Offset(.205, .185), false),
  torso(Rect.fromLTRB(.115, .045, .735, .385), Offset(.465, .215), false),
  foreNearUpper(Rect.fromLTRB(0, .245, .255, .365), Offset(.205, .295), true),
  foreNearLower(Rect.fromLTRB(0, .330, .255, .50), Offset(.125, .360), true),
  foreFarUpper(Rect.fromLTRB(.195, .245, .365, .355), Offset(.275, .295), true),
  foreFarLower(Rect.fromLTRB(.195, .325, .365, .50), Offset(.280, .350), true),
  hindNearUpper(
    Rect.fromLTRB(.645, .175, .800, .355),
    Offset(.700, .270),
    true,
  ),
  hindNearLower(Rect.fromLTRB(.695, .325, .835, .50), Offset(.750, .350), true),
  hindFarUpper(Rect.fromLTRB(.405, .245, .605, .360), Offset(.495, .290), true),
  hindFarLower(Rect.fromLTRB(.405, .330, .605, .50), Offset(.505, .355), true),
  tailRoot(Rect.fromLTRB(.660, .095, .805, .340), Offset(.690, .185), true),
  tailMid(Rect.fromLTRB(.775, .095, .915, .340), Offset(.800, .225), true),
  tailTip(Rect.fromLTRB(.870, .095, 1, .340), Offset(.895, .215), true);

  const CatTraceMotionSegment(this.zone, this.pivot, this.isArticulated);
  final Rect zone;
  final Offset pivot;
  final bool isArticulated;
}

/// A continuous six-stage brisk walk. Values are analytic and exactly cyclic.
@immutable
class CatTraceMotionSample {
  const CatTraceMotionSample._({
    required this.foreNearUpper,
    required this.foreNearLower,
    required this.foreFarUpper,
    required this.foreFarLower,
    required this.hindNearUpper,
    required this.hindNearLower,
    required this.hindFarUpper,
    required this.hindFarLower,
    required this.tailRoot,
    required this.tailMid,
    required this.tailTip,
    required this.torsoOffsetY,
    required this.torsoPitch,
    required this.headOffsetY,
  });

  factory CatTraceMotionSample.at(double phase) {
    final wave = _wave(phase);
    final opposite = _wave(phase + .5);
    return CatTraceMotionSample._(
      foreNearUpper: 7 * wave,
      foreNearLower: -9 * math.max(0, _wave(phase + .08)),
      foreFarUpper: 6 * opposite,
      foreFarLower: -7 * math.max(0, _wave(phase + .58)),
      hindNearUpper: -7 * opposite,
      hindNearLower: 10 * math.max(0, _wave(phase + .58)),
      hindFarUpper: -6 * wave,
      hindFarLower: 8 * math.max(0, _wave(phase + .08)),
      tailRoot: 2.2 * _wave(phase - .08),
      tailMid: 3.8 * _wave(phase - .14),
      tailTip: 5.2 * _wave(phase - .20),
      torsoOffsetY: .003 * _wave(phase + .25),
      torsoPitch: .55 * _wave(phase + .18),
      headOffsetY: -.0012 * _wave(phase + .25),
    );
  }

  factory CatTraceMotionSample.neutral() => const CatTraceMotionSample._(
    foreNearUpper: 0,
    foreNearLower: 0,
    foreFarUpper: 0,
    foreFarLower: 0,
    hindNearUpper: 0,
    hindNearLower: 0,
    hindFarUpper: 0,
    hindFarLower: 0,
    tailRoot: 0,
    tailMid: 0,
    tailTip: 0,
    torsoOffsetY: 0,
    torsoPitch: 0,
    headOffsetY: 0,
  );
  static double _wave(double phase) => math.sin(phase * math.pi * 2);

  final double foreNearUpper;
  final double foreNearLower;
  final double foreFarUpper;
  final double foreFarLower;
  final double hindNearUpper;
  final double hindNearLower;
  final double hindFarUpper;
  final double hindFarLower;
  final double tailRoot;
  final double tailMid;
  final double tailTip;
  final double torsoOffsetY;
  final double torsoPitch;
  final double headOffsetY;

  bool get isNeutral =>
      foreNearUpper == 0 &&
      foreNearLower == 0 &&
      foreFarUpper == 0 &&
      foreFarLower == 0 &&
      hindNearUpper == 0 &&
      hindNearLower == 0 &&
      hindFarUpper == 0 &&
      hindFarLower == 0 &&
      tailRoot == 0 &&
      tailMid == 0 &&
      tailTip == 0 &&
      torsoOffsetY == 0 &&
      torsoPitch == 0 &&
      headOffsetY == 0;
}

@immutable
class CatTraceMotionIntegrity {
  const CatTraceMotionIntegrity({
    required this.hasFiniteBounds,
    required this.hasForeRootOverlap,
    required this.hasHindRootOverlap,
    required this.hasTailRootOverlap,
  });

  factory CatTraceMotionIntegrity.fromSample({
    required CatTraceMotionPoc motion,
    required CatTraceMotionSample sample,
  }) {
    final paths = motion.pathsFor(sample);
    bool overlaps(CatTraceMotionSegment first, CatTraceMotionSegment second) {
      final bounds = Path.combine(
        PathOperation.intersect,
        paths[first]!,
        paths[second]!,
      ).getBounds();
      return !bounds.isEmpty && bounds.width * bounds.height > .0000001;
    }

    final allBounds = paths.values.map((path) => path.getBounds());
    final finite = allBounds.every(
      (bounds) => [
        bounds.left,
        bounds.top,
        bounds.right,
        bounds.bottom,
      ].every((value) => value.isFinite),
    );
    return CatTraceMotionIntegrity(
      hasFiniteBounds: finite,
      hasForeRootOverlap: overlaps(
        CatTraceMotionSegment.foreNearUpper,
        CatTraceMotionSegment.torso,
      ),
      hasHindRootOverlap: overlaps(
        CatTraceMotionSegment.hindNearUpper,
        CatTraceMotionSegment.torso,
      ),
      hasTailRootOverlap: overlaps(
        CatTraceMotionSegment.tailRoot,
        CatTraceMotionSegment.torso,
      ),
    );
  }

  final bool hasFiniteBounds;
  final bool hasForeRootOverlap;
  final bool hasHindRootOverlap;
  final bool hasTailRootOverlap;
  bool get isStructurallyValid =>
      hasFiniteBounds &&
      hasForeRootOverlap &&
      hasHindRootOverlap &&
      hasTailRootOverlap;
}
