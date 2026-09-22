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
  });

  final WildlifeEventPlan? plan;
  final int requestId;

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
                      'ambient-wildlife-preview-${_activePlan?.kind.name ?? 'idle'}',
                    ),
                    painter: DashboardAmbientWildlifePainter(
                      plan: _reducedMotion ? null : _activePlan,
                      progress: _controller,
                      palette: DashboardAmbientWildlifePalette.dark,
                    ),
                    willChange: _activePlan != null,
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

// V3 keeps identity stable: CAT changes 0.88–1.02 (15.9%), FOX 0.86–1.04
// (20.9%). The previous V2 ranges were 0.76–1.22 and 0.70–1.42.
const _catPoses = [
  WildlifePoseSample(
    bodyLength: .91,
    bodyHeight: .59,
    headOffset: -.02,
    earHeight: .29,
    foreReach: -.12,
    hindReach: .20,
    tailLength: .88,
    tailLift: -.06,
    tailThickness: .11,
    headForward: .30,
    tailRear: .88,
  ),
  WildlifePoseSample(
    bodyLength: .88,
    bodyHeight: .61,
    headOffset: -.05,
    earHeight: .29,
    foreReach: -.02,
    hindReach: .28,
    tailLength: .86,
    tailLift: -.12,
    tailThickness: .11,
    headForward: .30,
    tailRear: .86,
  ),
  WildlifePoseSample(
    bodyLength: .94,
    bodyHeight: .56,
    bodyLift: .07,
    headOffset: .02,
    earHeight: .28,
    foreReach: .14,
    hindReach: -.28,
    tailLength: .90,
    tailLift: .01,
    tailThickness: .11,
    headForward: .31,
    tailRear: .90,
  ),
  WildlifePoseSample(
    bodyLength: 1.02,
    bodyHeight: .53,
    bodyLift: .30,
    headOffset: .06,
    earHeight: .28,
    foreReach: .46,
    hindReach: -.40,
    foreLift: .28,
    hindLift: .34,
    tailLength: .94,
    tailLift: .12,
    tailThickness: .11,
    headForward: .32,
    tailRear: .94,
    isFlight: true,
  ),
  WildlifePoseSample(
    bodyLength: .99,
    bodyHeight: .54,
    bodyLift: .16,
    headOffset: .05,
    earHeight: .28,
    foreReach: .52,
    hindReach: -.12,
    foreLift: .05,
    hindLift: .16,
    tailLength: .92,
    tailLift: .08,
    tailThickness: .11,
    headForward: .32,
    tailRear: .92,
  ),
  WildlifePoseSample(
    bodyLength: .93,
    bodyHeight: .58,
    bodyLift: .03,
    earHeight: .29,
    foreReach: .20,
    hindReach: .04,
    tailLength: .89,
    tailLift: -.03,
    tailThickness: .11,
    headForward: .30,
    tailRear: .89,
  ),
];

