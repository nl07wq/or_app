import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/engine/operation_status.dart';
import '../../../core/theme/app_colors.dart';

enum OperationAmbientPreset { statusPulse }

enum OperationAmbientPulsePreset { green, yellow, red, neutral }

enum OperationAmbientSweepPhase { initialize, sweep }

/// Controlled ECG complex families. A trace chooses several families when it
/// is generated, never during frame-by-frame painting.
enum OperationAmbientEcgFamily {
  upDownUp,
  downUpDown,
  positiveDominant,
  negativeDominant,
  multiDeflection,
}

OperationAmbientPulsePreset operationAmbientPulsePresetFor(
  OperationStatus? s,
) => switch (s) {
  OperationStatus.green => OperationAmbientPulsePreset.green,
  OperationStatus.yellow => OperationAmbientPulsePreset.yellow,
  OperationStatus.red => OperationAmbientPulsePreset.red,
  OperationStatus.black || null => OperationAmbientPulsePreset.neutral,
};

/// Presentation-only top-edge slot. Future event renderers can use this slot.
class OperationAmbientAnimation extends StatefulWidget {
  const OperationAmbientAnimation({
    super.key,
    required this.status,
    this.preset = OperationAmbientPreset.statusPulse,
  });
  static const height = 28.0;
  static const drawDuration = Duration(seconds: 6);
  static const loopDuration = drawDuration;
  final OperationStatus? status;
  final OperationAmbientPreset preset;
  @override
  State<OperationAmbientAnimation> createState() =>
      _OperationAmbientAnimationState();
}

class _OperationAmbientAnimationState extends State<OperationAmbientAnimation>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: OperationAmbientAnimation.drawDuration,
  )..addStatusListener(_completed);
  bool _reducedMotion = false, _tickerEnabled = true, _appActive = true;
  OperationAmbientSweepPhase _sweepPhase =
      OperationAmbientSweepPhase.initialize;
  var _currentTraceIndex = 0;
  var _nextTraceIndex = 1;
  var _followingTraceIndex = 2;
  bool get _recorded =>
      operationAmbientPulsePresetFor(widget.status) !=
      OperationAmbientPulsePreset.neutral;
  bool get _motionAllowed => !_reducedMotion && _tickerEnabled && _appActive;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reducedMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    _tickerEnabled = TickerMode.valuesOf(context).enabled;
    _sync(restart: true);
  }

  @override
  void didUpdateWidget(covariant OperationAmbientAnimation old) {
    super.didUpdateWidget(old);
    if (operationAmbientPulsePresetFor(old.status) !=
        operationAmbientPulsePresetFor(widget.status)) {
      _sync(restart: true);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appActive = state == AppLifecycleState.resumed;
    _sync();
  }

  void _sync({bool restart = false}) {
    if (!mounted) return;
    if (!_motionAllowed) {
      _controller.stop();
      return;
    }
    if (!_recorded) {
      _controller.repeat(period: OperationAmbientAnimation.loopDuration);
      return;
    }
    if (restart) {
      _startRecordedInitialization();
    } else if (!_controller.isAnimating) {
      _controller.forward();
    }
  }

  void _startRecordedInitialization() {
    if (!mounted || !_motionAllowed || !_recorded) return;
    setState(() {
      _sweepPhase = OperationAmbientSweepPhase.initialize;
      _currentTraceIndex = 0;
      _nextTraceIndex = 1;
      _followingTraceIndex = 2;
    });
    _controller.forward(from: 0);
  }

  void _completed(AnimationStatus status) {
    if (status != AnimationStatus.completed || !_recorded || !mounted) return;
    // Let the fully established/replaced trace render at progress 1 before a
    // new left-edge seam starts. This avoids a right-edge frame being skipped.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_motionAllowed || !_recorded) return;
      _beginNextSweep();
    });
  }

  void _beginNextSweep() {
    if (_sweepPhase == OperationAmbientSweepPhase.initialize) {
      setState(() {
        _sweepPhase = OperationAmbientSweepPhase.sweep;
      });
    } else {
      setState(() {
        _currentTraceIndex = _nextTraceIndex;
        _nextTraceIndex = _followingTraceIndex;
        _followingTraceIndex += 1;
      });
    }
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final preset = operationAmbientPulsePresetFor(widget.status);
    final staticFrame = !_motionAllowed;
    final geometry = OperationAmbientPulseGeometry.forPreset(preset);
    return IgnorePointer(
      child: Semantics(
        label: 'Operation status ambient pulse: ${geometry.semanticLabel}',
        child: RepaintBoundary(
          child: SizedBox(
            key: const ValueKey('operation-ambient-animation-slot'),
            height: OperationAmbientAnimation.height,
            width: double.infinity,
            child: CustomPaint(
              key: const ValueKey('operation-ambient-animation-paint'),
              painter: OperationAmbientPulsePainter(
                phase: _controller,
                geometry: geometry,
                preset: preset,
                staticFrame: staticFrame,
                sweepPhase: _sweepPhase,
                currentTraceIndex: _currentTraceIndex,
                nextTraceIndex: _nextTraceIndex,
              ),
              willChange: !staticFrame,
            ),
          ),
        ),
      ),
    );
  }
}

