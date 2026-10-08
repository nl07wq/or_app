import 'dart:async';

import 'package:flutter/material.dart';

/// Command Center-only continuous data processing ambience.
///
/// The renderer deliberately avoids characters, code, and Matrix styling. It
/// uses bounded blue/cyan vertical signal traces to imply asynchronous data
/// movement behind the operational glass surfaces.
class CommandCenterAmbientProcessing extends StatefulWidget {
  const CommandCenterAmbientProcessing({super.key, required this.enabled});

  static const rootKey = ValueKey('command-center-ambient-processing');
  static const dataRainKey = ValueKey('command-center-data-rain');
  static const streamCount = 48;

  final bool enabled;

  /// Linear distance for every stream: no easing or speed change exists
  /// between recycling points.
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
      // The delayed start keeps route transitions quiet, then 80 ms handoffs
      // preserve continuous motion without a permanently active page ticker.
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
        _running = false;
        _cycle++;
      });
      _nextCycle = Timer(const Duration(milliseconds: 80), _startCycle);
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
    return IgnorePointer(
      child: RepaintBoundary(
        key: CommandCenterAmbientProcessing.rootKey,
        child: CustomPaint(
          key: CommandCenterAmbientProcessing.dataRainKey,
          painter: _DataRainPainter(
            animation: _controller,
            color: Theme.of(context).colorScheme.primary,
            staticFrame: !_motionAllowed,
            running: _running,
            completedSeconds: _cycle * _cycleDuration.inMilliseconds / 1000,
          ),
        ),
      ),
    );
  }
}

class _DataRainPainter extends CustomPainter {
  const _DataRainPainter({
    required this.animation,
    required this.color,
    required this.staticFrame,
    required this.running,
    required this.completedSeconds,
  }) : super(repaint: animation);

  final Animation<double> animation;
  final Color color;
  final bool staticFrame;
  final bool running;
  final double completedSeconds;

  double get _seconds => staticFrame || !running
      ? completedSeconds
      : completedSeconds + animation.value * 8;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    for (
      var index = 0;
      index < CommandCenterAmbientProcessing.streamCount;
      index++
    ) {
      _paintStream(canvas, size, _StreamSpec.forIndex(index));
    }
  }

  void _paintStream(Canvas canvas, Size size, _StreamSpec stream) {
    final trail = size.height * stream.length;
    final span = size.height + trail;
    final offset = CommandCenterAmbientProcessing.constantSpeedOffset(
      elapsed: _seconds,
      pixelsPerSecond: CommandCenterAmbientProcessing.speeds[stream.speed]!,
    );
    final head = (stream.initialOffset * span + offset) % span - trail;
    final tail = head - trail;
    final x = stream.x * size.width;
    final visibleTop = tail.clamp(0.0, size.height);
    final visibleBottom = head.clamp(0.0, size.height);
    if (visibleBottom <= visibleTop) return;

    final bright = _brightStrength(stream);
    final baseAlpha = .018 + stream.opacity * .045;
    final trailAlpha = baseAlpha + bright * .16;
    final trailPaint = Paint()
      ..shader =
          LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              color.withValues(alpha: baseAlpha * .2),
              color.withValues(alpha: trailAlpha),
            ],
          ).createShader(
            Rect.fromLTWH(x - 1, visibleTop, 2, visibleBottom - visibleTop),
          );
    canvas.drawRect(
      Rect.fromLTWH(x - .65, visibleTop, 1.3, visibleBottom - visibleTop),
      trailPaint,
    );

    // Head segments make the stream read as data, while retaining the same
    // vertical trajectory and constant speed as its fading trail.
    final headHeight = 3.5 + bright * 7;
    final headTop = (head - headHeight).clamp(0.0, size.height);
    final headBottom = head.clamp(0.0, size.height);
    if (headBottom > headTop) {
      final accent = Color.lerp(color, Colors.cyanAccent, .28)!;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            x - (1 + bright),
            headTop,
            2 + bright * 2,
            headBottom - headTop,
          ),
          const Radius.circular(1),
        ),
        Paint()..color = accent.withValues(alpha: .18 + bright * .45),
      );
    }
  }

  double _brightStrength(_StreamSpec stream) {
    // Each stream owns a different interval, duration and phase. The modulo
    // schedules localized emphasis without any synchronized global reset.
    final local = (_seconds + stream.brightPhase) % stream.brightInterval;
    if (local > stream.brightDuration) return 0;
    final normalized = local / stream.brightDuration;
    return normalized < .18
        ? normalized / .18
        : normalized > .78
        ? (1 - normalized) / .22
        : 1;
  }

  @override
  bool shouldRepaint(covariant _DataRainPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.staticFrame != staticFrame ||
      oldDelegate.running != running ||
      oldDelegate.completedSeconds != completedSeconds;
}

class _StreamSpec {
  const _StreamSpec({
    required this.x,
    required this.initialOffset,
    required this.length,
    required this.opacity,
    required this.speed,
    required this.brightPhase,
    required this.brightInterval,
    required this.brightDuration,
  });

  final double x;
  final double initialOffset;
  final double length;
  final double opacity;
  final DataRainSpeed speed;
  final double brightPhase;
  final double brightInterval;
  final double brightDuration;

  factory _StreamSpec.forIndex(int index) {
    // Coprime multipliers distribute starts, brightness and lengths without
    // per-frame randomness or a synchronized master pattern.
    final lane = ((index * 37) % 101) / 100;
    return _StreamSpec(
      x: .018 + lane * .964,
      initialOffset: ((index * 29) % 97) / 97,
      length: .10 + ((index * 17) % 19) / 100,
      opacity: .35 + ((index * 11) % 13) / 20,
      speed: DataRainSpeed.values[index % DataRainSpeed.values.length],
      brightPhase: (index * 2.7) % 23,
      brightInterval: 15 + (index % 6) * 3.5,
      brightDuration: .7 + (index % 4) * .24,
    );
  }
}
