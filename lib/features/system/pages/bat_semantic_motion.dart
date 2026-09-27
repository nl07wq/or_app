import 'dart:ui';

import 'bat_source_vector_rebuild_data.dart';

/// Motion-only topology-safe BAT representation.  It deliberately does not
/// share editable paths with [BatSourceVectorRebuild]: source vectors are the
/// audit authority, while these semantic layers exist only between key poses.
enum BatSemanticLayer { all, body, nearWing, farWing }

enum BatMotionTiming { fast, normal, slow }

extension BatMotionTimingValues on BatMotionTiming {
  int get milliseconds => switch (this) {
    BatMotionTiming.fast => 20,
    BatMotionTiming.normal => 24,
    BatMotionTiming.slow => 28,
  };

  String get label => switch (this) {
    BatMotionTiming.fast => 'FAST',
    BatMotionTiming.normal => 'NORMAL',
    BatMotionTiming.slow => 'SLOW',
  };
}

class BatSemanticComponent {
  const BatSemanticComponent(this.points);

  final List<Offset> points;

  Path path() {
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    return path..close();
  }

  /// The authored motion polygons are deliberately simple.  This is a stable,
  /// deterministic topology check rather than an attempt to morph source paths.
  bool get isTopologySafe => points.length >= 3 && _hasNoCrossings(points);
}

class BatSemanticMotionFrame {
  const BatSemanticMotionFrame.key(this.keyIndex)
    : transition = null,
      progress = null,
      farWing = null,
      body = null,
      nearWing = null,
      manualIntermediate = false;

  const BatSemanticMotionFrame.intermediate({
    required this.transition,
    required this.progress,
    required this.farWing,
    required this.body,
    required this.nearWing,
  }) : keyIndex = null,
       manualIntermediate = true;

  final int? keyIndex;
  final int? transition;
  final double? progress;
  final BatSemanticComponent? farWing;
  final BatSemanticComponent? body;
  final BatSemanticComponent? nearWing;
  final bool manualIntermediate;

  bool get isKeyPose => keyIndex != null;
  bool get topologySafe =>
      isKeyPose ||
      farWing!.isTopologySafe &&
          body!.isTopologySafe &&
          nearWing!.isTopologySafe;

  Offset get registrationTranslation {
    if (isKeyPose) {
      return BatSourceVectorRebuild.frames[keyIndex!].registrationTranslation;
    }
    final a =
        BatSourceVectorRebuild.frames[transition!].registrationTranslation;
    final b =
        BatSourceVectorRebuild.frames[transition! + 1].registrationTranslation;
    return Offset.lerp(a, b, progress!)!;
  }
}

/// Five frozen source keys plus two explicitly-authored semantic-layer frames
/// per forward transition.  The reverse cycle reuses these exact objects.
abstract final class BatSemanticMotion {
  static const keyCompositeIou = <double>[1, 1, 1, 1, 1];
  static const keyCompositeDisagreement = <double>[0, 0, 0, 0, 0];
  static const layerOrder = <BatSemanticLayer>[
    BatSemanticLayer.farWing,
    BatSemanticLayer.body,
    BatSemanticLayer.nearWing,
  ];

  static final intermediates = <BatSemanticMotionFrame>[
    _frame(0, 1 / 3),
    _frame(0, 2 / 3),
    _frame(1, 1 / 3),
    _frame(1, 2 / 3),
    _frame(2, 1 / 3),
    _frame(2, 2 / 3),
    _frame(3, 1 / 3),
    _frame(3, 2 / 3),
  ];

