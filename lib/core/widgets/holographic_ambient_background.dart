import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show PathMetric;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

const holographicCircuitRouteCount = 8;
const holographicCircuitMinimumRouteSegments = 8;
const holographicCircuitMaximumRouteSegments = 14;
const holographicCircuitSignalPixelsPerSecond = 112.0;
const holographicCircuitIdleDuration = Duration(seconds: 4);
const holographicAmbientUpdateCadence = Duration(milliseconds: 50);
const holographicCircuitAfterglowDuration = Duration(milliseconds: 1600);
const holographicCircuitTerminalNodeDuration = Duration(milliseconds: 420);

@immutable
class HolographicCircuitRoute {
  const HolographicCircuitRoute({
    required this.points,
    this.terminalNode = false,
  });

  final List<Offset> points;
  final bool terminalNode;

  int get segmentCount => points.length - 1;
}

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
  Size? _resolvedSize;
  List<_ResolvedCircuitRoute>? _resolvedRoutes;

  @override
  void paint(Canvas canvas, Size size) {
    final elapsed = seconds.value;
    if (!motionEnabled) return;
    _paintCircuit(canvas, _resolveRoutes(size), elapsed);
  }

  List<_ResolvedCircuitRoute> _resolveRoutes(Size size) {
    if (_resolvedSize == size && _resolvedRoutes != null) {
      return _resolvedRoutes!;
    }
    _resolvedSize = size;
    _resolvedRoutes = holographicCircuitRoutes
        .map((route) {
          final path = Path()
            ..moveTo(
              route.points.first.dx * size.width,
              route.points.first.dy * size.height,
            );
          for (final point in route.points.skip(1)) {
            path.lineTo(point.dx * size.width, point.dy * size.height);
          }
          return _ResolvedCircuitRoute(route, path.computeMetrics().first);
        })
        .toList(growable: false);
    return _resolvedRoutes!;
  }

  void _paintCircuit(
    Canvas canvas,
    List<_ResolvedCircuitRoute> routes,
    double elapsed,
  ) {
    final phase = _phaseFor(routes, elapsed);
    _paintAfterglow(canvas, phase);
    if (phase.isPropagating) {
      _paintSignal(canvas, phase);
    } else if (phase.isTerminalNode) {
      _paintTerminalNode(canvas, phase);
    }
  }

  _CircuitPhase _phaseFor(List<_ResolvedCircuitRoute> routes, double elapsed) {
    final idleSeconds = holographicCircuitIdleDuration.inMilliseconds / 1000;
    final nodeSeconds =
        holographicCircuitTerminalNodeDuration.inMilliseconds / 1000;
    final cycleSeconds = routes.fold<double>(
      0,
      (total, route) =>
          total +
          route.metric.length / holographicCircuitSignalPixelsPerSecond +
          (route.definition.terminalNode ? nodeSeconds : 0) +
          idleSeconds,
    );
    var routeElapsed = elapsed % cycleSeconds;
    for (final route in routes) {
      final travelSeconds =
          route.metric.length / holographicCircuitSignalPixelsPerSecond;
      final nodeWindow = route.definition.terminalNode ? nodeSeconds : 0.0;
      final routeWindow = travelSeconds + nodeWindow + idleSeconds;
      if (routeElapsed < routeWindow) {
        return _CircuitPhase(
          route: route,
          elapsedSeconds: routeElapsed,
          travelSeconds: travelSeconds,
          nodeSeconds: nodeWindow,
        );
      }
      routeElapsed -= routeWindow;
    }
    return _CircuitPhase(
      route: routes.last,
      elapsedSeconds: 0,
      travelSeconds:
          routes.last.metric.length / holographicCircuitSignalPixelsPerSecond,
      nodeSeconds: routes.last.definition.terminalNode ? nodeSeconds : 0,
    );
  }

  void _paintAfterglow(Canvas canvas, _CircuitPhase phase) {
    final metric = phase.route.metric;
    final fadeSeconds =
        holographicCircuitAfterglowDuration.inMilliseconds / 1000;
    final chunkCount = math
        .max(8, math.min(18, (metric.length / 52).round()))
        .toInt();
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.7
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.4);
    for (var index = 0; index < chunkCount; index++) {
      final start = metric.length * index / chunkCount;
      final end = metric.length * (index + 1) / chunkCount;
      final energizedAt = end / holographicCircuitSignalPixelsPerSecond;
      final age = phase.elapsedSeconds - energizedAt;
      if (age < 0 || age > fadeSeconds) continue;
      final fade = 1 - age / fadeSeconds;
      paint.color = color.withValues(alpha: .18 * fade * fade);
      canvas.drawPath(metric.extractPath(start, end), paint);
    }
  }

  void _paintSignal(Canvas canvas, _CircuitPhase phase) {
    final metric = phase.route.metric;
    final head = phase.elapsedSeconds * holographicCircuitSignalPixelsPerSecond;
    final segmentLength = math.min(metric.length * .085, 72.0).toDouble();
    final start = math.max(0.0, head - segmentLength).toDouble();
    final end = math.min(metric.length, head).toDouble();
    final visibility = math.min(1.0, phase.elapsedSeconds / .12);
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

  void _paintTerminalNode(Canvas canvas, _CircuitPhase phase) {
    final progress =
        (phase.elapsedSeconds - phase.travelSeconds) / phase.nodeSeconds;
    final intensity = math.sin(progress * math.pi);
    if (intensity <= 0) return;
    final position = phase.route.metric
        .getTangentForOffset(phase.route.metric.length)
        ?.position;
    if (position == null) return;
    final halo = Paint()
      ..color = color.withValues(alpha: .32 * intensity)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7);
    final glow = Paint()
      ..color = color.withValues(alpha: .62 * intensity)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);
    final core = Paint()..color = color.withValues(alpha: .92 * intensity);
    final radius = 2.2 + intensity * 1.6;
    canvas.drawCircle(position, radius + 5, halo);
    canvas.drawCircle(position, radius + 1.6, glow);
    canvas.drawCircle(position, radius, core);
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
      ..color = color.withValues(alpha: .014)
      ..strokeWidth = 1;
    for (var y = 1.5; y < size.height; y += 3) {
      canvas.drawLine(Offset.zero + Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_ScanlinePainter oldDelegate) =>
      oldDelegate.color != color;
}

