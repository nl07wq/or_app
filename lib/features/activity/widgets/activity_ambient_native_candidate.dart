import 'dart:math' as math;

import 'package:flutter/material.dart';

/// An opt-in, Flutter-native comparison renderer for the Activity reference
/// media. It deliberately has no asset or platform-view dependency: every
/// luminous trail is drawn from deterministic stream metadata.
class ActivityAmbientNativeCandidate extends StatelessWidget {
  const ActivityAmbientNativeCandidate({
    super.key,
    required this.animation,
    required this.reducedMotion,
  });

  static const fieldKey = ValueKey('activity-ambient-native-candidate');
  static const filamentCount = 540;

  final Animation<double> animation;
  final bool reducedMotion;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      key: fieldKey,
      painter: _NativeLuminousFlowPainter(
        animation: animation,
        staticFrame: reducedMotion,
      ),
      child: const SizedBox.expand(),
    );
  }
}

@immutable
class _NativeFilament {
  const _NativeFilament({
    required this.seed,
    required this.radius,
    required this.phase,
    required this.length,
    required this.speed,
    required this.counterFlow,
    required this.color,
  });

  final int seed;
  final double radius;
  final double phase;
  final double length;
  final double speed;
  final bool counterFlow;
  final Color color;
}

class _NativeLuminousFlowPainter extends CustomPainter {
  _NativeLuminousFlowPainter({
    required this.animation,
    required this.staticFrame,
  }) : super(repaint: animation);

  final Animation<double> animation;
  final bool staticFrame;

  static final _filaments = List<_NativeFilament>.unmodifiable(
    List<_NativeFilament>.generate(
      ActivityAmbientNativeCandidate.filamentCount,
      _filamentFor,
    ),
  );

  static _NativeFilament _filamentFor(int index) {
    final unit = index / ActivityAmbientNativeCandidate.filamentCount;
    final ring = index % 12;
    final phase = unit * math.pi * 2 + (ring % 3) * .14;
    final color = switch ((phase / math.pi * 3).round() % 6) {
      0 => const Color(0xFFFF4F9E),
      1 => const Color(0xFFFF66BE),
      2 => const Color(0xFFD77BFF),
      3 => const Color(0xFF728DFF),
      4 => const Color(0xFF35D5FF),
      _ => const Color(0xFF5B9CFF),
    };
    return _NativeFilament(
      seed: index,
      radius: .13 + ((index * 37) % 67) / 100,
      phase: phase,
      length: .55 + ((index * 19) % 46) / 100,
      speed: .58 + ((index * 23) % 21) / 100,
      // A restrained inner counter-flow gives the centre the folded, living
      // motion visible in the source without introducing figure-eight paths.
      counterFlow: index % 11 == 0 || (index % 17 == 0 && ring < 4),
      color: color,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final center = size.center(Offset.zero);
    final radius = size.shortestSide * .49;
    // The source is twelve seconds. Mapping the existing controller phase to
    // those seconds makes native/reference captures comparable at a phase.
    final sourceSeconds = (staticFrame ? .5 : animation.value) * 12;
    final breathing = 1 + .055 * math.sin(sourceSeconds * .63);
    for (final filament in _filaments) {
      final path = _pathFor(
        filament: filament,
        center: center,
        radius: radius,
        seconds: sourceSeconds,
        breathing: breathing,
      );
      final opacity =
          .15 +
          .28 * (.5 + .5 * math.sin(sourceSeconds * .71 + filament.phase));
      final core = Paint()
        ..color = filament.color.withValues(alpha: opacity)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = .34 + (1 - filament.radius) * .22;
      final halo = Paint()
        ..color = filament.color.withValues(alpha: opacity * .22)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = core.strokeWidth * 3.2
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, .9);
      canvas
        ..drawPath(path, halo)
        ..drawPath(path, core);
    }
  }

  Path _pathFor({
    required _NativeFilament filament,
    required Offset center,
    required double radius,
    required double seconds,
    required double breathing,
  }) {
    const samples = 24;
    final direction = filament.counterFlow ? -1.0 : 1.0;
    final leading = filament.phase + direction * seconds * filament.speed;
    final path = Path();
    for (var sample = 0; sample < samples; sample++) {
      final tail = sample / (samples - 1);
      final angle = leading - direction * tail * filament.length;
      final irregularity =
          math.sin(angle * 2.7 + filament.phase * 1.9 + seconds * .36) * .030 +
          math.sin(angle * 5.1 - seconds * .22 + filament.seed) * .010;
      final radialDrift =
          math.sin(
                seconds * (.31 + filament.radius * .23) +
                    filament.phase * 2.4 +
                    tail * 1.7,
              ) *
              .038 +
          irregularity;
      final localRadius =
          radius * (filament.radius * breathing + radialDrift + tail * .018);
      final warpedAngle =
          angle + math.sin(angle * 3.0 + seconds * .28 + filament.phase) * .045;
      final point =
          center +
          Offset(math.cos(warpedAngle), math.sin(warpedAngle)) * localRadius;
      if (sample == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    return path;
  }

  @override
  bool shouldRepaint(covariant _NativeLuminousFlowPainter oldDelegate) =>
      oldDelegate.staticFrame != staticFrame ||
      oldDelegate.animation != animation;
}
