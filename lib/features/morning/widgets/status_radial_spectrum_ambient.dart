import 'dart:math' as math;

import 'package:flutter/material.dart';

/// STATUS-only native ambient: a deterministic radial spectrum behind the
/// existing form. It is visual-only and deliberately has no audio input.
class StatusRadialSpectrumAmbient extends StatefulWidget {
  const StatusRadialSpectrumAmbient({
    super.key,
    required this.enabled,
    required this.reducedMotion,
  });

  static const fieldKey = ValueKey('status-radial-spectrum-ambient');
  static const barCount = 144;
  static const bubbleCount = 64;
  static const cycleDuration = Duration(seconds: 13);

  final bool enabled;
  final bool reducedMotion;

  @override
  State<StatusRadialSpectrumAmbient> createState() =>
      _StatusRadialSpectrumAmbientState();
}

class _StatusRadialSpectrumAmbientState
    extends State<StatusRadialSpectrumAmbient>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: StatusRadialSpectrumAmbient.cycleDuration,
  );
  var _tickerEnabled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final tickerEnabled = TickerMode.valuesOf(context).enabled;
    if (_tickerEnabled != tickerEnabled) {
      _tickerEnabled = tickerEnabled;
      _syncAnimation();
    }
  }

  @override
  void didUpdateWidget(covariant StatusRadialSpectrumAmbient oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled != widget.enabled ||
        oldWidget.reducedMotion != widget.reducedMotion) {
      _syncAnimation();
    }
  }

  void _syncAnimation() {
    if (!mounted) return;
    if (widget.enabled && !widget.reducedMotion && _tickerEnabled) {
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
        key: StatusRadialSpectrumAmbient.fieldKey,
        child: CustomPaint(
          painter: _StatusRadialSpectrumPainter(
            animation: _controller,
            staticFrame: widget.reducedMotion || !_tickerEnabled,
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _StatusRadialSpectrumPainter extends CustomPainter {
  _StatusRadialSpectrumPainter({
    required this.animation,
    required this.staticFrame,
  }) : super(repaint: animation);

  final Animation<double> animation;
  final bool staticFrame;

  static const _palette = <Color>[
    Color(0xFF5DECF2),
    Color(0xFF4EABFF),
    Color(0xFF9B78FF),
    Color(0xFFE36AC6),
  ];
  static const _donutPalette = <Color>[
    Color(0xFFFFC96D),
    Color(0xFF6FE5B8),
    Color(0xFF5DECF2),
    Color(0xFF4EABFF),
    Color(0xFF9B78FF),
    Color(0xFFE36AC6),
    Color(0xFFFFC96D),
  ];

  double get _time => staticFrame ? .39 : animation.value;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final center = Offset(size.width / 2, size.height * .46);
    final shortest = size.shortestSide;
    final donutOuterRadius = (shortest * .185).clamp(48.0, 96.0);
    final donutThickness = (shortest * .045).clamp(12.0, 20.0);
    final coreRadius = donutOuterRadius - donutThickness;
    final maxLength = (shortest * .105).clamp(22.0, 60.0);
    final time = _time * math.pi * 2;

    final core = Paint()..color = const Color(0xEE03060D);
    _paintBubbles(canvas, size, center, shortest, time);
    _paintDonut(canvas, center, donutOuterRadius, donutThickness, time);
    canvas.drawCircle(center, coreRadius, core);

    final broadHalo = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 4.2);
    final nearHalo = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 1.6);
    final corePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (var index = 0; index < StatusRadialSpectrumAmbient.barCount; index++) {
      final angle = math.pi * 2 * index / StatusRadialSpectrumAmbient.barCount;
      final amplitude = _amplitude(index, angle, time);
      final length = 5 + maxLength * amplitude;
      final start = center + Offset.fromDirection(angle, donutOuterRadius + 4);
      final end =
          center + Offset.fromDirection(angle, donutOuterRadius + 4 + length);
      final color = _colorFor(angle, time, index);

      broadHalo
        ..strokeWidth = 1.25 + amplitude * 1.65
        ..color = color.withValues(alpha: .010 + amplitude * .030);
      nearHalo
        ..strokeWidth = .55 + amplitude * .68
        ..color = color.withValues(alpha: .030 + amplitude * .070);
      corePaint
        ..strokeWidth = .20 + amplitude * .32
        ..color = color.withValues(alpha: .18 + amplitude * .38);
      canvas
        ..drawLine(start, end, broadHalo)
        ..drawLine(start, end, nearHalo)
        ..drawLine(start, end, corePaint);
    }
  }

  /// V22's bubbles are independent of the spectrum envelopes: each starts
  /// faint near the donut, drifts outward slowly, and has fully dissolved
  /// before it wraps to a new inner position. That prevents radial trails or
  /// a visible position reset at the loop boundary.
  void _paintBubbles(
    Canvas canvas,
    Size size,
    Offset center,
    double shortest,
    double time,
  ) {
    final halo = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.2);
    final nearHalo = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.1);
    final core = Paint();

    for (
      var index = 0;
      index < StatusRadialSpectrumAmbient.bubbleCount;
      index++
    ) {
      final speed = .26 + _noise(index, 1) * .24;
      final progress = (time / (math.pi * 2) * speed + _noise(index, 2)) % 1;
      final appear = _smoothStep(.02, .16, progress);
      final dissolve = 1 - _smoothStep(.68, .98, progress);
      final alpha = appear * dissolve;
      if (alpha < .01) continue;

      final baseAngle = _noise(index, 3) * math.pi * 2;
      final angle = baseAngle + math.sin(time * .31 + index * .73) * .18;
      final origin = shortest * (.18 + _noise(index, 4) * .20);
      final radius =
          origin + shortest * (.44 + _noise(index, 5) * .22) * progress;
      final point = center + Offset.fromDirection(angle, radius);
      // Let edge-bound bubbles dissolve naturally rather than clipping into
      // a line at a particular viewport boundary.
      final edgeDistance = math.min(
        math.min(point.dx, size.width - point.dx),
        math.min(point.dy, size.height - point.dy),
      );
      final edgeFade = _smoothStep(0, shortest * .095, edgeDistance);
      final visibility = alpha * edgeFade;
      if (visibility < .01) continue;

      final color = _colorFor(angle, time * .34, index);
      final radiusPx =
          .8 +
          shortest *
              (.0015 + _noise(index, 6) * .0035) *
              (.72 + .28 * math.sin(progress * math.pi));
      halo.color = color.withValues(alpha: visibility * .035);
      nearHalo.color = color.withValues(alpha: visibility * .12);
      core.color = color.withValues(alpha: visibility * .42);
      canvas
        ..drawCircle(point, radiusPx * 2.5, halo)
        ..drawCircle(point, radiusPx * 1.35, nearHalo)
        ..drawCircle(point, radiusPx, core);
    }
  }

  void _paintDonut(
    Canvas canvas,
    Offset center,
    double outerRadius,
    double thickness,
    double time,
  ) {
    final oval = Rect.fromCircle(
      center: center,
      radius: outerRadius - thickness / 2,
    );
    final shader = SweepGradient(
      colors: _donutPalette,
      transform: GradientRotation(time * .035),
    ).createShader(oval);
    final broadHalo = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, thickness * 1.1)
      ..shader = shader
      ..strokeWidth = thickness * 1.7;
    final nearHalo = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, thickness * .34)
      ..shader = shader
      ..strokeWidth = thickness * 1.12;
    final core = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..shader = shader
      ..strokeWidth = thickness * .62;
    canvas
      ..drawCircle(center, outerRadius - thickness / 2, broadHalo)
      ..drawCircle(center, outerRadius - thickness / 2, nearHalo)
      ..drawCircle(center, outerRadius - thickness / 2, core);
  }

  double _smoothStep(double lower, double upper, double value) {
    final t = ((value - lower) / (upper - lower)).clamp(0.0, 1.0);
    return t * t * (3 - 2 * t);
  }

  double _noise(int index, int salt) {
    var value = index * 73856093 ^ salt * 19349663 ^ 83492791;
    value ^= value >> 13;
    value *= 1274126177;
    return (value & 0x7fffffff) / 0x7fffffff;
  }

  /// Neighboring bars share the traveling envelopes, while their smaller
  /// deterministic offsets keep the spectrum from pulsing mechanically.
  double _amplitude(int index, double angle, double time) {
    final travelingPeak = .5 + .5 * math.sin(angle * 2.0 - time * 1.18);
    final localBand = .5 + .5 * math.sin(angle * 8.0 + time * 2.7 + .48);
    final detail = .5 + .5 * math.sin(index * 1.73 - time * 4.2);
    final attack = math.pow(
      (.04 + .55 * travelingPeak + .24 * localBand + .17 * detail).clamp(
        0.0,
        1.0,
      ),
      .72,
    );
    return attack.toDouble().clamp(.02, 1.0);
  }

  Color _colorFor(double angle, double time, int index) {
    final region = ((angle / (math.pi * 2) + time * .035) * _palette.length)
        .floor();
    final first = _palette[region % _palette.length];
    final second = _palette[(region + 1) % _palette.length];
    final blend = .22 + .24 * math.sin(angle * 3 + time + index * .11);
    return Color.lerp(first, second, blend.clamp(0.0, 1.0))!;
  }

  @override
  bool shouldRepaint(covariant _StatusRadialSpectrumPainter oldDelegate) =>
      oldDelegate.staticFrame != staticFrame ||
      oldDelegate.animation != animation;
}