class OperationAmbientPulseGeometry {
  const OperationAmbientPulseGeometry({
    required this.color,
    required this.amplitude,
    required this.waveLength,
    required this.waveform,
    required this.semanticLabel,
  });
  factory OperationAmbientPulseGeometry.forPreset(
    OperationAmbientPulsePreset p,
  ) => switch (p) {
    OperationAmbientPulsePreset.green => const OperationAmbientPulseGeometry(
      color: AppColors.success,
      amplitude: 12,
      waveLength: 80,
      waveform: OperationAmbientWaveform.ecg,
      semanticLabel: 'GREEN stable',
    ),
    OperationAmbientPulsePreset.yellow => const OperationAmbientPulseGeometry(
      color: AppColors.warning,
      amplitude: 10,
      waveLength: 40,
      waveform: OperationAmbientWaveform.ecg,
      semanticLabel: 'YELLOW monitoring',
    ),
    OperationAmbientPulsePreset.red => const OperationAmbientPulseGeometry(
      color: AppColors.danger,
      amplitude: 5,
      waveLength: 15,
      waveform: OperationAmbientWaveform.ecg,
      semanticLabel: 'RED elevated',
    ),
    OperationAmbientPulsePreset.neutral => const OperationAmbientPulseGeometry(
      color: AppColors.secondary,
      amplitude: .8,
      waveLength: 32,
      waveform: OperationAmbientWaveform.sine,
      semanticLabel: 'status unavailable',
    ),
  };
  final Color color;
  final double amplitude, waveLength;
  final OperationAmbientWaveform waveform;
  final String semanticLabel;
}

enum OperationAmbientWaveform { sine, ecg }

/// Recorded ECG geometry stays in fixed viewport coordinates. The first pass
/// establishes a trace, then each sweep replaces it behind a small clear seam.
class OperationAmbientPulsePainter extends CustomPainter {
  static const clearWindowWidth = 8.0;
  static const traceStrokeWidth = 1.5;
  static const activeHeadStrokeWidth = 2.25;
  static const activeHeadLength = 4.0;
  OperationAmbientPulsePainter({
    required this.phase,
    required this.geometry,
    required this.preset,
    required this.staticFrame,
    required this.sweepPhase,
    required this.currentTraceIndex,
    required this.nextTraceIndex,
  }) : super(repaint: phase);
  final Animation<double> phase;
  final OperationAmbientPulseGeometry geometry;
  final OperationAmbientPulsePreset preset;
  final bool staticFrame;
  final OperationAmbientSweepPhase sweepPhase;
  final int currentTraceIndex;
  final int nextTraceIndex;
  final Map<int, _OperationAmbientCachedTrace> _cachedTraces = {};
  Size? _cachedSize;
  double get revealProgress =>
      staticFrame || geometry.waveform == OperationAmbientWaveform.sine
      ? 1
      : phase.value;

