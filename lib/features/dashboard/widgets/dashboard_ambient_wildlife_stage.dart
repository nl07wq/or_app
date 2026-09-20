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
    isFlight: t < .5 ? a.isFlight : b.isFlight,
  );
}

double _lerp(double a, double b, double t) => a + (b - a) * t;

const _catPoses = [
  WildlifePoseSample(
    bodyLength: .84,
    bodyHeight: .64,
    headOffset: -.03,
    earHeight: .30,
    foreReach: -.18,
    hindReach: .28,
    tailLength: .82,
    tailLift: -.18,
    tailThickness: .11,
  ),
  WildlifePoseSample(
    bodyLength: .76,
    bodyHeight: .70,
    headOffset: -.10,
    earHeight: .31,
    foreReach: -.05,
    hindReach: .42,
    tailLength: .76,
    tailLift: -.30,
    tailThickness: .12,
  ),
  WildlifePoseSample(
    bodyLength: .94,
    bodyHeight: .54,
    bodyLift: .10,
    headOffset: .04,
    earHeight: .29,
    foreReach: .16,
    hindReach: -.42,
    tailLength: .90,
    tailLift: .05,
    tailThickness: .12,
  ),
  WildlifePoseSample(
    bodyLength: 1.22,
    bodyHeight: .42,
    bodyLift: .44,
    headOffset: .11,
    earHeight: .27,
    foreReach: .64,
    hindReach: -.58,
    foreLift: .42,
    hindLift: .52,
    tailLength: 1.04,
    tailLift: .24,
    tailThickness: .11,
    isFlight: true,
  ),
  WildlifePoseSample(
    bodyLength: 1.10,
    bodyHeight: .46,
    bodyLift: .24,
    headOffset: .10,
    earHeight: .28,
    foreReach: .70,
    hindReach: -.20,
    foreLift: .08,
    hindLift: .24,
    tailLength: .98,
    tailLift: .14,
    tailThickness: .11,
  ),
  WildlifePoseSample(
    bodyLength: .90,
    bodyHeight: .58,
    bodyLift: .04,
    earHeight: .30,
    foreReach: .28,
    hindReach: .10,
    tailLength: .85,
    tailLift: -.08,
    tailThickness: .12,
  ),
];

const _foxPoses = [
  WildlifePoseSample(
    bodyLength: .78,
    bodyHeight: .68,
    headOffset: -.08,
    muzzleLength: .52,
    earHeight: .46,
    foreReach: -.22,
    hindReach: .36,
    tailLength: 1.18,
    tailLift: -.25,
    tailThickness: .28,
  ),
  WildlifePoseSample(
    bodyLength: .70,
    bodyHeight: .76,
    headOffset: -.16,
    muzzleLength: .54,
    earHeight: .48,
    foreReach: -.08,
    hindReach: .52,
    tailLength: 1.10,
    tailLift: -.40,
    tailThickness: .30,
  ),
  WildlifePoseSample(
    bodyLength: 1.02,
    bodyHeight: .52,
    bodyLift: .14,
    headOffset: .06,
    muzzleLength: .55,
    earHeight: .45,
    foreReach: .20,
    hindReach: -.50,
    tailLength: 1.28,
    tailLift: .04,
    tailThickness: .29,
  ),
  WildlifePoseSample(
    bodyLength: 1.42,
    bodyHeight: .40,
    bodyLift: .54,
    headOffset: .15,
    muzzleLength: .58,
    earHeight: .42,
    foreReach: .78,
    hindReach: -.72,
    foreLift: .48,
    hindLift: .60,
    tailLength: 1.42,
    tailLift: .30,
    tailThickness: .30,
    isFlight: true,
  ),
  WildlifePoseSample(
    bodyLength: 1.26,
    bodyHeight: .45,
    bodyLift: .28,
    headOffset: .14,
    muzzleLength: .56,
    earHeight: .43,
    foreReach: .82,
    hindReach: -.28,
    foreLift: .10,
    hindLift: .30,
    tailLength: 1.36,
    tailLift: .16,
    tailThickness: .30,
  ),
  WildlifePoseSample(
    bodyLength: .92,
    bodyHeight: .62,
    bodyLift: .06,
    muzzleLength: .53,
    earHeight: .46,
    foreReach: .30,
    hindReach: .08,
    tailLength: 1.22,
    tailLift: -.08,
    tailThickness: .29,
  ),
];

