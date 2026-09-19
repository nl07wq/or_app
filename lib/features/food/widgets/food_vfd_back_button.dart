import 'package:flutter/material.dart';

import 'food_vfd_scale_display_title.dart';

enum FoodVfdBackPhase {
  idle,
  extinguish,
  sweep1,
  sweepGap1,
  sweep2,
  sweepGap2,
  sweep3,
  afterglow,
  complete,
}

/// Timing and geometry state for FOOD's short, three-pass VFD scan response.
class FoodVfdBackTiming {
  const FoodVfdBackTiming._();

  static const triangleExtinguishDuration = Duration(milliseconds: 45);
  static const sweepDuration = Duration(milliseconds: 115);
  static const interSweepGapDuration = Duration(milliseconds: 15);
  static const finalAfterglowDuration = Duration(milliseconds: 30);
  static const totalDuration = Duration(milliseconds: 450);

  static FoodVfdBackFrame frameFor(double controllerValue) {
    var elapsed =
        controllerValue.clamp(0.0, 1.0) *
        totalDuration.inMilliseconds.toDouble();
    if (elapsed == 0) return const FoodVfdBackFrame.idle();

    final extinguish = triangleExtinguishDuration.inMilliseconds.toDouble();
    if (elapsed < extinguish) {
      return FoodVfdBackFrame.extinguish(elapsed / extinguish);
    }
    elapsed -= extinguish;

    for (var sweep = 0; sweep < 3; sweep++) {
      final sweepMilliseconds = sweepDuration.inMilliseconds.toDouble();
      if (elapsed < sweepMilliseconds) {
        return FoodVfdBackFrame.sweep(sweep, elapsed / sweepMilliseconds);
      }
      elapsed -= sweepMilliseconds;

      if (sweep == 2) break;
      final gapMilliseconds = interSweepGapDuration.inMilliseconds.toDouble();
      if (elapsed < gapMilliseconds) {
        return FoodVfdBackFrame.gap(sweep, elapsed / gapMilliseconds);
      }
      elapsed -= gapMilliseconds;
    }

    final afterglow = finalAfterglowDuration.inMilliseconds.toDouble();
    if (elapsed < afterglow) {
      return FoodVfdBackFrame.afterglow(elapsed / afterglow);
    }
    return const FoodVfdBackFrame.complete();
  }
}

class FoodVfdBackFrame {
  const FoodVfdBackFrame._({
    required this.phase,
    this.sweepIndex,
    this.sweepProgress = 0,
    this.phaseProgress = 0,
  });

  const FoodVfdBackFrame.idle() : this._(phase: FoodVfdBackPhase.idle);

  const FoodVfdBackFrame.extinguish(double progress)
    : this._(phase: FoodVfdBackPhase.extinguish, phaseProgress: progress);

  FoodVfdBackFrame.sweep(int index, double progress)
    : this._(
        phase: switch (index) {
          0 => FoodVfdBackPhase.sweep1,
          1 => FoodVfdBackPhase.sweep2,
          _ => FoodVfdBackPhase.sweep3,
        },
        sweepIndex: index,
        sweepProgress: progress,
      );

  FoodVfdBackFrame.gap(int index, double progress)
    : this._(
        phase: switch (index) {
          0 => FoodVfdBackPhase.sweepGap1,
          _ => FoodVfdBackPhase.sweepGap2,
        },
        phaseProgress: progress,
      );

  const FoodVfdBackFrame.afterglow(double progress)
    : this._(phase: FoodVfdBackPhase.afterglow, phaseProgress: progress);

  const FoodVfdBackFrame.complete() : this._(phase: FoodVfdBackPhase.complete);

  final FoodVfdBackPhase phase;
  final int? sweepIndex;
  final double sweepProgress;
  final double phaseProgress;

  bool get hasTriangle =>
      phase == FoodVfdBackPhase.idle || phase == FoodVfdBackPhase.extinguish;
  bool get hasSweep => sweepIndex != null;
  bool get hasAfterglow => phase == FoodVfdBackPhase.afterglow;

  double get triangleOpacity => switch (phase) {
    FoodVfdBackPhase.idle => 1,
    FoodVfdBackPhase.extinguish => 1 - phaseProgress,
    _ => 0,
  };

  /// 1 is the aperture's right edge and 0 is its left edge.
  double get scanPosition => 1 - Curves.easeInOut.transform(sweepProgress);
  double get afterglowOpacity => hasAfterglow ? 1 - phaseProgress : 0;
}

/// Shared local geometry for the static triangle and its scan aperture.
class FoodVfdBackGeometry {
  const FoodVfdBackGeometry._();

  static const visualSize = Size(18, 18);
  static const scanLineWidth = 1.2;

  static Rect triangleVisualBoundsFor(Size size) => Rect.fromLTWH(
    size.width * .1,
    size.height * .08,
    size.width * .8,
    size.height * .84,
  );

  static Rect scanApertureFor(Size size) => triangleVisualBoundsFor(size);