  static final cycle = <BatSemanticMotionFrame>[
    const BatSemanticMotionFrame.key(0),
    intermediates[0],
    intermediates[1],
    const BatSemanticMotionFrame.key(1),
    intermediates[2],
    intermediates[3],
    const BatSemanticMotionFrame.key(2),
    intermediates[4],
    intermediates[5],
    const BatSemanticMotionFrame.key(3),
    intermediates[6],
    intermediates[7],
    const BatSemanticMotionFrame.key(4),
    intermediates[7],
    intermediates[6],
    const BatSemanticMotionFrame.key(3),
    intermediates[5],
    intermediates[4],
    const BatSemanticMotionFrame.key(2),
    intermediates[3],
    intermediates[2],
    const BatSemanticMotionFrame.key(1),
    intermediates[1],
    intermediates[0],
  ];

  static const semanticKeyComponents = <String>[
    'BODY',
    'NEAR WING',
    'FAR WING',
  ];
  static const normalCycleDurationMilliseconds = 24 * 24;

  static BatSemanticMotionFrame _frame(int transition, double progress) {
    // Manual motion-only intermediates are authorized for occlusion changes;
    // the wing pose evolves per transition while components stay separate.
    final phase = transition + progress;
    final shoulder = Offset(675 + 18 * phase, 505 - 8 * phase);
    final body = BatSemanticComponent(_body(shoulder));
    return BatSemanticMotionFrame.intermediate(
      transition: transition,
      progress: progress,
      farWing: BatSemanticComponent(_farWing(shoulder, phase)),
      body: body,
      nearWing: BatSemanticComponent(_nearWing(shoulder, phase)),
    );
  }

  static List<Offset> _body(Offset s) => [
    s + const Offset(110, -38),
    s + const Offset(145, -72),
    s + const Offset(184, -58),
    s + const Offset(205, -27),
    s + const Offset(255, -20),
    s + const Offset(276, 2),
    s + const Offset(257, 22),
    s + const Offset(204, 25),
    s + const Offset(160, 50),
    s + const Offset(105, 61),
    s + const Offset(54, 55),
    s + const Offset(10, 30),
    s + const Offset(0, -5),
    s + const Offset(35, -25),
  ];

  static List<Offset> _farWing(Offset s, double phase) {
    final lift = [
      -145.0,
      -85.0,
      -20.0,
      -100.0,
      -155.0,
    ][phase.round().clamp(0, 4)];
    return [
      s + const Offset(24, -17),
      s + Offset(-135, lift),
      s + Offset(-360, lift - 20),
      s + Offset(-525, lift + 48),
      s + Offset(-390, lift + 92),
      s + Offset(-210, lift + 110),
      s + const Offset(-42, 42),
      s + const Offset(14, 14),
    ];
  }

  static List<Offset> _nearWing(Offset s, double phase) {
    final lift = [
      -128.0,
      -74.0,
      -4.0,
      -70.0,
      -132.0,
    ][phase.round().clamp(0, 4)];
    return [
      s + const Offset(18, -15),
      s + Offset(138, lift),
      s + Offset(375, lift - 18),
      s + Offset(540, lift + 32),
      s + Offset(408, lift + 84),
      s + Offset(242, lift + 113),
      s + const Offset(120, 44),
      s + const Offset(76, 20),
      s + const Offset(33, 24),
    ];
  }
}

bool _hasNoCrossings(List<Offset> points) {
  for (var i = 0; i < points.length; i++) {
    final a = points[i];
    final b = points[(i + 1) % points.length];
    for (var j = i + 1; j < points.length; j++) {
      if (j == i ||
          (j + 1) % points.length == i ||
          (i + 1) % points.length == j) {
        continue;
      }
      if (_segmentsCross(a, b, points[j], points[(j + 1) % points.length])) {
        return false;
      }
    }
  }
  return true;
}

bool _segmentsCross(Offset a, Offset b, Offset c, Offset d) {
  double cross(Offset p, Offset q, Offset r) =>
      (q.dx - p.dx) * (r.dy - p.dy) - (q.dy - p.dy) * (r.dx - p.dx);
  final abC = cross(a, b, c);
  final abD = cross(a, b, d);
  final cdA = cross(c, d, a);
  final cdB = cross(c, d, b);
  return abC * abD < 0 && cdA * cdB < 0;
}