const _birdPoses = [
  WildlifePoseSample(
    bodyLength: .68,
    bodyHeight: .34,
    wingSpan: .82,
    wingUp: 1.18,
    wingDown: .14,
    wingFold: .78,
  ),
  WildlifePoseSample(
    bodyLength: .70,
    bodyHeight: .34,
    wingSpan: 1.08,
    wingUp: .62,
    wingDown: .20,
    wingFold: .48,
  ),
  WildlifePoseSample(
    bodyLength: .72,
    bodyHeight: .32,
    wingSpan: 1.48,
    wingUp: .16,
    wingDown: .16,
    wingFold: .16,
  ),
  WildlifePoseSample(
    bodyLength: .70,
    bodyHeight: .36,
    wingSpan: 1.32,
    wingUp: .10,
    wingDown: 1.12,
    wingFold: .32,
  ),
  WildlifePoseSample(
    bodyLength: .68,
    bodyHeight: .36,
    wingSpan: 1.12,
    wingUp: .10,
    wingDown: .62,
    wingFold: .52,
  ),
  WildlifePoseSample(
    bodyLength: .70,
    bodyHeight: .34,
    wingSpan: 1.18,
    wingUp: .28,
    wingDown: .28,
    wingFold: .34,
  ),
];

const _batPoses = [
  WildlifePoseSample(
    bodyLength: .48,
    bodyHeight: .52,
    wingSpan: .78,
    wingUp: 1.16,
    wingDown: .08,
    wingFold: .92,
  ),
  WildlifePoseSample(
    bodyLength: .50,
    bodyHeight: .52,
    wingSpan: 1.02,
    wingUp: .68,
    wingDown: .22,
    wingFold: .68,
  ),
  WildlifePoseSample(
    bodyLength: .52,
    bodyHeight: .50,
    wingSpan: 1.48,
    wingUp: .22,
    wingDown: .28,
    wingFold: .26,
  ),
  WildlifePoseSample(
    bodyLength: .50,
    bodyHeight: .54,
    wingSpan: 1.34,
    wingUp: .08,
    wingDown: 1.24,
    wingFold: .22,
  ),
  WildlifePoseSample(
    bodyLength: .48,
    bodyHeight: .56,
    wingSpan: .96,
    wingUp: .08,
    wingDown: .72,
    wingFold: .72,
  ),
  WildlifePoseSample(
    bodyLength: .50,
    bodyHeight: .52,
    wingSpan: 1.12,
    wingUp: .34,
    wingDown: .36,
    wingFold: .50,
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
  WildlifeKind.cat => 5.6,
  WildlifeKind.fox => 5.1,
  WildlifeKind.birds => 7.0,
  WildlifeKind.bat => 10.5,
};

double wildlifeCycleCountForTraversal(WildlifeEventPlan plan, double width) =>
    wildlifeCycleFrequencyFor(plan.kind) *
    plan.durationForWidth(width).inMilliseconds /
    Duration.millisecondsPerSecond;

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
    final scale = isFox ? 16.0 : 14.0;
    final length = pose.bodyLength * scale;
    final height = pose.bodyHeight * scale;
    final center = Offset(0, -scale * (.78 + pose.bodyLift));
    final left = center.dx - length / 2;
    final right = center.dx + length / 2;
    final top = center.dy - height / 2;
    final bottom = center.dy + height / 2;
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
    canvas.drawPath(body, paint);

    final tailBase = Offset(left + scale * .08, center.dy);
    _drawTail(canvas, paint, tailBase, pose, scale, isFox);
    _drawLeg(
      canvas,
      paint,
      Offset(right - length * .23, bottom - scale * .05),
      pose.foreReach,
      pose.foreLift,
      scale,
    );
    _drawLeg(
      canvas,
      paint,
      Offset(right - length * .05, bottom - scale * .02),
      pose.foreReach - .12,
      pose.foreLift * .8,
      scale,
    );
    _drawLeg(
      canvas,
      paint,
      Offset(left + length * .25, bottom - scale * .05),
      pose.hindReach,
      pose.hindLift,
      scale,
    );
    _drawLeg(
      canvas,
      paint,
      Offset(left + length * .06, bottom - scale * .02),
      pose.hindReach + .12,
      pose.hindLift * .8,
      scale,
    );
    _drawQuadrupedHead(canvas, paint, right, top, center, pose, scale, isFox);
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
    final leg = _strokeFor(paint, 1.7);
    canvas.drawLine(shoulderOrHip, knee, leg);
    canvas.drawLine(knee, foot, leg);
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
        ..moveTo(base.dx, base.dy)
        ..quadraticBezierTo(control.dx, control.dy, tip.dx, tip.dy);
      canvas.drawPath(tail, _strokeFor(paint, 1.8));
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
    double bodyRight,
    double bodyTop,
    Offset center,
    WildlifePoseSample pose,
    double scale,
    bool isFox,
  ) {
    final headCenter = Offset(
      bodyRight + scale * .15,
      center.dy - scale * (.18 + pose.headOffset),
    );
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
    final ears = Path()
      ..moveTo(headCenter.dx - scale * .18, bodyTop + scale * .12)
      ..lineTo(headCenter.dx - scale * .08, bodyTop - pose.earHeight * scale)
      ..lineTo(headCenter.dx + scale * .02, bodyTop + scale * .12)
      ..moveTo(headCenter.dx + scale * .04, bodyTop + scale * .10)
      ..lineTo(
        headCenter.dx + scale * .17,
        bodyTop - pose.earHeight * scale * .88,
      )
      ..lineTo(headCenter.dx + scale * .25, bodyTop + scale * .18);
    canvas.drawPath(ears, paint);
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
      final x = baseX - direction * index * 10;
      final y =
          (isBat ? 16.0 : 13.0) +
          index * 4 +
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
    const scale = 7.4;
    _drawWingPair(canvas, paint, pose, scale, false);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(0, pose.wingDown * scale * .05),
        width: pose.bodyLength * scale,
        height: pose.bodyHeight * scale,
      ),
      paint,
    );
    canvas.drawCircle(Offset(pose.bodyLength * scale * .48, -.5), 1.1, paint);
    final tail = Path()
      ..moveTo(-pose.bodyLength * scale * .42, 0)
      ..lineTo(-pose.bodyLength * scale * .82, 1.5)
      ..lineTo(-pose.bodyLength * scale * .36, 1.4)
      ..close();
    canvas.drawPath(tail, paint);
  }

  void _drawBat(Canvas canvas, Paint paint, WildlifePoseSample pose) {
    const scale = 8.2;
    _drawWingPair(canvas, paint, pose, scale, true);
    canvas.drawOval(
      Rect.fromCenter(
        center: const Offset(0, 0),
        width: pose.bodyLength * scale,
        height: pose.bodyHeight * scale,
      ),
      paint,
    );
  }

  void _drawWingPair(
    Canvas canvas,
    Paint paint,
    WildlifePoseSample pose,
    double scale,
    bool isBat,
  ) {
    final span = pose.wingSpan * scale;
    final up = pose.wingUp * scale;
    final down = pose.wingDown * scale;
    final fold = pose.wingFold * scale;
    for (final side in [-1.0, 1.0]) {
      final root = Offset(side * pose.bodyLength * scale * .20, 0);
      final leading = Offset(side * span, -up);
      final outer = Offset(side * span * (isBat ? .94 : .78), down);
      final trailing = Offset(side * span * .38, down + fold * .26);
      final wing = Path()..moveTo(root.dx, root.dy);
      if (isBat) {
        wing
          ..lineTo(leading.dx, leading.dy)
          ..lineTo(side * span * .78, down + fold * .14)
          ..lineTo(outer.dx, outer.dy)
          ..lineTo(side * span * .43, down + fold * .58)
          ..lineTo(trailing.dx, trailing.dy)
          ..close();
      } else {
        wing
          ..quadraticBezierTo(leading.dx, leading.dy, outer.dx, outer.dy)
          ..quadraticBezierTo(trailing.dx, trailing.dy, root.dx, root.dy)
          ..close();
      }
      canvas.drawPath(wing, paint);
    }
  }

  @override
  bool shouldRepaint(covariant DashboardAmbientWildlifePainter oldDelegate) =>
      oldDelegate.plan != plan || oldDelegate.palette != palette;
}
