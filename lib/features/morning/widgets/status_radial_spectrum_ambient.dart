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
  static const bubbleCount = 96;
  static const cycleDuration = Duration(seconds: 24);
  static const _motionCycleSeconds = 13.0;
  static const equalizerSpeedMultiplier = 1.5;
  static const equalizerAmplitudeMultiplier = 1.3;
  static const amplitudeTargetUpdatesPerSecond = 10;
  static const amplitudeAttack = Duration(milliseconds: 60);
  static const amplitudeRelease = Duration(milliseconds: 140);

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
  _SpectrumLayout? _layout;
  static final _spectrumMotion = _FastSpectrumMotion();

  // These paints are mutable drawing resources, deliberately retained by the
  // painter rather than allocated for every animation frame.
  final _coreFill = Paint()..color = const Color(0xEE03060D);
  final _barBroadHalo = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.2);
  final _barNearHalo = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.6);
  final _barCore = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;
  final _bubbleHalo = Paint()
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.2);
  final _bubbleNearHalo = Paint()
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.1);
  final _bubbleCore = Paint();
  final _donutBroadHalo = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;
  final _donutNearHalo = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;
  final _donutCore = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;

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
    final layout = _layoutFor(size);
    final colorTime = _time * math.pi * 2;
    // Preserve the established physical motion rate while color completes a
    // separate, continuous 24-second revolution.
    final time =
        colorTime * (cycleDuration.inMilliseconds / 1000) / _motionCycleSeconds;
    final spectrumTime =
        time * StatusRadialSpectrumAmbient.equalizerSpeedMultiplier;

    _paintBubbles(canvas, size, layout, time, colorTime);
    _paintDonut(canvas, layout, colorTime);
    canvas.drawCircle(layout.center, layout.coreRadius, _coreFill);

    for (var index = 0; index < StatusRadialSpectrumAmbient.barCount; index++) {
      final angle = layout.angles[index];
      final amplitude = _spectrumMotion.amplitudeFor(index, _time);
      final length =
          5 +
          layout.maxBarLength *
              amplitude *
              StatusRadialSpectrumAmbient.equalizerAmplitudeMultiplier;
      final start = layout.barStarts[index];
      final end = start + layout.barDirections[index] * length;
      final color = _colorFor(angle, colorTime, index);

      _barBroadHalo
        ..strokeWidth = 1.25 + amplitude * 1.65
        ..color = color.withValues(alpha: .010 + amplitude * .030);
      _barNearHalo
        ..strokeWidth = .55 + amplitude * .68
        ..color = color.withValues(alpha: .030 + amplitude * .070);
      _barCore
        ..strokeWidth = .20 + amplitude * .32
        ..color = color.withValues(alpha: .18 + amplitude * .38);
      canvas
        ..drawLine(start, end, _barBroadHalo)
        ..drawLine(start, end, _barNearHalo)
        ..drawLine(start, end, _barCore);
    }
  }

  _SpectrumLayout _layoutFor(Size size) {
    final current = _layout;
    if (current != null && current.size == size) return current;
    final shortest = size.shortestSide;
    final center = Offset(size.width / 2, size.height * .46);
    final donutOuterRadius = (shortest * .185).clamp(48.0, 96.0);
    final donutThickness = (shortest * .045).clamp(12.0, 20.0);
    final angles = List<double>.generate(
      StatusRadialSpectrumAmbient.barCount,
      (index) => math.pi * 2 * index / StatusRadialSpectrumAmbient.barCount,
      growable: false,
    );
    final directions = List<Offset>.generate(
      StatusRadialSpectrumAmbient.barCount,
      (index) => Offset(math.cos(angles[index]), math.sin(angles[index])),
      growable: false,
    );
    return _layout = _SpectrumLayout(
      size: size,
      center: center,
      shortest: shortest,
      donutOuterRadius: donutOuterRadius,
      donutThickness: donutThickness,
      coreRadius: donutOuterRadius - donutThickness,
      maxBarLength: (shortest * .105).clamp(22.0, 60.0),
      donutBroadBlur: MaskFilter.blur(BlurStyle.normal, donutThickness * 1.1),
      donutNearBlur: MaskFilter.blur(BlurStyle.normal, donutThickness * .34),
      angles: angles,
      barDirections: directions,
      barStarts: List<Offset>.generate(
        StatusRadialSpectrumAmbient.barCount,
        (index) => center + directions[index] * (donutOuterRadius + 4),
        growable: false,
      ),
    );
  }

  /// V22's bubbles are independent of the spectrum envelopes: each starts
  /// faint near the donut, drifts outward slowly, and has fully dissolved
  /// before it wraps to a new inner position. That prevents radial trails or
  /// a visible position reset at the loop boundary.
  void _paintBubbles(
    Canvas canvas,
    Size size,
    _SpectrumLayout layout,
    double time,
    double colorTime,
  ) {
    for (
      var index = 0;
      index < StatusRadialSpectrumAmbient.bubbleCount;
      index++
    ) {
      final speed = .26 + _seededNoise(index, 1) * .24;
      final progress =
          (time / (math.pi * 2) * speed + _seededNoise(index, 2)) % 1;
      final appear = _smoothStep(.02, .16, progress);
      final dissolve = 1 - _smoothStep(.68, .98, progress);
      final alpha = appear * dissolve;
      if (alpha < .01) continue;

      final baseAngle = _seededNoise(index, 3) * math.pi * 2;
      final angle = baseAngle + math.sin(time * .31 + index * .73) * .18;
      final origin = layout.shortest * (.18 + _seededNoise(index, 4) * .20);
      final radius =
          origin +
          layout.shortest * (.44 + _seededNoise(index, 5) * .22) * progress;
      final point = layout.center + Offset.fromDirection(angle, radius);
      // Let edge-bound bubbles dissolve naturally rather than clipping into
      // a line at a particular viewport boundary.
      final edgeDistance = math.min(
        math.min(point.dx, size.width - point.dx),
        math.min(point.dy, size.height - point.dy),
      );
      final edgeFade = _smoothStep(0, layout.shortest * .095, edgeDistance);
      final visibility = alpha * edgeFade;
      if (visibility < .01) continue;

      final color = _colorFor(angle, colorTime, index);
      final radiusPx =
          .8 +
          layout.shortest *
              (.0015 + _seededNoise(index, 6) * .0035) *
              (.72 + .28 * math.sin(progress * math.pi));
      _bubbleHalo.color = color.withValues(alpha: visibility * .035);
      _bubbleNearHalo.color = color.withValues(alpha: visibility * .12);
      _bubbleCore.color = color.withValues(alpha: visibility * .42);
      canvas
        ..drawCircle(point, radiusPx * 2.5, _bubbleHalo)
        ..drawCircle(point, radiusPx * 1.35, _bubbleNearHalo)
        ..drawCircle(point, radiusPx, _bubbleCore);
    }
  }

  void _paintDonut(Canvas canvas, _SpectrumLayout layout, double colorTime) {
    final oval = Rect.fromCircle(
      center: layout.center,
      radius: layout.donutOuterRadius - layout.donutThickness / 2,
    );
    final shader = SweepGradient(
      colors: _donutPalette,
      transform: GradientRotation(colorTime),
    ).createShader(oval);
    _donutBroadHalo
      ..maskFilter = layout.donutBroadBlur
      ..shader = shader
      ..strokeWidth = layout.donutThickness * 1.7;
    _donutNearHalo
      ..maskFilter = layout.donutNearBlur
      ..shader = shader
      ..strokeWidth = layout.donutThickness * 1.12;
    _donutCore
      ..shader = shader
      ..strokeWidth = layout.donutThickness * .62;
    canvas
      ..drawCircle(
        layout.center,
        layout.donutOuterRadius - layout.donutThickness / 2,
        _donutBroadHalo,
      )
      ..drawCircle(
        layout.center,
        layout.donutOuterRadius - layout.donutThickness / 2,
        _donutNearHalo,
      )
      ..drawCircle(
        layout.center,
        layout.donutOuterRadius - layout.donutThickness / 2,
        _donutCore,
      );
  }

  double _smoothStep(double lower, double upper, double value) {
    final t = ((value - lower) / (upper - lower)).clamp(0.0, 1.0);
    return t * t * (3 - 2 * t);
  }

  Color _colorFor(double angle, double colorTime, int index) {
    final region =
        ((angle / (math.pi * 2) + colorTime / (math.pi * 2)) * _palette.length)
            .floor();
    final first = _palette[region % _palette.length];
    final second = _palette[(region + 1) % _palette.length];
    final blend = .22 + .24 * math.sin(angle * 3 + colorTime + index * .11);
    return Color.lerp(first, second, blend.clamp(0.0, 1.0))!;
  }

  @override
  bool shouldRepaint(covariant _StatusRadialSpectrumPainter oldDelegate) =>
      oldDelegate.staticFrame != staticFrame ||
      oldDelegate.animation != animation;
}