  /// The trace metadata is generated from presentation-only inputs and cached
  /// with the Path. This is intentionally available to widget tests so
  /// spacing, families, widths, and envelopes are verified structurally.
  List<OperationAmbientEcgEvent> traceEventsFor(Size size, int traceIndex) =>
      _traceFor(size, traceIndex).events;

  int eventCountFor(Size size, int traceIndex) =>
      traceEventsFor(size, traceIndex).length;

  OperationAmbientSweepRegions sweepRegionsFor(
    Size size, {
    double? phaseValue,
  }) {
    final progress = (phaseValue ?? phase.value).clamp(0.0, 1.0);
    if (staticFrame || sweepPhase == OperationAmbientSweepPhase.initialize) {
      return OperationAmbientSweepRegions(
        newTrace: Rect.fromLTWH(0, 0, size.width * progress, size.height),
        clear: Rect.zero,
        oldTrace: Rect.zero,
      );
    }
    if (progress >= 1) {
      return OperationAmbientSweepRegions(
        newTrace: Rect.fromLTWH(0, 0, size.width, size.height),
        clear: Rect.zero,
        oldTrace: Rect.zero,
      );
    }
    final head = size.width * progress;
    final clearRight = math.min(size.width, head + clearWindowWidth);
    return OperationAmbientSweepRegions(
      newTrace: Rect.fromLTWH(0, 0, head, size.height),
      clear: Rect.fromLTRB(head, 0, clearRight, size.height),
      oldTrace: Rect.fromLTRB(clearRight, 0, size.width, size.height),
    );
  }

  OperationAmbientWaveformCoverage coverageFor(
    Size size, {
    double? phaseValue,
  }) {
    if (geometry.waveform == OperationAmbientWaveform.sine) {
      return OperationAmbientWaveformCoverage(
        left: -geometry.waveLength * 2,
        right: size.width + geometry.waveLength * 2,
      );
    }
    final regions = sweepRegionsFor(size, phaseValue: phaseValue);
    return OperationAmbientWaveformCoverage(
      left: regions.newTrace.left,
      right: regions.newTrace.right,
    );
  }

