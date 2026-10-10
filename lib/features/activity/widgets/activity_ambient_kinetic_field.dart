import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Activity-only kinetic measurement field.
class ActivityAmbientKineticField extends StatefulWidget {
  const ActivityAmbientKineticField({super.key, required this.enabled});

  static const fieldKey = ValueKey('activity-ambient-kinetic-field');
  static const trackingRegionCount = 7;
  static const cycleSeconds = 15.5;

  /// Bounded, reusable stream geometry for the reference-inspired luminous
  /// field. These are not polygon tracks: each stream is advected through a
  /// continuously evolving shared flow field.
  static const luminousStreamCount = 360;
  static const luminousFlowRegionCount = 8;
  static const luminousStreamLayers = 3;
  static const luminousStreamDrawOperationsPerFrame =
      luminousStreamCount * luminousStreamLayers;
  static const luminousStreamSamples = 16;
  static const continuityEvidenceSeconds = 30.0;

  // V4.10 keeps the soft edge local to every moving strand while putting the
  // visible width back in the core instead of a large blurred halo.
  static const filamentCoreBaseWidth = 1.10;
  static const filamentCoreDepthWidth = .60;
  static const filamentHaloBaseWidth = 2.60;
  static const filamentHaloDepthWidth = 1.05;
  static const filamentHaloBlurSigma = 1.10;
  static const scopeTopInset = 16.0;
  static const scopeBottomInset = 24.0;
  final bool enabled;

  @visibleForTesting
  static double swarmSecondsFor({required int cycle, required double phase}) =>
      (cycle + phase) * cycleSeconds;

  /// Production-flow telemetry for deterministic tests. The metric is derived
  /// from the same agent positions used by the painter; it is never used while
  /// painting a frame.
  @visibleForTesting
  static ActivitySwarmMetrics swarmMetricsFor(double elapsedSeconds) =>
      _MovingScopePainter.swarmMetricsFor(elapsedSeconds);

  @visibleForTesting
  /// Deterministic telemetry derived from the same advected positions used by
  /// the production painter. It describes the continuous outer orbital,
  /// central counterflow, and radial exchange in the one shared field.
  @visibleForTesting
  static ActivityMultiDirectionalFlowMetrics multiDirectionalFlowMetricsFor(
    double elapsedSeconds,
  ) => _MovingScopePainter.multiDirectionalFlowMetricsFor(elapsedSeconds);

  /// Test-only paint telemetry. It is assigned exclusively from an assert,
  /// so release builds do not retain or update runtime instrumentation.
  @visibleForTesting
  static ActivityAmbientScopeGeometry? debugLastPaintGeometry;

  @visibleForTesting
  static ActivityAmbientScopeGeometry scopeGeometryFor({
    required Size painterSize,
    required double phase,
  }) {
    final radius = (painterSize.shortestSide * .34)
        .clamp(92.0, 168.0)
        .toDouble();
    // V4.6 Phase 1 deliberately fixes the instrument and swarm center. The
    // viewport remains expanded so Phase 2 can restore travel without another
    // layout change.
    final center = Offset(painterSize.width / 2, painterSize.height / 2);
    return ActivityAmbientScopeGeometry(
      painterSize: painterSize,
      center: center,
      radius: radius,
    );
  }

