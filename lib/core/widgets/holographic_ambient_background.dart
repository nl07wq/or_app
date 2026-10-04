import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show PathMetric;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

const holographicCircuitRouteCount = 8;
const holographicCircuitMinimumRouteSegments = 8;
const holographicCircuitMaximumRouteSegments = 14;
const holographicCircuitSignalPixelsPerSecond = 340.0;
const holographicCircuitInitialDelay = Duration(milliseconds: 750);
const holographicCircuitIdleDuration = Duration(milliseconds: 1750);
const holographicAmbientUpdateCadence = Duration(milliseconds: 50);
const holographicCircuitAfterglowDuration = Duration(seconds: 15);
const holographicCircuitTerminalNodeDuration = Duration(milliseconds: 420);
const holographicCircuitMaximumConcurrentSignals = 2;
const holographicCircuitAmbientNodeDiameter = 5.8;

enum HolographicCircuitTopologyKind { branch, parallel }

@immutable
class HolographicCircuitTopologyTrace {
  const HolographicCircuitTopologyTrace({
    required this.kind,
    required this.activationPointIndex,
    required this.points,
  });

  final HolographicCircuitTopologyKind kind;
  final int activationPointIndex;
  final List<Offset> points;
}

@immutable
class HolographicCircuitScheduledPhase {
  const HolographicCircuitScheduledPhase({
    required this.routeIndex,
    required this.elapsedSeconds,
    required this.travelSeconds,
    required this.nodeSeconds,
  });

  final int routeIndex;
  final double elapsedSeconds;
  final double travelSeconds;
  final double nodeSeconds;

  bool get isPropagating => elapsedSeconds < travelSeconds;
}

/// Returns every still-visible circuit phase for [elapsedSeconds].
///
/// Scenario cadence intentionally uses only traveling-signal completion. The
/// route afterglow remains independently visible without delaying the next
/// scenario's signal.
@visibleForTesting
List<HolographicCircuitScheduledPhase> holographicCircuitPhasesAt({
  required List<double> routeTravelSeconds,
  required double elapsedSeconds,
}) {
  if (elapsedSeconds < holographicCircuitInitialDelay.inMilliseconds / 1000) {
    return const [];
  }
  assert(routeTravelSeconds.length == holographicCircuitRoutes.length);

  final initialDelaySeconds =
      holographicCircuitInitialDelay.inMilliseconds / 1000;
  final idleSeconds = holographicCircuitIdleDuration.inMilliseconds / 1000;
  final nodeSeconds =
      holographicCircuitTerminalNodeDuration.inMilliseconds / 1000;
  final afterglowSeconds =
      holographicCircuitAfterglowDuration.inMilliseconds / 1000;
  final scenarioStarts = <double>[];
  var scenarioStart = 0.0;
  for (final scenario in holographicCircuitTrafficScenarios) {
    scenarioStarts.add(scenarioStart);
    var lastTravelerCompletion = 0.0;
    for (final entry in scenario.entries) {
      lastTravelerCompletion = math.max(
        lastTravelerCompletion,
        entry.startDelay + routeTravelSeconds[entry.routeIndex],
      );
    }
    scenarioStart += lastTravelerCompletion + idleSeconds;
  }

  final activeElapsed = elapsedSeconds - initialDelaySeconds;
  final cycleSeconds = scenarioStart;
  final earliestVisibleStart = activeElapsed - afterglowSeconds - nodeSeconds;
  final firstCycle = math.max(0, (earliestVisibleStart / cycleSeconds).floor());
  final lastCycle = (activeElapsed / cycleSeconds).floor();
  final phases = <HolographicCircuitScheduledPhase>[];
  for (var cycle = firstCycle; cycle <= lastCycle; cycle++) {
    final cycleOffset = cycle * cycleSeconds;
    for (
      var scenarioIndex = 0;
      scenarioIndex < holographicCircuitTrafficScenarios.length;
      scenarioIndex++
    ) {
      final scenario = holographicCircuitTrafficScenarios[scenarioIndex];
      for (final entry in scenario.entries) {
        final travelSeconds = routeTravelSeconds[entry.routeIndex];
        final routeNodeSeconds =
            holographicCircuitRoutes[entry.routeIndex].terminalNode
            ? nodeSeconds
            : 0.0;
        final phaseElapsed =
            activeElapsed -
            cycleOffset -
            scenarioStarts[scenarioIndex] -
            entry.startDelay;
        if (phaseElapsed < 0 ||
            phaseElapsed >
                travelSeconds + routeNodeSeconds + afterglowSeconds) {
          continue;
        }
        phases.add(
          HolographicCircuitScheduledPhase(
            routeIndex: entry.routeIndex,
            elapsedSeconds: phaseElapsed,
            travelSeconds: travelSeconds,
            nodeSeconds: routeNodeSeconds,
          ),
        );
      }
    }
  }
  return phases;
}

