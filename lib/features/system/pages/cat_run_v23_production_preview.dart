import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/operation_card.dart';
import '../../../core/widgets/section_header.dart';
import 'cat_run_v2_registration.dart';
import 'cat_run_v2_trace_data.dart';
import 'cat_run_coat_patterns.dart';
import 'cat_run_v24_presentation.dart';

/// Preview-only presentation tuning. It never changes the CAT's travel
/// progress, duration, source frames, or production geometry.
@immutable
class CatRunV23SmoothTuning {
  const CatRunV23SmoothTuning({
    required this.blendDuration,
    required this.maximumVisualAnchorOffset,
    required this.maximumVerticalAnchorOffset,
  });

  final Duration blendDuration;
  final double maximumVisualAnchorOffset;
  final double maximumVerticalAnchorOffset;
}

/// Preview-only overlap window for comparing direct CAT pose swaps with a
/// short, ground-registered transition. It does not change travel progress,
/// duration, source frame order, or canonical geometry.
@immutable
class CatRunV23PoseBlendTuning {
  const CatRunV23PoseBlendTuning({required this.transitionDuration});

  final Duration transitionDuration;
}

/// Measured presentation geometry for one frozen CAT pose. This is kept next
/// to the production renderer so the comparison profiles are audited against
/// the same corrected paths that Dashboard paints.
@immutable
class CatRunV23PoseGeometry {
  const CatRunV23PoseGeometry({
    required this.frame,
    required this.duration,
    required this.visibleBounds,
    required this.visibleCenter,
    required this.groundContactY,
  });

  final int frame;
  final Duration duration;
  final Rect visibleBounds;
  final Offset visibleCenter;
  final double groundContactY;
}

@immutable
class CatRunV23PoseBlendState {
  const CatRunV23PoseBlendState({
    required this.outgoingFrame,
    required this.incomingFrame,
    required this.incomingOpacity,
  });

  final int outgoingFrame;
  final int incomingFrame;
  final double incomingOpacity;
}

/// Presentation-only travel model for V2.2's frozen registered HIGH frames.
/// It does not alter source geometry, registration, contact metadata, or timing.
class CatRunV23Travel {
  CatRunV23Travel._();

  static const stageHeight = CatRunV24Travel.stageHeight;
  static const catUnit = CatRunV24Travel.catUnit;
  static const offstagePadding = CatRunV24Travel.offstagePadding;
  static const crossingDuration = CatRunV24Travel.crossingDuration;

  static double horizontalPosition({
    required double stageWidth,
    required double progress,
  }) {
    final safeProgress = progress.clamp(0.0, 1.0).toDouble();
    return -offstagePadding +
        (stageWidth + (offstagePadding * 2)) * safeProgress;
  }

  static double velocityFor(double stageWidth) =>
      (stageWidth + (offstagePadding * 2)) /
      crossingDuration.inMilliseconds *
      1000;

  /// Global event progress advances at one individual CAT crossing per
  /// [crossingDuration]. A staggered group extends its range, not its speed.
  static Duration durationForGlobalProgress(double progress) => Duration(
    microseconds: (crossingDuration.inMicroseconds * progress).round(),
  );

  static double globalProgressAt(Duration elapsed) =>
      elapsed.inMicroseconds / crossingDuration.inMicroseconds;

  static int frameAtTravelProgress(double progress) {
    final safeProgress = progress.clamp(0.0, 0.999999).toDouble();
    final elapsedMicroseconds = (crossingDuration.inMicroseconds * safeProgress)
        .round();
    final cycleMicroseconds = CatRunV2Registration.cycleDuration.inMicroseconds;
    final cycleProgress =
        (elapsedMicroseconds % cycleMicroseconds) / cycleMicroseconds;
    return CatRunV2Registration.frameAtCycleProgress(cycleProgress);
  }

  /// Resolves a cycle-only pose offset without changing the crossing's travel
  /// progress. The returned value stays within one pose cycle so callers can
  /// safely use it for frame/anchor selection only.
  static double poseProgressForPhaseOffset({
    required double travelProgress,
    required double phaseOffset,
  }) {
    final cycles =
        (travelProgress *
            crossingDuration.inMicroseconds /
            CatRunV28Timing.cycleDuration.inMicroseconds) +
        phaseOffset;
    final wrappedCycles = cycles - cycles.floorToDouble();
    return wrappedCycles *
        CatRunV28Timing.cycleDuration.inMicroseconds /
        crossingDuration.inMicroseconds;
  }

  static List<Offset> registeredPointsAt(double progress) =>
      CatRunV24Travel.pointsAt(progress);

