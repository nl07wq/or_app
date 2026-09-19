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
          _drawCat(canvas, silhouette, t, event.phaseSeed);
        });
      case WildlifeKind.fox:
        _withDirection(canvas, Offset(x, size.height - 5), direction, () {
          _drawFox(canvas, silhouette, t, event.phaseSeed);
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

  void _drawCat(Canvas canvas, Paint paint, double t, double seed) {
    final cycle = math.sin((t * 7 + seed) * math.pi * 2);
    final bounce = math.sin((t * 14 + seed) * math.pi * 2) * .8;
    final body = Rect.fromCenter(
      center: Offset(0, -9 + bounce),
      width: 16 + cycle * 1.4,
      height: 7,
    );
    canvas.drawOval(body, paint);
    canvas.drawCircle(Offset(10, -13 + bounce), 3.2, paint);
    final ears = Path()
      ..moveTo(8, -15 + bounce)
      ..lineTo(9, -19 + bounce)
      ..lineTo(11, -15 + bounce)
      ..moveTo(11, -15 + bounce)
      ..lineTo(13, -18 + bounce)
      ..lineTo(13.5, -14 + bounce);
    canvas.drawPath(ears, paint);
    _drawLegs(canvas, paint, bounce, cycle, 1.8, 5.2);
    final tail = Path()
      ..moveTo(-8, -10 + bounce)
      ..quadraticBezierTo(-15, -14 - cycle * 2, -16, -7 + cycle * 2);
    canvas.drawPath(tail, _strokeFor(paint, 2));
  }

  void _drawFox(Canvas canvas, Paint paint, double t, double seed) {
    final cycle = math.sin((t * 8 + seed) * math.pi * 2);
    final bounce = math.sin((t * 16 + seed) * math.pi * 2) * .9;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(-1, -10 + bounce),
        width: 22 + cycle * 2.2,
        height: 7.5,
      ),
      paint,
    );
    final head = Path()
      ..moveTo(10, -14 + bounce)
      ..lineTo(16, -13 + bounce)
      ..lineTo(19, -10 + bounce)
      ..lineTo(12, -8 + bounce)
      ..close();
    canvas.drawPath(head, paint);
    final ears = Path()
      ..moveTo(10, -14 + bounce)
      ..lineTo(11, -20 + bounce)
      ..lineTo(14, -14 + bounce)
      ..moveTo(14, -14 + bounce)
      ..lineTo(16, -19 + bounce)
      ..lineTo(17, -13 + bounce);
    canvas.drawPath(ears, paint);
    final tail = Path()
      ..moveTo(-11, -10 + bounce)
      ..quadraticBezierTo(-19, -18 - cycle * 2, -24, -10 + cycle * 2)
      ..quadraticBezierTo(-19, -5, -12, -7 + bounce)
      ..close();
    canvas.drawPath(tail, paint);
    _drawLegs(canvas, paint, bounce, cycle, 2.4, 6.5);
  }

  void _drawLegs(
    Canvas canvas,
    Paint paint,
    double bounce,
    double cycle,
    double stride,
    double separation,
  ) {
    final legPaint = _strokeFor(paint, 1.8);
    for (final leg in [
      (-separation, cycle),
      (-separation / 2, -cycle),
      (separation / 2, -cycle),
      (separation, cycle),
    ]) {
      final hipX = leg.$1;
      final footX = hipX + leg.$2 * stride;
      canvas.drawLine(Offset(hipX, -6 + bounce), Offset(footX, 0), legPaint);
    }
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
          if (isBat) {
            _drawBat(canvas, paint, t, phase);
          } else {
            _drawBird(canvas, paint, t, phase);
          }
        },
      );
    }
  }

  void _drawBird(Canvas canvas, Paint paint, double t, double phase) {
    final flap = math.sin((t * 7 + phase) * math.pi * 2);
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(0, 0), width: 5, height: 2.6),
      paint,
    );
    canvas.drawCircle(const Offset(2.8, -.5), 1.1, paint);
    final wing = Path()
      ..moveTo(-.5, 0)
      ..quadraticBezierTo(-4, -4 - flap * 2.2, -6, -1 - flap * 1.4)
      ..quadraticBezierTo(-3, 1, -.5, 0)
      ..moveTo(.2, 0)
      ..quadraticBezierTo(-1.5, 4 + flap * 2.2, -4, 2 + flap * 1.4)
      ..quadraticBezierTo(-2, .5, .2, 0);
    canvas.drawPath(wing, paint);
  }

  void _drawBat(Canvas canvas, Paint paint, double t, double phase) {
    final flap = math.sin((t * 11 + phase) * math.pi * 2);
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(0, 0), width: 3.5, height: 4),
      paint,
    );
    final wings = Path()
      ..moveTo(-1, 0)
      ..lineTo(-7, -4 - flap * 2.5)
      ..lineTo(-9, 2)
      ..lineTo(-4, 3 + flap)
      ..close()
      ..moveTo(1, 0)
      ..lineTo(7, -4 - flap * 2.5)
      ..lineTo(9, 2)
      ..lineTo(4, 3 + flap)
      ..close();
    canvas.drawPath(wings, paint);
  }

  @override
  bool shouldRepaint(covariant DashboardAmbientWildlifePainter oldDelegate) =>
      oldDelegate.plan != plan || oldDelegate.palette != palette;
}
