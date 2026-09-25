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
    this.onEventActiveChanged,
    this.onEventMetadataChanged,
  });

  static const height = CatRunV24Travel.stageHeight;

  /// Single production-only size control. 0.50–0.75 is the approved tuning
  /// envelope; source vectors and the sandbox preview remain untouched.
  static const productionScale = .75;
  static const productionCatUnit = CatRunV23Travel.catUnit * productionScale;
  static const groundInset = 5.0;
  static const groundLineColor = Color(0xFF383838);
  static const chainContinueProbability = CatRunProductionEventPolicy.chainContinueProbability;
  static const chainStopProbability = CatRunProductionEventPolicy.chainStopProbability;
  static const chainFollowerTriggerProgress = CatRunProductionEventPolicy.normalFollowerTriggerProgress;
  static const glitchProbability = CatRunProductionEventPolicy.glitchProbability;
  static const normalEventProbability = CatRunProductionEventPolicy.normalEventProbability;
  static const glitchCatCount = CatRunProductionEventPolicy.glitchCatCount;
  static const glitchFollowerTriggerProgress = CatRunProductionEventPolicy.glitchFollowerTriggerProgress;
  static const stageKey = ValueKey('dashboard-production-cat-stage');
  static const activeKey = ValueKey('dashboard-production-cat-active');

  final math.Random? random;
  final Duration minimumInterval;
  final Duration maximumInterval;
  final ValueChanged<bool>? onEventActiveChanged;
  final ValueChanged<DashboardCatEventMetadata>? onEventMetadataChanged;

  /// A single five-way roll deliberately has no chain-length input or cap.
  static bool chainContinuesForRoll(int roll) {
    return CatRunProductionEventPolicy.chainContinuesForRoll(roll);
  }

  /// The event roll is sampled once per auto or manual appearance event.
  static DashboardCatEventKind eventKindForRoll(int roll) {
    return CatRunProductionEventPolicy.isGlitchRoll(roll)
        ? DashboardCatEventKind.glitch
        : DashboardCatEventKind.normal;
  }

  @override
  DashboardCatRunStageState createState() => DashboardCatRunStageState();
}

enum DashboardCatEventKind { normal, glitch }

class DashboardCatEventMetadata {
  const DashboardCatEventMetadata({
    required this.source,
    required this.eventRoll,
    required this.eventKind,
    required this.direction,
    required this.plannedCatCount,
    required this.spawnedCatCount,
    required this.completedCatCount,
    required this.active,
    required this.completed,
  });

  final CatRunProductionEventSource source;
  final int? eventRoll;
  final DashboardCatEventKind eventKind;
  final CatRunV23Direction direction;
  final int plannedCatCount;
  final int spawnedCatCount;
  final int completedCatCount;
  final bool active;
  final bool completed;
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
  DashboardCatEventKind? _eventKind;
  CatRunProductionEventPlan? _eventPlan;
  bool _appActive = true;
  bool _tickerEnabled = true;
  bool _reducedMotion = false;
  bool _measured = false;
  bool _lastPublishedEventActive = false;
  DashboardCatEventMetadata? _lastEventMetadata;

  bool get _hasActiveCrossing => _chain.isNotEmpty;
  bool get _motionAllowed =>
      mounted && _appActive && _tickerEnabled && !_reducedMotion;

  int _next(int max) => _random.nextInt(max);

  void _publishEventActivity() {
    final active = _hasActiveCrossing;
    if (_lastPublishedEventActive == active) return;
    _lastPublishedEventActive = active;
    widget.onEventActiveChanged?.call(active);
  }

  void _publishEventMetadata({required bool completed}) {
    final plan = _eventPlan;
    final direction = _chainDirection;
    final kind = _eventKind;
    if (plan == null || direction == null || kind == null) return;
    final completedCount = completed
        ? _chain.length
        : _chain
              .where(
                (crossing) =>
                    _controller.value - crossing.startedAtProgress >= 1,
              )
              .length;
    final metadata = DashboardCatEventMetadata(
      source: plan.source,
      eventRoll: plan.eventRoll,
      eventKind: kind,
      direction: direction,
      plannedCatCount: _chain.length,
      spawnedCatCount: _chain.length,
      completedCatCount: completedCount,
      active: !completed,
      completed: completed,
    );
    final previous = _lastEventMetadata;
    if (previous != null &&
        previous.source == metadata.source &&
        previous.eventRoll == metadata.eventRoll &&
        previous.eventKind == metadata.eventKind &&
        previous.direction == metadata.direction &&
        previous.plannedCatCount == metadata.plannedCatCount &&
        previous.spawnedCatCount == metadata.spawnedCatCount &&
        previous.completedCatCount == metadata.completedCatCount &&
        previous.active == metadata.active &&
        previous.completed == metadata.completed) {
      return;
    }
    _lastEventMetadata = metadata;
    widget.onEventMetadataChanged?.call(metadata);
  }

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
        _eventKind = null;
        _eventPlan = null;
      });
    } else {
      _chain.clear();
      _chainDirection = null;
      _eventKind = null;
      _eventPlan = null;
    }
    _publishEventActivity();
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
      _startSampledEvent(CatRunProductionEventSource.automatic);
    });
  }

  void _startSampledEvent(CatRunProductionEventSource source) {
    _startEvent(CatRunProductionEventPlan.sampled(source: source, random: _random));
  }

  void _startEvent(CatRunProductionEventPlan plan) {
    if (!_motionAllowed || !_measured || _hasActiveCrossing) return;
    setState(() {
      _eventPlan = plan;
      _chainDirection = plan.direction;
      _eventKind = plan.isGlitch
          ? DashboardCatEventKind.glitch
          : DashboardCatEventKind.normal;
      _chain.addAll(
        plan.crossings.map(
          (crossing) => _ScheduledCatCrossing(
            startedAtProgress: crossing.startedAtProgress,
            coatVariant: crossing.coatVariant,
            continuationRolled: crossing.continuationRolled,
          ),
        ),
      );
    });
    _publishEventActivity();
    _controller.value = 0;
    _publishEventMetadata(completed: false);
    _continueChain();
  }

  /// Starts one production event immediately. This deliberately uses the same
  /// NORMAL/GLITCH roll, direction, coat, chain, and renderer path as the
  /// scheduler.
  /// A running chain remains the sole active event, so rapid manual taps are
  /// ignored rather than queued.
  bool triggerManualAppearance() {
    if (!_motionAllowed || !_measured || _hasActiveCrossing) return false;
    _nextAppearanceTimer?.cancel();
    _nextAppearanceTimer = null;
    _startSampledEvent(CatRunProductionEventSource.manual);
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
      if (_eventPlan?.allowsRecursiveContinuation == true &&
          !crossing.continuationRolled &&
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
      _publishEventMetadata(completed: false);
      _continueChain();
    }
    _publishEventMetadata(completed: false);
  }

  void _onAnimationStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || !mounted) return;
    if (_chain.any((crossing) => !crossing.continuationRolled)) return;
    _publishEventMetadata(completed: true);
    setState(() {
      _chain.clear();
      _chainDirection = null;
      _eventKind = null;
      _eventPlan = null;
    });
    _publishEventActivity();
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
    this.continuationRolled = false,
  });

  final double startedAtProgress;
  final CatRunCoatVariant coatVariant;
  bool continuationRolled;
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