@immutable
class HolographicCircuitRoute {
  const HolographicCircuitRoute({
    required this.points,
    this.nodePointIndexes = const [],
    this.topologyTraces = const [],
    this.terminalNode = false,
  });

  final List<Offset> points;
  final List<int> nodePointIndexes;
  final List<HolographicCircuitTopologyTrace> topologyTraces;
  final bool terminalNode;

  int get segmentCount => points.length - 1;
}

@immutable
class HolographicCircuitTrafficEntry {
  const HolographicCircuitTrafficEntry(this.routeIndex, {this.startDelay = 0});

  final int routeIndex;
  final double startDelay;
}

@immutable
class HolographicCircuitTrafficScenario {
  const HolographicCircuitTrafficScenario(this.entries);

  final List<HolographicCircuitTrafficEntry> entries;
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
  final _clock = Stopwatch();
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
    _clock
      ..stop()
      ..reset();
    _seconds.value = 0;
    if (!motionEnabled) return;
    _clock.start();
    _setSeconds();
    _driftTimer = Timer.periodic(holographicAmbientUpdateCadence, (_) {
      if (mounted) _setSeconds();
    });
  }

  void _setSeconds() => _seconds.value =
      _clock.elapsedMicroseconds / Duration.microsecondsPerSecond;

  @override
  void dispose() {
    _driftTimer?.cancel();
    _clock.stop();
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
          final scaledPoints = route.points
              .map(
                (point) =>
                    Offset(point.dx * size.width, point.dy * size.height),
              )
              .toList(growable: false);
          final path = Path()
            ..moveTo(scaledPoints.first.dx, scaledPoints.first.dy);
          for (final point in scaledPoints.skip(1)) {
            path.lineTo(point.dx, point.dy);
          }
          var distance = 0.0;
          final nodeDistances = <double>[];
          final pointDistances = <double>[0];
          for (var index = 1; index < scaledPoints.length; index++) {
            distance +=
                (scaledPoints[index] - scaledPoints[index - 1]).distance;
            pointDistances.add(distance);
            if (route.nodePointIndexes.contains(index)) {
              nodeDistances.add(distance);
            }
          }
          final topologyTraces = route.topologyTraces
              .map((trace) {
                final tracePoints = trace.points
                    .map(
                      (point) =>
                          Offset(point.dx * size.width, point.dy * size.height),
                    )
                    .toList(growable: false);
                final tracePath = Path()
                  ..moveTo(tracePoints.first.dx, tracePoints.first.dy);
                for (final point in tracePoints.skip(1)) {
                  tracePath.lineTo(point.dx, point.dy);
                }
                return _ResolvedCircuitTopologyTrace(
                  trace,
                  tracePath.computeMetrics().first,
                  pointDistances[trace.activationPointIndex],
                );
              })
              .toList(growable: false);
          return _ResolvedCircuitRoute(
            route,
            path.computeMetrics().first,
            nodeDistances,
            topologyTraces,
          );
        })
        .toList(growable: false);
    return _resolvedRoutes!;
  }

  void _paintCircuit(
    Canvas canvas,
    List<_ResolvedCircuitRoute> routes,
    double elapsed,
  ) {
    final phases = _phasesFor(routes, elapsed);
    for (final phase in phases) {
      _paintAfterglow(canvas, phase);
      _paintTopologyAfterglow(canvas, phase);
      _paintRouteNodes(canvas, phase);
    }
    for (final phase in phases) {
      if (phase.isPropagating) {
        _paintSignal(canvas, phase);
        _paintTopologySignals(canvas, phase);
      } else if (phase.isTerminalNode) {
        _paintTerminalNode(canvas, phase);
      }
    }
  }

  List<_CircuitPhase> _phasesFor(
    List<_ResolvedCircuitRoute> routes,
    double elapsed,
  ) =>
      holographicCircuitPhasesAt(
            routeTravelSeconds: routes
                .map(
                  (route) =>
                      route.metric.length /
                      holographicCircuitSignalPixelsPerSecond,
                )
                .toList(growable: false),
            elapsedSeconds: elapsed,
          )
          .map(
            (phase) => _CircuitPhase(
              route: routes[phase.routeIndex],
              elapsedSeconds: phase.elapsedSeconds,
              travelSeconds: phase.travelSeconds,
              nodeSeconds: phase.nodeSeconds,
            ),
          )
          .toList(growable: false);

  void _paintAfterglow(Canvas canvas, _CircuitPhase phase) {
    _paintMetricAfterglow(canvas, phase.route.metric, phase.elapsedSeconds);
  }

  void _paintTopologyAfterglow(Canvas canvas, _CircuitPhase phase) {
    for (final trace in phase.route.topologyTraces) {
      final traceElapsed = phase.elapsedSeconds - trace.activationSeconds;
      if (traceElapsed < 0) continue;
      _paintMetricAfterglow(canvas, trace.metric, traceElapsed);
    }
  }

  void _paintMetricAfterglow(
    Canvas canvas,
    PathMetric metric,
    double elapsedSeconds,
  ) {
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
      final age = elapsedSeconds - energizedAt;
      if (age < 0 || age > fadeSeconds) continue;
      final fade = 1 - age / fadeSeconds;
      paint.color = color.withValues(alpha: .20 * fade);
      canvas.drawPath(metric.extractPath(start, end), paint);
    }
  }

  void _paintSignal(Canvas canvas, _CircuitPhase phase) {
    _paintMetricSignal(canvas, phase.route.metric, phase.elapsedSeconds);
  }

  void _paintTopologySignals(Canvas canvas, _CircuitPhase phase) {
    for (final trace in phase.route.topologyTraces) {
      final traceElapsed = phase.elapsedSeconds - trace.activationSeconds;
      if (traceElapsed < 0) continue;
      _paintMetricSignal(canvas, trace.metric, traceElapsed);
    }
  }

  void _paintMetricSignal(
    Canvas canvas,
    PathMetric metric,
    double elapsedSeconds,
  ) {
    final head = elapsedSeconds * holographicCircuitSignalPixelsPerSecond;
    final segmentLength = math.min(metric.length * .085, 72.0).toDouble();
    final start = math.max(0.0, head - segmentLength).toDouble();
    final end = math.min(metric.length, head).toDouble();
    final visibility = math.min(1.0, elapsedSeconds / .12);
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

  void _paintRouteNodes(Canvas canvas, _CircuitPhase phase) {
    final fadeSeconds =
        holographicCircuitAfterglowDuration.inMilliseconds / 1000;
    for (final distance in phase.route.nodeDistances) {
      final age =
          phase.elapsedSeconds -
          distance / holographicCircuitSignalPixelsPerSecond;
      if (age < 0 || age > fadeSeconds) continue;
      final intensity = math.pow(1 - age / fadeSeconds, 1.15).toDouble();
      final position = phase.route.metric
          .getTangentForOffset(distance)
          ?.position;
      if (position == null) continue;
      final halo = Paint()
        ..color = color.withValues(alpha: .16 * intensity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
      final ring = Paint()
        ..color = color.withValues(alpha: .48 * intensity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1;
      canvas.drawCircle(position, 5.8, halo);
      canvas.drawCircle(
        position,
        holographicCircuitAmbientNodeDiameter / 2,
        ring,
      );
    }
    if (!phase.route.definition.terminalNode ||
        phase.elapsedSeconds < phase.travelSeconds) {
      return;
    }
    final age = phase.elapsedSeconds - phase.travelSeconds;
    if (age > fadeSeconds) return;
    final intensity = math.pow(1 - age / fadeSeconds, 1.2).toDouble();
    final position = phase.route.metric
        .getTangentForOffset(phase.route.metric.length)
        ?.position;
    if (position == null) return;
    if (phase.isTerminalNode) return;
    final halo = Paint()
      ..color = color.withValues(alpha: .16 * intensity)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    final ring = Paint()
      ..color = color.withValues(alpha: .42 * intensity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;
    canvas.drawCircle(position, 5.8, halo);
    canvas.drawCircle(
      position,
      holographicCircuitAmbientNodeDiameter / 2,
      ring,
    );
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
    final ring = Paint()
      ..color = color.withValues(alpha: .88 * intensity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final radius = holographicCircuitAmbientNodeDiameter / 2 + intensity * .45;
    canvas.drawCircle(position, radius + 5, halo);
    canvas.drawCircle(position, radius, ring);
  }

  @override
  bool shouldRepaint(_AmbientGeometryPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.motionEnabled != motionEnabled;
}

/// Static display texture for the large holographic surfaces only.
class HolographicScanlineOverlay extends StatelessWidget {
  const HolographicScanlineOverlay({
    super.key,
    this.lineSpacing = 3,
    this.opacity = .018,
  });

  final double lineSpacing;
  final double opacity;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: RepaintBoundary(
      child: CustomPaint(
        key: const ValueKey('holographic-scanline-overlay'),
        painter: _ScanlinePainter(
          Theme.of(context).colorScheme.primary,
          lineSpacing: lineSpacing,
          opacity: opacity,
        ),
        child: const SizedBox.expand(),
      ),
    ),
  );
}

class _ScanlinePainter extends CustomPainter {
  const _ScanlinePainter(
    this.color, {
    required this.lineSpacing,
    required this.opacity,
  });

  final Color color;
  final double lineSpacing;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: opacity)
      ..strokeWidth = 1;
    for (var y = lineSpacing / 2; y < size.height; y += lineSpacing) {
      canvas.drawLine(Offset.zero + Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_ScanlinePainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.lineSpacing != lineSpacing ||
      oldDelegate.opacity != opacity;
}

class _ResolvedCircuitRoute {
  const _ResolvedCircuitRoute(
    this.definition,
    this.metric,
    this.nodeDistances,
    this.topologyTraces,
  );

  final HolographicCircuitRoute definition;
  final PathMetric metric;
  final List<double> nodeDistances;
  final List<_ResolvedCircuitTopologyTrace> topologyTraces;
}

class _ResolvedCircuitTopologyTrace {
  const _ResolvedCircuitTopologyTrace(
    this.definition,
    this.metric,
    this.activationDistance,
  );

  final HolographicCircuitTopologyTrace definition;
  final PathMetric metric;
  final double activationDistance;

  double get activationSeconds =>
      activationDistance / holographicCircuitSignalPixelsPerSecond;
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
    nodePointIndexes: [3, 6],
    topologyTraces: [
      HolographicCircuitTopologyTrace(
        kind: HolographicCircuitTopologyKind.branch,
        activationPointIndex: 3,
        points: [
          Offset(.35, .22),
          Offset(.47, .10),
          Offset(.66, .10),
          Offset(.76, .20),
        ],
      ),
      HolographicCircuitTopologyTrace(
        kind: HolographicCircuitTopologyKind.parallel,
        activationPointIndex: 4,
        points: [
          Offset(.35, .36),
          Offset(.39, .40),
          Offset(.50, .40),
          Offset(.61, .29),
          Offset(.57, .27),
        ],
      ),
    ],
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
    nodePointIndexes: [3, 7, 9],
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
    nodePointIndexes: [3, 6],
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
    nodePointIndexes: [2, 5, 8],
    topologyTraces: [
      HolographicCircuitTopologyTrace(
        kind: HolographicCircuitTopologyKind.branch,
        activationPointIndex: 5,
        points: [
          Offset(.37, .48),
          Offset(.49, .48),
          Offset(.60, .58),
          Offset(.74, .58),
        ],
      ),
      HolographicCircuitTopologyTrace(
        kind: HolographicCircuitTopologyKind.parallel,
        activationPointIndex: 5,
        points: [
          Offset(.37, .48),
          Offset(.41, .51),
          Offset(.53, .39),
          Offset(.65, .39),
          Offset(.61, .36),
        ],
      ),
    ],
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
    nodePointIndexes: [3, 7, 10],
    topologyTraces: [
      HolographicCircuitTopologyTrace(
        kind: HolographicCircuitTopologyKind.branch,
        activationPointIndex: 7,
        points: [
          Offset(.35, .77),
          Offset(.24, .67),
          Offset(.12, .67),
          Offset(.04, .75),
        ],
      ),
    ],
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
    nodePointIndexes: [3, 6],
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
    nodePointIndexes: [2, 5, 8],
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
    nodePointIndexes: [3, 6, 9],
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

const holographicCircuitTrafficScenarios = <HolographicCircuitTrafficScenario>[
  HolographicCircuitTrafficScenario([HolographicCircuitTrafficEntry(0)]),
  HolographicCircuitTrafficScenario([HolographicCircuitTrafficEntry(1)]),
  HolographicCircuitTrafficScenario([
    HolographicCircuitTrafficEntry(2),
    HolographicCircuitTrafficEntry(6, startDelay: .8),
  ]),
  HolographicCircuitTrafficScenario([HolographicCircuitTrafficEntry(3)]),
  HolographicCircuitTrafficScenario([
    HolographicCircuitTrafficEntry(4),
    HolographicCircuitTrafficEntry(7, startDelay: .65),
  ]),
  HolographicCircuitTrafficScenario([HolographicCircuitTrafficEntry(5)]),
  HolographicCircuitTrafficScenario([
    HolographicCircuitTrafficEntry(6),
    HolographicCircuitTrafficEntry(1, startDelay: .95),
  ]),
  HolographicCircuitTrafficScenario([HolographicCircuitTrafficEntry(7)]),
];
