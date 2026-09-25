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
/// Geometry and motion remain wholly in the existing V2.10 presentation
/// implementation. A chain reuses its original direction while every CAT
/// independently receives one of the five accepted coat variants.
class DashboardCatRunStage extends StatefulWidget {
  const DashboardCatRunStage({
    super.key,
    this.random,
    this.minimumInterval = const Duration(seconds: 30),
    this.maximumInterval = const Duration(seconds: 60),
  });

  static const height = CatRunV24Travel.stageHeight;

  /// Single production-only size control. 0.50–0.75 is the approved tuning
  /// envelope; source vectors and the sandbox preview remain untouched.
  static const productionScale = .75;
  static const productionCatUnit = CatRunV23Travel.catUnit * productionScale;
  static const groundInset = 5.0;
  static const groundLineColor = Color(0xFF383838);
  static const chainContinueProbability = .2;
  static const chainStopProbability = .8;
  static const chainFollowerTriggerProgress = .50;
  static const stageKey = ValueKey('dashboard-production-cat-stage');
  static const activeKey = ValueKey('dashboard-production-cat-active');

  final math.Random? random;
  final Duration minimumInterval;
  final Duration maximumInterval;

  /// A single five-way roll deliberately has no chain-length input or cap.
  static bool chainContinuesForRoll(int roll) {
    if (roll < 0 || roll >= 5) throw ArgumentError.value(roll, 'roll');
    return roll == 0;
  }

  @override
  DashboardCatRunStageState createState() => DashboardCatRunStageState();
}

class DashboardCatRunStageState extends State<DashboardCatRunStage>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final math.Random _random = widget.random ?? math.Random();
  late final AnimationController _controller =
      AnimationController.unbounded(vsync: this)
        ..addListener(_advanceChain)
        ..addStatusListener(_onAnimationStatus);
  Timer? _nextAppearanceTimer;
  final List<_ScheduledCatCrossing> _chain = [];
  CatRunV23Direction? _chainDirection;
  bool _appActive = true;
  bool _tickerEnabled = true;
  bool _reducedMotion = false;
  bool _measured = false;

  bool get _hasActiveCrossing => _chain.isNotEmpty;
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
      if (!_controller.isAnimating) _continueChain();
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
        _chain.clear();
        _chainDirection = null;
      });
    } else {
      _chain.clear();
      _chainDirection = null;
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
    final direction = _next(2) == 0
        ? CatRunV23Direction.leftToRight
        : CatRunV23Direction.rightToLeft;
    setState(() {
      _chainDirection = direction;
      _chain.add(
        _ScheduledCatCrossing(
          startedAtProgress: 0,
          coatVariant: CatRunCoatPatterns.chooseRandom(_random),
        ),
      );
    });
    _controller.value = 0;
    _continueChain();
  }

  /// Starts one normal production event immediately. This deliberately uses
  /// the same direction, coat, chain, and renderer path as the scheduler.
  /// A running chain remains the sole active event, so rapid manual taps are
  /// ignored rather than queued.
  bool triggerManualAppearance() {
    if (!_motionAllowed || !_measured || _hasActiveCrossing) return false;
    _nextAppearanceTimer?.cancel();
    _nextAppearanceTimer = null;
    _startCrossing();
    return true;
  }

  void _continueChain() {
    if (!_motionAllowed || _chain.isEmpty) return;
    final finalProgress = _chain.last.startedAtProgress + 1;
    final remaining = (finalProgress - _controller.value).clamp(0.0, 1e9);
    _controller.animateTo(
      finalProgress,
      duration: Duration(
        microseconds:
            (CatRunV24Travel.crossingDuration.inMicroseconds * remaining)
                .round(),
      ),
      curve: Curves.linear,
    );
  }

  void _advanceChain() {
    if (!_motionAllowed || _chain.isEmpty) return;
    var changed = false;
    for (final crossing in _chain.toList(growable: false)) {
      final progress = _controller.value - crossing.startedAtProgress;
      if (!crossing.continuationRolled &&
          progress >= DashboardCatRunStage.chainFollowerTriggerProgress) {
        crossing.continuationRolled = true;
        if (DashboardCatRunStage.chainContinuesForRoll(_next(5))) {
          _chain.add(
            _ScheduledCatCrossing(
              startedAtProgress: _controller.value,
              coatVariant: CatRunCoatPatterns.chooseRandom(_random),
            ),
          );
        }
        changed = true;
      }
    }
    if (changed) {
      setState(() {});
      _continueChain();
    }
  }

  void _onAnimationStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || !mounted) return;
    if (_chain.any((crossing) => !crossing.continuationRolled)) return;
    setState(() {
      _chain.clear();
      _chainDirection = null;
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
                  builder: (context, _) {
                    final crossings = [
                      for (final crossing in _chain)
                        CatRunV23Crossing(
                          progress:
                              _controller.value - crossing.startedAtProgress,
                          direction: _chainDirection!,
                          coatVariant: crossing.coatVariant,
                        ),
                    ];
                    return ClipRect(
                      child: CustomPaint(
                        key: active
                            ? DashboardCatRunStage.activeKey
                            : const ValueKey('dashboard-production-cat-idle'),
                        painter: active
                            ? CatRunV23StagePainter(
                                progress: _controller.value,
                                direction: _chainDirection!,
                                coatVariant: _chain.first.coatVariant,
                                crossings: crossings,
                                catUnit: DashboardCatRunStage.productionCatUnit,
                                showGroundLine: true,
                                groundInset: DashboardCatRunStage.groundInset,
                                groundLineColor:
                                    DashboardCatRunStage.groundLineColor,
                              )
                            : null,
                        foregroundPainter: active
                            ? null
                            : _ProductionStageBackgroundPainter(),
                        willChange: active,
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _ScheduledCatCrossing {
  _ScheduledCatCrossing({
    required this.startedAtProgress,
    required this.coatVariant,
  });

  final double startedAtProgress;
  final CatRunCoatVariant coatVariant;
  bool continuationRolled = false;
}

class _ProductionStageBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF101010),
    );
    canvas.drawLine(
      Offset(0, size.height - DashboardCatRunStage.groundInset),
      Offset(size.width, size.height - DashboardCatRunStage.groundInset),
      Paint()
        ..color = DashboardCatRunStage.groundLineColor
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(covariant _ProductionStageBackgroundPainter oldDelegate) =>
      false;
}