  /// Keeps the CAT silhouette's visual centre stable across direct pose
  /// swaps. Registration already preserves the anatomical torso/ground
  /// anchors; this small, bounded presentation correction removes only the
  /// remaining outer-contour shift visible in Dashboard Preview's SMOOTH
  /// profile. It never changes crossing progress, frame order, or timing.
  static Offset smoothVisualAnchorOffsetAt(
    double progress, {
    CatRunV23SmoothTuning tuning = smoothBTuning,
  }) {
    final cycleDuration = CatRunV28Timing.cycleDuration.inMicroseconds;
    final elapsed =
        (crossingDuration.inMicroseconds *
                progress.clamp(0.0, .999999).toDouble())
            .round();
    final cycleElapsed = elapsed % cycleDuration;
    var frameStart = 0;
    for (
      var index = 0;
      index < CatRunV28Timing.frameDurations.length;
      index++
    ) {
      final duration = CatRunV28Timing.frameDurations[index].inMicroseconds;
      final frameEnd = frameStart + duration;
      if (cycleElapsed < frameEnd) {
        final local = cycleElapsed - frameStart;
        final requestedHalfBlendMicroseconds =
            tuning.blendDuration.inMicroseconds ~/ 2;
        final halfBlendMicroseconds = math.min(
          requestedHalfBlendMicroseconds,
          duration ~/ 2,
        );
        final blendMicroseconds = halfBlendMicroseconds * 2;
        final current = _boundedSmoothAnchorOffset(
          _rawSmoothVisualAnchorOffsets[index],
          tuning,
        );
        if (blendMicroseconds == 0) return current;
        if (local < halfBlendMicroseconds) {
          final previous = _boundedSmoothAnchorOffset(
            _rawSmoothVisualAnchorOffsets[(index -
                    1 +
                    _rawSmoothVisualAnchorOffsets.length) %
                _rawSmoothVisualAnchorOffsets.length],
            tuning,
          );
          return Offset.lerp(
            previous,
            current,
            _smoothStep((halfBlendMicroseconds + local) / blendMicroseconds),
          )!;
        }
        if (local > duration - halfBlendMicroseconds) {
          final next = _boundedSmoothAnchorOffset(
            _rawSmoothVisualAnchorOffsets[(index + 1) %
                _rawSmoothVisualAnchorOffsets.length],
            tuning,
          );
          return Offset.lerp(
            current,
            next,
            _smoothStep(
              (local - (duration - halfBlendMicroseconds)) / blendMicroseconds,
            ),
          )!;
        }
        return current;
      }
      frameStart = frameEnd;
    }
    return _boundedSmoothAnchorOffset(
      _rawSmoothVisualAnchorOffsets.first,
      tuning,
    );
  }

  /// The retained Preview comparison baseline. It normalizes visible frame
  /// centers and vertical body movement without changing travel timing.
  static const smoothBTuning = CatRunV23SmoothTuning(
    blendDuration: Duration(milliseconds: 150),
    maximumVisualAnchorOffset: .045,
    maximumVerticalAnchorOffset: .040,
  );

  /// A stronger Preview-only comparison that leaves the horizontal crossing
  /// linear while allowing more of each pose's measured center correction.
  static const smoothCTuning = CatRunV23SmoothTuning(
    blendDuration: Duration(milliseconds: 210),
    maximumVisualAnchorOffset: .060,
    maximumVerticalAnchorOffset: .050,
  );

  /// The deliberately strongest safe Preview-only comparison. It is not a
  /// production default and still only translates the presentation layer.
  static const smoothMaxTuning = CatRunV23SmoothTuning(
    blendDuration: Duration(milliseconds: 250),
    maximumVisualAnchorOffset: .070,
    maximumVerticalAnchorOffset: .060,
  );

  /// The two Preview-only candidates are deliberately short: they soften the
  /// direct 25–30ms pose swaps without changing the CAT's crossing clock.
  static const poseBlendATuning = CatRunV23PoseBlendTuning(
    transitionDuration: Duration(milliseconds: 25),
  );

  static const poseBlendBTuning = CatRunV23PoseBlendTuning(
    transitionDuration: Duration(milliseconds: 50),
  );

  /// Frame geometry audit for the corrected production paths. The varied
  /// bounds/centres confirm that a translation-only correction cannot remove
  /// the underlying head, torso, paw, and silhouette shape transition.
  static List<CatRunV23PoseGeometry> get poseGeometryAudit =>
      List<CatRunV23PoseGeometry>.unmodifiable([
        for (var frame = 0; frame < catRunV2HighTraces.length; frame++)
          () {
            final path = Path()
              ..addPolygon(
                CatRunV24ScaleAudit.correctedPoints(catRunV2HighTraces[frame]),
                true,
              );
            final bounds = path.getBounds();
            return CatRunV23PoseGeometry(
              frame: frame,
              duration: CatRunV28Timing.frameDurations[frame],
              visibleBounds: bounds,
              visibleCenter: bounds.center,
              groundContactY: CatRunV2Registration.virtualGround,
            );
          }(),
      ]);