  /// Deterministic, auditable measurement lifecycle used by the production
  /// painter: detection leads to tracking, then a measurement signal and an
  /// accumulation update. Regions use phase offsets rather than global resets.
  static ActivityKineticSample sampleFor({
    required int region,
    required double elapsedSeconds,
  }) {
    assert(region >= 0 && region < trackingRegionCount);
    const offsets = [.00, .14, .29, .43, .58, .72, .86];
    final local = (elapsedSeconds / cycleSeconds + offsets[region]) % 1;
    if (local < .10) {
      return ActivityKineticSample(
        phase: ActivityKineticPhase.detect,
        pathProgress: 0,
        ringResponse: 1 - local / .10,
        signalProgress: 0,
        accumulationProgress: 0,
      );
    }
    if (local < .66) {
      return ActivityKineticSample(
        phase: ActivityKineticPhase.track,
        pathProgress: (local - .10) / .56,
        ringResponse: .22,
        signalProgress: 0,
        accumulationProgress: 0,
      );
    }
    if (local < .79) {
      final measurement = (local - .66) / .13;
      return ActivityKineticSample(
        phase: ActivityKineticPhase.measure,
        pathProgress: 1,
        ringResponse: 1 - measurement * .18,
        signalProgress: measurement,
        accumulationProgress: 0,
      );
    }
    if (local < .94) {
      return ActivityKineticSample(
        phase: ActivityKineticPhase.accumulate,
        pathProgress: 1,
        ringResponse: .35,
        signalProgress: 1,
        accumulationProgress: (local - .79) / .15,
      );
    }
    return const ActivityKineticSample(
      phase: ActivityKineticPhase.continueMonitoring,
      pathProgress: 1,
      ringResponse: .14,
      signalProgress: 1,
      accumulationProgress: 1,
    );
  }

  @override
  State<ActivityAmbientKineticField> createState() =>
      _ActivityAmbientKineticFieldState();
}

enum ActivityKineticPhase {
  detect,
  track,
  measure,
  accumulate,
  continueMonitoring,
}

@immutable
class ActivityKineticSample {
  const ActivityKineticSample({
    required this.phase,
    required this.pathProgress,
    required this.ringResponse,
    required this.signalProgress,
    required this.accumulationProgress,
  });

  final ActivityKineticPhase phase;
  final double pathProgress;
  final double ringResponse;
  final double signalProgress;
  final double accumulationProgress;
}

@immutable
class ActivityAmbientScopeGeometry {
  const ActivityAmbientScopeGeometry({
    required this.painterSize,
    required this.center,
    required this.radius,
  });

  final Size painterSize;
  final Offset center;
  final double radius;

  Rect get scopeBounds => Rect.fromCircle(center: center, radius: radius);

  Rect get visibleScopeBounds =>
      scopeBounds.intersect(Offset.zero & painterSize);
}