const _foxPoses = [
  WildlifePoseSample(
    bodyLength: .90,
    bodyHeight: .63,
    headOffset: -.03,
    muzzleLength: .52,
    earHeight: .44,
    foreReach: -.14,
    hindReach: .24,
    tailLength: 1.22,
    tailLift: -.08,
    tailThickness: .29,
    headForward: .60,
    tailRear: 1.22,
  ),
  WildlifePoseSample(
    bodyLength: .86,
    bodyHeight: .65,
    headOffset: -.06,
    muzzleLength: .53,
    earHeight: .44,
    foreReach: -.03,
    hindReach: .32,
    tailLength: 1.20,
    tailLift: -.15,
    tailThickness: .29,
    headForward: .60,
    tailRear: 1.20,
  ),
  WildlifePoseSample(
    bodyLength: .95,
    bodyHeight: .58,
    bodyLift: .08,
    headOffset: .03,
    muzzleLength: .54,
    earHeight: .43,
    foreReach: .15,
    hindReach: -.32,
    tailLength: 1.26,
    tailLift: .01,
    tailThickness: .29,
    headForward: .61,
    tailRear: 1.26,
  ),
  WildlifePoseSample(
    bodyLength: 1.04,
    bodyHeight: .54,
    bodyLift: .36,
    headOffset: .07,
    muzzleLength: .55,
    earHeight: .42,
    foreReach: .58,
    hindReach: -.48,
    foreLift: .30,
    hindLift: .38,
    tailLength: 1.31,
    tailLift: .15,
    tailThickness: .30,
    headForward: .62,
    tailRear: 1.31,
    isFlight: true,
  ),
  WildlifePoseSample(
    bodyLength: 1.01,
    bodyHeight: .55,
    bodyLift: .18,
    headOffset: .06,
    muzzleLength: .55,
    earHeight: .43,
    foreReach: .64,
    hindReach: -.15,
    foreLift: .06,
    hindLift: .18,
    tailLength: 1.29,
    tailLift: .10,
    tailThickness: .30,
    headForward: .62,
    tailRear: 1.29,
  ),
  WildlifePoseSample(
    bodyLength: .94,
    bodyHeight: .60,
    bodyLift: .04,
    muzzleLength: .53,
    earHeight: .44,
    foreReach: .24,
    hindReach: .05,
    tailLength: 1.24,
    tailLift: -.02,
    tailThickness: .29,
    headForward: .61,
    tailRear: 1.24,
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

/// Samples one of six organic key poses and interpolates to its successor.
WildlifePoseSample wildlifePoseFor(WildlifeKind kind, double phase) {
  final poses = switch (kind) {
    WildlifeKind.cat => _catPoses,
    WildlifeKind.fox => _foxPoses,
    WildlifeKind.birds => _birdPoses,
    WildlifeKind.bat => _batPoses,
  };
  final wrapped = phase - phase.floorToDouble();
  final position = wrapped * poses.length;
  final index = position.floor() % poses.length;
  return WildlifePoseSample.lerp(
    poses[index],
    poses[(index + 1) % poses.length],
    position - position.floorToDouble(),
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
  final scale = kind == WildlifeKind.fox ? 16.0 : 14.0;
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
  }) : super(repaint: progress);

  final WildlifeEventPlan? plan;
  final Animation<double> progress;
  final DashboardAmbientWildlifePalette palette;

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
    final event = plan;
    if (event == null || size.isEmpty) return;
    final t = progress.value;
    final direction = event.leftToRight ? 1.0 : -1.0;
    final travel = size.width + (event.isGround ? 60.0 : 52.0);
    final x = event.leftToRight
        ? -30 + travel * t
        : size.width + 30 - travel * t;
    final silhouette = Paint()..color = palette.silhouette;
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
    );
    _drawLeg(
      canvas,
      paint,
      Offset(geometry.hipRoot.dx - length * .12, geometry.hipRoot.dy),
      pose.hindReach + .12,
      pose.hindLift * .8,
      scale,
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
    );
    _drawLeg(
      canvas,
      paint,
      geometry.hipRoot,
      pose.hindReach,
      pose.hindLift,
      scale,
    );
    _drawQuadrupedHead(canvas, paint, geometry, pose, isFox);
  }

  void _drawLeg(
    Canvas canvas,
    Paint paint,
    Offset shoulderOrHip,
    double reach,
    double lift,
    double scale,
  ) {
    final foot = Offset(shoulderOrHip.dx + reach * scale, -lift * scale);
    final knee = Offset(
      (shoulderOrHip.dx + foot.dx) / 2 - reach * scale * .16,
      (shoulderOrHip.dy + foot.dy) / 2 + scale * .10,
    );
    final upper = scale * .13;
    final lower = scale * .075;
    final leg = Path()
      ..moveTo(shoulderOrHip.dx - upper, shoulderOrHip.dy - upper * .20)
      ..quadraticBezierTo(knee.dx - lower, knee.dy, foot.dx - lower, foot.dy)
      ..quadraticBezierTo(
        foot.dx,
        foot.dy + lower * .55,
        foot.dx + lower,
        foot.dy,
      )
      ..quadraticBezierTo(
        knee.dx + lower,
        knee.dy,
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
    if (!isFox) {
      final tail = Path()
        ..moveTo(base.dx + scale * .12, base.dy + scale * .06)
        ..quadraticBezierTo(control.dx, control.dy, tip.dx, tip.dy);
      canvas.drawPath(tail, _strokeFor(paint, 2.2));
      return;
    }
    final thickness = pose.tailThickness * scale;
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
      canvas.drawCircle(headCenter, scale * .23, paint);
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

  Paint _strokeFor(Paint source, double width) => Paint()
    ..color = source.color
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

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
    canvas.drawOval(
      Rect.fromCenter(
        center: const Offset(0, 0),
        width: pose.bodyLength * scale,
        height: pose.bodyHeight * scale,
      ),
      paint,
    );
    final head = Offset(pose.headForward * scale, -.35);
    canvas.drawCircle(head, 1.15, paint);
    final beak = Path()
      ..moveTo(head.dx + 1, head.dy)
      ..lineTo(head.dx + 2.25, head.dy + .35)
      ..lineTo(head.dx + 1, head.dy + .75)
      ..close();
    canvas.drawPath(beak, paint);
    final tail = Path()
      ..moveTo(-pose.bodyLength * scale * .42, 0)
      ..lineTo(-pose.tailRear * scale, 1.7)
      ..lineTo(-pose.bodyLength * scale * .34, 1.45)
      ..close();
    canvas.drawPath(tail, paint);
    _drawBirdNearWing(canvas, paint, pose, scale);
  }

  void _drawBat(Canvas canvas, Paint paint, WildlifePoseSample pose) {
    const scale = 8.4;
    _drawBatFarWing(canvas, paint, pose, scale);
    canvas.drawOval(
      Rect.fromCenter(
        center: const Offset(0, 0),
        width: pose.bodyLength * scale,
        height: pose.bodyHeight * scale,
      ),
      paint,
    );
    final head = Offset(pose.headForward * scale, -.35);
    canvas.drawCircle(head, 1.05, paint);
    final rear = Path()
      ..moveTo(-pose.bodyLength * scale * .38, -.2)
      ..lineTo(-pose.tailRear * scale, .85)
      ..lineTo(-pose.bodyLength * scale * .32, 1.15)
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
        -span * .58,
        -pose.wingUp * scale,
        -span,
        -pose.wingUp * scale * .50,
      )
      ..quadraticBezierTo(
        -span * .88,
        pose.wingDown * scale,
        -span * .38,
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
      ..lineTo(-span * .84, pose.wingDown * scale)
      ..lineTo(-span * .52, pose.wingDown * scale + pose.wingFold * scale * .48)
      ..lineTo(-span * .24, pose.wingFold * scale * .30)
      ..lineTo(scale * .03, .30)
      ..close();
    canvas.drawPath(wing, paint);
  }

  @override
  bool shouldRepaint(covariant DashboardAmbientWildlifePainter oldDelegate) =>
      oldDelegate.plan != plan || oldDelegate.palette != palette;
}