  /// Returns a short outgoing/incoming overlap immediately after each frame
  /// boundary. Outside that window the production incoming pose is painted
  /// directly, preserving the frozen cadence and order.
  static CatRunV23PoseBlendState? poseBlendStateAt(
    double progress, {
    required CatRunV23PoseBlendTuning tuning,
  }) {
    final cycleDuration = CatRunV28Timing.cycleDuration.inMicroseconds;
    final elapsed =
        (crossingDuration.inMicroseconds * progress.clamp(0.0, .999999))
            .round();
    final cycleElapsed = elapsed % cycleDuration;
    var frameStart = 0;
    for (
      var frame = 0;
      frame < CatRunV28Timing.frameDurations.length;
      frame++
    ) {
      final frameDuration =
          CatRunV28Timing.frameDurations[frame].inMicroseconds;
      final frameEnd = frameStart + frameDuration;
      if (cycleElapsed < frameEnd) {
        final localElapsed = cycleElapsed - frameStart;
        final blendMicroseconds = math.min(
          tuning.transitionDuration.inMicroseconds,
          frameDuration,
        );
        if (localElapsed >= blendMicroseconds || blendMicroseconds == 0) {
          return null;
        }
        return CatRunV23PoseBlendState(
          outgoingFrame:
              (frame - 1 + CatRunV28Timing.frameDurations.length) %
              CatRunV28Timing.frameDurations.length,
          incomingFrame: frame,
          incomingOpacity: localElapsed / blendMicroseconds,
        );
      }
      frameStart = frameEnd;
    }
    return null;
  }

  static double poseProgressForFrame(int frame) {
    final frameDurations = CatRunV28Timing.frameDurations;
    final elapsed =
        frameDurations
            .take(frame)
            .fold<int>(
              0,
              (total, duration) => total + duration.inMicroseconds,
            ) +
        (frameDurations[frame].inMicroseconds ~/ 2);
    return elapsed / crossingDuration.inMicroseconds;
  }

  /// Returns the production-presentation visible bounds for a single CAT at a
  /// given progress. The result is intentionally based on the registered
  /// silhouette path, rather than canvas spacing or an asset rectangle.
  static Rect visibleBoundsAt({
    required double stageWidth,
    required double progress,
    required double catUnit,
    required CatRunV23Direction direction,
  }) {
    final points = registeredPointsAt(progress);
    final localBounds = (Path()..addPolygon(points, true)).getBounds();
    final travelX = CatRunV24Travel.horizontalPosition(
      stageWidth: stageWidth,
      progress: progress,
    );
    if (direction == CatRunV23Direction.leftToRight) {
      return Rect.fromLTRB(
        travelX + localBounds.left * catUnit,
        localBounds.top * catUnit,
        travelX + localBounds.right * catUnit,
        localBounds.bottom * catUnit,
      );
    }
    final originX = stageWidth - travelX;
    return Rect.fromLTRB(
      originX - localBounds.right * catUnit,
      localBounds.top * catUnit,
      originX - localBounds.left * catUnit,
      localBounds.bottom * catUnit,
    );
  }

  /// Measures the empty visible space between a leading CAT and its immediate
  /// follower after stage scale and direction have been applied. A negative
  /// result denotes silhouette overlap.
  static double visibleFollowerGap({
    required double stageWidth,
    required double eventProgress,
    required double followerTriggerProgress,
    required double catUnit,
    required CatRunV23Direction direction,
  }) {
    final leader = visibleBoundsAt(
      stageWidth: stageWidth,
      progress: eventProgress,
      catUnit: catUnit,
      direction: direction,
    );
    final follower = visibleBoundsAt(
      stageWidth: stageWidth,
      progress: eventProgress - followerTriggerProgress,
      catUnit: catUnit,
      direction: direction,
    );
    return direction == CatRunV23Direction.leftToRight
        ? leader.left - follower.right
        : follower.left - leader.right;
  }

  static final _rawSmoothVisualAnchorOffsets = () {
    final centers = catRunV2HighTraces
        .map((trace) {
          final path = Path()
            ..addPolygon(CatRunV24ScaleAudit.correctedPoints(trace), true);
          return path.getBounds().center;
        })
        .toList(growable: false);
    final meanCenter = Offset(
      centers.map((center) => center.dx).reduce((a, b) => a + b) /
          centers.length,
      centers.map((center) => center.dy).reduce((a, b) => a + b) /
          centers.length,
    );
    return List<Offset>.unmodifiable(
      centers
          .map((center) {
            return meanCenter - center;
          })
          .toList(growable: false),
    );
  }();

