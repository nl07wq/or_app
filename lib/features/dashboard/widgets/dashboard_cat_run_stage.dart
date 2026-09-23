import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../system/pages/cat_run_coat_patterns.dart';
import '../../system/pages/cat_run_v23_production_preview.dart';
import '../../system/pages/cat_run_v24_presentation.dart';

/// Resolves the single stage's visual position. When its document slot is
/// below the viewport it occupies the safe viewport bottom; as the slot
/// arrives it follows that one natural final-row location without duplication.
Rect dashboardAdaptiveCatStageRect({
  required Rect naturalSlotRect,
  required Size viewportSize,
  required double safeBottom,
}) {
  final pinnedTop =
      viewportSize.height - safeBottom - DashboardCatRunStage.height;
  return Rect.fromLTWH(
    naturalSlotRect.left,
    math.min(naturalSlotRect.top, pinnedTop),
    naturalSlotRect.width,
    DashboardCatRunStage.height,
  );
}

/// The sparse production scheduler for the accepted frozen CAT run.
///
/// It selects one coat and direction per completed crossing. Geometry and
/// motion remain wholly in the existing V2.10 presentation implementation.
class DashboardCatRunStage extends StatefulWidget {
  const DashboardCatRunStage({
    super.key,
    this.random,
    this.minimumInterval = const Duration(seconds: 45),
    this.maximumInterval = const Duration(seconds: 90),
  });

  static const height = CatRunV24Travel.stageHeight;
  static const stageKey = ValueKey('dashboard-production-cat-stage');
  static const activeKey = ValueKey('dashboard-production-cat-active');

  final math.Random? random;
  final Duration minimumInterval;
  final Duration maximumInterval;

  @override
  State<DashboardCatRunStage> createState() => _DashboardCatRunStageState();
}

class _DashboardCatRunStageState extends State<DashboardCatRunStage>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final math.Random _random = widget.random ?? math.Random();
  late final AnimationController _controller = AnimationController(vsync: this)
    ..addStatusListener(_onAnimationStatus);
  Timer? _nextAppearanceTimer;
  CatRunCoatVariant? _coat;
  CatRunV23Direction? _direction;
  bool _appActive = true;
  bool _tickerEnabled = true;
  bool _reducedMotion = false;
  bool _measured = false;

  bool get _hasActiveCrossing => _coat != null && _direction != null;
  bool get _motionAllowed =>
      mounted && _appActive && _tickerEnabled && !_reducedMotion;

  int _next(int max) => _random.nextInt(max);

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
    _syncScheduling();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appActive = state == AppLifecycleState.resumed;
    _syncScheduling();
  }

  Duration _nextInterval() {
    final minimum = widget.minimumInterval;
    final maximum = widget.maximumInterval;
    assert(maximum >= minimum);
    final span = maximum.inMilliseconds - minimum.inMilliseconds;
    return minimum + Duration(milliseconds: span == 0 ? 0 : _next(span + 1));
  }

  void _syncScheduling() {
    if (_reducedMotion) {
      _cancelAndClear();
      return;
    }
    if (!_motionAllowed) {
      _nextAppearanceTimer?.cancel();
      _nextAppearanceTimer = null;
      _controller.stop();
      return;
    }
    if (_hasActiveCrossing) {
      if (!_controller.isAnimating) _controller.forward();
      return;
    }
    if (_measured && _nextAppearanceTimer == null) _scheduleNextAppearance();
  }

  void _cancelAndClear() {
    _nextAppearanceTimer?.cancel();
    _nextAppearanceTimer = null;
    _controller.stop();
    if (_hasActiveCrossing && mounted) {
      setState(() {
        _coat = null;
        _direction = null;
      });
    } else {
      _coat = null;
      _direction = null;
    }
  }

  void _scheduleNextAppearance() {
    if (!_motionAllowed ||
        !_measured ||
        _hasActiveCrossing ||
        _nextAppearanceTimer != null) {
      return;
    }
    _nextAppearanceTimer = Timer(_nextInterval(), () {
      _nextAppearanceTimer = null;
      _startCrossing();
    });
  }

  void _startCrossing() {
    if (!_motionAllowed || !_measured || _hasActiveCrossing) return;
    setState(() {
      _coat = CatRunCoatPatterns.chooseRandom(_random);
      _direction = _next(2) == 0
          ? CatRunV23Direction.leftToRight
          : CatRunV23Direction.rightToLeft;
    });
    _controller
      ..duration = CatRunV24Travel.crossingDuration
      ..forward(from: 0);
  }

  void _onAnimationStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || !mounted) return;
    setState(() {
      _coat = null;
      _direction = null;
    });
    // The delay deliberately begins only after the CAT is fully offstage.
    _scheduleNextAppearance();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _nextAppearanceTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ExcludeSemantics(
        child: RepaintBoundary(
          child: SizedBox(
            key: DashboardCatRunStage.stageKey,
            height: DashboardCatRunStage.height,
            width: double.infinity,
            child: LayoutBuilder(
              builder: (context, constraints) {
                _measured = constraints.maxWidth > 0;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) _syncScheduling();
                });
                final active = _hasActiveCrossing && !_reducedMotion;
                return AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) => ClipRect(
                    child: CustomPaint(
                      key: active
                          ? DashboardCatRunStage.activeKey
                          : const ValueKey('dashboard-production-cat-idle'),
                      painter: active
                          ? CatRunV23StagePainter(
                              progress: _controller.value,
                              direction: _direction!,
                              coatVariant: _coat!,
                            )
                          : null,
                      foregroundPainter: active
                          ? null
                          : _ProductionStageBackgroundPainter(),
                      willChange: active,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _ProductionStageBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF101010),
    );
  }

  @override
  bool shouldRepaint(covariant _ProductionStageBackgroundPainter oldDelegate) =>
      false;
}