/// Deterministic audio-spectrum targets. Targets are refreshed at 10 Hz;
/// response is analytic between samples, so bars have a sharp attack and
/// smooth release without per-frame random work or controller state resets.
class _FastSpectrumMotion {
  _FastSpectrumMotion()
    : _targets = List<List<double>>.generate(
        _targetCount,
        (tick) => List<double>.generate(
          StatusRadialSpectrumAmbient.barCount,
          (index) => _targetFor(index, tick),
          growable: false,
        ),
        growable: false,
      ) {
    var state = List<double>.filled(StatusRadialSpectrumAmbient.barCount, .08);
    // Find the periodic steady state before recording it. Consequently the
    // final target flows into the initial target without a controller reset.
    for (var cycle = 0; cycle < 32; cycle++) {
      for (final target in _targets) {
        for (var index = 0; index < state.length; index++) {
          state[index] = _settledValue(state[index], target[index], 1);
        }
      }
    }
    _states = List<List<double>>.generate(_targetCount, (tick) {
      final snapshot = List<double>.of(state, growable: false);
      final target = _targets[tick];
      for (var index = 0; index < state.length; index++) {
        state[index] = _settledValue(state[index], target[index], 1);
      }
      return snapshot;
    }, growable: false);
  }

  static const _updateHz =
      StatusRadialSpectrumAmbient.amplitudeTargetUpdatesPerSecond;
  static const _targetCount = 13 * _updateHz;
  static const _attackSeconds = .060;
  static const _releaseSeconds = .140;

