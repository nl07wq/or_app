import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

const holographicCircuitRouteCount = 5;
const holographicCircuitSignalDuration = Duration(seconds: 16);
const holographicCircuitIdleDuration = Duration(seconds: 5);
const holographicAmbientUpdateCadence = Duration(milliseconds: 120);

/// A single, non-interactive circuit-signal layer behind the Calendar and
/// Reminder display planes. Routes are intentionally never drawn at rest.
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
    if (!motionEnabled) return;
    _paintCircuitSignal(canvas, _routes(size), elapsed);
  }

  List<Path> _routes(Size size) => [
    Path()
      ..moveTo(-size.width * .14, size.height * .16)
      ..lineTo(size.width * .24, size.height * .16)
      ..lineTo(size.width * .39, size.height * .34)
      ..lineTo(size.width * .87, size.height * .34),
    Path()
      ..moveTo(size.width * .10, size.height * 1.10)
      ..lineTo(size.width * .10, size.height * .66)
      ..lineTo(size.width * .31, size.height * .51)
      ..lineTo(size.width * .72, size.height * .51),
    Path()
      ..moveTo(size.width * 1.12, size.height * .13)
      ..lineTo(size.width * .68, size.height * .13)
      ..lineTo(size.width * .55, size.height * .38)
      ..lineTo(size.width * .18, size.height * .38),
    Path()
      ..moveTo(-size.width * .10, size.height * .82)
      ..lineTo(size.width * .29, size.height * .82)
      ..lineTo(size.width * .44, size.height * .65)
      ..lineTo(size.width * .44, size.height * .24),
    Path()
      ..moveTo(size.width * .92, size.height * 1.10)
      ..lineTo(size.width * .92, size.height * .72)
      ..lineTo(size.width * .68, size.height * .59)
      ..lineTo(size.width * .68, -size.height * .08),
  ];

  void _paintCircuitSignal(Canvas canvas, List<Path> paths, double elapsed) {
    final cycleDuration =
        holographicCircuitSignalDuration.inSeconds +
        holographicCircuitIdleDuration.inSeconds;
    final cycle = elapsed / cycleDuration;
    final pathIndex = cycle.floor() % paths.length;
    final progress =
        (elapsed % cycleDuration) / holographicCircuitSignalDuration.inSeconds;
    if (progress >= 1) return;
    final metric = paths[pathIndex].computeMetrics().first;
    final segmentLength = math.min(metric.length * .085, 78.0).toDouble();
    final head = progress * (metric.length + segmentLength);
    final start = math.max(0.0, head - segmentLength).toDouble();
    final end = math.min(metric.length, head).toDouble();
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

/// Static display texture for the large holographic surfaces only.
class HolographicScanlineOverlay extends StatelessWidget {
  const HolographicScanlineOverlay({super.key});

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: RepaintBoundary(
      child: CustomPaint(
        key: const ValueKey('holographic-scanline-overlay'),
        painter: _ScanlinePainter(Theme.of(context).colorScheme.primary),
        child: const SizedBox.expand(),
      ),
    ),
  );
}

class _ScanlinePainter extends CustomPainter {
  const _ScanlinePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: .035)
      ..strokeWidth = 1;
    for (var y = 2.0; y < size.height; y += 4) {
      canvas.drawLine(Offset.zero + Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_ScanlinePainter oldDelegate) =>
      oldDelegate.color != color;
}
