import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/engine/operation_status.dart';
import '../../../core/theme/app_colors.dart';

enum OperationAmbientPreset { statusPulse }

enum OperationAmbientPulsePreset { green, yellow, red, neutral }

enum OperationAmbientSweepPhase { initialize, sweep }

/// Each trace uses one restrained ECG family member. Selection occurs once per
/// completed sweep, never while a trace is being painted.
enum OperationAmbientEcgVariant { a, b, c }

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
  static const height = 20.0;
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
  OperationAmbientEcgVariant _currentVariant = OperationAmbientEcgVariant.a;
  OperationAmbientEcgVariant _nextVariant = OperationAmbientEcgVariant.b;
  var _nextVariantSequenceIndex = 2;
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
      _currentVariant = OperationAmbientPulsePainter.variantAt(0);
      _nextVariant = OperationAmbientPulsePainter.variantAt(1);
      _nextVariantSequenceIndex = 2;
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
        _currentVariant = _nextVariant;
        _nextVariant = OperationAmbientPulsePainter.variantAt(
          _nextVariantSequenceIndex,
        );
        _nextVariantSequenceIndex += 1;
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
                currentVariant: _currentVariant,
                nextVariant: _nextVariant,
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
      amplitude: 8,
      waveLength: 100,
      waveform: OperationAmbientWaveform.ecg,
      semanticLabel: 'GREEN stable',
    ),
    OperationAmbientPulsePreset.yellow => const OperationAmbientPulseGeometry(
      color: AppColors.warning,
      amplitude: 6,
      waveLength: 60,
      waveform: OperationAmbientWaveform.ecg,
      semanticLabel: 'YELLOW monitoring',
    ),
    OperationAmbientPulsePreset.red => const OperationAmbientPulseGeometry(
      color: AppColors.danger,
      amplitude: 4,
      waveLength: 35,
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
  static const _variantSequence = [
    OperationAmbientEcgVariant.a,
    OperationAmbientEcgVariant.b,
    OperationAmbientEcgVariant.c,
    OperationAmbientEcgVariant.a,
    OperationAmbientEcgVariant.c,
    OperationAmbientEcgVariant.b,
    OperationAmbientEcgVariant.c,
    OperationAmbientEcgVariant.a,
    OperationAmbientEcgVariant.b,
    OperationAmbientEcgVariant.c,
    OperationAmbientEcgVariant.b,
    OperationAmbientEcgVariant.c,
  ];
  static OperationAmbientEcgVariant variantAt(int sequenceIndex) =>
      _variantSequence[sequenceIndex % _variantSequence.length];
  OperationAmbientPulsePainter({
    required this.phase,
    required this.geometry,
    required this.preset,
    required this.staticFrame,
    required this.sweepPhase,
    required this.currentVariant,
    required this.nextVariant,
  }) : super(repaint: phase);
  final Animation<double> phase;
  final OperationAmbientPulseGeometry geometry;
  final OperationAmbientPulsePreset preset;
  final bool staticFrame;
  final OperationAmbientSweepPhase sweepPhase;
  final OperationAmbientEcgVariant currentVariant;
  final OperationAmbientEcgVariant nextVariant;
  final Map<OperationAmbientEcgVariant, Path> _cachedPaths = {};
  Size? _cachedSize;
  double get revealProgress =>
      staticFrame || geometry.waveform == OperationAmbientWaveform.sine
      ? 1
      : phase.value;

  List<double> pulseFractionsFor(
    OperationAmbientEcgVariant variant,
  ) => switch (variant) {
    // Baseline, small pre-deflection, peak, negative return, recovery,
    // baseline. Variants differ only horizontally, preserving amplitude.
    OperationAmbientEcgVariant.a => const [.42, .46, .49, .52, .56, .60, .64],
    OperationAmbientEcgVariant.b => const [.30, .35, .39, .43, .47, .52, .58],
    OperationAmbientEcgVariant.c => const [.54, .58, .61, .64, .68, .72, .78],
  };

  /// A full trace is composed from several controlled family members. The
  /// composition is deterministic for a trace variant and viewport, and is
  /// only rebuilt when the cached trace itself changes.
  List<OperationAmbientEcgVariant> traceCompositionFor(
    Size size,
    OperationAmbientEcgVariant traceVariant,
  ) {
    final count = math.max(1, (size.width / geometry.waveLength).ceil());
    return List.generate(
      count,
      (index) =>
          _variantSequence[(traceVariant.index + index) %
              _variantSequence.length],
    );
  }

  int eventCountFor(Size size, OperationAmbientEcgVariant traceVariant) =>
      traceCompositionFor(size, traceVariant).length;

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
      canvas.drawPath(_ecg(size, currentVariant), paint);
      return;
    }
    final regions = sweepRegionsFor(size);
    if (sweepPhase == OperationAmbientSweepPhase.initialize) {
      _paintClipped(
        canvas,
        _ecg(size, currentVariant),
        regions.newTrace,
        paint,
      );
      return;
    }
    _paintClipped(canvas, _ecg(size, currentVariant), regions.oldTrace, paint);
    _paintClipped(canvas, _ecg(size, nextVariant), regions.newTrace, paint);
    final head = activeHeadRegionFor(size);
    if (!head.isEmpty) {
      _paintClipped(
        canvas,
        _ecg(size, nextVariant),
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

  Path _ecg(Size size, OperationAmbientEcgVariant variant) {
    if (_cachedSize != size) {
      _cachedSize = size;
      _cachedPaths.clear();
    }
    final existing = _cachedPaths[variant];
    if (existing != null) return existing;
    final path = Path();
    final mid = size.height / 2, period = geometry.waveLength;
    path.moveTo(0, mid);
    final composition = traceCompositionFor(size, variant);
    for (var index = 0; index < composition.length; index++) {
      final start = index * period;
      final fractions = pulseFractionsFor(composition[index]);
      void line(double f, double y) {
        final x = start + period * f;
        if (x <= size.width) path.lineTo(x, y);
      }

      line(fractions[0], mid);
      line(fractions[1], mid - geometry.amplitude * .25);
      line(fractions[2], mid + geometry.amplitude * .12);
      line(fractions[3], mid - geometry.amplitude);
      line(fractions[4], mid + geometry.amplitude * .55);
      line(fractions[5], mid - geometry.amplitude * .30);
      line(fractions[6], mid);
      if (preset == OperationAmbientPulsePreset.red) {
        line(.82, mid - geometry.amplitude * .38);
        line(.87, mid + geometry.amplitude * .28);
        line(.92, mid - geometry.amplitude * .18);
      }
      path.lineTo(math.min(start + period, size.width), mid);
    }
    return _cachedPaths[variant] = path..lineTo(size.width, mid);
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
      old.currentVariant != currentVariant ||
      old.nextVariant != nextVariant;
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