  final List<List<double>> _targets;
  late final List<List<double>> _states;

  double amplitudeFor(int index, double cycleProgress) {
    final tickPosition = cycleProgress * _targetCount;
    final absoluteTick = tickPosition.floor();
    final tick = absoluteTick % _targetCount;
    final progress = tickPosition - absoluteTick;
    return _settledValue(_states[tick][index], _targets[tick][index], progress);
  }

  static double _targetFor(int index, int tick) {
    // Small four-bar neighborhoods share a changing peak, while each bar and
    // its immediate neighbors preserve independent variation. The groups do
    // not travel; new high regions occur at irregular positions each update.
    final neighborhood =
        (_seededNoise(index - 1, tick * 43 + 101) +
            _seededNoise(index, tick * 43 + 101) +
            _seededNoise(index + 1, tick * 43 + 101)) /
        3;
    final localPeak = _seededNoise(index ~/ 4, tick * 71 + 203);
    final independent = _seededNoise(index, tick * 97 + 307);
    final tallPeak = _seededNoise(index ~/ 3, tick * 131 + 401) > .90
        ? .34 + _seededNoise(index, tick * 149 + 503) * .30
        : 0.0;
    return (.025 +
            .29 * math.pow(neighborhood, 1.75) +
            .28 * math.pow(localPeak, 2.15) +
            .18 * math.pow(independent, 2.4) +
            tallPeak)
        .clamp(.02, 1.0)
        .toDouble();
  }

  static double _settledValue(double current, double target, double progress) {
    final seconds = progress / _updateHz;
    final tau = target >= current ? _attackSeconds : _releaseSeconds;
    return target + (current - target) * math.exp(-seconds / tau);
  }
}

double _seededNoise(int index, int salt) {
  var value = index * 73856093 ^ salt * 19349663 ^ 83492791;
  value ^= value >> 13;
  value *= 1274126177;
  return (value & 0x7fffffff) / 0x7fffffff;
}

/// Geometry that is invariant until the ambient viewport changes size.
/// Keeping it in the painter removes per-frame angle and start-position
/// allocation while retaining the exact bar layout.
class _SpectrumLayout {
  const _SpectrumLayout({
    required this.size,
    required this.center,
    required this.shortest,
    required this.donutOuterRadius,
    required this.donutThickness,
    required this.coreRadius,
    required this.maxBarLength,
    required this.donutBroadBlur,
    required this.donutNearBlur,
    required this.angles,
    required this.barDirections,
    required this.barStarts,
  });

  final Size size;
  final Offset center;
  final double shortest;
  final double donutOuterRadius;
  final double donutThickness;
  final double coreRadius;
  final double maxBarLength;
  final MaskFilter donutBroadBlur;
  final MaskFilter donutNearBlur;
  final List<double> angles;
  final List<Offset> barDirections;
  final List<Offset> barStarts;
}
