import 'dart:async';

import 'package:flutter/material.dart';

/// Command Center-only industrial glyph Data Rain.
///
/// A compact, programmatic seven-segment atlas provides recognizable 0–9/A–F
/// glyphs without an external font dependency or per-frame text layout.
class CommandCenterAmbientProcessing extends StatefulWidget {
  const CommandCenterAmbientProcessing({super.key, required this.enabled});

  static const rootKey = ValueKey('command-center-ambient-processing');
  static const foregroundKey = ValueKey('command-center-data-rain-foreground');
  static const midgroundKey = ValueKey('command-center-data-rain-midground');
  static const backgroundKey = ValueKey('command-center-data-rain-background');

  static const foregroundColumnsAt390 = 43;
  static const midgroundColumnsAt390 = 65;
  static const backgroundColumnsAt390 = 63;
  static const totalColumnsAt390 =
      foregroundColumnsAt390 + midgroundColumnsAt390 + backgroundColumnsAt390;

  final bool enabled;

  /// Constant linear movement. A stream never eases between recycle points.
  static double constantSpeedOffset({
    required double elapsed,
    required double pixelsPerSecond,
  }) => elapsed * pixelsPerSecond;

  static const speeds = <DataRainSpeed, double>{
    DataRainSpeed.slow: 12,
    DataRainSpeed.normal: 22,
    DataRainSpeed.fast: 38,
    DataRainSpeed.burst: 60,
  };

  @override
  State<CommandCenterAmbientProcessing> createState() =>
      _CommandCenterAmbientProcessingState();
}

enum DataRainSpeed { slow, normal, fast, burst }

class _CommandCenterAmbientProcessingState
    extends State<CommandCenterAmbientProcessing>
    with SingleTickerProviderStateMixin {
  static const _cycleDuration = Duration(seconds: 8);
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _cycleDuration,
  );
  Timer? _nextCycle;
  var _motionAllowed = false;
  var _running = false;
  var _cycle = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _motionAllowed =
        !(MediaQuery.maybeOf(context)?.disableAnimations ?? false) &&
        TickerMode.valuesOf(context).enabled;
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant CommandCenterAmbientProcessing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled != widget.enabled) _syncAnimation();
  }

  void _syncAnimation() {
    if (!mounted) return;
    _nextCycle?.cancel();
    _controller.stop();
    _running = false;
    if (widget.enabled && _motionAllowed) {
      // Schedule only the first frame; subsequent cycles restart immediately
      // so every independently offset stream remains continuously active.
      _nextCycle = Timer(Duration.zero, _startCycle);
    } else {
      _controller.value = 0;
    }
  }

  void _startCycle() {
    if (!mounted || !widget.enabled || !_motionAllowed) return;
    setState(() => _running = true);
    _controller.forward(from: 0).whenComplete(() {
      if (!mounted || !widget.enabled || !_motionAllowed) return;
      setState(() {
        _cycle++;
      });
      _startCycle();
    });
  }

  @override
  void dispose() {
    _nextCycle?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return const SizedBox.shrink();
    final color = Theme.of(context).colorScheme.primary;
    final completedSeconds = _cycle * _cycleDuration.inMilliseconds / 1000;
    return IgnorePointer(
      child: RepaintBoundary(
        key: CommandCenterAmbientProcessing.rootKey,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _layer(
              CommandCenterAmbientProcessing.backgroundKey,
              _RainLayer.background,
              color,
              completedSeconds,
            ),
            _layer(
              CommandCenterAmbientProcessing.midgroundKey,
              _RainLayer.midground,
              color,
              completedSeconds,
            ),
            _layer(
              CommandCenterAmbientProcessing.foregroundKey,
              _RainLayer.foreground,
              color,
              completedSeconds,
            ),
          ],
        ),
      ),
    );
  }

  Widget _layer(
    Key key,
    _RainLayer layer,
    Color color,
    double completedSeconds,
  ) => CustomPaint(
    key: key,
    painter: _IndustrialDataRainPainter(
      animation: _controller,
      color: color,
      layer: layer,
      staticFrame: !_motionAllowed,
      running: _running,
      completedSeconds: completedSeconds,
    ),
  );
}

enum _RainLayer { foreground, midground, background }

class _IndustrialDataRainPainter extends CustomPainter {
  const _IndustrialDataRainPainter({
    required this.animation,
    required this.color,
    required this.layer,
    required this.staticFrame,
    required this.running,
    required this.completedSeconds,
  }) : super(repaint: animation);

  final Animation<double> animation;
  final Color color;
  final _RainLayer layer;
  final bool staticFrame;
  final bool running;
  final double completedSeconds;

