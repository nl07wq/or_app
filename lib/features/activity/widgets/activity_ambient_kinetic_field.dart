import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Activity-only kinetic measurement field.
class ActivityAmbientKineticField extends StatefulWidget {
  const ActivityAmbientKineticField({super.key, required this.enabled});

  static const fieldKey = ValueKey('activity-ambient-kinetic-field');
  static const trackingRegionCount = 7;
  static const cycleSeconds = 15.5;
  final bool enabled;

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
    _controller.dispose();
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
            color: Theme.of(context).colorScheme.primary,
            staticFrame: !_motionAllowed,
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

/// V4: one moving precision scope reveals the technical field it scans.
class _MovingScopePainter extends CustomPainter {
  const _MovingScopePainter({
    required this.animation,
    required this.color,
    required this.staticFrame,
  }) : super(repaint: animation);
  final Animation<double> animation;
  final Color color;
  final bool staticFrame;

  double get _t => staticFrame ? .42 : animation.value;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final angle = _t * 6.283185307179586;
    final center = Offset(
      size.width * (.5 + .37 * math.sin(angle)),
      size.height * (.5 + .29 * math.sin(angle * 2 + .72)),
    );
    final radius = (size.shortestSide * .34).clamp(92.0, 168.0);
    _field(canvas, size, center, radius);
    _scope(canvas, center, radius);
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
    for (final (index, factor) in [.42, .66, 1.0].indexed) {
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
  }

  @override
  bool shouldRepaint(covariant _MovingScopePainter old) =>
      old.color != color || old.staticFrame != staticFrame;
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
