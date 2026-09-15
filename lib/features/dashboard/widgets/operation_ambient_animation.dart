import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/engine/operation_status.dart';
import '../../../core/theme/app_colors.dart';

enum OperationAmbientPreset { statusPulse }

enum OperationAmbientPulsePreset { green, yellow, red, neutral }

enum OperationAmbientSweepPhase { draw, hold, reset }

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
  static const height = 10.0;
  static const drawDuration = Duration(seconds: 6);
  static const holdDuration = Duration(milliseconds: 1300);
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
  Timer? _holdTimer;
  bool _reducedMotion = false, _tickerEnabled = true, _appActive = true;
  OperationAmbientSweepPhase _sweepPhase = OperationAmbientSweepPhase.draw;
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
    _holdTimer?.cancel();
    if (!_motionAllowed) {
      _controller.stop();
      return;
    }
    if (!_recorded) {
      _sweepPhase = OperationAmbientSweepPhase.draw;
      _controller.repeat(period: OperationAmbientAnimation.loopDuration);
      return;
    }
    if (restart) {
      _startDraw();
    } else if (_sweepPhase == OperationAmbientSweepPhase.hold) {
      _scheduleReset();
    } else if (!_controller.isAnimating) {
      _controller.forward();
    }
  }

  void _startDraw() {
    _holdTimer?.cancel();
    if (!mounted || !_motionAllowed || !_recorded) return;
    setState(() => _sweepPhase = OperationAmbientSweepPhase.draw);
    _controller.forward(from: 0);
  }

  void _completed(AnimationStatus status) {
    if (status != AnimationStatus.completed || !_recorded || !mounted) return;
    setState(() => _sweepPhase = OperationAmbientSweepPhase.hold);
    _scheduleReset();
  }

  void _scheduleReset() {
    _holdTimer?.cancel();
    if (!_motionAllowed || !_recorded) return;
    _holdTimer = Timer(OperationAmbientAnimation.holdDuration, () {
      if (!mounted || !_motionAllowed || !_recorded) return;
      setState(() {
        _sweepPhase = OperationAmbientSweepPhase.reset;
        _controller.value = 0;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _startDraw());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _holdTimer?.cancel();
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
      amplitude: 4,
      waveLength: 240,
      waveform: OperationAmbientWaveform.ecg,
      semanticLabel: 'GREEN stable',
    ),
    OperationAmbientPulsePreset.yellow => const OperationAmbientPulseGeometry(
      color: AppColors.warning,
      amplitude: 3,
      waveLength: 240,
      waveform: OperationAmbientWaveform.ecg,
      semanticLabel: 'YELLOW monitoring',
    ),
    OperationAmbientPulsePreset.red => const OperationAmbientPulseGeometry(
      color: AppColors.danger,
      amplitude: 2,
      waveLength: 240,
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

/// ECG geometry stays in viewport coordinates. DRAW clips it from the left;
/// HOLD keeps progress at one; RESET explicitly clears it before the next draw.
class OperationAmbientPulsePainter extends CustomPainter {
  static const ecgPulseStartFraction = .42, ecgPulseEndFraction = .64;
  OperationAmbientPulsePainter({
    required this.phase,
    required this.geometry,
    required this.preset,
    required this.staticFrame,
    required this.sweepPhase,
  }) : super(repaint: phase);
  final Animation<double> phase;
  final OperationAmbientPulseGeometry geometry;
  final OperationAmbientPulsePreset preset;
  final bool staticFrame;
  final OperationAmbientSweepPhase sweepPhase;
  Path? _cachedPath;
  Size? _cachedSize;
  double get revealProgress =>
      staticFrame ||
          geometry.waveform == OperationAmbientWaveform.sine ||
          sweepPhase == OperationAmbientSweepPhase.hold
      ? 1
      : sweepPhase == OperationAmbientSweepPhase.reset
      ? 0
      : phase.value;
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
    final p = staticFrame || sweepPhase == OperationAmbientSweepPhase.hold
        ? 1.0
        : sweepPhase == OperationAmbientSweepPhase.reset
        ? 0.0
        : (phaseValue ?? phase.value);
    return OperationAmbientWaveformCoverage(left: 0, right: size.width * p);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final paint = Paint()
      ..color = geometry.color.withValues(alpha: .78)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    if (geometry.waveform == OperationAmbientWaveform.sine) {
      canvas.drawPath(_sine(size), paint);
      return;
    }
    canvas.save();
    canvas.clipRect(
      Rect.fromLTWH(0, 0, size.width * revealProgress.clamp(0, 1), size.height),
    );
    canvas.drawPath(_ecg(size), paint);
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

  Path _ecg(Size size) {
    if (_cachedSize == size && _cachedPath != null) return _cachedPath!;
    final path = Path();
    final mid = size.height / 2, period = geometry.waveLength;
    path.moveTo(0, mid);
    for (var start = 0.0; start < size.width; start += period) {
      void line(double f, double y) {
        final x = start + period * f;
        if (x <= size.width) path.lineTo(x, y);
      }

      line(ecgPulseStartFraction, mid);
      line(.46, mid - geometry.amplitude * .25);
      line(.49, mid + geometry.amplitude * .12);
      line(.52, mid - geometry.amplitude);
      line(.56, mid + geometry.amplitude * .55);
      line(.60, mid - geometry.amplitude * .30);
      line(ecgPulseEndFraction, mid);
      path.lineTo(math.min(start + period, size.width), mid);
    }
    _cachedSize = size;
    return _cachedPath = path..moveTo(size.width, mid);
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
      old.sweepPhase != sweepPhase;
}

class OperationAmbientWaveformCoverage {
  const OperationAmbientWaveformCoverage({
    required this.left,
    required this.right,
  });
  final double left, right;
}