  static Path trianglePathFor(Size size) {
    final bounds = triangleVisualBoundsFor(size);
    return Path()
      ..moveTo(bounds.left, bounds.center.dy)
      ..lineTo(bounds.right, bounds.top)
      ..lineTo(bounds.right, bounds.bottom)
      ..close();
  }

  static Rect scanLineBoundsFor(Size size, double position) {
    final aperture = scanApertureFor(size);
    final width = scanLineWidth.clamp(0.0, aperture.width).toDouble();
    final left = aperture.left + (aperture.width - width) * position;
    return Rect.fromLTWH(left, aperture.top, width, aperture.height);
  }

  /// The energized VFD electrode is never a free rectangular bar: this is
  /// its visible intersection with the very same path used for idle ◀.
  static Path scanPathFor(Size size, double position) => Path.combine(
    PathOperation.intersect,
    trianglePathFor(size),
    Path()..addRRect(
      RRect.fromRectAndRadius(
        scanLineBoundsFor(size, position),
        const Radius.circular(scanLineWidth / 2),
      ),
    ),
  );

  static Path afterglowPathFor(Size size) => scanPathFor(size, 0);
}

/// FOOD's shared visible Back control. System and browser Back paths remain
/// under Navigator's normal behavior; only this AppBar control animates.
class FoodVfdBackButton extends StatefulWidget {
  const FoodVfdBackButton({super.key});

  static const exitDuration = FoodVfdBackTiming.totalDuration;

  @override
  State<FoodVfdBackButton> createState() => _FoodVfdBackButtonState();
}

class _FoodVfdBackButtonState extends State<FoodVfdBackButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _popRequested = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: FoodVfdBackButton.exitDuration,
    );
  }

  void _handlePressed() {
    if (_popRequested || _controller.isAnimating) return;
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      _popOnce();
      return;
    }
    _controller.forward(from: 0).whenComplete(_popOnce);
  }

  void _popOnce() {
    if (!mounted || _popRequested) return;
    _popRequested = true;
    Navigator.maybePop(context);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tooltip = MaterialLocalizations.of(context).backButtonTooltip;
    return Semantics(
      button: true,
      label: tooltip,
      child: IconButton(
        key: const ValueKey('food-vfd-back'),
        tooltip: tooltip,
        onPressed: _handlePressed,
        icon: ExcludeSemantics(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) => _FoodVfdBackVisual(
              frame: FoodVfdBackTiming.frameFor(_controller.value),
            ),
          ),
        ),
      ),
    );
  }
}

class _FoodVfdBackVisual extends StatelessWidget {
  const _FoodVfdBackVisual({required this.frame});

  final FoodVfdBackFrame frame;

  @override
  Widget build(BuildContext context) => SizedBox(
    key: const ValueKey('food-vfd-back-aperture'),
    width: 18,
    height: 18,
    child: CustomPaint(
      key: const ValueKey('food-vfd-back-triangle'),
      painter: _FoodVfdBackPainter(frame),
      child: Stack(
        children: [
          if (frame.hasSweep)
            SizedBox(
              key: ValueKey('food-vfd-back-sweep-${frame.sweepIndex! + 1}'),
            ),
          if (frame.hasAfterglow)
            const SizedBox(key: ValueKey('food-vfd-back-afterglow')),
        ],
      ),
    ),
  );
}

class _FoodVfdBackPainter extends CustomPainter {
  const _FoodVfdBackPainter(this.frame);

  final FoodVfdBackFrame frame;

  @override
  void paint(Canvas canvas, Size size) {
    final triangle = FoodVfdBackGeometry.trianglePathFor(size);
    _drawEmission(canvas, triangle, frame.triangleOpacity, blur: 1.25);

    if (frame.hasSweep) {
      _paintTaperedScan(
        canvas,
        triangle,
        FoodVfdBackGeometry.scanPathFor(size, frame.scanPosition),
        frame.sweepIndex == 1 ? 1 : .9,
        blur: 1.1,
      );
    }

    if (frame.hasAfterglow) {
      _paintTaperedScan(
        canvas,
        triangle,
        FoodVfdBackGeometry.afterglowPathFor(size),
        frame.afterglowOpacity * .65,
        blur: 1.1,
      );
    }
  }

  void _paintTaperedScan(
    Canvas canvas,
    Path triangle,
    Path taperedColumn,
    double opacity, {
    required double blur,
  }) {
    canvas
      ..save()
      ..clipPath(triangle);
    _drawEmission(canvas, taperedColumn, opacity, blur: blur);
    canvas.restore();
  }

  void _drawEmission(
    Canvas canvas,
    Path path,
    double opacity, {
    required double blur,
  }) {
    if (opacity <= 0) return;
    canvas.drawPath(
      path,
      Paint()
        ..color = FoodVfdScaleDisplayTitle.bloomEmissionColor.withValues(
          alpha: FoodVfdScaleDisplayTitle.bloomEmissionColor.a * opacity,
        )
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = FoodVfdScaleDisplayTitle.activeEmissionColor.withValues(
          alpha: opacity,
        ),
    );
  }

  @override
  bool shouldRepaint(covariant _FoodVfdBackPainter oldDelegate) =>
      oldDelegate.frame != frame;
}