class _ResolvedCircuitRoute {
  const _ResolvedCircuitRoute(this.definition, this.metric);

  final HolographicCircuitRoute definition;
  final PathMetric metric;
}

class _CircuitPhase {
  const _CircuitPhase({
    required this.route,
    required this.elapsedSeconds,
    required this.travelSeconds,
    required this.nodeSeconds,
  });

  final _ResolvedCircuitRoute route;
  final double elapsedSeconds;
  final double travelSeconds;
  final double nodeSeconds;

  bool get isPropagating => elapsedSeconds < travelSeconds;
  bool get isTerminalNode =>
      route.definition.terminalNode &&
      elapsedSeconds >= travelSeconds &&
      elapsedSeconds < travelSeconds + nodeSeconds;
}

const holographicCircuitRoutes = <HolographicCircuitRoute>[
  HolographicCircuitRoute(
    terminalNode: true,
    points: [
      Offset(-.16, .13),
      Offset(.12, .13),
      Offset(.20, .22),
      Offset(.35, .22),
      Offset(.35, .36),
      Offset(.48, .36),
      Offset(.57, .27),
      Offset(.71, .27),
      Offset(.71, .13),
      Offset(1.10, .13),
    ],
  ),
  HolographicCircuitRoute(
    points: [
      Offset(.07, 1.12),
      Offset(.07, .86),
      Offset(.17, .76),
      Offset(.31, .76),
      Offset(.31, .61),
      Offset(.43, .61),
      Offset(.52, .50),
      Offset(.66, .50),
      Offset(.66, .38),
      Offset(.79, .38),
      Offset(.93, .25),
      Offset(1.12, .25),
    ],
  ),
  HolographicCircuitRoute(
    terminalNode: true,
    points: [
      Offset(1.14, .20),
      Offset(.89, .20),
      Offset(.80, .29),
      Offset(.80, .42),
      Offset(.68, .42),
      Offset(.58, .54),
      Offset(.45, .54),
      Offset(.45, .66),
      Offset(.27, .66),
      Offset(.17, .57),
      Offset(-.10, .57),
    ],
  ),
  HolographicCircuitRoute(
    points: [
      Offset(-.12, .86),
      Offset(.12, .86),
      Offset(.22, .76),
      Offset(.22, .64),
      Offset(.37, .64),
      Offset(.37, .48),
      Offset(.49, .36),
      Offset(.61, .36),
      Offset(.61, .25),
      Offset(.88, .25),
    ],
  ),
  HolographicCircuitRoute(
    terminalNode: true,
    points: [
      Offset(.94, 1.12),
      Offset(.94, .89),
      Offset(.84, .79),
      Offset(.70, .79),
      Offset(.70, .67),
      Offset(.57, .67),
      Offset(.47, .77),
      Offset(.35, .77),
      Offset(.35, .89),
      Offset(.20, .89),
      Offset(.10, .78),
      Offset(.10, .62),
      Offset(-.10, .62),
    ],
  ),
  HolographicCircuitRoute(
    points: [
      Offset(-.10, .34),
      Offset(.12, .34),
      Offset(.23, .45),
      Offset(.23, .55),
      Offset(.34, .55),
      Offset(.34, .71),
      Offset(.47, .83),
      Offset(.59, .83),
      Offset(.59, .95),
      Offset(.76, 1.12),
    ],
  ),
  HolographicCircuitRoute(
    points: [
      Offset(.76, -.10),
      Offset(.76, .15),
      Offset(.66, .25),
      Offset(.53, .25),
      Offset(.53, .36),
      Offset(.40, .36),
      Offset(.30, .47),
      Offset(.30, .59),
      Offset(.18, .59),
      Offset(.18, .77),
      Offset(.04, .90),
    ],
  ),
  HolographicCircuitRoute(
    points: [
      Offset(1.12, .93),
      Offset(.89, .93),
      Offset(.80, .84),
      Offset(.67, .84),
      Offset(.67, .72),
      Offset(.55, .72),
      Offset(.45, .83),
      Offset(.34, .83),
      Offset(.34, .96),
      Offset(.18, .96),
      Offset(.02, 1.10),
    ],
  ),
];