  /// Bounds horizontal and vertical correction separately. The dedicated Y
  /// cap keeps pose-to-pose body height continuous without allowing a CAT to
  /// float away from its registered ground contact.
  static Offset _boundedSmoothAnchorOffset(
    Offset raw,
    CatRunV23SmoothTuning tuning,
  ) {
    final horizontal = raw.dx.clamp(
      -tuning.maximumVisualAnchorOffset,
      tuning.maximumVisualAnchorOffset,
    );
    final vertical = raw.dy.clamp(
      -tuning.maximumVerticalAnchorOffset,
      tuning.maximumVerticalAnchorOffset,
    );
    return Offset(horizontal, vertical);
  }

  static double _smoothStep(double value) {
    final t = value.clamp(0.0, 1.0).toDouble();
    return t * t * (3 - (2 * t));
  }
}

/// One complete, frozen-vector CAT crossing. The dashboard may paint multiple
/// instances when a same-direction production chain is active; each instance
/// still owns one coat and one immutable traversal progress value.
class CatRunV23Crossing {
  const CatRunV23Crossing({
    required this.progress,
    required this.direction,
    required this.coatVariant,
    this.posePhaseOffset = 0,
  });

  final double progress;
  final CatRunV23Direction direction;
  final CatRunCoatVariant coatVariant;
  final double posePhaseOffset;
}

/// Frozen production event policy shared by the Dashboard scheduler and the
/// Sandbox inspection controls. Keeping these values here lets Sandbox force
/// the exact production plan instead of maintaining a look-alike sequence.
class CatRunProductionEventPolicy {
  CatRunProductionEventPolicy._();

  static const chainContinueProbability = .3;
  static const chainStopProbability = .7;
  static const normalFollowerTriggerProgress = .15;
  static const glitchProbability = .05;
  static const normalEventProbability = .95;
  static const glitchCatCount = 10;

  /// A dense rare-event procession. This is deliberately independent from
  /// normal-chain spacing so CAT ×1/×2/×3 presentation remains unchanged.
  static const glitchFollowerTriggerProgress = .025;

  static bool isGlitchRoll(int roll) {
    if (roll < 0 || roll >= 20) throw ArgumentError.value(roll, 'roll');
    return roll == 0;
  }

  static bool chainContinuesForRoll(int roll) {
    if (roll < 0 || roll >= 10) throw ArgumentError.value(roll, 'roll');
    return roll < 3;
  }
}

/// Origin of an observable production CAT event. Sandbox plans are explicit
/// and never alter the AUTO/MANUAL probability policy.
enum CatRunProductionEventSource { automatic, manual, sandbox }

/// Immutable crossing scheduled by the shared production event executor.
class CatRunProductionScheduledCrossing {
  CatRunProductionScheduledCrossing({
    required this.startedAtProgress,
    required this.coatVariant,
    this.continuationRolled = false,
  });

  final double startedAtProgress;
  final CatRunCoatVariant coatVariant;
  bool continuationRolled;
}

/// Runtime authority for the recursive Production CAT chain. Dashboard and
/// Ambient consumers share this executor; renderers only consume crossings.
class CatRunProductionEventExecutor {
  CatRunProductionEventExecutor({
    required this.plan,
    required math.Random random,
  }) : _random = random,
       crossings = plan.crossings
           .map(
             (crossing) => CatRunProductionScheduledCrossing(
               startedAtProgress: crossing.startedAtProgress,
               coatVariant: crossing.coatVariant,
               continuationRolled: crossing.continuationRolled,
             ),
           )
           .toList();

  final CatRunProductionEventPlan plan;
  final math.Random _random;
  final List<CatRunProductionScheduledCrossing> crossings;

  bool advance(double eventProgress) {
    if (!plan.allowsRecursiveContinuation) return false;
    var changed = false;
    for (final crossing in List.of(crossings)) {
      if (crossing.continuationRolled ||
          eventProgress - crossing.startedAtProgress <
              CatRunProductionEventPolicy.normalFollowerTriggerProgress) {
        continue;
      }
      crossing.continuationRolled = true;
      if (CatRunProductionEventPolicy.chainContinuesForRoll(
        _random.nextInt(10),
      )) {
        crossings.add(
          CatRunProductionScheduledCrossing(
            startedAtProgress: eventProgress,
            coatVariant: CatRunCoatPatterns.chooseRandom(_random),
          ),
        );
      }
      changed = true;
    }
    return changed;
  }

  bool get isComplete =>
      crossings.every((crossing) => crossing.continuationRolled);

  double get finalProgress => crossings.last.startedAtProgress + 1;
}

