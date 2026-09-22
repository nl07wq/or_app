import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// The local-clock periods used exclusively by Dashboard wildlife selection.
enum WildlifePeriod { day, night }

/// The small set of programmatic wildlife silhouettes available to the stage.
enum WildlifeKind { cat, birds, fox, bat }

/// Resolves the daylight pool from the device's local clock.
WildlifePeriod wildlifePeriodFor(DateTime localTime) =>
    localTime.hour >= 6 && localTime.hour < 18
    ? WildlifePeriod.day
    : WildlifePeriod.night;

List<WildlifeKind> wildlifeKindsFor(WildlifePeriod period) => switch (period) {
  WildlifePeriod.day => const [WildlifeKind.cat, WildlifeKind.birds],
  WildlifePeriod.night => const [WildlifeKind.fox, WildlifeKind.bat],
};

double wildlifeSpeedFor(WildlifeKind kind) => switch (kind) {
  WildlifeKind.cat => 140,
  WildlifeKind.fox => 175,
  WildlifeKind.birds => 110,
  WildlifeKind.bat => 130,
};

/// Deterministic, scheduler-free plan used by the diagnostic Sandbox. This
/// shares production speed/duration and renderer data while intentionally
/// bypassing Dashboard day/night eligibility and the sparse timer.
WildlifeEventPlan wildlifePreviewPlan({
  required WildlifeKind kind,
  required bool leftToRight,
}) => WildlifeEventPlan(
  kind: kind,
  leftToRight: leftToRight,
  count: switch (kind) {
    WildlifeKind.birds => 3,
    WildlifeKind.bat => 2,
    WildlifeKind.cat || WildlifeKind.fox => 1,
  },
  phaseSeed: 0,
  speedPixelsPerSecond: wildlifeSpeedFor(kind),
);

/// One neutral palette for all Dashboard wildlife. Day/night controls the
/// available species only; it never changes decorative hierarchy or color.
@immutable
class DashboardAmbientWildlifePalette {
  const DashboardAmbientWildlifePalette({
    required this.silhouette,
    required this.groundLine,
  });

  /// Light-gray rather than white: clear on #101010 while remaining below
  /// primary foreground text and module/status accents.
  static const dark = DashboardAmbientWildlifePalette(
    silhouette: Color(0xFFB8B8B8),
    groundLine: Color(0xFF383838),
  );

  /// The same subdued neutral relationship when the app is previewed using a
  /// light ThemeData in tests or future appearance modes.
  static const light = DashboardAmbientWildlifePalette(
    silhouette: Color(0xFF565656),
    groundLine: Color(0xFFD6D6D6),
  );

  final Color silhouette;
  final Color groundLine;

  static DashboardAmbientWildlifePalette forTheme(ThemeData theme) =>
      theme.brightness == Brightness.dark ? dark : light;

  /// The production Dashboard's settled background, kept here so contrast
  /// checks use the actual compositing surface rather than a generic black.
  static const productionBackground = AppColors.background;
}

/// Immutable, pre-selected motion data. Painting only reads this plan; it
/// never performs frame-time random selection.
@immutable
class WildlifeEventPlan {
  const WildlifeEventPlan({
    required this.kind,
    required this.leftToRight,
    required this.count,
    required this.phaseSeed,
    required this.speedPixelsPerSecond,
  });

  final WildlifeKind kind;
  final bool leftToRight;
  final int count;
  final double phaseSeed;
  final double speedPixelsPerSecond;

  bool get isGround => kind == WildlifeKind.cat || kind == WildlifeKind.fox;

  Duration durationForWidth(double width) {
    final distance = width + (isGround ? 60 : 52);
    final rawMilliseconds = (distance / speedPixelsPerSecond * 1000).round();
    final limits = switch (kind) {
      WildlifeKind.cat => (2000, 3200),
      WildlifeKind.fox => (1700, 2700),
      WildlifeKind.birds => (3000, 5000),
      WildlifeKind.bat => (2400, 4000),
    };
    return Duration(
      milliseconds: rawMilliseconds.clamp(limits.$1, limits.$2).toInt(),
    );
  }
}

/// A quiet, decorative Dashboard-bottom lane. It owns no product state and
/// remains completely idle except for its bounded next-event timer.
class DashboardAmbientWildlifeStage extends StatefulWidget {
  const DashboardAmbientWildlifeStage({
    super.key,
    this.localNow = DateTime.now,
    this.nextInt,
    this.minimumInterval = const Duration(seconds: 45),
    this.maximumInterval = const Duration(seconds: 150),
  });

  static const double height = 48;
  static const double groundInset = 5;

  final DateTime Function() localNow;
  final int Function(int max)? nextInt;
  final Duration minimumInterval;
  final Duration maximumInterval;

  @override
  State<DashboardAmbientWildlifeStage> createState() =>
      _DashboardAmbientWildlifeStageState();
}

