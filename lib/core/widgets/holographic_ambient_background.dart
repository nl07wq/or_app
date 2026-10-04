import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

const holographicCircuitRouteCount = 8;
const holographicCircuitMinimumRouteSegments = 5;
const holographicCircuitSignalDuration = Duration(seconds: 9);
const holographicCircuitIdleDuration = Duration(seconds: 4);
const holographicAmbientUpdateCadence = Duration(milliseconds: 50);

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

  List<Path> _routes(Size size) => _routeCoordinates
      .map(
        (points) => Path()
          ..moveTo(points.first.dx * size.width, points.first.dy * size.height)
          ..addPolygon(
            points
                .skip(1)
                .map(
                  (point) =>
                      Offset(point.dx * size.width, point.dy * size.height),
                )
                .toList(growable: false),
            false,
          ),
      )
      .toList(growable: false);

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
    final segmentLength = math.min(metric.length * .09, 76.0).toDouble();
    final head = _travelProgress(progress) * (metric.length + segmentLength);
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

  double _travelProgress(double progress) {
    final eased = Curves.easeInOutCubic.transform(progress);
    final modulation = math.sin(progress * math.pi * 3) * .018;
    return (eased + modulation).clamp(0.0, 1.0).toDouble();
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
      ..color = color.withValues(alpha: .022)
      ..strokeWidth = 1;
    for (var y = 2.5; y < size.height; y += 5) {
      canvas.drawLine(Offset.zero + Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_ScanlinePainter oldDelegate) =>
      oldDelegate.color != color;
}

const _routeCoordinates = <List<Offset>>[
  [
    Offset(-.16, .13),
    Offset(.18, .13),
    Offset(.27, .25),
    Offset(.51, .25),
    Offset(.65, .12),
    Offset(1.10, .12),
  ],
  [
    Offset(.08, 1.12),
    Offset(.08, .77),
    Offset(.21, .64),
    Offset(.42, .64),
    Offset(.56, .47),
    Offset(.92, .47),
  ],
  [
    Offset(1.14, .20),
    Offset(.82, .20),
    Offset(.72, .33),
    Offset(.72, .52),
    Offset(.46, .52),
    Offset(-.10, .52),
  ],
  [
    Offset(-.12, .85),
    Offset(.19, .85),
    Offset(.33, .71),
    Offset(.33, .46),
    Offset(.51, .34),
    Offset(.88, .34),
  ],
  [
    Offset(.94, 1.12),
    Offset(.94, .74),
    Offset(.75, .63),
    Offset(.55, .63),
    Offset(.43, .79),
    Offset(.18, .79),
  ],
  [
    Offset(-.10, .34),
    Offset(.16, .34),
    Offset(.29, .47),
    Offset(.29, .68),
    Offset(.48, .80),
    Offset(.76, 1.12),
  ],
  [
    Offset(.76, -.10),
    Offset(.76, .18),
    Offset(.58, .30),
    Offset(.41, .30),
    Offset(.28, .47),
    Offset(.28, .76),
  ],
  [
    Offset(1.12, .92),
    Offset(.81, .92),
    Offset(.68, .78),
    Offset(.50, .78),
    Offset(.38, .94),
    Offset(.02, .94),
  ],
];
