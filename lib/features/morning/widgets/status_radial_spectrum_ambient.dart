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

  double get _time => staticFrame ? .39 : animation.value;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final center = Offset(size.width / 2, size.height * .46);
    final shortest = size.shortestSide;
    final coreRadius = (shortest * .205).clamp(54.0, 142.0);
    final maxLength = (shortest * .19).clamp(34.0, 118.0);
    final time = _time * math.pi * 2;

    final coreGlow = Paint()
      ..color = const Color(0xFF101A2B).withValues(alpha: .38)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, coreRadius * .2);
    final core = Paint()..color = const Color(0xEE03060D);
    canvas
      ..drawCircle(center, coreRadius * 1.07, coreGlow)
      ..drawCircle(center, coreRadius, core);

    final broadHalo = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 7);
    final nearHalo = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2.2);
    final corePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (var index = 0; index < StatusRadialSpectrumAmbient.barCount; index++) {
      final angle = math.pi * 2 * index / StatusRadialSpectrumAmbient.barCount;
      final amplitude = _amplitude(index, angle, time);
      final length = 5 + maxLength * amplitude;
      final start = center + Offset.fromDirection(angle, coreRadius + 4);
      final end = center + Offset.fromDirection(angle, coreRadius + 4 + length);
      final color = _colorFor(angle, time, index);

      broadHalo
        ..strokeWidth = 2.5 + amplitude * 4.6
        ..color = color.withValues(alpha: .045 + amplitude * .12);
      nearHalo
        ..strokeWidth = 1.25 + amplitude * 2.1
        ..color = color.withValues(alpha: .11 + amplitude * .25);
      corePaint
        ..strokeWidth = .42 + amplitude * .92
        ..color = color.withValues(alpha: .38 + amplitude * .52);
      canvas
        ..drawLine(start, end, broadHalo)
        ..drawLine(start, end, nearHalo)
        ..drawLine(start, end, corePaint);
    }
  }

  /// Neighboring bars share the traveling envelopes, while their smaller
  /// deterministic offsets keep the spectrum from pulsing mechanically.
  double _amplitude(int index, double angle, double time) {
    final travelingPeak = .5 + .5 * math.sin(angle * 2.0 - time * 1.18);
    final localBand = .5 + .5 * math.sin(angle * 8.0 + time * 2.7 + .48);
    final detail = .5 + .5 * math.sin(index * 1.73 - time * 4.2);
    final attack = math.pow(
      (.18 + .55 * travelingPeak + .23 * localBand + .16 * detail).clamp(
        0.0,
        1.0,
      ),
      .72,
    );
    return attack.toDouble().clamp(.08, 1.0);
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
