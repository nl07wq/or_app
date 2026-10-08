import 'dart:async';

import 'package:flutter/material.dart';

/// Command Center-only industrial glyph Data Rain.
///
/// The painter uses a compact programmatic 5×7 atlas instead of a platform
/// font. Glyph sequences are generated once per stream recycle, then remain
/// fixed while their columns move at a constant speed.
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

  /// The repeating 20-slot library gives exactly 45% letters, 25% numbers,
  /// and 30% technical symbols before its deterministic stream offset.
  static const glyphCategoryPeriod = 20;
  static const letterSlotsPerPeriod = 9;
  static const numberSlotsPerPeriod = 5;
  static const symbolSlotsPerPeriod = 6;

  /// V2.1 dimensions were 90%; V2.1 acceptance uses an actual 80% scale.
  static const glyphScale = .8;
  static const longStreamsPerPeriod = 15;
  static const mediumStreamsPerPeriod = 4;
  static const shortStreamsPerPeriod = 1;

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

  /// Exposed for deterministic regression coverage of the generated library.
  static List<String> glyphSequenceForStream({
    required DataRainLayer layer,
    required int streamIndex,
    required int recycleIndex,
    required int length,
  }) {
    final seed = _streamSeed(layer, streamIndex, recycleIndex);
    return List<String>.generate(
      length,
      (position) => _IndustrialGlyphAtlas.glyphFor(seed, position),
      growable: false,
    );
  }

  static DataRainGlyphCategory glyphCategoryFor(String glyph) {
    if (glyph.codeUnitAt(0) >= 65 && glyph.codeUnitAt(0) <= 90) {
      return DataRainGlyphCategory.letter;
    }
    if (glyph.codeUnitAt(0) >= 48 && glyph.codeUnitAt(0) <= 57) {
      return DataRainGlyphCategory.number;
    }
    return DataRainGlyphCategory.symbol;
  }

  /// Layers deliberately use separate jittered grids, permitting real X-axis
  /// overlap rather than reserving mutually exclusive column slots.
  static double columnXFraction({
    required DataRainLayer layer,
    required int streamIndex,
    required int count,
  }) {
    final slot = (streamIndex + .5) / count;
    final jitter =
        ((_hash(streamIndex, 17 + layer.index * 19) % 1000) / 1000 - .5) *
        1.28 /
        count;
    return (slot + jitter).clamp(.006, .994);
  }

  static DataRainPulseDirection pulseDirectionForStream({
    required DataRainLayer layer,
    required int streamIndex,
  }) => _hash(streamIndex, 107 + layer.index * 13).isEven
      ? DataRainPulseDirection.downward
      : DataRainPulseDirection.upward;

  static DataRainStreamLength streamLengthFor({
    required DataRainLayer layer,
    required int streamIndex,
  }) {
    final slot = (streamIndex * 7 + layer.index * 5) % 20;
    if (slot < longStreamsPerPeriod) return DataRainStreamLength.long;
    if (slot < longStreamsPerPeriod + mediumStreamsPerPeriod) {
      return DataRainStreamLength.medium;
    }
    return DataRainStreamLength.short;
  }

  static int _streamSeed(
    DataRainLayer layer,
    int streamIndex,
    int recycleIndex,
  ) => _hash(streamIndex + recycleIndex * 101, 83 + layer.index * 31);

  static int _hash(int value, int salt) =>
      (value * salt * 1103515245 + 12345) & 0x7fffffff;

  @override
  State<CommandCenterAmbientProcessing> createState() =>
      _CommandCenterAmbientProcessingState();
}

enum DataRainSpeed { slow, normal, fast, burst }

enum DataRainLayer { foreground, midground, background }

enum DataRainGlyphCategory { letter, number, symbol }

enum DataRainPulseDirection { upward, downward }