  double get _seconds => staticFrame || !running
      ? completedSeconds
      : completedSeconds + animation.value * 8;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final columns = _columnCount(size.width);
    for (var column = 0; column < columns; column++) {
      _paintColumn(canvas, size, column, columns);
    }
  }

  int _columnCount(double width) => switch (layer) {
    _RainLayer.foreground => (width / 9).round().clamp(32, 48),
    _RainLayer.midground => (width / 6).round().clamp(48, 72),
    _RainLayer.background => (width / 6.2).round().clamp(40, 80),
  };

  void _paintColumn(Canvas canvas, Size size, int index, int count) {
    final spacing = size.width / count;
    final xOffset = ((_hash(index, 17) % 100) / 100 - .5) * spacing * .54;
    final x = (index + .5) * spacing + xOffset;
    final speed = DataRainSpeed.values[_hash(index, 29) % 4];
    final glyphSize = switch (layer) {
      _RainLayer.foreground => 6.4,
      _RainLayer.midground => 4.1,
      _RainLayer.background => 2.2,
    };
    final step =
        glyphSize *
        switch (layer) {
          _RainLayer.foreground => 1.58,
          _RainLayer.midground => 1.72,
          _RainLayer.background => 2.1,
        };
    final length = switch (layer) {
      _RainLayer.foreground => 7 + _hash(index, 41) % 11,
      _RainLayer.midground => 4 + _hash(index, 53) % 8,
      _RainLayer.background => 5 + _hash(index, 61) % 7,
    };
    final trail = length * step;
    final span = size.height + trail;
    final offset = CommandCenterAmbientProcessing.constantSpeedOffset(
      elapsed: _seconds,
      pixelsPerSecond: CommandCenterAmbientProcessing.speeds[speed]!,
    );
    final head =
        (_hash(index, 71) % 1000 / 1000 * span + offset) % span - trail;
    final bright = _brightStrength(index);
    for (var glyph = 0; glyph < length; glyph++) {
      final y = head - glyph * step;
      if (y < -glyphSize || y > size.height + glyphSize) continue;
      final fade = 1 - glyph / length;
      final baseAlpha = switch (layer) {
        _RainLayer.foreground => .09,
        _RainLayer.midground => .045,
        _RainLayer.background => .018,
      };
      final alpha =
          (baseAlpha * fade + (glyph == 0 ? bright * .62 : bright * .12 * fade))
              .clamp(0.0, 1.0);
      if (alpha <= .003) continue;
      final glyphColor = glyph == 0 && bright > .12
          ? Color.lerp(color, Colors.cyanAccent, .35)!
          : color;
      final glyphIndex =
          (_hash(index, 83) + glyph * 11 + (offset / step).floor()) %
          _IndustrialGlyphAtlas.masks.length;
      _paintGlyph(
        canvas,
        Offset(x, y),
        glyphSize,
        glyphIndex,
        glyphColor.withValues(alpha: alpha),
      );
    }
  }

  void _paintGlyph(
    Canvas canvas,
    Offset center,
    double size,
    int glyphIndex,
    Color glyphColor,
  ) {
    if (layer == _RainLayer.background) {
      // Background may use only small broken fragments; it never substitutes
      // for the distinct foreground industrial glyphs.
      final fragment = Rect.fromCenter(
        center: center,
        width: size * .9,
        height: size * .22,
      );
      canvas.drawRect(fragment, Paint()..color = glyphColor);
      return;
    }
    final mask = _IndustrialGlyphAtlas.masks[glyphIndex];
    final halfWidth = size * .38;
    final halfHeight = size * .62;
    final paint = Paint()
      ..color = glyphColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = layer == _RainLayer.foreground ? .9 : .62
      ..strokeCap = StrokeCap.square;
    for (var segment = 0; segment < 7; segment++) {
      if ((mask & (1 << segment)) == 0) continue;
      final (from, to) = _IndustrialGlyphAtlas.segmentEndpoints(
        center,
        halfWidth,
        halfHeight,
        segment,
      );
      canvas.drawLine(from, to, paint);
    }
  }

  double _brightStrength(int index) {
    final interval = 13 + _hash(index, 97) % 19;
    final duration = .55 + (_hash(index, 101) % 8) * .14;
    final phase = (_hash(index, 103) % 1000) / 1000 * interval;
    final local = (_seconds + phase) % interval;
    if (local > duration) return 0;
    final normalized = local / duration;
    if (normalized < .18) return normalized / .18;
    if (normalized > .78) return (1 - normalized) / .22;
    // Background events stay subtle; foreground events remain localized.
    return layer == _RainLayer.foreground
        ? 1
        : layer == _RainLayer.midground
        ? .42
        : .14;
  }

  int _hash(int value, int salt) =>
      (value * salt * 1103515245 + 12345) & 0x7fffffff;

  @override
  bool shouldRepaint(covariant _IndustrialDataRainPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.layer != layer ||
      oldDelegate.staticFrame != staticFrame ||
      oldDelegate.running != running ||
      oldDelegate.completedSeconds != completedSeconds;
}

class _IndustrialGlyphAtlas {
  // 0–9, A–F in seven-segment bit order: top, upper-right, lower-right,
  // bottom, lower-left, upper-left, middle. This produces compact angular,
  // monospaced industrial glyphs rather than font-dependent text.
  static const masks = <int>[
    0x3f,
    0x06,
    0x5b,
    0x4f,
    0x66,
    0x6d,
    0x7d,
    0x07,
    0x7f,
    0x6f,
    0x77,
    0x7c,
    0x39,
    0x5e,
    0x79,
    0x71,
  ];

  static (Offset, Offset) segmentEndpoints(
    Offset center,
    double halfWidth,
    double halfHeight,
    int segment,
  ) => switch (segment) {
    0 => (
      Offset(center.dx - halfWidth, center.dy - halfHeight),
      Offset(center.dx + halfWidth, center.dy - halfHeight),
    ),
    1 => (
      Offset(center.dx + halfWidth, center.dy - halfHeight),
      Offset(center.dx + halfWidth, center.dy),
    ),
    2 => (
      Offset(center.dx + halfWidth, center.dy),
      Offset(center.dx + halfWidth, center.dy + halfHeight),
    ),
    3 => (
      Offset(center.dx - halfWidth, center.dy + halfHeight),
      Offset(center.dx + halfWidth, center.dy + halfHeight),
    ),
    4 => (
      Offset(center.dx - halfWidth, center.dy),
      Offset(center.dx - halfWidth, center.dy + halfHeight),
    ),
    5 => (
      Offset(center.dx - halfWidth, center.dy - halfHeight),
      Offset(center.dx - halfWidth, center.dy),
    ),
    _ => (
      Offset(center.dx - halfWidth, center.dy),
      Offset(center.dx + halfWidth, center.dy),
    ),
  };
}