class _DashboardAmbientWildlifeStageState
    extends State<DashboardAmbientWildlifeStage>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final math.Random _random = math.Random();
  late final AnimationController _controller = AnimationController(vsync: this)
    ..addStatusListener(_onAnimationStatus);
  Timer? _nextEventTimer;
  WildlifeEventPlan? _activePlan;
  bool _reducedMotion = false;
  bool _tickerEnabled = true;
  bool _appActive = true;
  bool _waitingForMeasurement = false;
  double _stageWidth = 0;

  bool get _motionAllowed =>
      !_reducedMotion && _tickerEnabled && _appActive && mounted;

  int _next(int max) => widget.nextInt?.call(max) ?? _random.nextInt(max);

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

  void _syncScheduling() {
    if (!_motionAllowed) {
      _cancelAndClear();
      return;
    }
    if (_activePlan == null && _nextEventTimer == null) {
      _scheduleNextEvent();
    }
  }

  void _cancelAndClear() {
    _nextEventTimer?.cancel();
    _nextEventTimer = null;
    _waitingForMeasurement = false;
    _controller.stop();
    if (_activePlan != null && mounted) {
      setState(() => _activePlan = null);
    } else {
      _activePlan = null;
    }
  }

  Duration _nextInterval() {
    final minimum = widget.minimumInterval;
    final maximum = widget.maximumInterval;
    assert(maximum >= minimum);
    final delta = maximum.inMilliseconds - minimum.inMilliseconds;
    return minimum + Duration(milliseconds: delta == 0 ? 0 : _next(delta + 1));
  }

  void _scheduleNextEvent() {
    if (!_motionAllowed || _activePlan != null || _nextEventTimer != null) {
      return;
    }
    _nextEventTimer = Timer(_nextInterval(), () {
      _nextEventTimer = null;
      _startEvent();
    });
  }

  WildlifeEventPlan _createPlan() {
    final kinds = wildlifeKindsFor(wildlifePeriodFor(widget.localNow()));
    final kind = kinds[_next(kinds.length)];
    final count = switch (kind) {
      WildlifeKind.birds => 2 + _next(3),
      WildlifeKind.bat => 1 + _next(3),
      WildlifeKind.cat || WildlifeKind.fox => 1,
    };
    return WildlifeEventPlan(
      kind: kind,
      leftToRight: _next(2) == 0,
      count: count,
      phaseSeed: _next(1000) / 1000,
      speedPixelsPerSecond: wildlifeSpeedFor(kind),
    );
  }

  void _startEvent() {
    if (!_motionAllowed || _activePlan != null) return;
    if (_stageWidth <= 0) {
      if (_waitingForMeasurement) return;
      _waitingForMeasurement = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _waitingForMeasurement = false;
        _startEvent();
      });
      return;
    }
    final plan = _createPlan();
    setState(() => _activePlan = plan);
    _controller
      ..duration = plan.durationForWidth(_stageWidth)
      ..forward(from: 0);
  }

  void _onAnimationStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || !mounted) return;
    setState(() => _activePlan = null);
    _scheduleNextEvent();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _nextEventTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ExcludeSemantics(
        child: RepaintBoundary(
          child: SizedBox(
            key: const ValueKey('dashboard-ambient-wildlife-stage'),
            height: DashboardAmbientWildlifeStage.height,
            width: double.infinity,
            child: LayoutBuilder(
              builder: (context, constraints) {
                _stageWidth = constraints.maxWidth;
                return ClipRect(
                  key: const ValueKey('dashboard-ambient-wildlife-clip'),
                  child: CustomPaint(
                    key: ValueKey(
                      'dashboard-ambient-wildlife-${_activePlan?.kind.name ?? 'idle'}',
                    ),
                    painter: DashboardAmbientWildlifePainter(
                      plan: _reducedMotion ? null : _activePlan,
                      progress: _controller,
                      palette: DashboardAmbientWildlifePalette.forTheme(
                        Theme.of(context),
                      ),
                    ),
                    willChange: _activePlan != null,
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

/// Explicit-event diagnostic lane for the Animations Sandbox. It deliberately
/// owns no sparse scheduler: a changed [requestId] restarts the supplied plan.
class DashboardAmbientWildlifePreviewStage extends StatefulWidget {
  const DashboardAmbientWildlifePreviewStage({
    super.key,
    required this.plan,
    required this.requestId,
    this.neutralKind,
    this.neutralLeftToRight = true,
    this.neutralScale = 1,
  });

  final WildlifeEventPlan? plan;
  final int requestId;
  final WildlifeKind? neutralKind;
  final bool neutralLeftToRight;
  final double neutralScale;

  @override
  State<DashboardAmbientWildlifePreviewStage> createState() =>
      _DashboardAmbientWildlifePreviewStageState();
}

class _DashboardAmbientWildlifePreviewStageState
    extends State<DashboardAmbientWildlifePreviewStage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this)
    ..addStatusListener(_onAnimationStatus);
  WildlifeEventPlan? _activePlan;
  double _stageWidth = 0;
  bool _reducedMotion = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reducedMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (_reducedMotion) {
      _controller.stop();
      _activePlan = null;
    }
  }

  @override
  void didUpdateWidget(covariant DashboardAmbientWildlifePreviewStage old) {
    super.didUpdateWidget(old);
    if (widget.neutralKind != null) {
      _controller.stop();
      _activePlan = null;
      return;
    }
    if (old.neutralKind != null) {
      _startPlan(widget.plan);
      return;
    }
    if (old.requestId != widget.requestId) {
      _startPlan(widget.plan);
    }
  }

  void _startPlan(WildlifeEventPlan? plan) {
    if (_reducedMotion || plan == null) return;
    if (_stageWidth <= 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _startPlan(plan);
      });
      return;
    }
    setState(() => _activePlan = plan);
    _controller
      ..duration = plan.durationForWidth(_stageWidth)
      ..forward(from: 0);
  }

  void _onAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && mounted) {
      setState(() => _activePlan = null);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: ExcludeSemantics(
      child: RepaintBoundary(
        child: SizedBox(
          key: const ValueKey('ambient-wildlife-preview-stage'),
          height: DashboardAmbientWildlifeStage.height,
          width: double.infinity,
          child: ColoredBox(
            color: DashboardAmbientWildlifePalette.productionBackground,
            child: LayoutBuilder(
              builder: (context, constraints) {
                _stageWidth = constraints.maxWidth;
                return ClipRect(
                  key: const ValueKey('ambient-wildlife-preview-clip'),
                  child: CustomPaint(
                    key: ValueKey(
                      'ambient-wildlife-preview-${widget.neutralKind?.name ?? _activePlan?.kind.name ?? 'idle'}',
                    ),
                    painter: DashboardAmbientWildlifePainter(
                      plan: _reducedMotion ? null : _activePlan,
                      progress: _controller,
                      palette: DashboardAmbientWildlifePalette.dark,
                      neutralKind: _reducedMotion ? null : widget.neutralKind,
                      neutralLeftToRight: widget.neutralLeftToRight,
                      neutralScale: widget.neutralScale,
                    ),
                    willChange:
                        _activePlan != null && widget.neutralKind == null,
                  ),
                );
              },
            ),
          ),
        ),
      ),
    ),
  );
}

/// A normalized, whole-silhouette sample from one species' locomotion cycle.
///
/// The renderer reconstructs body, limbs, tail, and wings from these shared
/// landmarks rather than translating a stable icon with moving appendages.
@immutable
class WildlifePoseSample {
  const WildlifePoseSample({
    this.bodyLength = 1,
    this.bodyHeight = .5,
    this.bodyLift = 0,
    this.headOffset = 0,
    this.muzzleLength = 0,
    this.earHeight = 0,
    this.foreReach = 0,
    this.hindReach = 0,
    this.foreLift = 0,
    this.hindLift = 0,
    this.tailLength = 0,
    this.tailLift = 0,
    this.tailThickness = 0,
    this.wingSpan = 0,
    this.wingUp = 0,
    this.wingDown = 0,
    this.wingFold = 0,
    this.farWingSpan = 0,
    this.headForward = 0,
    this.tailRear = 0,
    this.isFlight = false,
  });

  final double bodyLength;
  final double bodyHeight;
  final double bodyLift;
  final double headOffset;
  final double muzzleLength;
  final double earHeight;
  final double foreReach;
  final double hindReach;
  final double foreLift;
  final double hindLift;
  final double tailLength;
  final double tailLift;
  final double tailThickness;
  final double wingSpan;
  final double wingUp;
  final double wingDown;
  final double wingFold;
  final double farWingSpan;
  final double headForward;
  final double tailRear;
  final bool isFlight;

  static WildlifePoseSample lerp(
    WildlifePoseSample a,
    WildlifePoseSample b,
    double t,
  ) => WildlifePoseSample(
    bodyLength: _lerp(a.bodyLength, b.bodyLength, t),
    bodyHeight: _lerp(a.bodyHeight, b.bodyHeight, t),
    bodyLift: _lerp(a.bodyLift, b.bodyLift, t),
    headOffset: _lerp(a.headOffset, b.headOffset, t),
    muzzleLength: _lerp(a.muzzleLength, b.muzzleLength, t),
    earHeight: _lerp(a.earHeight, b.earHeight, t),
    foreReach: _lerp(a.foreReach, b.foreReach, t),
    hindReach: _lerp(a.hindReach, b.hindReach, t),
    foreLift: _lerp(a.foreLift, b.foreLift, t),
    hindLift: _lerp(a.hindLift, b.hindLift, t),
    tailLength: _lerp(a.tailLength, b.tailLength, t),
    tailLift: _lerp(a.tailLift, b.tailLift, t),
    tailThickness: _lerp(a.tailThickness, b.tailThickness, t),
    wingSpan: _lerp(a.wingSpan, b.wingSpan, t),
    wingUp: _lerp(a.wingUp, b.wingUp, t),
    wingDown: _lerp(a.wingDown, b.wingDown, t),
    wingFold: _lerp(a.wingFold, b.wingFold, t),
    farWingSpan: _lerp(a.farWingSpan, b.farWingSpan, t),
    headForward: _lerp(a.headForward, b.headForward, t),
    tailRear: _lerp(a.tailRear, b.tailRear, t),
    isFlight: t < .5 ? a.isFlight : b.isFlight,
  );
}

double _lerp(double a, double b, double t) => a + (b - a) * t;

// V4 anatomy is deliberately stable.  Locomotion changes joint placement and
// spinal curve, not the fundamental mass of the animal.
const _catPoses = [
  WildlifePoseSample(
    bodyLength: .94,
    bodyHeight: .46,
    headOffset: -.02,
    earHeight: .22,
    foreReach: -.08,
    hindReach: .16,
    tailLength: 1.08,
    tailLift: -.06,
    tailThickness: .09,
    headForward: .25,
    tailRear: 1.08,
  ),
  WildlifePoseSample(
    bodyLength: .92,
    bodyHeight: .48,
    headOffset: -.05,
    earHeight: .22,
    foreReach: -.02,
    hindReach: .23,
    tailLength: 1.06,
    tailLift: -.12,
    tailThickness: .09,
    headForward: .25,
    tailRear: 1.06,
  ),
  WildlifePoseSample(
    bodyLength: .96,
    bodyHeight: .45,
    bodyLift: .07,
    headOffset: .02,
    earHeight: .21,
    foreReach: .14,
    hindReach: -.22,
    tailLength: 1.10,
    tailLift: .01,
    tailThickness: .09,
    headForward: .26,
    tailRear: 1.10,
  ),
  WildlifePoseSample(
    bodyLength: .99,
    bodyHeight: .44,
    bodyLift: .24,
    headOffset: .06,
    earHeight: .21,
    foreReach: .40,
    hindReach: -.32,
    foreLift: .22,
    hindLift: .27,
    tailLength: 1.12,
    tailLift: .12,
    tailThickness: .09,
    headForward: .26,
    tailRear: 1.12,
    isFlight: true,
  ),
  WildlifePoseSample(
    bodyLength: .98,
    bodyHeight: .45,
    bodyLift: .14,
    headOffset: .05,
    earHeight: .21,
    foreReach: .45,
    hindReach: -.10,
    foreLift: .05,
    hindLift: .16,
    tailLength: 1.11,
    tailLift: .08,
    tailThickness: .09,
    headForward: .26,
    tailRear: 1.11,
  ),
  WildlifePoseSample(
    bodyLength: .95,
    bodyHeight: .47,
    bodyLift: .03,
    earHeight: .22,
    foreReach: .16,
    hindReach: .04,
    tailLength: 1.09,
    tailLift: -.03,
    tailThickness: .09,
    headForward: .25,
    tailRear: 1.09,
  ),
];

const _foxPoses = [
  WildlifePoseSample(
    bodyLength: .96,
    bodyHeight: .47,
    headOffset: -.03,
    muzzleLength: .58,
    earHeight: .38,
    foreReach: -.10,
    hindReach: .18,
    tailLength: 1.30,
    tailLift: -.08,
    tailThickness: .25,
    headForward: .48,
    tailRear: 1.30,
  ),
  WildlifePoseSample(
    bodyLength: .94,
    bodyHeight: .49,
    headOffset: -.06,
    muzzleLength: .58,
    earHeight: .38,
    foreReach: -.03,
    hindReach: .25,
    tailLength: 1.28,
    tailLift: -.15,
    tailThickness: .25,
    headForward: .48,
    tailRear: 1.28,
  ),
  WildlifePoseSample(
    bodyLength: .99,
    bodyHeight: .45,
    bodyLift: .08,
    headOffset: .03,
    muzzleLength: .59,
    earHeight: .37,
    foreReach: .15,
    hindReach: -.26,
    tailLength: 1.33,
    tailLift: .01,
    tailThickness: .25,
    headForward: .49,
    tailRear: 1.33,
  ),
  WildlifePoseSample(
    bodyLength: 1.04,
    bodyHeight: .43,
    bodyLift: .29,
    headOffset: .07,
    muzzleLength: .60,
    earHeight: .37,
    foreReach: .52,
    hindReach: -.38,
    foreLift: .24,
    hindLift: .30,
    tailLength: 1.36,
    tailLift: .15,
    tailThickness: .26,
    headForward: .50,
    tailRear: 1.36,
    isFlight: true,
  ),
  WildlifePoseSample(
    bodyLength: 1.02,
    bodyHeight: .44,
    bodyLift: .16,
    headOffset: .06,
    muzzleLength: .60,
    earHeight: .37,
    foreReach: .56,
    hindReach: -.12,
    foreLift: .06,
    hindLift: .18,
    tailLength: 1.35,
    tailLift: .10,
    tailThickness: .26,
    headForward: .50,
    tailRear: 1.35,
  ),
  WildlifePoseSample(
    bodyLength: .98,
    bodyHeight: .46,
    bodyLift: .04,
    muzzleLength: .58,
    earHeight: .38,
    foreReach: .20,
    hindReach: .05,
    tailLength: 1.32,
    tailLift: -.02,
    tailThickness: .25,
    headForward: .49,
    tailRear: 1.32,
  ),
];

// Lateral V3 air poses: one large near wing sweeps behind the horizontal
// body; a smaller far wing only supplies depth, never emblem symmetry.
const _birdPoses = [
  WildlifePoseSample(
    bodyLength: .72,
    bodyHeight: .33,
    wingSpan: 1.02,
    wingUp: .88,
    wingDown: .08,
    wingFold: .44,
    farWingSpan: .32,
    headForward: .46,
    tailRear: .48,
  ),
  WildlifePoseSample(
    bodyLength: .73,
    bodyHeight: .33,
    wingSpan: 1.12,
    wingUp: .48,
    wingDown: .12,
    wingFold: .32,
    farWingSpan: .36,
    headForward: .46,
    tailRear: .49,
  ),
  WildlifePoseSample(
    bodyLength: .74,
    bodyHeight: .32,
    wingSpan: 1.26,
    wingUp: .12,
    wingDown: .12,
    wingFold: .18,
    farWingSpan: .40,
    headForward: .47,
    tailRear: .50,
  ),
  WildlifePoseSample(
    bodyLength: .73,
    bodyHeight: .34,
    wingSpan: 1.16,
    wingUp: .06,
    wingDown: .78,
    wingFold: .25,
    farWingSpan: .34,
    headForward: .47,
    tailRear: .49,
  ),
  WildlifePoseSample(
    bodyLength: .72,
    bodyHeight: .34,
    wingSpan: 1.00,
    wingUp: .06,
    wingDown: .45,
    wingFold: .38,
    farWingSpan: .30,
    headForward: .46,
    tailRear: .48,
  ),
  WildlifePoseSample(
    bodyLength: .73,
    bodyHeight: .33,
    wingSpan: 1.08,
    wingUp: .22,
    wingDown: .24,
    wingFold: .30,
    farWingSpan: .34,
    headForward: .46,
    tailRear: .49,
  ),
];

const _batPoses = [
  WildlifePoseSample(
    bodyLength: .58,
    bodyHeight: .50,
    wingSpan: .98,
    wingUp: .92,
    wingDown: .06,
    wingFold: .62,
    farWingSpan: .28,
    headForward: .34,
    tailRear: .32,
  ),
  WildlifePoseSample(
    bodyLength: .59,
    bodyHeight: .50,
    wingSpan: 1.10,
    wingUp: .52,
    wingDown: .12,
    wingFold: .48,
    farWingSpan: .32,
    headForward: .34,
    tailRear: .33,
  ),
  WildlifePoseSample(
    bodyLength: .60,
    bodyHeight: .49,
    wingSpan: 1.28,
    wingUp: .16,
    wingDown: .18,
    wingFold: .20,
    farWingSpan: .38,
    headForward: .35,
    tailRear: .34,
  ),
  WildlifePoseSample(
    bodyLength: .59,
    bodyHeight: .51,
    wingSpan: 1.18,
    wingUp: .05,
    wingDown: .96,
    wingFold: .18,
    farWingSpan: .33,
    headForward: .35,
    tailRear: .33,
  ),
  WildlifePoseSample(
    bodyLength: .58,
    bodyHeight: .52,
    wingSpan: .94,
    wingUp: .05,
    wingDown: .52,
    wingFold: .52,
    farWingSpan: .27,
    headForward: .34,
    tailRear: .32,
  ),
  WildlifePoseSample(
    bodyLength: .59,
    bodyHeight: .50,
    wingSpan: 1.04,
    wingUp: .24,
    wingDown: .28,
    wingFold: .38,
    farWingSpan: .30,
    headForward: .34,
    tailRear: .33,
  ),
];

/// Canonical V4 neutral profiles used for anatomy inspection.  They are pose
/// data for the production renderer, never a separate Sandbox illustration.
WildlifePoseSample wildlifeNeutralPoseFor(WildlifeKind kind) => switch (kind) {
  WildlifeKind.cat => const WildlifePoseSample(
    bodyLength: .96,
    bodyHeight: .46,
    earHeight: .22,
    tailLength: 1.10,
    tailThickness: .09,
    headForward: .25,
    tailRear: 1.10,
  ),
  WildlifeKind.fox => const WildlifePoseSample(
    bodyLength: .99,
    bodyHeight: .46,
    muzzleLength: .59,
    earHeight: .38,
    tailLength: 1.33,
    tailThickness: .25,
    headForward: .49,
    tailRear: 1.33,
  ),
  WildlifeKind.birds => const WildlifePoseSample(
    bodyLength: .72,
    bodyHeight: .32,
    wingSpan: 1.16,
    wingUp: .10,
    wingDown: .12,
    wingFold: .18,
    farWingSpan: .34,
    headForward: .46,
    tailRear: .49,
  ),
  WildlifeKind.bat => const WildlifePoseSample(
    bodyLength: .58,
    bodyHeight: .50,
    wingSpan: 1.12,
    wingUp: .12,
    wingDown: .18,
    wingFold: .24,
    farWingSpan: .32,
    headForward: .34,
    tailRear: .33,
  ),
};

const _phaseWeights = <WildlifeKind, List<double>>{
  WildlifeKind.cat: [.22, .11, .10, .24, .19, .14],
  WildlifeKind.fox: [.20, .10, .09, .29, .19, .13],
  WildlifeKind.birds: [.18, .16, .10, .12, .25, .19],
  WildlifeKind.bat: [.17, .12, .14, .11, .27, .19],
};

/// Relative dwell times for the six canonical poses. They sum to one cycle;
/// frequency remains independent and unchanged.
List<double> wildlifePhaseWeightsFor(WildlifeKind kind) =>
    List<double>.unmodifiable(_phaseWeights[kind]!);

/// Samples one of six organic key poses with species-specific phase timing.
/// The tiny sinusoidal warp is bounded and keeps the velocity directed through
/// a boundary instead of using a stop/start ease on every segment.
WildlifePoseSample wildlifePoseFor(WildlifeKind kind, double phase) {
  final poses = switch (kind) {
    WildlifeKind.cat => _catPoses,
    WildlifeKind.fox => _foxPoses,
    WildlifeKind.birds => _birdPoses,
    WildlifeKind.bat => _batPoses,
  };
  final wrapped = phase - phase.floorToDouble();
  final weights = _phaseWeights[kind]!;
  var accumulated = 0.0;
  var index = weights.length - 1;
  for (var candidate = 0; candidate < weights.length; candidate++) {
    if (wrapped < accumulated + weights[candidate]) {
      index = candidate;
      break;
    }
    accumulated += weights[candidate];
  }
  final local = ((wrapped - accumulated) / weights[index]).clamp(0.0, 1.0);
  final shaped = local + math.sin(local * math.pi * 2) * .012;
  return WildlifePoseSample.lerp(
    poses[index],
    poses[(index + 1) % poses.length],
    shaped,
  );
}

/// Locomotion is measured in cycles per second, independent of traversal.
double wildlifeCycleFrequencyFor(WildlifeKind kind) => switch (kind) {
  WildlifeKind.cat => 3.2,
  WildlifeKind.fox => 2.9,
  WildlifeKind.birds => 3.6,
  WildlifeKind.bat => 5.2,
};

double wildlifeCycleCountForTraversal(WildlifeEventPlan plan, double width) =>
    wildlifeCycleFrequencyFor(plan.kind) *
    plan.durationForWidth(width).inMilliseconds /
    Duration.millisecondsPerSecond;

/// The anatomical attachment frame shared by the renderer and continuity
/// tests. Roots intentionally sit inside the torso instead of on its edge so
/// interpolation cannot turn a running animal into disconnected primitives.
@immutable
class WildlifeQuadrupedGeometry {
  const WildlifeQuadrupedGeometry({
    required this.body,
    required this.headCenter,
    required this.shoulderRoot,
    required this.hipRoot,
    required this.tailRoot,
    required this.scale,
  });

  final Rect body;
  final Offset headCenter;
  final Offset shoulderRoot;
  final Offset hipRoot;
  final Offset tailRoot;
  final double scale;
}

/// Canonical V5 CAT-neutral landmarks, normalized to shoulder-to-hip torso
/// length. This is intentionally independent of the animated CAT pose set:
/// the Sandbox neutral diagnostic evaluates this anatomy before any gait is
/// allowed to influence its proportions.
@immutable
class WildlifeNeutralCatGeometry {
  const WildlifeNeutralCatGeometry({
    required this.torsoBounds,
    required this.headBounds,
    required this.shoulder,
    required this.hip,
    required this.forePaw,
    required this.hindPaw,
    required this.hock,
    required this.tailRoot,
    required this.tailTip,
    required this.tailThickness,
    required this.components,
    required this.curvedContourRegions,
  });

  final Rect torsoBounds;
  final Rect headBounds;
  final Offset shoulder;
  final Offset hip;
  final Offset forePaw;
  final Offset hindPaw;
  final Offset hock;
  final Offset tailRoot;
  final Offset tailTip;
  final double tailThickness;
  final List<WildlifeNeutralCatComponent> components;

  /// Named organic regions reconstructed with Bezier contours at render time.
  /// The normalized component points remain topology guards; they are not
  /// exposed as straight visual edges.
  final Set<String> curvedContourRegions;
}

/// A closed, normalized CAT-neutral component. Components are intentionally
/// safe filled regions; visual unity comes from root overlap, not a fragile
/// single winding path across every concave anatomical feature.
@immutable
class WildlifeNeutralCatComponent {
  const WildlifeNeutralCatComponent({required this.name, required this.points});

  final String name;
  final List<Offset> points;

  bool get hasFinitePoints =>
      points.every((point) => point.dx.isFinite && point.dy.isFinite);

  double get signedArea {
    var sum = 0.0;
    for (var index = 0; index < points.length; index++) {
      final current = points[index];
      final next = points[(index + 1) % points.length];
      sum += current.dx * next.dy - next.dx * current.dy;
    }
    return sum / 2;
  }

  /// Closed convex/concave component outlines must never cross themselves.
  /// Adjacent segments share an intended endpoint and are ignored.
  bool get hasSelfIntersection {
    for (var first = 0; first < points.length; first++) {
      final firstNext = (first + 1) % points.length;
      for (var second = first + 1; second < points.length; second++) {
        final secondNext = (second + 1) % points.length;
        if (first == second ||
            firstNext == second ||
            secondNext == first ||
            first == 0 && secondNext == 0) {
          continue;
        }
        if (_segmentsIntersect(
          points[first],
          points[firstNext],
          points[second],
          points[secondNext],
        )) {
          return true;
        }
      }
    }
    return false;
  }

  Rect get bounds {
    final xs = points.map((point) => point.dx);
    final ys = points.map((point) => point.dy);
    return Rect.fromLTRB(
      xs.reduce(math.min),
      ys.reduce(math.min),
      xs.reduce(math.max),
      ys.reduce(math.max),
    );
  }
}

double _cross(Offset a, Offset b, Offset c) =>
    (b.dx - a.dx) * (c.dy - a.dy) - (b.dy - a.dy) * (c.dx - a.dx);

bool _segmentsIntersect(Offset a, Offset b, Offset c, Offset d) {
  final first = _cross(a, b, c);
  final second = _cross(a, b, d);
  final third = _cross(c, d, a);
  final fourth = _cross(c, d, b);
  return first * second < 0 && third * fourth < 0;
}

/// V5 CAT-neutral source-of-truth geometry. Positive x is the travel-facing
/// direction; y=0 is the ground baseline. It is not derived from run-cycle
/// poses. V5.0.1 uses overlapping closed components to avoid self-intersection.
const wildlifeNeutralCatGeometry = WildlifeNeutralCatGeometry(
  torsoBounds: Rect.fromLTRB(-1.02, -.55, .18, -.18),
  headBounds: Rect.fromLTRB(.15, -.88, .93, -.28),
  shoulder: Offset(.05, -.34),
  hip: Offset(-.70, -.34),
  forePaw: Offset(.25, 0),
  hindPaw: Offset(-.39, 0),
  hock: Offset(-.48, -.34),
  tailRoot: Offset(-1.02, -.18),
  tailTip: Offset(-2.30, -.74),
  tailThickness: .07,
  curvedContourRegions: {
    'skullNeck',
    'neckShoulder',
    'dorsalBack',
    'chestAbdomen',
    'abdominalTuck',
    'thighHock',
    'tailEnvelope',
  },
  components: [
    WildlifeNeutralCatComponent(
      name: 'core',
      points: [
        Offset(.84, -.65),
        Offset(.65, -.78),
        Offset(.60, -1.02),
        Offset(.46, -.76),
        Offset(.25, -1.05),
        Offset(.14, -.72),
        Offset(-.05, -.66),
        Offset(-.50, -.82),
        Offset(-.98, -.68),
        Offset(-1.10, -.48),
        Offset(-1.04, -.30),
        Offset(-.75, -.23),
        Offset(-.45, -.27),
        Offset(-.10, -.43),
        Offset(.12, -.43),
        Offset(.27, -.60),
        Offset(.54, -.55),
      ],
    ),
    WildlifeNeutralCatComponent(
      name: 'farHindLeg',
      points: [
        Offset(-1.04, -.57),
        Offset(-.82, -.55),
        Offset(-.66, -.35),
        Offset(-.72, -.12),
        Offset(-.66, 0),
        Offset(-.48, 0),
        Offset(-.45, -.09),
        Offset(-.55, -.16),
        Offset(-.48, -.38),
        Offset(-.68, -.57),
      ],
    ),
    WildlifeNeutralCatComponent(
      name: 'farForeLeg',
      points: [
        Offset(-.10, -.54),
        Offset(.05, -.54),
        Offset(.12, -.10),
        Offset(.11, 0),
        Offset(.24, 0),
        Offset(.26, -.10),
        Offset(.17, -.54),
      ],
    ),
    WildlifeNeutralCatComponent(
      name: 'tail',
      points: [
        Offset(-1.10, -.65),
        Offset(-1.58, -.93),
        Offset(-2.30, -.74),
        Offset(-2.35, -.62),
        Offset(-1.65, -.54),
        Offset(-.94, -.39),
      ],
    ),
    WildlifeNeutralCatComponent(
      name: 'nearHindLeg',
      points: [
        Offset(-1.05, -.58),
        Offset(-.73, -.58),
        Offset(-.45, -.38),
        Offset(-.48, -.23),
        Offset(-.62, -.10),
        Offset(-.67, 0),
        Offset(-.48, 0),
        Offset(-.36, -.08),
        Offset(-.44, -.17),
        Offset(-.34, -.42),
        Offset(-.55, -.60),
      ],
    ),
    WildlifeNeutralCatComponent(
      name: 'nearForeLeg',
      points: [
        Offset(.03, -.56),
        Offset(.22, -.54),
        Offset(.32, -.12),
        Offset(.31, 0),
        Offset(.48, 0),
        Offset(.55, -.08),
        Offset(.42, -.15),
        Offset(.24, -.54),
      ],
    ),
  ],
);

WildlifeQuadrupedGeometry wildlifeQuadrupedGeometryFor(
  WildlifeKind kind,
  double phase,
) {
  assert(kind == WildlifeKind.cat || kind == WildlifeKind.fox);
  final pose = wildlifePoseFor(kind, phase);
  return _quadrupedGeometryFromPose(kind, pose);
}

WildlifeQuadrupedGeometry _quadrupedGeometryFromPose(
  WildlifeKind kind,
  WildlifePoseSample pose,
) {
  // The V4 profiles use a shallower torso over longer articulated legs.
  final scale = kind == WildlifeKind.fox ? 17.0 : 15.0;
  final length = pose.bodyLength * scale;
  final height = pose.bodyHeight * scale;
  final center = Offset(0, -scale * (.78 + pose.bodyLift));
  final body = Rect.fromCenter(center: center, width: length, height: height);
  return WildlifeQuadrupedGeometry(
    body: body,
    // The head overlaps the forward chest rather than meeting it at a point.
    headCenter: Offset(
      body.right + scale * .04,
      center.dy - scale * (.18 + pose.headOffset),
    ),
    // Roots deliberately begin inside the chest/pelvis mass.
    shoulderRoot: Offset(body.right - length * .22, body.bottom - height * .30),
    hipRoot: Offset(body.left + length * .23, body.bottom - height * .28),
    tailRoot: Offset(body.left + scale * .20, center.dy + height * .05),
    scale: scale,
  );
}

/// V3 used 10px horizontal / 4px vertical follower offsets. V3.1 preserves
/// the formation but gives full wing envelopes room to read independently.
Offset wildlifeFormationOffsetFor(WildlifeKind kind, int index) {
  assert(kind == WildlifeKind.birds || kind == WildlifeKind.bat);
  final horizontal = kind == WildlifeKind.birds ? 14.0 : 15.0;
  final vertical = kind == WildlifeKind.birds ? 5.5 : 6.0;
  return Offset(index * horizontal, index * vertical);
}

/// Custom-programmatic wildlife silhouettes. The painter has no asset or
/// glyph dependencies and only repaints while an event controller is active.
class DashboardAmbientWildlifePainter extends CustomPainter {
  DashboardAmbientWildlifePainter({
    required this.plan,
    required this.progress,
    required this.palette,
    this.neutralKind,
    this.neutralLeftToRight = true,
    this.neutralScale = 1,
  }) : super(repaint: progress);

  final WildlifeEventPlan? plan;
  final Animation<double> progress;
  final DashboardAmbientWildlifePalette palette;
  final WildlifeKind? neutralKind;
  final bool neutralLeftToRight;
  final double neutralScale;

  @override
  void paint(Canvas canvas, Size size) {
    final ground = Paint()
      ..color = palette.groundLine
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(0, size.height - DashboardAmbientWildlifeStage.groundInset),
      Offset(
        size.width,
        size.height - DashboardAmbientWildlifeStage.groundInset,
      ),
      ground,
    );
    final neutral = neutralKind;
    if (neutral != null && !size.isEmpty) {
      _drawNeutral(
        canvas: canvas,
        silhouette: Paint()
          ..color = palette.silhouette
          ..isAntiAlias = true,
        size: size,
        kind: neutral,
      );
      return;
    }
    final event = plan;
    if (event == null || size.isEmpty) return;
    final t = progress.value;
    final direction = event.leftToRight ? 1.0 : -1.0;
    final travel = size.width + (event.isGround ? 60.0 : 52.0);
    final x = event.leftToRight
        ? -30 + travel * t
        : size.width + 30 - travel * t;
    final silhouette = Paint()
      ..color = palette.silhouette
      ..isAntiAlias = true;
    switch (event.kind) {
      case WildlifeKind.cat:
        _withDirection(canvas, Offset(x, size.height - 5), direction, () {
          _drawQuadruped(
            canvas,
            silhouette,
            WildlifeKind.cat,
            _poseAt(event, t, size.width),
          );
        });
      case WildlifeKind.fox:
        _withDirection(canvas, Offset(x, size.height - 5), direction, () {
          _drawQuadruped(
            canvas,
            silhouette,
            WildlifeKind.fox,
            _poseAt(event, t, size.width),
          );
        });
      case WildlifeKind.birds:
        _drawFlock(canvas, silhouette, size, x, t, event, false);
      case WildlifeKind.bat:
        _drawFlock(canvas, silhouette, size, x, t, event, true);
    }
  }

  void _drawNeutral({
    required Canvas canvas,
    required Paint silhouette,
    required Size size,
    required WildlifeKind kind,
  }) {
    final direction = neutralLeftToRight ? 1.0 : -1.0;
    final origin = Offset(
      size.width / 2,
      kind == WildlifeKind.cat || kind == WildlifeKind.fox
          ? size.height - 5
          : size.height / 2,
    );
    _withDirection(canvas, origin, direction, () {
      switch (kind) {
        case WildlifeKind.cat:
          canvas.save();
          canvas.scale(neutralScale);
          _drawNeutralCat(canvas, silhouette);
          canvas.restore();
        case WildlifeKind.fox:
          _drawQuadruped(
            canvas,
            silhouette,
            kind,
            wildlifeNeutralPoseFor(kind),
          );
        case WildlifeKind.birds:
          _drawBird(canvas, silhouette, wildlifeNeutralPoseFor(kind));
        case WildlifeKind.bat:
          _drawBat(canvas, silhouette, wildlifeNeutralPoseFor(kind));
      }
    });
  }

  /// V5.0.2 CAT neutral is independent of the run cycle. It intentionally
  /// layers safe, closed filled regions with deep anatomical root overlap.
  /// The topology landmarks guard against folds, while the visible anatomy is
  /// rebuilt as restrained Bezier contours rather than polygon edges.
  void _drawNeutralCat(Canvas canvas, Paint paint) {
    const s = 15.0;
    const order = [
      'farHindLeg',
      'farForeLeg',
      'tail',
      'core',
      'nearHindLeg',
      'nearForeLeg',
    ];
    final components = {
      for (final component in wildlifeNeutralCatGeometry.components)
        component.name: component,
    };
    for (final name in order) {
      canvas.drawPath(_neutralCatContour(name, s, components[name]!), paint);
    }
  }

  Path _neutralCatContour(
    String name,
    double scale,
    WildlifeNeutralCatComponent fallback,
  ) {
    final path = Path();
    switch (name) {
      case 'core':
        path
          ..moveTo(.86 * scale, -.64 * scale)
          // Short muzzle, jaw, and rounded skull.
          ..quadraticBezierTo(
            .76 * scale,
            -.73 * scale,
            .66 * scale,
            -.77 * scale,
          )
          // Ear tips are intentional, but their roots flow into the skull.
          ..lineTo(.60 * scale, -1.02 * scale)
          ..quadraticBezierTo(
            .52 * scale,
            -.86 * scale,
            .46 * scale,
            -.77 * scale,
          )
          ..lineTo(.25 * scale, -1.05 * scale)
          ..quadraticBezierTo(
            .20 * scale,
            -.84 * scale,
            .14 * scale,
            -.72 * scale,
          )
          // Neck through shoulder and one low-amplitude dorsal line.
          ..cubicTo(
            -.06 * scale,
            -.67 * scale,
            -.30 * scale,
            -.80 * scale,
            -.53 * scale,
            -.80 * scale,
          )
          ..cubicTo(
            -.76 * scale,
            -.80 * scale,
            -.96 * scale,
            -.70 * scale,
            -1.07 * scale,
            -.55 * scale,
          )
          // Pelvis into the curved chest/abdomen/tuck return.
          ..cubicTo(
            -1.11 * scale,
            -.46 * scale,
            -1.05 * scale,
            -.34 * scale,
            -.96 * scale,
            -.30 * scale,
          )
          ..cubicTo(
            -.78 * scale,
            -.22 * scale,
            -.60 * scale,
            -.23 * scale,
            -.45 * scale,
            -.28 * scale,
          )
          ..cubicTo(
            -.30 * scale,
            -.35 * scale,
            -.18 * scale,
            -.43 * scale,
            -.06 * scale,
            -.44 * scale,
          )
          ..cubicTo(
            .08 * scale,
            -.46 * scale,
            .17 * scale,
            -.45 * scale,
            .25 * scale,
            -.54 * scale,
          )
          ..cubicTo(
            .38 * scale,
            -.66 * scale,
            .63 * scale,
            -.56 * scale,
            .86 * scale,
            -.64 * scale,
          )
          ..close();
      case 'tail':
        path
          ..moveTo(-1.12 * scale, -.64 * scale)
          ..cubicTo(
            -1.48 * scale,
            -.88 * scale,
            -1.93 * scale,
            -.96 * scale,
            -2.30 * scale,
            -.74 * scale,
          )
          ..quadraticBezierTo(
            -2.38 * scale,
            -.67 * scale,
            -2.31 * scale,
            -.61 * scale,
          )
          ..cubicTo(
            -1.92 * scale,
            -.49 * scale,
            -1.46 * scale,
            -.48 * scale,
            -.94 * scale,
            -.39 * scale,
          )
          ..quadraticBezierTo(
            -1.04 * scale,
            -.51 * scale,
            -1.12 * scale,
            -.64 * scale,
          )
          ..close();
      case 'farHindLeg':
        path
          ..moveTo(-1.04 * scale, -.57 * scale)
          ..cubicTo(
            -.90 * scale,
            -.59 * scale,
            -.76 * scale,
            -.52 * scale,
            -.68 * scale,
            -.39 * scale,
          )
          ..quadraticBezierTo(
            -.76 * scale,
            -.20 * scale,
            -.66 * scale,
            -.04 * scale,
          )
          ..quadraticBezierTo(-.57 * scale, .03 * scale, -.48 * scale, 0)
          ..quadraticBezierTo(
            -.43 * scale,
            -.08 * scale,
            -.54 * scale,
            -.17 * scale,
          )
          ..cubicTo(
            -.56 * scale,
            -.33 * scale,
            -.55 * scale,
            -.48 * scale,
            -.68 * scale,
            -.57 * scale,
          )
          ..close();
      case 'farForeLeg':
        path
          ..moveTo(-.10 * scale, -.54 * scale)
          ..quadraticBezierTo(
            .00 * scale,
            -.59 * scale,
            .08 * scale,
            -.51 * scale,
          )
          ..cubicTo(
            .13 * scale,
            -.34 * scale,
            .14 * scale,
            -.18 * scale,
            .11 * scale,
            -.07 * scale,
          )
          ..quadraticBezierTo(.15 * scale, .03 * scale, .25 * scale, 0)
          ..quadraticBezierTo(
            .30 * scale,
            -.08 * scale,
            .21 * scale,
            -.16 * scale,
          )
          ..cubicTo(
            .19 * scale,
            -.32 * scale,
            .18 * scale,
            -.47 * scale,
            .17 * scale,
            -.54 * scale,
          )
          ..close();
      case 'nearHindLeg':
        path
          ..moveTo(-1.05 * scale, -.58 * scale)
          ..cubicTo(
            -.82 * scale,
            -.61 * scale,
            -.58 * scale,
            -.55 * scale,
            -.45 * scale,
            -.39 * scale,
          )
          ..quadraticBezierTo(
            -.47 * scale,
            -.25 * scale,
            -.62 * scale,
            -.10 * scale,
          )
          ..quadraticBezierTo(
            -.74 * scale,
            -.01 * scale,
            -.67 * scale,
            .01 * scale,
          )
          ..quadraticBezierTo(-.56 * scale, .04 * scale, -.47 * scale, 0)
          ..quadraticBezierTo(
            -.34 * scale,
            -.08 * scale,
            -.44 * scale,
            -.18 * scale,
          )
          ..cubicTo(
            -.42 * scale,
            -.34 * scale,
            -.42 * scale,
            -.50 * scale,
            -.55 * scale,
            -.60 * scale,
          )
          ..close();
      case 'nearForeLeg':
        path
          ..moveTo(.03 * scale, -.56 * scale)
          ..quadraticBezierTo(
            .17 * scale,
            -.60 * scale,
            .24 * scale,
            -.52 * scale,
          )
          ..cubicTo(
            .31 * scale,
            -.34 * scale,
            .34 * scale,
            -.18 * scale,
            .31 * scale,
            -.08 * scale,
          )
          ..quadraticBezierTo(.37 * scale, .04 * scale, .49 * scale, 0)
          ..quadraticBezierTo(
            .59 * scale,
            -.08 * scale,
            .43 * scale,
            -.17 * scale,
          )
          ..cubicTo(
            .37 * scale,
            -.34 * scale,
            .29 * scale,
            -.48 * scale,
            .24 * scale,
            -.54 * scale,
          )
          ..close();
      default:
        path.addPolygon([
          for (final landmark in fallback.points)
            Offset(landmark.dx * scale, landmark.dy * scale),
        ], true);
    }
    return path;
  }

  void _withDirection(
    Canvas canvas,
    Offset offset,
    double direction,
    VoidCallback draw,
  ) {
    canvas.save();
    canvas.translate(offset.dx, offset.dy);
    canvas.scale(direction, 1);
    draw();
    canvas.restore();
  }

  WildlifePoseSample _poseAt(
    WildlifeEventPlan event,
    double travelProgress,
    double stageWidth,
  ) {
    final elapsedSeconds =
        event.durationForWidth(stageWidth).inMilliseconds /
        Duration.millisecondsPerSecond *
        travelProgress;
    return wildlifePoseFor(
      event.kind,
      elapsedSeconds * wildlifeCycleFrequencyFor(event.kind) + event.phaseSeed,
    );
  }

  void _drawQuadruped(
    Canvas canvas,
    Paint paint,
    WildlifeKind kind,
    WildlifePoseSample pose,
  ) {
    final isFox = kind == WildlifeKind.fox;
    final geometry = _quadrupedGeometryFromPose(kind, pose);
    final scale = geometry.scale;
    final bodyRect = geometry.body;
    final length = bodyRect.width;
    final height = bodyRect.height;
    final center = bodyRect.center;
    final left = bodyRect.left;
    final right = bodyRect.right;
    final top = bodyRect.top;
    final bottom = bodyRect.bottom;
    final body = Path()
      ..moveTo(left, center.dy)
      ..quadraticBezierTo(left + length * .18, top, center.dx, top)
      ..quadraticBezierTo(
        right - length * .16,
        top - scale * .04,
        right,
        center.dy - height * .16,
      )
      ..quadraticBezierTo(right - length * .12, bottom, center.dx, bottom)
      ..quadraticBezierTo(
        left + length * .12,
        bottom + scale * .03,
        left,
        center.dy,
      )
      ..close();
    // Far limbs sit behind the torso. Their roots still overlap it, avoiding
    // a hinge seam when the silhouette changes between poses.
    _drawLeg(
      canvas,
      paint,
      Offset(geometry.shoulderRoot.dx - length * .12, geometry.shoulderRoot.dy),
      pose.foreReach - .12,
      pose.foreLift * .8,
      scale,
      isHind: false,
    );
    _drawLeg(
      canvas,
      paint,
      Offset(geometry.hipRoot.dx - length * .12, geometry.hipRoot.dy),
      pose.hindReach + .12,
      pose.hindLift * .8,
      scale,
      isHind: true,
    );
    canvas.drawPath(body, paint);
    _drawTail(canvas, paint, geometry.tailRoot, pose, scale, isFox);
    // Near limbs are filled mass rather than disconnected line segments.
    _drawLeg(
      canvas,
      paint,
      geometry.shoulderRoot,
      pose.foreReach,
      pose.foreLift,
      scale,
      isHind: false,
    );
    _drawLeg(
      canvas,
      paint,
      geometry.hipRoot,
      pose.hindReach,
      pose.hindLift,
      scale,
      isHind: true,
    );
    _drawQuadrupedHead(canvas, paint, geometry, pose, isFox);
  }

  void _drawLeg(
    Canvas canvas,
    Paint paint,
    Offset shoulderOrHip,
    double reach,
    double lift,
    double scale, {
    required bool isHind,
  }) {
    final foot = Offset(shoulderOrHip.dx + reach * scale, -lift * scale);
    // A feline/canid limb has a different knee/hock relation from a foreleg.
    // Keeping that hierarchy in the filled path avoids a generic hinged rod.
    final joint = Offset(
      shoulderOrHip.dx +
          reach * scale * (isHind ? .26 : .42) +
          scale * (isHind ? .12 : -.05),
      (shoulderOrHip.dy + foot.dy) / 2 + scale * (isHind ? .12 : .07),
    );
    final upper = scale * .115;
    final lower = scale * .062;
    final leg = Path()
      ..moveTo(shoulderOrHip.dx - upper, shoulderOrHip.dy - upper * .20)
      ..quadraticBezierTo(joint.dx - lower, joint.dy, foot.dx - lower, foot.dy)
      ..quadraticBezierTo(
        foot.dx,
        foot.dy + lower * .55,
        foot.dx + lower,
        foot.dy,
      )
      ..quadraticBezierTo(
        joint.dx + lower,
        joint.dy,
        shoulderOrHip.dx + upper,
        shoulderOrHip.dy + upper * .20,
      )
      ..close();
    canvas.drawPath(leg, paint);
  }

  void _drawTail(
    Canvas canvas,
    Paint paint,
    Offset base,
    WildlifePoseSample pose,
    double scale,
    bool isFox,
  ) {
    final tip = Offset(
      base.dx - pose.tailLength * scale,
      base.dy - pose.tailLift * scale,
    );
    final control = Offset(
      base.dx - pose.tailLength * scale * .52,
      base.dy - (pose.tailLift + .42) * scale,
    );
    final thickness = pose.tailThickness * scale * (isFox ? 1 : .82);
    final tail = Path()
      ..moveTo(base.dx, base.dy + thickness * .25)
      ..quadraticBezierTo(control.dx, control.dy - thickness, tip.dx, tip.dy)
      ..quadraticBezierTo(
        control.dx - thickness * .20,
        control.dy + thickness,
        base.dx,
        base.dy + thickness,
      )
      ..close();
    canvas.drawPath(tail, paint);
  }

  void _drawQuadrupedHead(
    Canvas canvas,
    Paint paint,
    WildlifeQuadrupedGeometry geometry,
    WildlifePoseSample pose,
    bool isFox,
  ) {
    final scale = geometry.scale;
    final bodyRight = geometry.body.right;
    final bodyTop = geometry.body.top;
    final headCenter = geometry.headCenter;
    final neck = Path()
      ..moveTo(bodyRight - scale * .22, geometry.body.center.dy - scale * .25)
      ..quadraticBezierTo(
        bodyRight + scale * .12,
        headCenter.dy - scale * .25,
        headCenter.dx + scale * .10,
        headCenter.dy,
      )
      ..quadraticBezierTo(
        bodyRight + scale * .08,
        headCenter.dy + scale * .25,
        bodyRight - scale * .20,
        geometry.body.center.dy + scale * .22,
      )
      ..close();
    canvas.drawPath(neck, paint);
    if (isFox) {
      final head = Path()
        ..moveTo(bodyRight - scale * .08, headCenter.dy - scale * .22)
        ..lineTo(
          headCenter.dx + pose.muzzleLength * scale,
          headCenter.dy - scale * .05,
        )
        ..lineTo(
          headCenter.dx + pose.muzzleLength * scale + scale * .12,
          headCenter.dy + scale * .10,
        )
        ..lineTo(bodyRight + scale * .04, headCenter.dy + scale * .26)
        ..close();
      canvas.drawPath(head, paint);
    } else {
      // Compact feline skull and short muzzle rather than a mascot circle.
      final head = Path()
        ..moveTo(bodyRight - scale * .10, headCenter.dy - scale * .20)
        ..quadraticBezierTo(
          headCenter.dx + scale * .16,
          headCenter.dy - scale * .18,
          headCenter.dx + scale * .28,
          headCenter.dy - scale * .03,
        )
        ..lineTo(headCenter.dx + scale * .30, headCenter.dy + scale * .08)
        ..quadraticBezierTo(
          headCenter.dx + scale * .08,
          headCenter.dy + scale * .23,
          bodyRight - scale * .06,
          headCenter.dy + scale * .18,
        )
        ..close();
      canvas.drawPath(head, paint);
    }
    final rearEar = Path()
      ..moveTo(headCenter.dx - scale * .18, bodyTop + scale * .12)
      ..lineTo(headCenter.dx - scale * .08, bodyTop - pose.earHeight * scale)
      ..lineTo(headCenter.dx + scale * .02, bodyTop + scale * .12)
      ..close();
    final frontEar = Path()
      ..moveTo(headCenter.dx + scale * .04, bodyTop + scale * .10)
      ..lineTo(
        headCenter.dx + scale * .17,
        bodyTop - pose.earHeight * scale * .88,
      )
      ..lineTo(headCenter.dx + scale * .25, bodyTop + scale * .18)
      ..close();
    canvas.drawPath(rearEar, paint);
    canvas.drawPath(frontEar, paint);
  }

  void _drawFlock(
    Canvas canvas,
    Paint paint,
    Size size,
    double baseX,
    double t,
    WildlifeEventPlan event,
    bool isBat,
  ) {
    final direction = event.leftToRight ? 1.0 : -1.0;
    for (var index = 0; index < event.count; index++) {
      final phase = event.phaseSeed + index * .19;
      final offset = wildlifeFormationOffsetFor(
        isBat ? WildlifeKind.bat : WildlifeKind.birds,
        index,
      );
      final x = baseX - direction * offset.dx;
      final y =
          (isBat ? 16.0 : 13.0) +
          offset.dy +
          math.sin((t * (isBat ? 4.2 : 2.2) + phase) * math.pi * 2) *
              (isBat ? 3.0 : 1.6);
      _withDirection(
        canvas,
        Offset(x, y.clamp(5.0, size.height - 20).toDouble()),
        direction,
        () {
          final elapsedSeconds =
              event.durationForWidth(size.width).inMilliseconds /
              Duration.millisecondsPerSecond *
              t;
          final kind = isBat ? WildlifeKind.bat : WildlifeKind.birds;
          final pose = wildlifePoseFor(
            kind,
            elapsedSeconds * wildlifeCycleFrequencyFor(kind) + phase,
          );
          if (isBat) {
            _drawBat(canvas, paint, pose);
          } else {
            _drawBird(canvas, paint, pose);
          }
        },
      );
    }
  }

  void _drawBird(Canvas canvas, Paint paint, WildlifePoseSample pose) {
    const scale = 8.0;
    _drawBirdFarWing(canvas, paint, pose, scale);
    // V4: a compact teardrop body. The head sits close to the shoulder so no
    // animated phase can create a swan/goose-like long neck.
    final body = Path()
      ..moveTo(-pose.bodyLength * scale * .43, .10)
      ..quadraticBezierTo(
        -pose.bodyLength * scale * .06,
        -pose.bodyHeight * scale * .70,
        pose.bodyLength * scale * .34,
        -.08,
      )
      ..quadraticBezierTo(
        pose.bodyLength * scale * .27,
        pose.bodyHeight * scale * .46,
        -pose.bodyLength * scale * .40,
        .30,
      )
      ..close();
    canvas.drawPath(body, paint);
    final head = Offset(pose.headForward * scale * .78, -.22);
    canvas.drawCircle(head, 1.05, paint);
    final beak = Path()
      ..moveTo(head.dx + 1, head.dy)
      ..lineTo(head.dx + 1.85, head.dy + .28)
      ..lineTo(head.dx + 1, head.dy + .60)
      ..close();
    canvas.drawPath(beak, paint);
    final tail = Path()
      ..moveTo(-pose.bodyLength * scale * .40, .04)
      ..lineTo(-pose.tailRear * scale * .78, .92)
      ..lineTo(-pose.tailRear * scale, 1.46)
      ..lineTo(-pose.tailRear * scale * .70, 1.66)
      ..lineTo(-pose.bodyLength * scale * .33, 1.05)
      ..close();
    canvas.drawPath(tail, paint);
    _drawBirdNearWing(canvas, paint, pose, scale);
  }

  void _drawBat(Canvas canvas, Paint paint, WildlifePoseSample pose) {
    const scale = 8.4;
    _drawBatFarWing(canvas, paint, pose, scale);
    // The torso deliberately stays short and compact; the head and ears are
    // independent outer-contour cues rather than being absorbed by a wing.
    final body = Path()
      ..moveTo(-pose.bodyLength * scale * .38, .06)
      ..quadraticBezierTo(
        -pose.bodyLength * scale * .05,
        -pose.bodyHeight * scale * .58,
        pose.bodyLength * scale * .28,
        -.05,
      )
      ..quadraticBezierTo(
        pose.bodyLength * scale * .22,
        pose.bodyHeight * scale * .48,
        -pose.bodyLength * scale * .35,
        .30,
      )
      ..close();
    canvas.drawPath(body, paint);
    final head = Offset(pose.headForward * scale * .82, -.24);
    final muzzle = Path()
      ..addOval(Rect.fromCenter(center: head, width: 2.25, height: 1.85))
      ..moveTo(head.dx + .72, head.dy - .22)
      ..lineTo(head.dx + 1.55, head.dy + .08)
      ..lineTo(head.dx + .72, head.dy + .38)
      ..close();
    canvas.drawPath(muzzle, paint);
    final rearEar = Path()
      ..moveTo(head.dx - .54, head.dy - .48)
      ..lineTo(head.dx - .20, head.dy - 1.75)
      ..lineTo(head.dx + .10, head.dy - .45)
      ..close();
    final frontEar = Path()
      ..moveTo(head.dx + .05, head.dy - .48)
      ..lineTo(head.dx + .48, head.dy - 1.60)
      ..lineTo(head.dx + .72, head.dy - .32)
      ..close();
    canvas.drawPath(rearEar, paint);
    canvas.drawPath(frontEar, paint);
    final rear = Path()
      ..moveTo(-pose.bodyLength * scale * .35, -.1)
      ..lineTo(-pose.tailRear * scale * .84, .75)
      ..lineTo(-pose.tailRear * scale, 1.10)
      ..lineTo(-pose.bodyLength * scale * .30, 1.02)
      ..close();
    canvas.drawPath(rear, paint);
    _drawBatNearWing(canvas, paint, pose, scale);
  }

  void _drawBirdFarWing(
    Canvas canvas,
    Paint paint,
    WildlifePoseSample pose,
    double scale,
  ) {
    final span = pose.farWingSpan * scale;
    final wing = Path()
      ..moveTo(-scale * .08, -.1)
      ..quadraticBezierTo(-span, -pose.wingUp * scale * .48, -span * .86, .2)
      ..quadraticBezierTo(
        -span * .40,
        pose.wingDown * scale * .36,
        -scale * .08,
        .45,
      )
      ..close();
    canvas.drawPath(wing, paint);
  }

  void _drawBirdNearWing(
    Canvas canvas,
    Paint paint,
    WildlifePoseSample pose,
    double scale,
  ) {
    final span = pose.wingSpan * scale;
    final wing = Path()
      ..moveTo(-scale * .02, -.28)
      ..quadraticBezierTo(
        -span * .42,
        -pose.wingUp * scale,
        -span,
        -pose.wingUp * scale * .50,
      )
      ..quadraticBezierTo(
        -span * 1.02,
        pose.wingDown * scale,
        -span * .48,
        pose.wingDown * scale + pose.wingFold * scale * .18,
      )
      ..quadraticBezierTo(
        -span * .14,
        pose.wingFold * scale * .10,
        scale * .06,
        .32,
      )
      ..close();
    canvas.drawPath(wing, paint);
  }

  void _drawBatFarWing(
    Canvas canvas,
    Paint paint,
    WildlifePoseSample pose,
    double scale,
  ) {
    final span = pose.farWingSpan * scale;
    final wing = Path()
      ..moveTo(-scale * .04, -.12)
      ..lineTo(-span, -pose.wingUp * scale * .45)
      ..lineTo(-span * .78, pose.wingDown * scale * .28)
      ..lineTo(-span * .34, pose.wingFold * scale * .22)
      ..close();
    canvas.drawPath(wing, paint);
  }

  void _drawBatNearWing(
    Canvas canvas,
    Paint paint,
    WildlifePoseSample pose,
    double scale,
  ) {
    final span = pose.wingSpan * scale;
    final wing = Path()
      ..moveTo(-scale * .02, -.24)
      ..lineTo(-span * .68, -pose.wingUp * scale)
      ..lineTo(-span, -pose.wingUp * scale * .38)
      ..lineTo(-span * .90, pose.wingDown * scale)
      ..lineTo(-span * .68, pose.wingDown * scale + pose.wingFold * scale * .40)
      ..lineTo(-span * .45, pose.wingDown * scale + pose.wingFold * scale * .58)
      ..lineTo(-span * .24, pose.wingFold * scale * .30)
      ..lineTo(scale * .03, .30)
      ..close();
    canvas.drawPath(wing, paint);
  }

  @override
  bool shouldRepaint(covariant DashboardAmbientWildlifePainter oldDelegate) =>
      oldDelegate.plan != plan ||
      oldDelegate.palette != palette ||
      oldDelegate.neutralKind != neutralKind ||
      oldDelegate.neutralLeftToRight != neutralLeftToRight ||
      oldDelegate.neutralScale != neutralScale;
}
