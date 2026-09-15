import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/engine/operation_status.dart';
import '../../../core/theme/app_colors.dart';

/// V1's ambient renderer. Future slot presets can be added without changing
/// Dashboard placement or the canonical status input.
enum OperationAmbientPreset { statusPulse }

enum OperationAmbientPulsePreset { green, yellow, red, neutral }

OperationAmbientPulsePreset operationAmbientPulsePresetFor(
  OperationStatus? status,
) => switch (status) {
  OperationStatus.green => OperationAmbientPulsePreset.green,
  OperationStatus.yellow => OperationAmbientPulsePreset.yellow,
  OperationStatus.red => OperationAmbientPulsePreset.red,
  OperationStatus.black || null => OperationAmbientPulsePreset.neutral,
};

/// Presentation-only top-edge slot for the canonical Operation Status.
///
/// V1 hosts the continuous status pulse. A future event renderer can occupy
/// this same slot temporarily and then return to the ambient preset.
class OperationAmbientAnimation extends StatefulWidget {
  const OperationAmbientAnimation({
    super.key,
    required this.status,
    this.preset = OperationAmbientPreset.statusPulse,
  });

  static const height = 8.0;
  static const loopDuration = Duration(seconds: 6);

  final OperationStatus? status;
  final OperationAmbientPreset preset;

  @override
  State<OperationAmbientAnimation> createState() =>
      _OperationAmbientAnimationState();
}

class _OperationAmbientAnimationState extends State<OperationAmbientAnimation>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _controller = AnimationController(vsync: this);
  bool _reducedMotion = false;
  bool _tickerEnabled = true;
  bool _appActive = true;

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
    _syncMotion();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appActive = state == AppLifecycleState.resumed;
    _syncMotion();
  }

  void _syncMotion() {
    if (!mounted) return;
    if (_reducedMotion || !_tickerEnabled || !_appActive) {
      _controller.stop();
      return;
    }
    if (!_controller.isAnimating) {
      _controller.repeat(period: OperationAmbientAnimation.loopDuration);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pulse = OperationAmbientPulseGeometry.forPreset(
      operationAmbientPulsePresetFor(widget.status),
    );
    return IgnorePointer(
      child: Semantics(
        label: 'Operation status ambient pulse: ${pulse.semanticLabel}',
        child: RepaintBoundary(
          child: SizedBox(
            key: const ValueKey('operation-ambient-animation-slot'),
            height: OperationAmbientAnimation.height,
            width: double.infinity,
            child: CustomPaint(
              key: const ValueKey('operation-ambient-animation-paint'),
              painter: OperationAmbientPulsePainter(
                phase: _controller,
                geometry: pulse,
                preset: operationAmbientPulsePresetFor(widget.status),
                staticFrame: _reducedMotion || !_tickerEnabled || !_appActive,
              ),
              willChange: !_reducedMotion && _tickerEnabled && _appActive,
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
    required this.semanticLabel,
  });

  factory OperationAmbientPulseGeometry.forPreset(
    OperationAmbientPulsePreset preset,
  ) => switch (preset) {
    OperationAmbientPulsePreset.green => const OperationAmbientPulseGeometry(
      color: AppColors.success,
      amplitude: 1.0,
      waveLength: 32,
      semanticLabel: 'GREEN stable',
    ),
    OperationAmbientPulsePreset.yellow => const OperationAmbientPulseGeometry(
      color: AppColors.warning,
      amplitude: 2.0,
      waveLength: 24,
      semanticLabel: 'YELLOW monitoring',
    ),
    OperationAmbientPulsePreset.red => const OperationAmbientPulseGeometry(
      color: AppColors.danger,
      amplitude: 3.0,
      waveLength: 16,
      semanticLabel: 'RED elevated',
    ),
    OperationAmbientPulsePreset.neutral => const OperationAmbientPulseGeometry(
      color: AppColors.secondary,
      amplitude: 0.8,
      waveLength: 32,
      semanticLabel: 'status unavailable',
    ),
  };

  final Color color;
  final double amplitude;
  final double waveLength;
  final String semanticLabel;
}

/// Paints a tileable waveform. Phase changes timing only; endpoints and wave
/// geometry remain independent of the controller's loop duration.
class OperationAmbientPulsePainter extends CustomPainter {
  OperationAmbientPulsePainter({
    required this.phase,
    required this._geometry,
    required this.preset,
    required this.staticFrame,
  }) : super(repaint: phase);

  final Animation<double> phase;
  final OperationAmbientPulseGeometry _geometry;
  final OperationAmbientPulsePreset preset;
  final bool staticFrame;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final value = staticFrame ? 0.0 : phase.value;
    // Four complete waves make phase 1.0 geometrically identical to 0.0.
    final offset = value * _geometry.waveLength * 4;
    final path = Path();
    final centerY = size.height / 2;
    for (
      var x = -_geometry.waveLength * 2;
      x <= size.width + _geometry.waveLength * 2;
      x += 1
    ) {
      final y =
          centerY +
          math.sin((x - offset) * math.pi * 2 / _geometry.waveLength) *
              _geometry.amplitude;
      if (x == -_geometry.waveLength * 2) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = _geometry.color.withValues(alpha: 0.78)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant OperationAmbientPulsePainter oldDelegate) =>
      oldDelegate._geometry.color != _geometry.color ||
      oldDelegate._geometry.amplitude != _geometry.amplitude ||
      oldDelegate._geometry.waveLength != _geometry.waveLength ||
      oldDelegate.preset != preset ||
      oldDelegate.staticFrame != staticFrame;
}