  Rect activeHeadRegionFor(Size size, {double? phaseValue}) {
    final progress = (phaseValue ?? phase.value).clamp(0.0, 1.0);
    if (staticFrame ||
        geometry.waveform != OperationAmbientWaveform.ecg ||
        sweepPhase != OperationAmbientSweepPhase.sweep ||
        progress <= 0 ||
        progress >= 1) {
      return Rect.zero;
    }
    final head = size.width * progress;
    return Rect.fromLTRB(
      math.max(0, head - activeHeadLength),
      0,
      head,
      size.height,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final paint = Paint()
      ..color = geometry.color.withValues(alpha: .78)
      ..style = PaintingStyle.stroke
      ..strokeWidth = traceStrokeWidth
      ..strokeCap = StrokeCap.round;
    if (geometry.waveform == OperationAmbientWaveform.sine) {
      canvas.drawPath(_sine(size), paint);
      return;
    }
    if (staticFrame) {
      canvas.drawPath(_ecg(size, currentTraceIndex), paint);
      return;
    }
    final regions = sweepRegionsFor(size);
    if (sweepPhase == OperationAmbientSweepPhase.initialize) {
      _paintClipped(
        canvas,
        _ecg(size, currentTraceIndex),
        regions.newTrace,
        paint,
      );
      return;
    }
    _paintClipped(
      canvas,
      _ecg(size, currentTraceIndex),
      regions.oldTrace,
      paint,
    );
    _paintClipped(canvas, _ecg(size, nextTraceIndex), regions.newTrace, paint);
    final head = activeHeadRegionFor(size);
    if (!head.isEmpty) {
      _paintClipped(
        canvas,
        _ecg(size, nextTraceIndex),
        head,
        Paint()
          ..color = geometry.color.withValues(alpha: .78)
          ..style = PaintingStyle.stroke
          ..strokeWidth = activeHeadStrokeWidth
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  void _paintClipped(Canvas canvas, Path path, Rect rect, Paint paint) {
    if (rect.isEmpty) return;
    canvas.save();
    canvas.clipRect(rect);
    canvas.drawPath(path, paint);
    canvas.restore();
  }

  Path _sine(Size size) {
    final path = Path();
    final offset = staticFrame
        ? 0.0
        : _remainder(phase.value * geometry.waveLength);
    final mid = size.height / 2;
    for (
      var x = -geometry.waveLength * 2;
      x <= size.width + geometry.waveLength * 2;
      x += 1
    ) {
      final y =
          mid +
          math.sin((x - offset) * math.pi * 2 / geometry.waveLength) *
              geometry.amplitude;
      x == -geometry.waveLength * 2 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    return path;
  }

  Path _ecg(Size size, int traceIndex) => _traceFor(size, traceIndex).path;

  _OperationAmbientCachedTrace _traceFor(Size size, int traceIndex) {
    if (_cachedSize != size) {
      _cachedSize = size;
      _cachedTraces.clear();
    }
    final existing = _cachedTraces[traceIndex];
    if (existing != null) return existing;

    final path = Path();
    final mid = size.height / 2;
    path.moveTo(0, mid);
    final events = _generateEvents(size, traceIndex);
    for (final event in events) {
      path.lineTo(event.x, mid);
      _appendEvent(path, event, mid);
      path.lineTo(event.right, mid);
    }
    path.lineTo(size.width, mid);
    final trace = _OperationAmbientCachedTrace(path: path, events: events);
    _cachedTraces[traceIndex] = trace;
    return trace;
  }

  List<OperationAmbientEcgEvent> _generateEvents(Size size, int traceIndex) {
    final random = _OperationAmbientDeterministicRandom(
      _traceSeed(size, traceIndex),
    );
    final nominal = geometry.waveLength;
    final intervalRange = switch (preset) {
      OperationAmbientPulsePreset.green => (min: .70, max: 1.30),
      OperationAmbientPulsePreset.yellow => (min: .70, max: 1.30),
      OperationAmbientPulsePreset.red => (min: 11 / 15, max: 20 / 15),
      OperationAmbientPulsePreset.neutral => (min: 1.0, max: 1.0),
    };
    final baseWidth = switch (preset) {
      OperationAmbientPulsePreset.green => 20.0,
      OperationAmbientPulsePreset.yellow => 12.0,
      OperationAmbientPulsePreset.red => 7.0,
      OperationAmbientPulsePreset.neutral => 0.0,
    };
    final minimumGap = switch (preset) {
      OperationAmbientPulsePreset.green => 4.0,
      OperationAmbientPulsePreset.yellow => 3.0,
      OperationAmbientPulsePreset.red => 2.0,
      OperationAmbientPulsePreset.neutral => 0.0,
    };
    final events = <OperationAmbientEcgEvent>[];
    var x = nominal * random.range(.32, .55);
    OperationAmbientEcgFamily? previousFamily;
    while (x + baseWidth * .72 <= size.width) {
      final width = baseWidth * random.range(.72, 1.22);
      if (x + width > size.width) break;
      var family = OperationAmbientEcgFamily
          .values[random.nextInt(OperationAmbientEcgFamily.values.length)];
      if (family == previousFamily) {
        family =
            OperationAmbientEcgFamily.values[(family.index +
                    1 +
                    random.nextInt(3)) %
                OperationAmbientEcgFamily.values.length];
      }
      final event = OperationAmbientEcgEvent(
        x: x,
        width: width,
        family: family,
        heightFactor: random.range(.65, 1.0),
        secondaryFactor: random.range(.35, .70),
      );
      events.add(event);
      previousFamily = family;
      final interval =
          nominal * random.range(intervalRange.min, intervalRange.max);
      x += math.max(interval, width + minimumGap);
    }
    return events;
  }

  int _traceSeed(Size size, int traceIndex) =>
      ((preset.index + 1) * 73856093 ^
          (traceIndex + 1) * 19349663 ^
          size.width.round() * 83492791) &
      0x7fffffff;

  void _appendEvent(Path path, OperationAmbientEcgEvent event, double mid) {
    final amplitude = geometry.amplitude * event.heightFactor;
    double up(double factor) => mid - amplitude * factor;
    double down(double factor) => mid + amplitude * factor;
    void point(double fraction, double y) =>
        path.lineTo(event.x + event.width * fraction, y);

    switch (event.family) {
      case OperationAmbientEcgFamily.upDownUp:
        point(.18, up(.62));
        point(.40, down(event.secondaryFactor));
        point(.64, up(1));
        point(.84, down(event.secondaryFactor * .82));
      case OperationAmbientEcgFamily.downUpDown:
        point(.18, down(.62));
        point(.40, up(event.secondaryFactor));
        point(.64, down(1));
        point(.84, up(event.secondaryFactor * .82));
      case OperationAmbientEcgFamily.positiveDominant:
        point(.16, down(.20));
        point(.42, up(1));
        point(.66, down(event.secondaryFactor));
        point(.84, up(.28));
      case OperationAmbientEcgFamily.negativeDominant:
        point(.16, up(.20));
        point(.42, down(1));
        point(.66, up(event.secondaryFactor));
        point(.84, down(.28));
      case OperationAmbientEcgFamily.multiDeflection:
        point(.14, up(.38));
        point(.30, down(event.secondaryFactor * .82));
        point(.50, up(.88));
        point(.70, down(event.secondaryFactor));
        point(.86, up(.34));
    }
  }

  double _remainder(double v) {
    final r = v % geometry.waveLength;
    return r < 0 ? r + geometry.waveLength : r;
  }

  @override
  bool shouldRepaint(covariant OperationAmbientPulsePainter old) =>
      old.geometry.color != geometry.color ||
      old.geometry.amplitude != geometry.amplitude ||
      old.geometry.waveLength != geometry.waveLength ||
      old.geometry.waveform != geometry.waveform ||
      old.preset != preset ||
      old.staticFrame != staticFrame ||
      old.sweepPhase != sweepPhase ||
      old.currentTraceIndex != currentTraceIndex ||
      old.nextTraceIndex != nextTraceIndex;
}

class OperationAmbientEcgEvent {
  const OperationAmbientEcgEvent({
    required this.x,
    required this.width,
    required this.family,
    required this.heightFactor,
    required this.secondaryFactor,
  });

  final double x;
  final double width;
  final OperationAmbientEcgFamily family;
  final double heightFactor;
  final double secondaryFactor;

  double get right => x + width;
  bool get positiveFirst => switch (family) {
    OperationAmbientEcgFamily.upDownUp ||
    OperationAmbientEcgFamily.negativeDominant ||
    OperationAmbientEcgFamily.multiDeflection => true,
    OperationAmbientEcgFamily.downUpDown ||
    OperationAmbientEcgFamily.positiveDominant => false,
  };
}

class _OperationAmbientCachedTrace {
  const _OperationAmbientCachedTrace({
    required this.path,
    required this.events,
  });
  final Path path;
  final List<OperationAmbientEcgEvent> events;
}

/// Tiny deterministic generator kept presentation-only: traces reproduce from
/// preset, viewport width, and generation index without wall-clock entropy.
class _OperationAmbientDeterministicRandom {
  _OperationAmbientDeterministicRandom(this._state);
  int _state;

  int _next() {
    _state = ((_state * 1103515245) + 12345) & 0x7fffffff;
    return _state;
  }

  int nextInt(int upperExclusive) => _next() % upperExclusive;
  double range(double minimum, double maximum) =>
      minimum + (_next() / 0x7fffffff) * (maximum - minimum);
}

class OperationAmbientSweepRegions {
  const OperationAmbientSweepRegions({
    required this.newTrace,
    required this.clear,
    required this.oldTrace,
  });
  final Rect newTrace, clear, oldTrace;
}

class OperationAmbientWaveformCoverage {
  const OperationAmbientWaveformCoverage({
    required this.left,
    required this.right,
  });
  final double left, right;
}