enum DataRainStreamLength { long, medium, short }

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
      // Preserve the established quiet route-entry window. Once started,
      // cycles join immediately and streams never return to a global idle.
      _nextCycle = Timer(const Duration(milliseconds: 900), _startCycle);
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
              DataRainLayer.background,
              color,
              completedSeconds,
            ),
            _layer(
              CommandCenterAmbientProcessing.midgroundKey,
              DataRainLayer.midground,
              color,
              completedSeconds,
            ),
            _layer(
              CommandCenterAmbientProcessing.foregroundKey,
              DataRainLayer.foreground,
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
    DataRainLayer layer,
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
  final DataRainLayer layer;
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
    for (var streamIndex = 0; streamIndex < columns; streamIndex++) {
      _paintStream(canvas, size, streamIndex, columns);
    }
  }

  int _columnCount(double width) => switch (layer) {
    DataRainLayer.foreground => (width / 9).round().clamp(32, 48),
    DataRainLayer.midground => (width / 6).round().clamp(48, 72),
    DataRainLayer.background => (width / 6.2).round().clamp(40, 80),
  };

  void _paintStream(Canvas canvas, Size size, int streamIndex, int count) {
    final glyphSize =
        switch (layer) {
          DataRainLayer.foreground => 8.0,
          DataRainLayer.midground => 4.8,
          DataRainLayer.background => 2.45,
        } *
        CommandCenterAmbientProcessing.glyphScale;
    final step =
        glyphSize *
        switch (layer) {
          DataRainLayer.foreground => 1.52,
          DataRainLayer.midground => 1.72,
          DataRainLayer.background => 2.06,
        };
    final length = _streamLength(streamIndex, size.height, step);
    final trail = length * step;
    final span = size.height + trail;
    final speed =
        DataRainSpeed.values[_hash(streamIndex, 29 + layer.index * 7) %
            DataRainSpeed.values.length];
    final travel = CommandCenterAmbientProcessing.constantSpeedOffset(
      elapsed: _seconds,
      pixelsPerSecond: CommandCenterAmbientProcessing.speeds[speed]!,
    );
    final initial =
        _hash(streamIndex, 71 + layer.index * 11) % 1000 / 1000 * span;
    final recycleIndex = ((initial + travel) / span).floor();
    final head = (initial + travel) % span - trail;
    final glyphs = CommandCenterAmbientProcessing.glyphSequenceForStream(
      layer: layer,
      streamIndex: streamIndex,
      recycleIndex: recycleIndex,
      length: length,
    );
    final x =
        size.width *
        CommandCenterAmbientProcessing.columnXFraction(
          layer: layer,
          streamIndex: streamIndex,
          count: count,
        );
    for (var glyphPosition = 0; glyphPosition < length; glyphPosition++) {
      final y = head - glyphPosition * step;
      if (y < -glyphSize || y > size.height + glyphSize) continue;
      final pulse = _pulseStrength(streamIndex, glyphPosition, length);
      final baseline = switch (layer) {
        DataRainLayer.foreground => .34,
        DataRainLayer.midground => .19,
        DataRainLayer.background => .065,
      };
      final alpha =
          (baseline +
                  pulse *
                      switch (layer) {
                        DataRainLayer.foreground => .53,
                        DataRainLayer.midground => .35,
                        DataRainLayer.background => .16,
                      })
              .clamp(0.0, 1.0);
      final glyphColor = pulse > .08
          ? Color.lerp(color, Colors.cyanAccent, .48)!
          : color;
      _paintGlyph(
        canvas,
        center: Offset(x, y),
        size: glyphSize,
        glyph: glyphs[glyphPosition],
        color: glyphColor.withValues(alpha: alpha),
      );
    }
  }

  int _streamLength(int streamIndex, double height, double step) {
    final kind = CommandCenterAmbientProcessing.streamLengthFor(
      layer: layer,
      streamIndex: streamIndex,
    );
    final variation = _hash(streamIndex, 191 + layer.index * 23) % 1000 / 1000;
    final fraction = switch (kind) {
      DataRainStreamLength.long => .26 + variation * .18,
      DataRainStreamLength.medium => .12 + variation * .09,
      DataRainStreamLength.short => .055 + variation * .045,
    };
    return (height * fraction / step).round().clamp(4, 42);
  }

  /// A moving pulse follows glyph positions, independently of stream travel.
  /// It may begin in either direction and never draws detached light geometry.
  double _pulseStrength(int streamIndex, int glyphPosition, int length) {
    if (staticFrame) return 0;
    final clustered = _hash(streamIndex, 131 + layer.index * 7) % 5 == 0;
    final pulseKey = clustered ? streamIndex ~/ 3 : streamIndex;
    final interval = 4.4 + (_hash(pulseKey, 137 + layer.index * 17) % 11) * .46;
    final duration =
        .72 + (_hash(streamIndex, 139 + layer.index * 23) % 7) * .15;
    final phase =
        (_hash(pulseKey, 149 + layer.index * 29) % 1000) / 1000 * interval;
    final local = (_seconds + phase) % interval;
    if (local > duration) return 0;
    final direction = CommandCenterAmbientProcessing.pulseDirectionForStream(
      layer: layer,
      streamIndex: streamIndex,
    );
    final pulseLength = 1.4 + (_hash(streamIndex, 151) % 4) * .48;
    final progress = local / duration;
    final position = direction == DataRainPulseDirection.downward
        ? -pulseLength + progress * (length - 1 + pulseLength * 2)
        : length - 1 + pulseLength - progress * (length - 1 + pulseLength * 2);
    final distance = (glyphPosition - position).abs();
    if (distance > pulseLength) return 0;
    return 1 - distance / pulseLength;
  }

  void _paintGlyph(
    Canvas canvas, {
    required Offset center,
    required double size,
    required String glyph,
    required Color color,
  }) {
    final rows = _IndustrialGlyphAtlas.rowsFor(glyph);
    final pixel = size * .15;
    final paint = Paint()..color = color;
    for (var row = 0; row < rows.length; row++) {
      final rowMask = rows[row];
      for (var column = 0; column < 5; column++) {
        if ((rowMask & (1 << (4 - column))) == 0) continue;
        // Background uses deliberately sparse micro-glyph fragments only.
        if (layer == DataRainLayer.background &&
            (row + column + glyph.codeUnitAt(0)) % 3 != 0) {
          continue;
        }
        final x = center.dx + (column - 2) * pixel * 1.45;
        final y = center.dy + (row - 3) * pixel * 1.45;
        canvas.drawRect(
          Rect.fromCenter(center: Offset(x, y), width: pixel, height: pixel),
          paint,
        );
      }
    }
  }

  int _hash(int value, int salt) =>
      CommandCenterAmbientProcessing._hash(value, salt);

  @override
  bool shouldRepaint(covariant _IndustrialDataRainPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.layer != layer ||
      oldDelegate.staticFrame != staticFrame ||
      oldDelegate.running != running ||
      oldDelegate.completedSeconds != completedSeconds;
}

