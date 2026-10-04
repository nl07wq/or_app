import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

const holographicAmbientDriftPeriod = Duration(seconds: 240);
const holographicAmbientTravelPeriod = Duration(seconds: 26);
const holographicAmbientUpdateCadence = Duration(milliseconds: 120);

/// A single, non-interactive background layer for the Calendar and Reminder
/// display planes. Its sparse geometry is intentionally independent from the
/// foreground layout so it remains a spatial depth cue rather than a grid.
class HolographicAmbientBackground extends StatefulWidget {
  const HolographicAmbientBackground({super.key});

  @override
  State<HolographicAmbientBackground> createState() =>
      _HolographicAmbientBackgroundState();
}

class _HolographicAmbientBackgroundState
    extends State<HolographicAmbientBackground> {
  Timer? _driftTimer;
  final _seconds = ValueNotifier<double>(0);
  bool _motionEnabled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _configureMotion(
      !(MediaQuery.maybeOf(context)?.disableAnimations ?? false),
    );
  }

  void _configureMotion(bool motionEnabled) {
    _driftTimer?.cancel();
    _driftTimer = null;
    _motionEnabled = motionEnabled;
    _setSeconds();
    if (!motionEnabled) return;
    _driftTimer = Timer.periodic(holographicAmbientUpdateCadence, (_) {
      if (mounted) _setSeconds();
    });
  }

  void _setSeconds() => _seconds.value =
      DateTime.now().microsecondsSinceEpoch / Duration.microsecondsPerSecond;

  @override
  void dispose() {
    _driftTimer?.cancel();
    _seconds.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: RepaintBoundary(
      child: CustomPaint(
        key: const ValueKey('holographic-ambient-background'),
        painter: _AmbientGeometryPainter(
          color: Theme.of(context).colorScheme.primary,
          seconds: _seconds,
          motionEnabled: _motionEnabled,
        ),
        child: const SizedBox.expand(),
      ),
    ),
  );
}

class _AmbientGeometryPainter extends CustomPainter {
  _AmbientGeometryPainter({
    required this.color,
    required this.seconds,
    required this.motionEnabled,
  }) : super(repaint: seconds);

  final Color color;
  final ValueListenable<double> seconds;
  final bool motionEnabled;

  @override
  void paint(Canvas canvas, Size size) {
    final elapsed = seconds.value;
    final drift =
        (elapsed % holographicAmbientDriftPeriod.inSeconds) /
        holographicAmbientDriftPeriod.inSeconds;
    final wave = drift * math.pi * 2;
    final driftX = motionEnabled ? math.sin(wave) * size.width * .035 : 0.0;
    final driftY = motionEnabled ? math.cos(wave) * size.height * .018 : 0.0;
    canvas.save();
    canvas.translate(driftX, driftY);

    final halo = Paint()
      ..color = color.withValues(alpha: .12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    final glow = Paint()
      ..color = color.withValues(alpha: .24)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);
    final core = Paint()
      ..color = color.withValues(alpha: .56)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.05;

    final first = Path()
      ..moveTo(-size.width * .18, size.height * .18)
      ..lineTo(size.width * .16, size.height * .08)
      ..lineTo(size.width * .42, size.height * .30)
      ..lineTo(size.width * 1.12, size.height * .14);
    final second = Path()
      ..moveTo(size.width * .72, -size.height * .12)
      ..lineTo(size.width * .57, size.height * .26)
      ..lineTo(size.width * .86, size.height * .48)
      ..lineTo(size.width * 1.16, size.height * .42);
    final third = Path()
      ..moveTo(-size.width * .12, size.height * .74)
      ..lineTo(size.width * .24, size.height * .62)
      ..lineTo(size.width * .47, size.height * .88)
      ..lineTo(size.width * .78, size.height * 1.08);
    final fourth = Path()
      ..moveTo(size.width * .24, size.height * 1.10)
      ..lineTo(size.width * .50, size.height * .72)
      ..lineTo(size.width * 1.14, size.height * .82);

    final paths = [first, second, third, fourth];
    for (final path in paths) {
      canvas.drawPath(path, halo);
      canvas.drawPath(path, glow);
      canvas.drawPath(path, core);
    }
    if (motionEnabled) {
      _paintTravelingLight(canvas, paths, elapsed);
    }
    final junction = Paint()..color = color.withValues(alpha: .52);
    canvas.drawCircle(
      Offset(size.width * .42, size.height * .30),
      1.4,
      junction,
    );
    canvas.drawCircle(
      Offset(size.width * .57, size.height * .26),
      1.2,
      junction,
    );
    canvas.drawCircle(
      Offset(size.width * .24, size.height * .62),
      1.2,
      junction,
    );
    canvas.restore();
  }

  void _paintTravelingLight(Canvas canvas, List<Path> paths, double elapsed) {
    final cycle = elapsed / holographicAmbientTravelPeriod.inSeconds;
    final pathIndex = cycle.floor() % paths.length;
    final progress =
        (elapsed % holographicAmbientTravelPeriod.inSeconds) /
        holographicAmbientTravelPeriod.inSeconds;
    final metric = paths[pathIndex].computeMetrics().first;
    final segmentLength = math.min(metric.length * .12, 110.0);
    final start = progress * metric.length;
    final end = math.min(metric.length, start + segmentLength);
    final visibility = math.sin(progress * math.pi);
    if (end <= start || visibility <= 0) return;
    final segment = metric.extractPath(start, end);
    final halo = Paint()
      ..color = color.withValues(alpha: .34 * visibility)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 11
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9);
    final glow = Paint()
      ..color = color.withValues(alpha: .70 * visibility)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    final core = Paint()
      ..color = color.withValues(alpha: .96 * visibility)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;
    canvas.drawPath(segment, halo);
    canvas.drawPath(segment, glow);
    canvas.drawPath(segment, core);
  }

  @override
  bool shouldRepaint(_AmbientGeometryPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.motionEnabled != motionEnabled;
}
