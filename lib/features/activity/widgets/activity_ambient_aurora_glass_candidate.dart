import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Opt-in, Flutter-native Aurora Glass V8 comparison field.
///
/// It draws deterministic translucent digital fragments directly; it has no
/// video, image, platform-view, or asset dependency.
class ActivityAmbientAuroraGlassCandidate extends StatelessWidget {
  const ActivityAmbientAuroraGlassCandidate({
    super.key,
    required this.animation,
    required this.reducedMotion,
  });

  static const fieldKey = ValueKey('activity-ambient-aurora-glass-candidate');
  static const fragmentCount = 576;

  final Animation<double> animation;
  final bool reducedMotion;

  @override
  Widget build(BuildContext context) => CustomPaint(
    key: fieldKey,
    painter: _AuroraGlassPainter(
      animation: animation,
      staticFrame: reducedMotion,
    ),
    child: const SizedBox.expand(),
  );
}

@immutable
class _AuroraFragment {
  const _AuroraFragment({
    required this.seed,
    required this.cluster,
    required this.angle,
    required this.radius,
    required this.depth,
    required this.color,
  });

  final int seed;
  final int cluster;
  final double angle;
  final double radius;
  final double depth;
  final Color color;
}

class _AuroraGlassPainter extends CustomPainter {
  _AuroraGlassPainter({required this.animation, required this.staticFrame})
    : super(repaint: animation);

  final Animation<double> animation;
  final bool staticFrame;

  static final _fragments = List<_AuroraFragment>.unmodifiable(
    List<_AuroraFragment>.generate(
      ActivityAmbientAuroraGlassCandidate.fragmentCount,
      _fragmentFor,
    ),
  );

  static _AuroraFragment _fragmentFor(int index) {
    final cluster = index % 6;
    final lane = (index ~/ 6) % 16;
    final layer = (index ~/ 96) % 6;
    final clusterAngle = cluster * math.pi / 3 + .18;
    final angle = clusterAngle + (lane - 7.5) * .047 + layer * .018;
    final color = switch (cluster) {
      0 || 4 => const Color(0xFF57E6EF),
      1 || 5 => const Color(0xFFE69AD8),
      2 => const Color(0xFF69CFE0),
      _ => const Color(0xFFD587C8),
    };
    return _AuroraFragment(
      seed: index,
      cluster: cluster,
      angle: angle,
      radius: .24 + layer * .085 + ((index * 37) % 13) / 100,
      depth: .35 + ((index * 19) % 61) / 100,
      color: color,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final center = size.center(Offset.zero);
    final fieldRadius = size.shortestSide * .49;
    final seconds = _seconds();
    for (final fragment in _fragments) {
      final phase = seconds * (.36 + fragment.depth * .16) + fragment.cluster;
      final assemble = .5 + .5 * math.sin(phase + fragment.seed * .071);
      final dissolve = .32 + .68 * assemble * assemble;
      final angle =
          fragment.angle +
          math.sin(phase * .82 + fragment.seed * .11) * .16 +
          seconds * (fragment.cluster.isEven ? .055 : -.048);
      final radial =
          fieldRadius *
          (fragment.radius +
              math.sin(phase * 1.31 + fragment.seed * .043) * .085);
      final rawPoint =
          center + Offset(math.cos(angle), math.sin(angle)) * radial;
      // Integer alignment retains the reference's visible digital-square
      // texture rather than soft circular particle silhouettes.
      final point = Offset(
        rawPoint.dx.roundToDouble(),
        rawPoint.dy.roundToDouble(),
      );
      final tile = .8 + fragment.depth * 2.0;
      final alpha =
          (.10 + .58 * dissolve) *
          (.62 + .38 * math.sin(phase * .57 + fragment.seed) * .5 + .19);
      final rect = Rect.fromCenter(center: point, width: tile, height: tile);
      final glow = Paint()
        ..color = fragment.color.withValues(alpha: alpha * .11)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, tile * .9);
      final glass = Paint()
        ..color = fragment.color.withValues(alpha: alpha)
        ..style = PaintingStyle.fill;
      final reflection = Paint()
        ..color = const Color(0xFFEFFBFF).withValues(alpha: alpha * .32);
      canvas
        ..drawRect(rect.inflate(tile * .35), glow)
        ..drawRect(rect, glass)
        ..drawRect(
          Rect.fromLTWH(rect.left, rect.top, rect.width, rect.height * .22),
          reflection,
        );
    }
  }

  double _seconds() {
    if (staticFrame) return 4.5;
    final elapsed = animation is AnimationController
        ? (animation as AnimationController).lastElapsedDuration
        : null;
    if (elapsed == null) return animation.value * 12;
    return elapsed.inMicroseconds / Duration.microsecondsPerSecond * .8;
  }

  @override
  bool shouldRepaint(covariant _AuroraGlassPainter oldDelegate) =>
      oldDelegate.staticFrame != staticFrame ||
      oldDelegate.animation != animation;
}