class _ActivityAmbientKineticFieldState
    extends State<ActivityAmbientKineticField>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: Duration(
      milliseconds: (ActivityAmbientKineticField.cycleSeconds * 1000).round(),
    ),
  );
  var _motionAllowed = false;
  var _resolvedMotion = false;
  late final ValueNotifier<int> _swarmCycle = ValueNotifier(0);
  var _previousAnimationValue = 0.0;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_advanceSwarmEpoch);
  }

  void _advanceSwarmEpoch() {
    final value = _controller.value;
    if (value < _previousAnimationValue && _previousAnimationValue > .8) {
      _swarmCycle.value++;
    }
    _previousAnimationValue = value;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final motionAllowed =
        !(MediaQuery.maybeOf(context)?.disableAnimations ?? false) &&
        TickerMode.valuesOf(context).enabled;
    if (!_resolvedMotion || motionAllowed != _motionAllowed) {
      _motionAllowed = motionAllowed;
      _resolvedMotion = true;
      _syncAnimation();
    }
  }

  @override
  void didUpdateWidget(covariant ActivityAmbientKineticField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled != oldWidget.enabled) _syncAnimation();
  }

  void _syncAnimation() {
    if (!mounted) return;
    if (widget.enabled && _motionAllowed) {
      _controller.repeat();
    } else {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_advanceSwarmEpoch);
    _controller.dispose();
    _swarmCycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return const SizedBox.shrink();
    return IgnorePointer(
      child: RepaintBoundary(
        key: ActivityAmbientKineticField.fieldKey,
        child: CustomPaint(
          painter: _MovingScopePainter(
            animation: _controller,
            swarmEpoch: _swarmCycle,
            swarmSeconds: () => ActivityAmbientKineticField.swarmSecondsFor(
              cycle: _swarmCycle.value,
              phase: _controller.value,
            ),
            color: Theme.of(context).colorScheme.primary,
            staticFrame: !_motionAllowed,
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

/// V4 Phase 1: one stationary precision scope contains the living field.
class _MovingScopePainter extends CustomPainter {
  _MovingScopePainter({
    required this.animation,
    required Listenable swarmEpoch,
    required this.swarmSeconds,
    required this.color,
    required this.staticFrame,
  }) : super(repaint: Listenable.merge([animation, swarmEpoch]));
  final Animation<double> animation;
  final double Function() swarmSeconds;
  final Color color;
  final bool staticFrame;
  final Paint _filamentHaloPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..blendMode = BlendMode.plus
    ..maskFilter = const MaskFilter.blur(
      BlurStyle.normal,
      ActivityAmbientKineticField.filamentHaloBlurSigma,
    );
  final Paint _filamentGlowPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..blendMode = BlendMode.plus;
  final Paint _filamentCorePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;

  /// Immutable seeds are built once. Runtime animation advances their flow
  /// coordinates; it never reconstructs a polygon population or restarts a
  /// finite sequence.
  static final List<_LuminousFlowStream> _streams = List.unmodifiable(
    List<_LuminousFlowStream>.generate(
      ActivityAmbientKineticField.luminousStreamCount,
      (index) {
        final radialUnit = (index * .7548776662466927) % 1;
        final seedAngle = (index * 2.399963229728653) % (math.pi * 2);
        final flowGroup =
            (seedAngle /
                    (math.pi * 2) *
                    ActivityAmbientKineticField.luminousFlowRegionCount)
                .floor() %
            ActivityAmbientKineticField.luminousFlowRegionCount;
        return _LuminousFlowStream(
          seedAngle: seedAngle,
          baseRadius: .028 + math.pow(radialUnit, 1.30) * .62,
          phase: index * .618033988749895,
          flowGroup: flowGroup,
          speed: .218 + flowGroup * .0015,
          trailSeconds: 1.72 + (index % 9) * .095,
          depth: .20 + (index % 11) / 14,
          colorIndex: const [0, 1, 2, 3, 4, 4, 3, 1][flowGroup],
        );
      },
      growable: false,
    ),
  );

  double get _t => staticFrame ? .42 : animation.value;

  double get _swarmTime => staticFrame
      ? ActivityAmbientKineticField.cycleSeconds * .42
      : swarmSeconds();

  static ActivitySwarmMetrics swarmMetricsFor(double elapsedSeconds) {
    final positions = [
      for (final stream in _streams)
        _flowPointFor(stream, elapsedSeconds, 0).position,
    ];
    final radii = [for (final position in positions) position.distance];
    final centerPopulation =
        radii.where((radius) => radius < .30).length / positions.length;
    final meanRadius =
        radii.reduce((sum, radius) => sum + radius) / positions.length;
    final radialSpread = math.sqrt(
      radii
              .map((radius) => math.pow(radius - meanRadius, 2))
              .reduce((sum, value) => sum + value) /
          positions.length,
    );
    // A deterministic sample catches a frozen or globally rigid arrangement
    // without retaining any per-frame instrumentation in release builds.
    var neighborSignature = 0.0;
    for (var index = 0; index < positions.length; index++) {
      neighborSignature +=
          (positions[index] - positions[(index + 37) % positions.length])
              .distance;
    }
    return ActivitySwarmMetrics(
      centerPopulation: centerPopulation,
      meanRadius: meanRadius,
      radialSpread: radialSpread,
      neighborSignature: neighborSignature / positions.length,
    );
  }

  static ActivityMultiDirectionalFlowMetrics multiDirectionalFlowMetricsFor(
    double elapsedSeconds,
  ) {
    var outerClockwiseAlignment = 0.0;
    var outerCount = 0;
    var centralCounterclockwiseAlignment = 0.0;
    var centralCount = 0;
    var centerPopulation = 0;
    var outwardExchange = 0;
    var inwardExchange = 0;
    var neighboringDirectionCoherence = 0.0;
    var neighboringSamples = 0;
    final regionalLanes = <int, List<_FilamentFlowPosition>>{};
    for (final stream in _streams) {
      final point = _flowPointFor(stream, elapsedSeconds, 0);
      final radialLane = (stream.baseRadius / .22).floor().clamp(0, 2).toInt();
      regionalLanes
          .putIfAbsent(stream.flowGroup * 3 + radialLane, () => [])
          .add(point);
      final radius = point.position.distance;
      final radialAngle = math.atan2(point.position.dy, point.position.dx);
      final alignment = math.sin(point.tangent - radialAngle);
      if (radius > .40) {
        outerClockwiseAlignment += alignment;
        outerCount++;
      }
      if (radius < .24) {
        centralCounterclockwiseAlignment -= alignment;
        centralCount++;
      }
      if (radius < .28) centerPopulation++;
      final previousRadius = _flowPointFor(
        stream,
        elapsedSeconds - .35,
        0,
      ).position.distance;
      if (radius - previousRadius > .002) outwardExchange++;
      if (radius - previousRadius < -.002) inwardExchange++;
    }
    for (final lane in regionalLanes.values) {
      for (var index = 0; index < lane.length - 1; index++) {
        final current = lane[index];
        final next = lane[index + 1];
        neighboringDirectionCoherence += math.cos(
          current.tangent - next.tangent,
        );
        neighboringSamples++;
      }
    }
    return ActivityMultiDirectionalFlowMetrics(
      outerClockwiseAlignment: outerClockwiseAlignment / outerCount,
      centralCounterclockwiseAlignment:
          centralCounterclockwiseAlignment / centralCount,
      centerPopulation: centerPopulation / _streams.length,
      outwardExchange: outwardExchange / _streams.length,
      inwardExchange: inwardExchange / _streams.length,
      neighboringDirectionCoherence:
          neighboringDirectionCoherence / neighboringSamples,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final geometry = ActivityAmbientKineticField.scopeGeometryFor(
      painterSize: size,
      phase: _t,
    );
    assert(() {
      ActivityAmbientKineticField.debugLastPaintGeometry = geometry;
      return true;
    }());
    _field(canvas, size, geometry.center, geometry.radius);
    _scope(canvas, geometry.center, geometry.radius);
  }

  void _field(Canvas canvas, Size size, Offset center, double radius) {
    final faint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = .55
      ..color = color.withValues(alpha: .025);
    final revealed = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = .75
      ..color = color.withValues(alpha: .15);
    for (var y = 32.0; y < size.height; y += 52) {
      for (var x = 8.0; x < size.width; x += 42) {
        final distance = (Offset(x, y) - center).distance;
        final reveal = (1 - ((distance - radius * .72) / (radius * .55))).clamp(
          0.0,
          1.0,
        );
        canvas.drawLine(
          Offset(x, y),
          Offset(x + 15, y),
          reveal > .01
              ? (revealed
                  ..color = color.withValues(alpha: .025 + .125 * reveal))
              : faint,
        );
      }
    }
    for (var i = 0; i < 9; i++) {
      final p = Offset(
        size.width * ((i * .137 + .08) % 1),
        size.height * ((i * .191 + .12) % 1),
      );
      canvas.drawCircle(
        p,
        2,
        (p - center).distance < radius ? revealed : faint,
      );
    }
  }

  void _scope(Canvas canvas, Offset c, double r) {
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = color.withValues(alpha: .26);
    final hi = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.35
      ..color = Colors.cyanAccent.withValues(alpha: .42);
    // The outer instrument remains cyan; its arcs and ticks are deliberately
    // distinct from the multicolor filament swarm inside it.
    for (final (index, factor) in [.66, 1.0].indexed) {
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r * factor),
        _t * 6.283185307179586 * (index == 1 ? -1.7 : 1.15 + index),
        3.3 + index * .58,
        false,
        base,
      );
    }
    for (var i = 0; i < 36; i++) {
      final a = i * 6.283 / 36;
      final outer = c + Offset.fromDirection(a, r);
      final inner = c + Offset.fromDirection(a, r - (i % 3 == 0 ? 10 : 5));
      canvas.drawLine(inner, outer, i % 7 == 0 ? hi : base);
    }
    final sweep = _t * 6.283 * 1.7;
    canvas.drawLine(c, c + Offset.fromDirection(sweep, r * .92), hi);
    canvas.drawLine(c + Offset(-r * .18, 0), c + Offset(r * .18, 0), base);
    canvas.drawLine(c + Offset(0, -r * .18), c + Offset(0, r * .18), base);
    _flow(canvas, c, r);
  }

  void _flow(Canvas canvas, Offset center, double radius) {
    const palette = <Color>[
      Colors.cyanAccent,
      Color(0xff4aa3ff),
      Color(0xff9b6dff),
      Color(0xffff64bd),
      Color(0xffff9ad9),
    ];
    final time = _swarmTime;
    for (final stream in _streams) {
      final path = _flowPath(stream, time, center, radius);
      final shimmer = .5 + .5 * math.sin(time * .83 + stream.phase);
      final head = _flowPointFor(stream, time, 0).position;
      final headAngle = math.atan2(head.dy, head.dx);
      final regionalFocus =
          .58 +
          .42 *
              (.5 +
                  .5 *
                      math.cos(
                        headAngle - time * .12 - stream.flowGroup * .31,
                      ));
      final color = palette[stream.colorIndex % palette.length];
      // A three-scale profile softens the hard strand boundary without
      // blurring the HUD or the rest of the Activity page. The halo and glow
      // accumulate only where moving filament paths overlap.
      _filamentHaloPaint
        ..strokeWidth =
            ActivityAmbientKineticField.filamentHaloBaseWidth +
            stream.depth * ActivityAmbientKineticField.filamentHaloDepthWidth
        ..color = color.withValues(
          alpha: (.006 + shimmer * .014) * regionalFocus,
        );
      _filamentGlowPaint
        ..strokeWidth = 1.34 + stream.depth * .68
        ..color = color.withValues(
          alpha: (.018 + shimmer * .030) * regionalFocus,
        );
      _filamentCorePaint
        ..strokeWidth =
            ActivityAmbientKineticField.filamentCoreBaseWidth +
            stream.depth * ActivityAmbientKineticField.filamentCoreDepthWidth
        ..color = color.withValues(
          alpha: (.075 + shimmer * .105) * regionalFocus,
        );
      canvas.drawPath(path, _filamentHaloPaint);
      canvas.drawPath(path, _filamentGlowPaint);
      canvas.drawPath(path, _filamentCorePaint);
    }
  }

  /// A long-lived point in one continuous orbital flow field. Its outer
  /// component advances clockwise, its central component counterclockwise,
  /// and an evolving radial term moves streams between both tendencies.
  static _FilamentFlowPosition _flowPointFor(
    _LuminousFlowStream stream,
    double time,
    double trailOffset,
  ) {
    final localTime = time - trailOffset;
    final regionPhase = stream.flowGroup * math.pi * 2 / 8;
    final radialSeed = .018 + stream.baseRadius * 1.10;
    final centralAffinity = math.exp(-math.pow(radialSeed / .25, 2));
    final orbitalDirection = 1 - centralAffinity * 2;
    final sharedOrbitalAdvance =
        orbitalDirection *
        (localTime * (.15 + stream.speed * .56) +
            math.sin(localTime * .071) * .11 +
            math.sin(localTime * .017 + .9) * .05);
    final regionalOrbitalTurn =
        orbitalDirection *
        (math.sin(localTime * .067 + regionPhase) * .048 +
            math.sin(localTime * .023 + regionPhase * 1.7) * .021);
    final fineOrbitalTurn =
        orbitalDirection *
        math.sin(
          stream.seedAngle * 3.0 + localTime * .081 + stream.phase * .07,
        );
    final angle =
        stream.seedAngle +
        sharedOrbitalAdvance +
        regionalOrbitalTurn +
        fineOrbitalTurn * .020;
    final breath =
        .95 +
        math.sin(localTime * .067) * .065 +
        math.sin(localTime * .021 + 1.8) * .035;
    final exchangePhase =
        localTime * .109 + regionPhase * .73 + stream.phase * .037;
    final radialExchange =
        math.sin(exchangePhase) * (.024 + (1 - centralAffinity) * .030);
    final regionalRadialShift =
        math.sin(localTime * .057 + regionPhase) * .021 +
        math.sin(localTime * .029 + regionPhase * 1.9) * .011;
    final fineRadial = math.sin(localTime * .087 + stream.phase * .23) * .011;
    final radial =
        (radialSeed * breath +
                radialExchange +
                regionalRadialShift +
                fineRadial)
            .clamp(.012, .75);
    final position = Offset.fromDirection(angle, radial);
    final radialVelocity =
        math.cos(exchangePhase) * (.024 + (1 - centralAffinity) * .030) * .109;
    final tangent =
        angle +
        math.atan2(orbitalDirection * .22, radialVelocity) +
        math.sin(angle * 4.0 + localTime * .041 + regionPhase) * .035;
    return _FilamentFlowPosition(position: position, tangent: tangent);
  }

  static Path _flowPath(
    _LuminousFlowStream stream,
    double time,
    Offset center,
    double radius,
  ) {
    final path = Path();
    const samples = ActivityAmbientKineticField.luminousStreamSamples;
    Offset? previous;
    for (var index = 0; index <= samples; index++) {
      final trailOffset = stream.trailSeconds * index / samples;
      final point = _flowPointFor(stream, time, trailOffset).position;
      final absolute = center + point * radius;
      if (index == 0) {
        path.moveTo(absolute.dx, absolute.dy);
      } else if (index == 1) {
        path.lineTo(absolute.dx, absolute.dy);
      } else {
        // The midpoint curve rounds a moving corner as its leading section
        // arrives first and the tail follows, rather than rotating a rigid
        // polygonal stroke.
        final midpoint = Offset.lerp(previous!, absolute, .5)!;
        path.quadraticBezierTo(
          previous.dx,
          previous.dy,
          midpoint.dx,
          midpoint.dy,
        );
      }
      previous = absolute;
    }
    return path;
  }

  @override
  bool shouldRepaint(covariant _MovingScopePainter old) =>
      old.color != color || old.staticFrame != staticFrame;
}

@immutable
class _LuminousFlowStream {
  const _LuminousFlowStream({
    required this.seedAngle,
    required this.baseRadius,
    required this.phase,
    required this.flowGroup,
    required this.speed,
    required this.trailSeconds,
    required this.depth,
    required this.colorIndex,
  });

  final double seedAngle;
  final double baseRadius;
  final double phase;
  final int flowGroup;
  final double speed;
  final double trailSeconds;
  final double depth;
  final int colorIndex;
}

@immutable
class _FilamentFlowPosition {
  const _FilamentFlowPosition({required this.position, required this.tangent});

  final Offset position;
  final double tangent;
}

@immutable
class ActivitySwarmMetrics {
  const ActivitySwarmMetrics({
    required this.centerPopulation,
    required this.meanRadius,
    required this.radialSpread,
    required this.neighborSignature,
  });

  /// Proportion of agents within the central 30% of the swarm radius.
  final double centerPopulation;

  /// Mean normalized distance from the stationary swarm center.
  final double meanRadius;

  /// A non-zero spread distinguishes a populated mass from a thin ring.
  final double radialSpread;

  /// Deterministic sampled neighbor-distance metric. Its change over time
  /// demonstrates that agents redistribute rather than rotate rigidly.
  final double neighborSignature;
}

@immutable
class ActivityMultiDirectionalFlowMetrics {
  const ActivityMultiDirectionalFlowMetrics({
    required this.outerClockwiseAlignment,
    required this.centralCounterclockwiseAlignment,
    required this.centerPopulation,
    required this.outwardExchange,
    required this.inwardExchange,
    required this.neighboringDirectionCoherence,
  });

  /// Mean clockwise tangential alignment outside the central field.
  final double outerClockwiseAlignment;

  /// Mean counterclockwise tangential alignment in the populated center.
  final double centralCounterclockwiseAlignment;

  /// Proportion of actual moving stream heads in the central 28% radius.
  final double centerPopulation;

  /// Proportions moving outward and inward over the local sample interval.
  final double outwardExchange;
  final double inwardExchange;

  /// Directional agreement among streams close enough to share local flow.
  final double neighboringDirectionCoherence;
}

class _KineticMeasurementPainter extends CustomPainter {
  const _KineticMeasurementPainter({
    required this.animation,
    required this.color,
    required this.staticFrame,
  }) : super(repaint: animation);

  final Animation<double> animation;
  final Color color;
  final bool staticFrame;

  static const _anchors = <Offset>[
    Offset(.18, .15),
    Offset(.76, .23),
    Offset(.30, .49),
    Offset(.72, .61),
    Offset(.46, .85),
    Offset(.10, .72),
    Offset(.89, .43),
  ];

  double get _elapsedSeconds => staticFrame
      ? ActivityAmbientKineticField.cycleSeconds * .68
      : animation.value * ActivityAmbientKineticField.cycleSeconds;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    _paintTrackingField(canvas, size);
    for (
      var region = 0;
      region < ActivityAmbientKineticField.trackingRegionCount;
      region++
    ) {
      _paintRegion(canvas, size, region);
    }
  }

  void _paintTrackingField(Canvas canvas, Size size) {
    final guide = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = .55
      ..color = color.withValues(alpha: .035);
    // Calibrated reference bands cover the full viewport without becoming a
    // wallpaper grid. Their interrupted marks establish an instrument field.
    for (var y = 42.0; y < size.height; y += 74) {
      for (var x = 12.0; x < size.width; x += 58) {
        canvas.drawLine(
          Offset(x, y),
          Offset((x + 18).clamp(0, size.width).toDouble(), y),
          guide,
        );
      }
    }
    for (var x = 28.0; x < size.width; x += 92) {
      canvas.drawLine(Offset(x, 0), Offset(x, 13), guide);
      canvas.drawLine(
        Offset(x, size.height - 13),
        Offset(x, size.height),
        guide,
      );
    }
  }

  void _paintRegion(Canvas canvas, Size size, int region) {
    final sample = ActivityAmbientKineticField.sampleFor(
      region: region,
      elapsedSeconds: _elapsedSeconds,
    );
    final geometry = _RegionGeometry.fromSize(size, region, _anchors[region]);
    final target = geometry.pointAt(sample.pathProgress);
    _paintGuide(canvas, geometry);
    _paintHistory(canvas, geometry, sample.pathProgress);
    _paintRing(canvas, target, geometry.radius, sample.ringResponse);
    _paintTarget(canvas, target, sample.phase);
    _paintSignal(canvas, geometry, sample.signalProgress);
    _paintAccumulation(canvas, geometry, region, sample.accumulationProgress);
  }

  void _paintGuide(Canvas canvas, _RegionGeometry geometry) {
    final guide = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = .65
      ..color = color.withValues(alpha: .055);
    canvas.drawPath(geometry.pathSegment(0, 1), guide);
    for (final progress in const [.2, .4, .6, .8]) {
      canvas.drawCircle(geometry.pointAt(progress), 1.15, guide);
    }
  }

  void _paintHistory(Canvas canvas, _RegionGeometry geometry, double progress) {
    if (progress <= 0) return;
    const segments = 11;
    final start = (progress - .42).clamp(0.0, 1.0);
    for (var index = 0; index < segments; index++) {
      final from = start + (progress - start) * index / segments;
      final to = start + (progress - start) * (index + 1) / segments;
      final age = (index + 1) / segments;
      canvas.drawPath(
        geometry.pathSegment(from, to),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = .8 + age * .7
          ..strokeCap = StrokeCap.round
          ..color = color.withValues(alpha: .025 + age * .18),
      );
    }
  }

  void _paintRing(
    Canvas canvas,
    Offset target,
    double radius,
    double response,
  ) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = .75 + response * .85
      ..color = color.withValues(alpha: .055 + response * .22);
    final ringRadius = radius * (.34 + response * .22);
    canvas.drawArc(
      Rect.fromCircle(center: target, radius: ringRadius),
      -.8,
      2.15 + response * .85,
      false,
      paint,
    );
    canvas.drawArc(
      Rect.fromCircle(center: target, radius: ringRadius * .72),
      2,
      .9 + response * .55,
      false,
      paint,
    );
  }

  void _paintTarget(Canvas canvas, Offset target, ActivityKineticPhase phase) {
    final active =
        phase == ActivityKineticPhase.track ||
        phase == ActivityKineticPhase.measure;
    canvas.drawCircle(
      target,
      active ? 2.7 : 2.05,
      Paint()..color = color.withValues(alpha: active ? .74 : .44),
    );
    final reticle = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = .75
      ..color = color.withValues(alpha: active ? .48 : .22);
    canvas.drawLine(
      target + const Offset(-6, 0),
      target + const Offset(-3, 0),
      reticle,
    );
    canvas.drawLine(
      target + const Offset(3, 0),
      target + const Offset(6, 0),
      reticle,
    );
    canvas.drawLine(
      target + const Offset(0, -6),
      target + const Offset(0, -3),
      reticle,
    );
    canvas.drawLine(
      target + const Offset(0, 3),
      target + const Offset(0, 6),
      reticle,
    );
  }

  void _paintSignal(Canvas canvas, _RegionGeometry geometry, double progress) {
    if (progress <= 0) return;
    canvas.drawLine(
      geometry.measurementPoint,
      geometry.accumulator,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = .75
        ..color = color.withValues(alpha: .06 + progress * .14),
    );
    final pulse = Offset.lerp(
      geometry.measurementPoint,
      geometry.accumulator,
      progress,
    )!;
    canvas.drawCircle(
      pulse,
      1.4 + progress * .9,
      Paint()
        ..color = Colors.cyanAccent.withValues(alpha: .22 + progress * .32),
    );
  }

  void _paintAccumulation(
    Canvas canvas,
    _RegionGeometry geometry,
    int region,
    double progress,
  ) {
    const totalTicks = 6;
    final completedCycles =
        (_elapsedSeconds / ActivityAmbientKineticField.cycleSeconds).floor();
    final stored = (completedCycles + region) % totalTicks;
    final current = progress > 0
        ? (progress * totalTicks).ceil().clamp(0, totalTicks)
        : 0;
    for (var tick = 0; tick < totalTicks; tick++) {
      final filled = tick < stored || tick < current;
      final x = geometry.accumulator.dx + (tick - (totalTicks - 1) / 2) * 4.2;
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset(x, geometry.accumulator.dy),
          width: 2,
          height: 5,
        ),
        Paint()..color = color.withValues(alpha: filled ? .34 : .075),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _KineticMeasurementPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.staticFrame != staticFrame;
}

class _RegionGeometry {
  const _RegionGeometry({
    required this.origin,
    required this.radius,
    required this.controlA,
    required this.controlB,
    required this.destination,
    required this.accumulator,
  });

  factory _RegionGeometry.fromSize(Size size, int region, Offset anchor) {
    final radius = 30.0 + (region % 3) * 9;
    final origin = Offset(size.width * anchor.dx, size.height * anchor.dy);
    final direction = region.isEven ? 1.0 : -1.0;
    final destination =
        origin + Offset(radius * direction * 1.55, radius * .54);
    return _RegionGeometry(
      origin: origin,
      radius: radius,
      controlA: origin + Offset(radius * direction * .36, -radius * .88),
      controlB: origin + Offset(radius * direction * 1.16, radius * 1.1),
      destination: destination,
      accumulator: destination + Offset(radius * direction * .42, radius * .48),
    );
  }

  final Offset origin;
  final double radius;
  final Offset controlA;
  final Offset controlB;
  final Offset destination;
  final Offset accumulator;
  Offset get measurementPoint => destination;

  Offset pointAt(double progress) {
    final t = progress.clamp(0.0, 1.0);
    final inverse = 1 - t;
    return origin * (inverse * inverse * inverse) +
        controlA * (3 * inverse * inverse * t) +
        controlB * (3 * inverse * t * t) +
        destination * (t * t * t);
  }

  Path pathSegment(double from, double to) {
    const pieces = 14;
    final path = Path()..moveTo(pointAt(from).dx, pointAt(from).dy);
    for (var piece = 1; piece <= pieces; piece++) {
      final point = pointAt(from + (to - from) * piece / pieces);
      path.lineTo(point.dx, point.dy);
    }
    return path;
  }
}