/// The initial, deterministic portion of one production event. Normal events
/// append recursive followers at runtime; GLITCH and Sandbox force plans are
/// complete at construction time and use the same scheduled crossings.
class CatRunProductionEventPlan {
  const CatRunProductionEventPlan._({
    required this.source,
    required this.eventRoll,
    required this.isGlitch,
    required this.direction,
    required this.crossings,
    required this.allowsRecursiveContinuation,
  });

  factory CatRunProductionEventPlan.sampled({
    required CatRunProductionEventSource source,
    required math.Random random,
  }) {
    final eventRoll = random.nextInt(20);
    final isGlitch = CatRunProductionEventPolicy.isGlitchRoll(eventRoll);
    final direction = random.nextInt(2) == 0
        ? CatRunV23Direction.leftToRight
        : CatRunV23Direction.rightToLeft;
    return CatRunProductionEventPlan._withCrossings(
      source: source,
      eventRoll: eventRoll,
      isGlitch: isGlitch,
      direction: direction,
      random: random,
      count: isGlitch ? CatRunProductionEventPolicy.glitchCatCount : 1,
      spacing: isGlitch
          ? CatRunProductionEventPolicy.glitchFollowerTriggerProgress
          : 0,
      allowsRecursiveContinuation: !isGlitch,
    );
  }

  /// Reuses the production roll, coat, and continuation authority while a
  /// caller supplies the surrounding stage's selected direction.
  factory CatRunProductionEventPlan.sampledForDirection({
    required CatRunProductionEventSource source,
    required math.Random random,
    required CatRunV23Direction direction,
    required int eventRoll,
  }) {
    final isGlitch = CatRunProductionEventPolicy.isGlitchRoll(eventRoll);
    return CatRunProductionEventPlan._withCrossings(
      source: source,
      eventRoll: eventRoll,
      isGlitch: isGlitch,
      direction: direction,
      random: random,
      count: isGlitch ? CatRunProductionEventPolicy.glitchCatCount : 1,
      spacing: isGlitch
          ? CatRunProductionEventPolicy.glitchFollowerTriggerProgress
          : 0,
      allowsRecursiveContinuation: !isGlitch,
    );
  }

  factory CatRunProductionEventPlan.forceChain({
    required math.Random random,
    required CatRunV23Direction direction,
  }) => CatRunProductionEventPlan._withCrossings(
    source: CatRunProductionEventSource.sandbox,
    eventRoll: null,
    isGlitch: false,
    direction: direction,
    random: random,
    count: 3,
    spacing: CatRunProductionEventPolicy.normalFollowerTriggerProgress,
    allowsRecursiveContinuation: false,
  );

  /// Uses the normal production follower spacing while allowing production
  /// consumers to inspect a specific supported chain count.
  factory CatRunProductionEventPlan.forceCount({
    required math.Random random,
    required CatRunV23Direction direction,
    required int count,
  }) {
    if (count < 1 || count > 3) {
      throw ArgumentError.value(count, 'count', 'Must be from 1 through 3.');
    }
    return CatRunProductionEventPlan._withCrossings(
      source: CatRunProductionEventSource.sandbox,
      eventRoll: null,
      isGlitch: false,
      direction: direction,
      random: random,
      count: count,
      spacing: CatRunProductionEventPolicy.normalFollowerTriggerProgress,
      allowsRecursiveContinuation: false,
    );
  }

  /// This is intentionally the same 10-crossing GLITCH executor used after
  /// the production 5% event roll; only the source/roll are forced.
  factory CatRunProductionEventPlan.forceGlitch({
    required math.Random random,
    required CatRunV23Direction direction,
    double? spacingOverride,
  }) => CatRunProductionEventPlan._withCrossings(
    source: CatRunProductionEventSource.sandbox,
    eventRoll: null,
    isGlitch: true,
    direction: direction,
    random: random,
    count: CatRunProductionEventPolicy.glitchCatCount,
    spacing:
        spacingOverride ??
        CatRunProductionEventPolicy.glitchFollowerTriggerProgress,
    allowsRecursiveContinuation: false,
  );

  factory CatRunProductionEventPlan._withCrossings({
    required CatRunProductionEventSource source,
    required int? eventRoll,
    required bool isGlitch,
    required CatRunV23Direction direction,
    required math.Random random,
    required int count,
    required double spacing,
    required bool allowsRecursiveContinuation,
  }) => CatRunProductionEventPlan._(
    source: source,
    eventRoll: eventRoll,
    isGlitch: isGlitch,
    direction: direction,
    crossings: [
      for (var index = 0; index < count; index++)
        CatRunProductionScheduledCrossing(
          startedAtProgress: index * spacing,
          coatVariant: CatRunCoatPatterns.chooseRandom(random),
          continuationRolled: !allowsRecursiveContinuation,
        ),
    ],
    allowsRecursiveContinuation: allowsRecursiveContinuation,
  );