class _IndustrialGlyphAtlas {
  static const _letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  static const _numbers = '0123456789';
  static const _symbols = r'+-/\=:[]<>';

  static String glyphFor(int seed, int position) {
    final slot =
        (seed + position) % CommandCenterAmbientProcessing.glyphCategoryPeriod;
    final source = slot < CommandCenterAmbientProcessing.letterSlotsPerPeriod
        ? _letters
        : slot <
              CommandCenterAmbientProcessing.letterSlotsPerPeriod +
                  CommandCenterAmbientProcessing.numberSlotsPerPeriod
        ? _numbers
        : _symbols;
    final selection = CommandCenterAmbientProcessing._hash(
      seed + position * 37,
      163,
    );
    return source[selection % source.length];
  }

  /// 5×7 monospaced dot-matrix patterns: angular, technical and independent
  /// from device fonts. Each integer supplies one left-to-right five-bit row.
  static const _patterns = <String, List<int>>{
    'A': [14, 17, 17, 31, 17, 17, 17],
    'B': [30, 17, 17, 30, 17, 17, 30],
    'C': [15, 16, 16, 16, 16, 16, 15],
    'D': [30, 17, 17, 17, 17, 17, 30],
    'E': [31, 16, 16, 30, 16, 16, 31],
    'F': [31, 16, 16, 30, 16, 16, 16],
    'G': [15, 16, 16, 23, 17, 17, 15],
    'H': [17, 17, 17, 31, 17, 17, 17],
    'I': [31, 4, 4, 4, 4, 4, 31],
    'J': [7, 2, 2, 2, 18, 18, 12],
    'K': [17, 18, 20, 24, 20, 18, 17],
    'L': [16, 16, 16, 16, 16, 16, 31],
    'M': [17, 27, 21, 21, 17, 17, 17],
    'N': [17, 25, 21, 19, 17, 17, 17],
    'O': [14, 17, 17, 17, 17, 17, 14],
    'P': [30, 17, 17, 30, 16, 16, 16],
    'Q': [14, 17, 17, 17, 21, 18, 13],
    'R': [30, 17, 17, 30, 20, 18, 17],
    'S': [15, 16, 16, 14, 1, 1, 30],
    'T': [31, 4, 4, 4, 4, 4, 4],
    'U': [17, 17, 17, 17, 17, 17, 14],
    'V': [17, 17, 17, 17, 17, 10, 4],
    'W': [17, 17, 17, 21, 21, 27, 17],
    'X': [17, 17, 10, 4, 10, 17, 17],
    'Y': [17, 17, 10, 4, 4, 4, 4],
    'Z': [31, 1, 2, 4, 8, 16, 31],
    '0': [14, 17, 19, 21, 25, 17, 14],
    '1': [4, 12, 4, 4, 4, 4, 14],
    '2': [14, 17, 1, 2, 4, 8, 31],
    '3': [30, 1, 1, 14, 1, 1, 30],
    '4': [2, 6, 10, 18, 31, 2, 2],
    '5': [31, 16, 16, 30, 1, 1, 30],
    '6': [14, 16, 16, 30, 17, 17, 14],
    '7': [31, 1, 2, 4, 8, 8, 8],
    '8': [14, 17, 17, 14, 17, 17, 14],
    '9': [14, 17, 17, 15, 1, 1, 14],
    '+': [0, 4, 4, 31, 4, 4, 0],
    '-': [0, 0, 0, 31, 0, 0, 0],
    '/': [1, 2, 2, 4, 8, 8, 16],
    r'\': [16, 8, 8, 4, 2, 2, 1],
    '=': [0, 31, 0, 31, 0, 0, 0],
    ':': [0, 4, 4, 0, 4, 4, 0],
    '[': [14, 8, 8, 8, 8, 8, 14],
    ']': [14, 2, 2, 2, 2, 2, 14],
    '<': [2, 4, 8, 16, 8, 4, 2],
    '>': [8, 4, 2, 1, 2, 4, 8],
  };

  static List<int> rowsFor(String glyph) => _patterns[glyph]!;
}
