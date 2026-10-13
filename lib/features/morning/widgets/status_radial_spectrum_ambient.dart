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
  static const pulseMinimumInterval = Duration(seconds: 3);
  static const pulseMaximumInterval = Duration(seconds: 6);
  static const pulseAttack = Duration(milliseconds: 65);
  static const pulseCompression = Duration(milliseconds: 90);
  static const pulseRecovery = Duration(milliseconds: 180);
  static const pulseDuration = Duration(milliseconds: 335);
  static const pulseMaximumScale = 1.13;
  static const pulseCompressionScale = .97;
  static const pulseMaximumDisplacement = 8.0;
  static const flameSampleCount = 216;

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
  static final _pulseMotion = _StatusPulseMotion();
  static const _flameMotionSpeed = .65 * 1.30;
  static const _flameMotionAmplitude = 1.0 * 1.50;

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
  final _ringBandPath = Path();
  final _ringOuterPath = Path();
  final _hudMarkingPath = Path();
  final _donutCore = Paint()..style = PaintingStyle.fill;
  final _hudMarkingCore = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;
  final _impactFlash = Paint();

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
    final pulse = staticFrame
        ? const _StatusPulseState.rest()
        : _pulseMotion.stateFor(_time);
    // Preserve the established physical motion rate while color completes a
    // separate, continuous 24-second revolution.
    final time =
        colorTime *
        (StatusRadialSpectrumAmbient.cycleDuration.inMilliseconds / 1000) /
        StatusRadialSpectrumAmbient._motionCycleSeconds;

    // Pulse only the ambient field. STATUS controls remain spatially stable,
    // while the donut, indicators, and bubbles get a brief, organic impact.
    final jitter = _pulseMotion.jitterFor(_time) * pulse.impact;
    _paintImpactField(canvas, size, layout, colorTime, pulse.impact);
    canvas.save();
    canvas.translate(
      layout.center.dx + jitter.dx,
      layout.center.dy + jitter.dy,
    );
    canvas.scale(pulse.scale, pulse.scale);
    canvas.translate(-layout.center.dx, -layout.center.dy);
    _paintBubbles(canvas, size, layout, time, colorTime, pulse.impact);
    _paintDonut(canvas, layout, colorTime, time, pulse.impact);
    canvas.drawCircle(layout.center, layout.coreRadius, _coreFill);
    _barBroadHalo.maskFilter = pulse.impact == 0
        ? const MaskFilter.blur(BlurStyle.normal, 4.2)
        : MaskFilter.blur(BlurStyle.normal, 4.2 + pulse.impact * 2.2);

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
        ..color = color.withValues(
          alpha: (.010 + amplitude * .030) * (1 + pulse.impact * .85),
        );
      _barNearHalo
        ..strokeWidth = .55 + amplitude * .68
        ..color = color.withValues(
          alpha: (.030 + amplitude * .070) * (1 + pulse.impact * .45),
        );
      _barCore
        ..strokeWidth = .20 + amplitude * .32
        ..color = color.withValues(alpha: .18 + amplitude * .38);
      canvas
        ..drawLine(start, end, _barBroadHalo)
        ..drawLine(start, end, _barNearHalo)
        ..drawLine(start, end, _barCore);
    }
    canvas.restore();
  }

  void _paintImpactField(
    Canvas canvas,
    Size size,
    _SpectrumLayout layout,
    double colorTime,
    double impact,
  ) {
    if (impact <= 0) return;
    final flashColor = _colorFor(colorTime, colorTime, 0);
    _impactFlash.shader =
        RadialGradient(
          colors: [
            flashColor.withValues(alpha: impact * .21),
            flashColor.withValues(alpha: impact * .070),
            flashColor.withValues(alpha: 0),
          ],
          stops: const [.0, .58, 1],
        ).createShader(
          Rect.fromCircle(
            center: layout.center,
            radius: size.longestSide * 1.08,
          ),
        );
    canvas.drawRect(Offset.zero & size, _impactFlash);
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
    double pulse,
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
      _bubbleHalo.color = color.withValues(
        alpha: visibility * .035 * (1 + pulse * .7),
      );
      _bubbleNearHalo.color = color.withValues(
        alpha: visibility * .12 * (1 + pulse * .35),
      );
      _bubbleCore.color = color.withValues(alpha: visibility * .42);
      canvas
        ..drawCircle(point, radiusPx * 2.5, _bubbleHalo)
        ..drawCircle(point, radiusPx * 1.35, _bubbleNearHalo)
        ..drawCircle(point, radiusPx, _bubbleCore);
    }
  }

  void _paintDonut(
    Canvas canvas,
    _SpectrumLayout layout,
    double colorTime,
    double time,
    double pulse,
  ) {
    final outer = _ringOuterPath..reset();
    final band = _ringBandPath..reset();
    final sampleCount = StatusRadialSpectrumAmbient.flameSampleCount;
    final visibleThickness = layout.donutThickness * .62;
    final nominalOuter = layout.donutOuterRadius - layout.donutThickness * .19;
    _appendDeformedRingContour(outer, layout, time, nominalOuter, sampleCount);
    outer.close();
    _appendDeformedRingContour(band, layout, time, nominalOuter, sampleCount);
    _appendDeformedRingContour(
      band,
      layout,
      time,
      nominalOuter - visibleThickness,
      sampleCount,
      reverse: true,
      deformed: false,
    );
    band.close();
    final oval = Rect.fromCircle(
      center: layout.center,
      radius: layout.donutOuterRadius + 10,
    );
    final shader = SweepGradient(
      colors: _donutPalette,
      transform: GradientRotation(colorTime),
    ).createShader(oval);
    _donutBroadHalo
      ..maskFilter = pulse == 0
          ? MaskFilter.blur(BlurStyle.normal, visibleThickness * .72)
          : MaskFilter.blur(
              BlurStyle.normal,
              visibleThickness * (.72 + pulse * .30),
            )
      ..shader = shader
      ..strokeWidth = visibleThickness * (1.35 + pulse * .18);
    _donutNearHalo
      ..maskFilter = pulse == 0
          ? MaskFilter.blur(BlurStyle.normal, visibleThickness * .22)
          : MaskFilter.blur(
              BlurStyle.normal,
              visibleThickness * (.22 + pulse * .08),
            )
      ..shader = shader
      ..strokeWidth = visibleThickness * (1.05 + pulse * .08);
    _donutCore..shader = shader;
    canvas
      ..drawPath(outer, _donutBroadHalo)
      ..drawPath(outer, _donutNearHalo)
      ..drawPath(band, _donutCore);
    _paintHudRingPattern(canvas, layout, nominalOuter, visibleThickness);
  }

  /// The ring's actual outer edge controls its luminous core and glow. The
  /// inner contour intentionally remains circular to keep the hollow center
  /// stable while the visible outer boundary flows in and out.
  void _appendDeformedRingContour(
    Path path,
    _SpectrumLayout layout,
    double time,
    double radius,
    int sampleCount, {
    bool reverse = false,
    bool deformed = true,
  }) {
    Offset? previous;
    for (var step = 0; step <= sampleCount; step++) {
      final index = reverse ? sampleCount - step : step;
      final angle = math.pi * 2 * index / sampleCount;
      final extension = deformed ? _flameContourExtension(angle, time) : 0.0;
      final point =
          layout.center + Offset.fromDirection(angle, radius + extension);
      if (step == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        final midpoint = Offset(
          (previous!.dx + point.dx) / 2,
          (previous.dy + point.dy) / 2,
        );
        path.quadraticBezierTo(
          previous.dx,
          previous.dy,
          midpoint.dx,
          midpoint.dy,
        );
      }
      previous = point;
    }
  }

  void _paintHudRingPattern(
    Canvas canvas,
    _SpectrumLayout layout,
    double nominalOuter,
    double visibleThickness,
  ) {
    final markings = _hudMarkingPath..reset();
    final innerRadius = nominalOuter - visibleThickness;
    // Continuous background-colored grooves are engraved into the existing
    // rainbow band. Their radii remain safely inside the hollow and outer
    // boundaries, so this does not add separate decorative rings.
    for (var track = 0; track < 3; track++) {
      final grooveRadius = innerRadius + visibleThickness * (.14 + track * .16);
      markings.addOval(
        Rect.fromCircle(center: layout.center, radius: grooveRadius),
      );
    }
    _hudMarkingCore
      ..shader = null
      ..strokeWidth = (layout.donutThickness * .045).clamp(.5, .85)
      // The markings erase narrow sections from the luminous band instead
      // of adding a second color or a separate ornament layer.
      ..color = const Color(0x7003060D)
      ..maskFilter = null;
    canvas.drawPath(markings, _hudMarkingCore);
  }

  double _flameContourExtension(double angle, double time) {
    final broad =
        math.sin(angle * 2 + time * .53 * _flameMotionSpeed + .37) * 3.2 +
        math.sin(angle * 3 - time * .31 * _flameMotionSpeed + 1.83) * 1.85 +
        math.sin(angle * 5 + time * .19 * _flameMotionSpeed + .91) * .95 +
        math.sin(angle * 8 - time * .27 * _flameMotionSpeed + 2.34) * .48;
    return (broad * _flameMotionAmplitude).clamp(-6.9, 6.9);
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

/// Five short, seeded impact moments occur per color cycle. Their start gaps
/// remain between three and six seconds. Each is a fast expansion, a brief
/// compression, then a recovery; only the ambient painter is transformed.
class _StatusPulseMotion {
  static const _cycleSeconds = 24.0;
  static const _attackSeconds = .065;
  static const _compressionSeconds = .090;
  static const _recoverySeconds = .180;
  static const _starts = <double>[3.42, 7.63, 12.76, 17.08, 21.45];

  _StatusPulseState stateFor(double cycleProgress) {
    final seconds = cycleProgress * _cycleSeconds;
    for (var index = 0; index < _starts.length; index++) {
      final localSeconds = seconds - _starts[index];
      if (localSeconds < 0 ||
          localSeconds >=
              _attackSeconds + _compressionSeconds + _recoverySeconds) {
        continue;
      }
      if (localSeconds < _attackSeconds) {
        final progress = _smoothStep(0, _attackSeconds, localSeconds);
        return _StatusPulseState(
          scale: _lerp(
            1,
            StatusRadialSpectrumAmbient.pulseMaximumScale,
            progress,
          ),
          impact: progress,
        );
      }
      if (localSeconds < _attackSeconds + _compressionSeconds) {
        final progress = _smoothStep(
          _attackSeconds,
          _attackSeconds + _compressionSeconds,
          localSeconds,
        );
        return _StatusPulseState(
          scale: _lerp(
            StatusRadialSpectrumAmbient.pulseMaximumScale,
            StatusRadialSpectrumAmbient.pulseCompressionScale,
            progress,
          ),
          impact: 1 - progress * .45,
        );
      }
      final progress = _smoothStep(
        _attackSeconds + _compressionSeconds,
        _attackSeconds + _compressionSeconds + _recoverySeconds,
        localSeconds,
      );
      return _StatusPulseState(
        scale: _lerp(
          StatusRadialSpectrumAmbient.pulseCompressionScale,
          1,
          progress,
        ),
        impact: (1 - progress) * .55,
      );
    }
    return const _StatusPulseState.rest();
  }

  Offset jitterFor(double cycleProgress) {
    final seconds = cycleProgress * _cycleSeconds;
    final direction =
        math.sin(seconds * 31.7 + .4) * 1.4 + math.sin(seconds * 19.3 + 1.7);
    return Offset.fromDirection(
      direction,
      StatusRadialSpectrumAmbient.pulseMaximumDisplacement,
    );
  }

  static double _lerp(double begin, double end, double progress) =>
      begin + (end - begin) * progress;

  static double _smoothStep(double lower, double upper, double value) {
    final t = ((value - lower) / (upper - lower)).clamp(0.0, 1.0);
    return t * t * (3 - 2 * t);
  }
}

class _StatusPulseState {
  const _StatusPulseState({required this.scale, required this.impact});

  const _StatusPulseState.rest() : scale = 1, impact = 0;

  final double scale;
  final double impact;
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
  final List<double> angles;
  final List<Offset> barDirections;
  final List<Offset> barStarts;
}