  final CatRunProductionEventSource source;
  final int? eventRoll;
  final bool isGlitch;
  final CatRunV23Direction direction;
  final List<CatRunProductionScheduledCrossing> crossings;
  final bool allowsRecursiveContinuation;

  double get finalProgress => crossings.last.startedAtProgress + 1;
}

/// Sandbox-only 48px travel inspection for direct sequential HIGH vectors.
class CatRunV23ProductionPreview extends StatefulWidget {
  const CatRunV23ProductionPreview({super.key, this.random});

  final math.Random? random;

  @override
  State<CatRunV23ProductionPreview> createState() =>
      _CatRunV23ProductionPreviewState();
}

class _CatRunV23ProductionPreviewState extends State<CatRunV23ProductionPreview>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  var _direction = CatRunV23Direction.leftToRight;
  var _speed = 1.0;
  var _playing = true;
  var _randomSelection = false;
  var _coatVariant = CatRunCoatVariant.normal;
  var _lastProgress = 0.0;
  CatRunProductionEventPlan? _forcedPlan;
  late final math.Random _random = widget.random ?? math.Random();

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController.unbounded(
            vsync: this,
            duration: CatRunV23Travel.crossingDuration,
          )
          ..addListener(() {
            if (!mounted || !_playing) return;
            if (_randomSelection && _controller.value < _lastProgress) {
              _coatVariant = CatRunCoatPatterns.chooseRandom(_random);
            }
            _lastProgress = _controller.value;
            setState(() {});
          })
          ..addStatusListener((status) {
            if (status != AnimationStatus.completed || _forcedPlan == null) {
              return;
            }
            setState(() {
              _forcedPlan = null;
              _playing = false;
            });
          });
    _controller.repeat(min: 0, max: 1);
  }

  void _restart() {
    setState(() {
      _forcedPlan = null;
      _playing = true;
      _lastProgress = 0;
      if (_randomSelection) {
        _coatVariant = CatRunCoatPatterns.chooseRandom(_random);
      }
      _controller
        ..value = 0
        ..repeat(min: 0, max: 1);
    });
  }

  void _setSpeed(double speed) {
    setState(() {
      _speed = speed;
      _controller.duration = Duration(
        microseconds: (CatRunV23Travel.crossingDuration.inMicroseconds / speed)
            .round(),
      );
      if (_playing) _controller.repeat(min: 0, max: 1);
    });
  }

  void _selectCoat(CatRunCoatVariant variant) {
    setState(() {
      _randomSelection = false;
      _coatVariant = variant;
    });
  }

  void _selectRandomCoat() {
    setState(() {
      _randomSelection = true;
      _coatVariant = CatRunCoatPatterns.chooseRandom(_random);
    });
  }

  void _startForced(CatRunProductionEventPlan plan) {
    if (_forcedPlan != null && _controller.isAnimating) return;
    final finalProgress = plan.finalProgress;
    setState(() {
      _forcedPlan = plan;
      _playing = true;
      _lastProgress = 0;
      _controller
        ..stop()
        ..value = 0
        ..animateTo(
          finalProgress,
          duration: CatRunV23Travel.durationForGlobalProgress(finalProgress),
          curve: Curves.linear,
        );
    });
  }

  void _forceChain() => _startForced(
    CatRunProductionEventPlan.forceChain(
      random: _random,
      direction: _direction,
    ),
  );

  void _forceGlitch() => _startForced(
    CatRunProductionEventPlan.forceGlitch(
      random: _random,
      direction: _direction,
    ),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(
          icon: Icons.directions_run,
          title: 'CAT RUN V2.10 — PRODUCTION PREVIEW',
        ),
        AppSpacing.gapSM,
        OperationCard(
          key: const ValueKey('cat-run-v23-production-preview'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  return SizedBox(
                    height: CatRunV23Travel.stageHeight,
                    child: CustomPaint(
                      key: const ValueKey('cat-run-v23-stage'),
                      painter: CatRunV23StagePainter(
                        progress: _controller.value,
                        direction: _direction,
                        coatVariant: _coatVariant,
                        showGroundLine: true,
                        groundLineColor: Theme.of(
                          context,
                        ).colorScheme.outlineVariant,
                        crossings: _forcedPlan == null
                            ? null
                            : [
                                for (final crossing in _forcedPlan!.crossings)
                                  CatRunV23Crossing(
                                    progress:
                                        _controller.value -
                                        crossing.startedAtProgress,
                                    direction: _forcedPlan!.direction,
                                    coatVariant: crossing.coatVariant,
                                  ),
                              ],
                      ),
                    ),
                  );
                },
              ),
              AppSpacing.gapSM,
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton(
                    key: const ValueKey('cat-run-v23-play-restart'),
                    onPressed: _restart,
                    child: const Text('PLAY / RESTART'),
                  ),
                  OutlinedButton(
                    key: const ValueKey('cat-run-v23-force-chain'),
                    onPressed: _forcedPlan == null ? _forceChain : null,
                    child: const Text('FORCE CHAIN ×3'),
                  ),
                  OutlinedButton(
                    key: const ValueKey('cat-run-v23-force-glitch'),
                    onPressed: _forcedPlan == null ? _forceGlitch : null,
                    child: const Text('FORCE GLITCH ×10'),
                  ),
                  for (final direction in CatRunV23Direction.values)
                    OutlinedButton(
                      key: ValueKey('cat-run-v23-direction-${direction.name}'),
                      onPressed: () => setState(() => _direction = direction),
                      child: Text(
                        direction == CatRunV23Direction.leftToRight
                            ? 'L→R'
                            : 'R→L',
                      ),
                    ),
                  for (final speed in [0.5, 1.0])
                    OutlinedButton(
                      key: ValueKey('cat-run-v23-speed-$speed'),
                      onPressed: _forcedPlan == null
                          ? () => _setSpeed(speed)
                          : null,
                      child: Text('$speed×'),
                    ),
                  for (final variant in CatRunCoatPatterns.visualVariants)
                    OutlinedButton(
                      key: ValueKey('cat-run-v23-coat-${variant.name}'),
                      onPressed: () => _selectCoat(variant),
                      child: Text(variant.label),
                    ),
                  OutlinedButton(
                    key: const ValueKey('cat-run-v23-coat-random'),
                    onPressed: _selectRandomCoat,
                    child: const Text('RANDOM'),
                  ),
                ],
              ),
              AppSpacing.gapSM,
              LayoutBuilder(
                builder: (context, constraints) {
                  final frame = CatRunV24Travel.frameAtTravelProgress(
                    _controller.value,
                  );
                  return Text(
                    '48PX STAGE · FRAME ${(frame + 1).toString().padLeft(2, '0')} · '
                    '${CatRunV23Travel.crossingDuration.inSeconds.toStringAsFixed(1)}s crossing · '
                    '${CatRunV23Travel.velocityFor(constraints.maxWidth).toStringAsFixed(0)}px/s · $_speed× · '
                    '${_randomSelection ? 'RANDOM: ' : ''}${_coatVariant.label}',
                  );
                },
              ),
              const Text(
                'V2.10: NEW POSE 01 HIGH TRACE + 25MS CONTACT + STANCE-FOOT ROOT LOCK · FROZEN V2.2 HIGH / REGISTRATION / '
                'CONTACT / TIMING · NO MORPH / RESAMPLING / ARTICULATION',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Shared vector painter for the frozen V2.10 production-scale CAT crossing.
/// Dashboard scheduling supplies appearance state; this painter owns no timer
/// and does not alter geometry, timing, registration, or coat data.
class CatRunV23StagePainter extends CustomPainter {
  const CatRunV23StagePainter({
    required this.progress,
    required this.direction,
    required this.coatVariant,
    this.crossings,
    this.catUnit = CatRunV23Travel.catUnit,
    this.showGroundLine = false,
    this.paintBackground = true,
    this.smoothTuning,
    this.poseBlendTuning,
    this.neutralFrame02 = false,
    this.groundInset = 5,
    this.groundLineColor = const Color(0xFF383838),
  });

  final double progress;
  final CatRunV23Direction direction;
  final CatRunCoatVariant coatVariant;
  final List<CatRunV23Crossing>? crossings;
  final double catUnit;
  final bool showGroundLine;
  final bool paintBackground;

  /// Preview-only visual continuity mode. A null value retains direct
  /// registered anchors; a tuning applies bounded presentation correction
  /// without changing the travel timeline.
  final CatRunV23SmoothTuning? smoothTuning;

  /// Preview-only frame overlap comparison. A null value retains the direct
  /// production pose swap used by Dashboard.
  final CatRunV23PoseBlendTuning? poseBlendTuning;

  /// Renders the production canonical Frame 02 at the stage centre without
  /// consuming crossing progress. Used only by Ambient Wildlife neutral mode.
  final bool neutralFrame02;
  final double groundInset;
  final Color groundLineColor;

  static List<Offset> get neutralFrame02Points =>
      CatRunV24ScaleAudit.correctedPoints(catRunV2HighTraces[1]);

  @override
  void paint(Canvas canvas, Size size) {
    if (paintBackground) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = const Color(0xFF101010),
      );
    }
    if (showGroundLine) {
      canvas.drawLine(
        Offset(0, size.height - groundInset),
        Offset(size.width, size.height - groundInset),
        Paint()
          ..color = groundLineColor
          ..strokeWidth = 1,
      );
    }
    if (neutralFrame02) {
      _paintNeutralFrame02(canvas, size);
      return;
    }
    final activeCrossings =
        crossings ??
        [
          CatRunV23Crossing(
            progress: progress,
            direction: direction,
            coatVariant: coatVariant,
          ),
        ];

    for (final crossing in activeCrossings) {
      _paintCrossing(canvas, size, crossing);
    }
  }

  void _paintNeutralFrame02(Canvas canvas, Size size) {
    final trace = catRunV2HighTraces[1];
    final path = Path()..addPolygon(neutralFrame02Points, true);
    final bounds = path.getBounds();
    final groundY =
        size.height -
        groundInset -
        CatRunV2Registration.virtualGround * catUnit;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.translate(size.width / 2, groundY);
    canvas.scale(
      direction == CatRunV23Direction.leftToRight ? catUnit : -catUnit,
      catUnit,
    );
    canvas.translate(-bounds.center.dx, 0);
    canvas.drawPath(
      path,
      Paint()
        ..color = CatRunCoatPatterns.baseColor
        ..isAntiAlias = true,
    );
    CatRunCoatPatterns.paint(
      canvas: canvas,
      silhouette: path,
      trace: trace,
      variant: coatVariant,
    );
    canvas.restore();
  }

  void _paintCrossing(Canvas canvas, Size size, CatRunV23Crossing crossing) {
    final poseProgress = CatRunV23Travel.poseProgressForPhaseOffset(
      travelProgress: crossing.progress,
      phaseOffset: crossing.posePhaseOffset,
    );
    final travelX = CatRunV24Travel.horizontalPosition(
      stageWidth: size.width,
      progress: crossing.progress,
    );
    final groundY =
        size.height - 5 - CatRunV2Registration.virtualGround * catUnit;
    final smoothAnchorOffset = smoothTuning == null
        ? Offset.zero
        : CatRunV23Travel.smoothVisualAnchorOffsetAt(
            poseProgress,
            tuning: smoothTuning!,
          );

    canvas.save();
    canvas.clipRect(Offset.zero & size);
    if (crossing.direction == CatRunV23Direction.leftToRight) {
      canvas.translate(travelX, groundY);
      canvas.scale(catUnit);
    } else {
      canvas.translate(size.width - travelX, groundY);
      canvas.scale(-catUnit, catUnit);
    }
    canvas.translate(smoothAnchorOffset.dx, smoothAnchorOffset.dy);
    final blend = poseBlendTuning == null
        ? null
        : CatRunV23Travel.poseBlendStateAt(
            poseProgress,
            tuning: poseBlendTuning!,
          );
    if (blend == null) {
      _paintPose(
        canvas,
        frame: CatRunV24Travel.frameAtTravelProgress(poseProgress),
        poseProgress: poseProgress,
        variant: crossing.coatVariant,
      );
    } else {
      _paintPose(
        canvas,
        frame: blend.outgoingFrame,
        poseProgress: CatRunV23Travel.poseProgressForFrame(blend.outgoingFrame),
        variant: crossing.coatVariant,
        opacity: 1 - blend.incomingOpacity,
      );
      _paintPose(
        canvas,
        frame: blend.incomingFrame,
        poseProgress: CatRunV23Travel.poseProgressForFrame(blend.incomingFrame),
        variant: crossing.coatVariant,
        opacity: blend.incomingOpacity,
      );
    }
    canvas.restore();
  }

  void _paintPose(
    Canvas canvas, {
    required int frame,
    required double poseProgress,
    required CatRunCoatVariant variant,
    double opacity = 1,
  }) {
    if (opacity <= 0) return;
    final trace = catRunV2HighTraces[frame];
    final path = Path()
      ..addPolygon(CatRunV24Travel.pointsAt(poseProgress), true);
    if (opacity < 1) {
      canvas.saveLayer(
        null,
        Paint()..color = Colors.white.withValues(alpha: opacity),
      );
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = CatRunCoatPatterns.baseColor
        ..isAntiAlias = true,
    );
    CatRunCoatPatterns.paint(
      canvas: canvas,
      silhouette: path,
      trace: trace,
      variant: variant,
    );
    if (opacity < 1) canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CatRunV23StagePainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.direction != direction ||
      oldDelegate.coatVariant != coatVariant ||
      oldDelegate.crossings != crossings ||
      oldDelegate.catUnit != catUnit ||
      oldDelegate.showGroundLine != showGroundLine ||
      oldDelegate.paintBackground != paintBackground ||
      oldDelegate.smoothTuning != smoothTuning ||
      oldDelegate.poseBlendTuning != poseBlendTuning ||
      oldDelegate.neutralFrame02 != neutralFrame02 ||
      oldDelegate.groundInset != groundInset ||
      oldDelegate.groundLineColor != groundLineColor;
}
