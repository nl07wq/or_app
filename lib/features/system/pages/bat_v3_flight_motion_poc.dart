import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/operation_card.dart';
import '../../../core/widgets/section_header.dart';
import 'bat_v3_source_data.dart';

enum BatV3View { canonical, bodyOverlay }

class BatV3FlightMotionPoc extends StatefulWidget {
  const BatV3FlightMotionPoc({
    super.key,
    this.initiallySourceExpanded = false,
    this.initiallyFlapExpanded = false,
  });

  /// Test-only opt-in; the Sandbox page itself always begins collapsed.
  final bool initiallySourceExpanded;
  final bool initiallyFlapExpanded;

  @override
  State<BatV3FlightMotionPoc> createState() => _BatV3FlightMotionPocState();
}

class _BatV3FlightMotionPocState extends State<BatV3FlightMotionPoc> {
  Timer? _timer;
  var _poseIndex = 0;
  var _cycleIndex = 0;
  var _milliseconds = 125;
  var _playing = false;
  var _flutter = true;
  var _crossing = false;
  var _leftToRight = true;
  var _inspectionScale = 1.0;
  var _view = BatV3View.canonical;
  var _travel = 0.0;
  late var _sourceExpanded = widget.initiallySourceExpanded;
  late var _flapExpanded = widget.initiallyFlapExpanded;

  BatV3SourcePose get _pose => BatV3SourceSet.poses[_poseIndex];
  double get _flutterY =>
      _flutter ? BatV3SourceSet.flutterOffsets[_cycleIndex] : 0;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _select(int index) {
    _pause();
    setState(() {
      _poseIndex = index;
      _cycleIndex = BatV3SourceSet.cycle.indexOf(index);
    });
  }

  void _start() {
    if (_playing) return;
    setState(() => _playing = true);
    _run();
  }

  void _pause() {
    _timer?.cancel();
    _timer = null;
    if (_playing && mounted) setState(() => _playing = false);
  }

  void _restart() {
    _timer?.cancel();
    setState(() {
      _poseIndex = 0;
      _cycleIndex = 0;
      _travel = 0;
      _playing = true;
    });
    _run();
  }

  void _run() {
    _timer?.cancel();
    _timer = Timer.periodic(Duration(milliseconds: _milliseconds), (_) {
      if (!mounted) return;
      setState(() {
        _cycleIndex = (_cycleIndex + 1) % BatV3SourceSet.cycle.length;
        _poseIndex = BatV3SourceSet.cycle[_cycleIndex];
        _travel = (_travel + .035) % 1;
      });
    });
  }

  void _timing(int value) {
    final resume = _playing;
    _timer?.cancel();
    setState(() => _milliseconds = value);
    if (resume) _run();
  }

  void _toggleFlap() {
    setState(() {
      _flapExpanded = !_flapExpanded;
      if (!_flapExpanded) _pause();
    });
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _BatV3Disclosure(
        key: const ValueKey('bat-v3-source-disclosure'),
        icon: Icons.document_scanner_outlined,
        title: 'BAT V3 — NEW 5-POSE SOURCE SET',
        expanded: _sourceExpanded,
        onTap: () => setState(() => _sourceExpanded = !_sourceExpanded),
      ),
      if (_sourceExpanded) ...[
        AppSpacing.gapSM,
        OperationCard(
          key: const ValueKey('bat-v3-source-audit'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'FRAME ${_pose.index.toString().padLeft(2, '0')} · ${_pose.name}',
                key: const ValueKey('bat-v3-pose-label'),
              ),
              const Text(
                'CANONICAL ASSET · shared 1800×1700 transparent canvas',
              ),
              AppSpacing.gapSM,
              _BatV3Image(
                pose: _pose,
                view: _view,
                leftToRight: _leftToRight,
                inspectionScale: _inspectionScale,
                flutterY: 0,
              ),
              AppSpacing.gapSM,
              _frames('bat-v3-source-frame'),
              AppSpacing.gapSM,
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final view in BatV3View.values)
                    _choice(
                      'bat-v3-view-${view.name}',
                      switch (view) {
                        BatV3View.canonical => 'CANONICAL',
                        BatV3View.bodyOverlay => 'BODY OVERLAY',
                      },
                      _view == view,
                      () => setState(() => _view = view),
                    ),
                ],
              ),
              AppSpacing.gapSM,
              Text(
                'BODY AXIS ${_pose.canonicalBodyAxis.toStringAsFixed(1)} px · ORIGIN 800, 850',
                key: const ValueKey('bat-v3-body-metrics'),
              ),
              const Text(
                'CANONICAL CANVAS 1800×1700 · CAT V2.10 NORMAL GRAY · SAFETY 96',
                key: ValueKey('bat-v3-canonical-metrics'),
              ),
            ],
          ),
        ),
      ],
      AppSpacing.gapLG,
      _BatV3Disclosure(
        key: const ValueKey('bat-v3-flap-disclosure'),
        icon: Icons.motion_photos_on_outlined,
        title: 'BAT V3 BODY-REGISTERED FLAP CYCLE',
        expanded: _flapExpanded,
        onTap: _toggleFlap,
      ),
      if (_flapExpanded) ...[
        AppSpacing.gapSM,
        OperationCard(
          key: const ValueKey('bat-v3-flap-poc'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _playing
                    ? 'PLAYING · $_milliseconds ms / POSE'
                    : 'PAUSED · $_milliseconds ms / POSE',
                key: const ValueKey('bat-v3-state'),
              ),
              if (_crossing) ...[
                const Text('FLIGHT / CROSSING · SELECTED SIZE'),
                _BatV3Crossing(
                  pose: _pose,
                  leftToRight: _leftToRight,
                  progress: _travel,
                  flutterY: _flutterY,
                  inspectionScale: _inspectionScale,
                ),
              ] else
                _BatV3Image(
                  pose: _pose,
                  view: BatV3View.canonical,
                  leftToRight: _leftToRight,
                  inspectionScale: _inspectionScale,
                  flutterY: _flutterY,
                ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _choice('bat-v3-play', 'PLAY', _playing, _start),
                  _choice('bat-v3-pause', 'PAUSE', !_playing, _pause),
                  _choice('bat-v3-restart', 'RESTART', false, _restart),
                ],
              ),
              AppSpacing.gapSM,
              _frames('bat-v3-frame'),
              AppSpacing.gapSM,
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _choice(
                    'bat-v3-in-place',
                    'IN-PLACE',
                    !_crossing,
                    () => setState(() => _crossing = false),
                  ),
                  _choice(
                    'bat-v3-crossing',
                    'FLIGHT / CROSSING',
                    _crossing,
                    () => setState(() => _crossing = true),
                  ),
                  _choice(
                    'bat-v3-flutter-on',
                    'FLUTTER ON',
                    _flutter,
                    () => setState(() => _flutter = true),
                  ),
                  _choice(
                    'bat-v3-flutter-off',
                    'FLUTTER OFF',
                    !_flutter,
                    () => setState(() => _flutter = false),
                  ),
                ],
              ),
              AppSpacing.gapSM,
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final value in [100, 125, 150])
                    _choice(
                      'bat-v3-timing-$value',
                      value == 100
                          ? 'FAST 100 · 800ms'
                          : value == 125
                          ? 'NORMAL 125 · 1000ms'
                          : 'SLOW 150 · 1200ms',
                      _milliseconds == value,
                      () => _timing(value),
                    ),
                ],
              ),
              AppSpacing.gapSM,
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _choice(
                    'bat-v3-ltr',
                    'L→R',
                    _leftToRight,
                    () => setState(() => _leftToRight = true),
                  ),
                  _choice(
                    'bat-v3-rtl',
                    'R→L',
                    !_leftToRight,
                    () => setState(() => _leftToRight = false),
                  ),
                  for (final value in [1.0, .5, .25])
                    _choice(
                      'bat-v3-scale-${value.toStringAsFixed(2)}',
                      '${value.toStringAsFixed(2)}×',
                      _inspectionScale == value,
                      () => setState(() => _inspectionScale = value),
                    ),
                ],
              ),
              AppSpacing.gapSM,
              const Text('48PX PRODUCTION PREVIEW'),
              BatV3CanonicalFrame(
                pose: _pose,
                leftToRight: _leftToRight,
                inspectionScale: 1,
                flutterY: _flutterY,
                bodyOverlay: false,
                viewportHeight: 48,
              ),
              AppSpacing.gapSM,
              const Text(
                '01 NEUTRAL → 02 TOP INTERMEDIATE → 03 TOP → 02 → 01 → 04 BOTTOM INTERMEDIATE → 05 BOTTOM → 04. Same-rect canonical PNG switching; flutter is shared whole-object Y motion only.',
              ),
            ],
          ),
        ),
      ],
    ],
  );

  Widget _frames(String prefix) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (var i = 0; i < 5; i++)
        _choice(
          '$prefix-${i + 1}',
          'FRAME ${(i + 1).toString().padLeft(2, '0')}',
          _poseIndex == i,
          () => _select(i),
        ),
    ],
  );
  Widget _choice(
    String key,
    String label,
    bool selected,
    VoidCallback action,
  ) => OutlinedButton(
    key: ValueKey(key),
    style: selected
        ? OutlinedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          )
        : null,
    onPressed: action,
    child: Text(label),
  );
}

class _BatV3Disclosure extends StatelessWidget {
  const _BatV3Disclosure({
    super.key,
    required this.icon,
    required this.title,
    required this.expanded,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => OperationCard(
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(icon),
            const SizedBox(width: 12),
            Expanded(child: Text(title)),
            Icon(expanded ? Icons.expand_less : Icons.expand_more),
          ],
        ),
      ),
    ),
  );
}

class _BatV3Image extends StatelessWidget {
  const _BatV3Image({
    required this.pose,
    required this.view,
    required this.leftToRight,
    required this.inspectionScale,
    required this.flutterY,
  });
  final BatV3SourcePose pose;
  final BatV3View view;
  final bool leftToRight;
  final double inspectionScale;
  final double flutterY;
  @override
  Widget build(BuildContext context) {
    return BatV3CanonicalFrame(
      key: ValueKey('bat-v3-image-${inspectionScale.toStringAsFixed(2)}'),
      pose: pose,
      leftToRight: leftToRight,
      inspectionScale: inspectionScale,
      flutterY: flutterY,
      bodyOverlay: view == BatV3View.bodyOverlay,
      viewportHeight: 260,
    );
  }
}

class _BatV3BodyOverlayPainter extends CustomPainter {
  const _BatV3BodyOverlayPainter({required this.pose});

  final BatV3SourcePose pose;

  @override
  void paint(Canvas canvas, Size size) {
    final anchor = BatV3SourceSet.canonicalBodyAnchor;
    final paint = Paint()
      ..color = Colors.cyan
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final head = BatV3SourceSet.canonicalLandmark(pose, pose.head);
    final posterior = BatV3SourceSet.canonicalLandmark(pose, pose.posterior);
    canvas.drawLine(head, posterior, paint);
    canvas.drawCircle(head, 9, paint);
    canvas.drawCircle(posterior, 9, paint);
    canvas.drawLine(
      Offset(anchor.dx - 8, anchor.dy),
      Offset(anchor.dx + 8, anchor.dy),
      paint,
    );
    canvas.drawLine(
      Offset(anchor.dx, anchor.dy - 8),
      Offset(anchor.dx, anchor.dy + 8),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _BatV3BodyOverlayPainter oldDelegate) =>
      oldDelegate.pose != pose;
}

class BatV3CanonicalFrame extends StatelessWidget {
  const BatV3CanonicalFrame({
    super.key,
    required this.pose,
    required this.leftToRight,
    required this.inspectionScale,
    required this.flutterY,
    required this.bodyOverlay,
    required this.viewportHeight,
  });

  final BatV3SourcePose pose;
  final bool leftToRight;
  final double inspectionScale;
  final double flutterY;
  final bool bodyOverlay;
  final double viewportHeight;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: viewportHeight,
    child: FittedBox(
      fit: BoxFit.contain,
      child: SizedBox(
        width: BatV3SourceSet.canonicalCanvas.width,
        height: BatV3SourceSet.canonicalCanvas.height,
        child: ClipRect(
          child: Transform.flip(
            // Sources face left. Mirroring is coupled to travel direction so
            // L→R is right-facing and R→L is left-facing.
            flipX: leftToRight,
            child: Transform.translate(
              offset: Offset(
                0,
                flutterY /
                    viewportHeight *
                    BatV3SourceSet.canonicalCanvas.height,
              ),
              child: Transform.scale(
                scale: inspectionScale,
                alignment: Alignment.center,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _BatV3RegisteredSource(pose: pose),
                    if (bodyOverlay)
                      CustomPaint(
                        painter: _BatV3BodyOverlayPainter(pose: pose),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _BatV3RegisteredSource extends StatelessWidget {
  const _BatV3RegisteredSource({required this.pose});

  final BatV3SourcePose pose;

  @override
  Widget build(BuildContext context) => Image.asset(
    pose.canonicalAsset,
    width: BatV3SourceSet.canonicalCanvas.width,
    height: BatV3SourceSet.canonicalCanvas.height,
    fit: BoxFit.fill,
  );
}

class _BatV3Crossing extends StatelessWidget {
  const _BatV3Crossing({
    required this.pose,
    required this.leftToRight,
    required this.progress,
    required this.flutterY,
    required this.inspectionScale,
  });

  final BatV3SourcePose pose;
  final bool leftToRight;
  final double progress;
  final double flutterY;
  final double inspectionScale;

  @override
  Widget build(BuildContext context) => SizedBox(
    key: const ValueKey('bat-v3-crossing-stage'),
    height: 260,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final frameWidth =
            260 *
            inspectionScale *
            BatV3SourceSet.canonicalCanvas.width /
            BatV3SourceSet.canonicalCanvas.height;
        final x = -frameWidth + (constraints.maxWidth + frameWidth) * progress;
        return ClipRect(
          child: Transform.translate(
            offset: Offset(
              leftToRight ? x : constraints.maxWidth - x - frameWidth,
              flutterY,
            ),
            child: SizedBox(
              width: frameWidth,
              child: BatV3CanonicalFrame(
                pose: pose,
                leftToRight: leftToRight,
                inspectionScale: 1,
                flutterY: 0,
                bodyOverlay: false,
                viewportHeight: 260,
              ),
            ),
          ),
        );
      },
    ),
  );
}

/// Production-scale tuning surface. It intentionally reuses the V4 canonical
/// cels and applies only shared time, Y flutter, X travel, and mirror state.
class BatV3ProductionPreview extends StatefulWidget {
  const BatV3ProductionPreview({super.key, this.nextInt});

  /// Test injection only. Production uses an unbiased local random source.
  final int Function(int max)? nextInt;

  @override
  State<BatV3ProductionPreview> createState() => _BatV3ProductionPreviewState();
}

/// Final screen-space motion contract for the 48px preview. It is deliberately
/// separate from canonical cel registration.
abstract final class BatV3ProductionFlight {
  static const stageHeight = 112.0;
  static const batHeight = 48.0;
  static const batWidth = 51.0;
  static const poseDurationMs = 60;
  static const fullSpeedDurationMs = 2200;
  static const halfSpeedDurationMs = 4400;
  static const flutterAmplitude = 8;
  // Derived from the union of all five canonical silhouette bounds after the
  // 1800×1700 canvas is fitted to the 48px-class production rect. These are
  // visible pixels, not the transparent PNG/widget bounds.
  static const visibleBatMinX = 14.23;
  static const visibleBatMaxX = 45.23;
  static const entryExitGap = 3.0;
  static const instances = <BatV3ProductionInstance>[
    BatV3ProductionInstance(
      identifier: 0,
      phaseOffset: 0,
      startDelayMs: 0,
      formationY: 0,
    ),
    BatV3ProductionInstance(
      identifier: 2,
      phaseOffset: 2,
      startDelayMs: 180,
      formationY: -12,
    ),
    BatV3ProductionInstance(
      identifier: 5,
      phaseOffset: 5,
      startDelayMs: 360,
      formationY: 10,
    ),
  ];
  static const glitchInstances = <BatV3ProductionInstance>[
    BatV3ProductionInstance(
      identifier: 0,
      phaseOffset: 0,
      startDelayMs: 0,
      formationY: 0,
    ),
    BatV3ProductionInstance(
      identifier: 1,
      phaseOffset: 2,
      startDelayMs: 80,
      formationY: -12,
    ),
    BatV3ProductionInstance(
      identifier: 2,
      phaseOffset: 5,
      startDelayMs: 160,
      formationY: -6,
    ),
    BatV3ProductionInstance(
      identifier: 3,
      phaseOffset: 1,
      startDelayMs: 240,
      formationY: 6,
    ),
    BatV3ProductionInstance(
      identifier: 4,
      phaseOffset: 4,
      startDelayMs: 320,
      formationY: 12,
    ),
    BatV3ProductionInstance(
      identifier: 5,
      phaseOffset: 7,
      startDelayMs: 400,
      formationY: 18,
    ),
    BatV3ProductionInstance(
      identifier: 6,
      phaseOffset: 3,
      startDelayMs: 480,
      formationY: -18,
    ),
    BatV3ProductionInstance(
      identifier: 7,
      phaseOffset: 6,
      startDelayMs: 560,
      formationY: -15,
    ),
    BatV3ProductionInstance(
      identifier: 8,
      phaseOffset: 2,
      startDelayMs: 640,
      formationY: -9,
    ),
    BatV3ProductionInstance(
      identifier: 9,
      phaseOffset: 5,
      startDelayMs: 720,
      formationY: 9,
    ),
  ];

  static int crossingDurationForSpeed(String speed) =>
      speed == '0.5×' ? halfSpeedDurationMs : fullSpeedDurationMs;

  static double progressFor({
    required int elapsedMs,
    required int durationMs,
    required BatV3ProductionInstance instance,
  }) => ((elapsedMs - instance.startDelayMs) / durationMs).clamp(0, 1);

  static double leftFor({
    required double stageWidth,
    required double progress,
    required bool leftToRight,
  }) {
    final entry = -visibleBatMaxX - entryExitGap;
    final exit = stageWidth - visibleBatMinX + entryExitGap;
    final fullRange = entry + (exit - entry) * progress;
    return leftToRight ? fullRange : entry + exit - fullRange;
  }

  static double topFor(double flutterY) =>
      (stageHeight - batHeight) / 2 + flutterY;

  static bool isInstanceComplete({
    required int elapsedMs,
    required int durationMs,
    required BatV3ProductionInstance instance,
  }) => elapsedMs >= durationMs + instance.startDelayMs;

  static double flutterOffset({
    required int cycleIndex,
    required int amplitude,
    required bool enabled,
  }) => enabled ? BatV3SourceSet.flutterOffsets[cycleIndex] * amplitude / 4 : 0;
}

/// Production event-selection authority. FORCE actions may bypass this policy,
/// but all normal random count selection uses these exact weights.
abstract final class BatV3ProductionEventPolicy {
  static const glitchProbability = .05;
  static const normalEventProbability = .95;
  static const normalOneProbability = .50;
  static const normalTwoProbability = .30;
  static const normalThreeProbability = .20;
  static const glitchBatCount = 10;

  static bool isGlitchRoll(int roll) {
    if (roll < 0 || roll >= 20) throw ArgumentError.value(roll, 'roll');
    return roll == 0;
  }

  static int normalCountForRoll(int roll) {
    if (roll < 0 || roll >= 100) throw ArgumentError.value(roll, 'roll');
    if (roll < 50) return 1;
    if (roll < 80) return 2;
    return 3;
  }

  static List<BatV3ProductionInstance> instancesFor({
    required int eventRoll,
    required int countRoll,
  }) => isGlitchRoll(eventRoll)
      ? BatV3ProductionFlight.glitchInstances
      : BatV3ProductionFlight.instances
            .take(normalCountForRoll(countRoll))
            .toList(growable: false);
}

/// A deterministic, compact group formation. Delays keep every bat at the
/// shared offscreen entry until its own flight begins; phase and Y offsets keep
/// the visible cels from reading as a duplicated stack.
class BatV3ProductionInstance {
  const BatV3ProductionInstance({
    required this.identifier,
    required this.phaseOffset,
    required this.startDelayMs,
    required this.formationY,
  });

  final int identifier;
  final int phaseOffset;
  final int startDelayMs;
  final double formationY;
}

class _BatV3ProductionPreviewState extends State<BatV3ProductionPreview> {
  Timer? _poseTicker;
  Timer? _crossingTicker;
  Timer? _eventBoundaryTimer;
  final math.Random _random = math.Random();
  var _crossingElapsed = 0;
  var _cycleIndex = 0;
  var _playing = false;
  var _eventActive = false;
  var _forcedGlitch = false;
  var _resumeNormalAfterForced = false;
  var _flutterOn = true;
  var _leftToRight = true;
  var _speed = '1×';
  int? _selectedBatCount = 1;
  var _eventBatCount = 1;

  BatV3SourcePose get _pose =>
      BatV3SourceSet.poses[BatV3SourceSet.cycle[_cycleIndex]];
  int get _crossingDuration =>
      BatV3ProductionFlight.crossingDurationForSpeed(_speed);
  List<BatV3ProductionInstance> get _eventInstances => _forcedGlitch
      ? BatV3ProductionFlight.glitchInstances
      : BatV3ProductionFlight.instances.take(_eventBatCount).toList();
  List<BatV3ProductionInstance> get _visibleInstances => _eventInstances
      .where(
        (instance) => !BatV3ProductionFlight.isInstanceComplete(
          elapsedMs: _crossingElapsed,
          durationMs: _crossingDuration,
          instance: instance,
        ),
      )
      .toList(growable: false);
  int get _eventEndMs => _crossingDuration + _eventInstances.last.startDelayMs;
  int get _nextEventBatCount =>
      _selectedBatCount ??
      BatV3ProductionEventPolicy.normalCountForRoll(
        widget.nextInt?.call(100) ?? _random.nextInt(100),
      );
  String get _countTelemetry => _selectedBatCount == null
      ? _eventActive
            ? 'RANDOM → ×$_eventBatCount'
            : 'RANDOM'
      : '×$_selectedBatCount';

  @override
  void dispose() {
    _poseTicker?.cancel();
    _crossingTicker?.cancel();
    _eventBoundaryTimer?.cancel();
    super.dispose();
  }

  void _play() {
    if (_playing) return;
    setState(() => _playing = true);
    _startPoseClock();
    _beginNextEvent();
  }

  void _beginNextEvent() {
    if (!mounted || !_playing) return;
    _eventBoundaryTimer?.cancel();
    setState(() {
      _crossingElapsed = 0;
      _cycleIndex = 0;
      _eventBatCount = _nextEventBatCount;
      _forcedGlitch = false;
      _eventActive = true;
    });
    _crossingTicker?.cancel();
    _crossingTicker = Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (!mounted) return;
      final nextElapsed = _crossingElapsed + 16;
      if (nextElapsed >= _eventEndMs) {
        _finishCurrentEvent();
      } else {
        setState(() => _crossingElapsed = nextElapsed);
      }
    });
  }

  void _finishCurrentEvent() {
    _crossingTicker?.cancel();
    _crossingTicker = null;
    final continueEndlessly = _forcedGlitch
        ? _resumeNormalAfterForced
        : _playing;
    setState(() {
      _eventActive = false;
      _forcedGlitch = false;
      _resumeNormalAfterForced = false;
      if (!continueEndlessly) _playing = false;
    });
    // The single frame boundary guarantees completed cels are removed before
    // the next endless event becomes paintable, without a visible pause.
    _eventBoundaryTimer = Timer(const Duration(milliseconds: 16), () {
      if (!mounted) return;
      if (continueEndlessly) {
        _playing = true;
        _beginNextEvent();
      } else {
        _poseTicker?.cancel();
        _poseTicker = null;
      }
    });
  }

  void _forceGlitch() {
    final resumeNormal = _playing;
    _stopClocks();
    setState(() {
      _crossingElapsed = 0;
      _cycleIndex = 0;
      _eventActive = true;
      _forcedGlitch = true;
      _resumeNormalAfterForced = resumeNormal;
      _playing = true;
    });
    _startPoseClock();
    _crossingTicker = Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (!mounted) return;
      final nextElapsed = _crossingElapsed + 16;
      if (nextElapsed >= _eventEndMs) {
        _finishCurrentEvent();
      } else {
        setState(() => _crossingElapsed = nextElapsed);
      }
    });
  }

  void _startPoseClock() {
    _poseTicker?.cancel();
    _poseTicker = Timer.periodic(
      const Duration(milliseconds: BatV3ProductionFlight.poseDurationMs),
      (_) {
        if (!mounted) return;
        setState(() {
          _cycleIndex = (_cycleIndex + 1) % BatV3SourceSet.cycle.length;
        });
      },
    );
  }

  void _stopClocks() {
    _poseTicker?.cancel();
    _crossingTicker?.cancel();
    _eventBoundaryTimer?.cancel();
    _poseTicker = null;
    _crossingTicker = null;
    _eventBoundaryTimer = null;
  }

  void _restart() {
    _stopClocks();
    setState(() {
      _crossingElapsed = 0;
      _cycleIndex = 0;
      _eventActive = false;
      _forcedGlitch = false;
      _resumeNormalAfterForced = false;
      _playing = true;
    });
    _startPoseClock();
    _beginNextEvent();
  }

  void _playOrRestart() {
    if (_playing || _eventActive) {
      _restart();
    } else {
      _play();
    }
  }

  void _setCount(int? count) => setState(() => _selectedBatCount = count);

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SectionHeader(
        icon: Icons.flight_outlined,
        title: 'BAT FLIGHT — PRODUCTION PREVIEW V2.1',
      ),
      AppSpacing.gapSM,
      OperationCard(
        key: const ValueKey('bat-v3-production-preview'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'FRAME ${_pose.index.toString().padLeft(2, '0')} · ${BatV3ProductionFlight.poseDurationMs}ms · FLUTTER ${_flutterOn ? '${BatV3ProductionFlight.flutterAmplitude}px' : 'OFF'} · $_speed · $_countTelemetry · ${_leftToRight ? 'L→R' : 'R→L'}',
              key: const ValueKey('bat-v3-production-telemetry'),
            ),
            AppSpacing.gapSM,
            BatV3ProductionStage(
              leftToRight: _leftToRight,
              cycleIndex: _cycleIndex,
              crossingElapsed: _crossingElapsed,
              crossingDuration: _crossingDuration,
              instances: _eventActive ? _visibleInstances : const [],
              flutterOn: _flutterOn,
            ),
            AppSpacing.gapSM,
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _option(
                  'bat-v3-production-play-restart',
                  'PLAY / RESTART',
                  _playing,
                  _playOrRestart,
                ),
                OutlinedButton(
                  key: const ValueKey('bat-v3-production-force-glitch'),
                  onPressed: _forcedGlitch ? null : _forceGlitch,
                  child: const Text('FORCE GLITCH ×10'),
                ),
              ],
            ),
            AppSpacing.gapSM,
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _option(
                  'bat-v3-production-flutter-off',
                  'FLUTTER OFF',
                  !_flutterOn,
                  () => setState(() => _flutterOn = false),
                ),
                _option(
                  'bat-v3-production-flutter-on',
                  'FLUTTER ON',
                  _flutterOn,
                  () => setState(() => _flutterOn = true),
                ),
              ],
            ),
            AppSpacing.gapSM,
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _option(
                  'bat-v3-production-ltr',
                  'L→R',
                  _leftToRight,
                  () => setState(() => _leftToRight = true),
                ),
                _option(
                  'bat-v3-production-rtl',
                  'R→L',
                  !_leftToRight,
                  () => setState(() => _leftToRight = false),
                ),
                _option(
                  'bat-v3-production-speed-1x',
                  '1×',
                  _speed == '1×',
                  () => setState(() => _speed = '1×'),
                ),
                _option(
                  'bat-v3-production-speed-half',
                  '0.5×',
                  _speed == '0.5×',
                  () => setState(() => _speed = '0.5×'),
                ),
                for (final count in [1, 2, 3])
                  _option(
                    'bat-v3-production-count-$count',
                    '×$count',
                    _selectedBatCount == count,
                    () => _setCount(count),
                  ),
                _option(
                  'bat-v3-production-count-random',
                  'RANDOM',
                  _selectedBatCount == null,
                  () => _setCount(null),
                ),
              ],
            ),
            Text(
              '48px-class canonical cels · $_speed = ${_crossingDuration}ms · Production BAT remains inactive.',
            ),
          ],
        ),
      ),
    ],
  );

  Widget _option(
    String key,
    String label,
    bool selected,
    VoidCallback action,
  ) => OutlinedButton(
    key: ValueKey(key),
    style: selected
        ? OutlinedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          )
        : null,
    onPressed: action,
    child: Text(label),
  );
}

class BatV3ProductionStage extends StatelessWidget {
  const BatV3ProductionStage({
    super.key,
    required this.leftToRight,
    required this.cycleIndex,
    required this.crossingElapsed,
    required this.crossingDuration,
    required this.instances,
    required this.flutterOn,
    this.flightEnvelopeScale = 1,
    this.presentationScale = 1,
  });

  final bool leftToRight;
  final int cycleIndex;
  final int crossingElapsed;
  final int crossingDuration;
  final List<BatV3ProductionInstance> instances;
  final bool flutterOn;
  final double flightEnvelopeScale;
  final double presentationScale;

  @override
  Widget build(BuildContext context) => SizedBox(
    key: const ValueKey('bat-v3-production-stage'),
    height: BatV3ProductionFlight.stageHeight,
    child: LayoutBuilder(
      builder: (context, constraints) {
        return ClipRect(
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              for (final instance in instances)
                _productionBat(constraints.maxWidth, instance),
            ],
          ),
        );
      },
    ),
  );

  Widget _productionBat(double stageWidth, BatV3ProductionInstance instance) {
    final index =
        (cycleIndex + instance.phaseOffset) % BatV3SourceSet.cycle.length;
    final pose = BatV3SourceSet.poses[BatV3SourceSet.cycle[index]];
    final flutterY = BatV3ProductionFlight.flutterOffset(
      cycleIndex: index,
      amplitude: BatV3ProductionFlight.flutterAmplitude,
      enabled: flutterOn,
    );
    return Positioned(
      key: ValueKey('bat-v3-production-instance-${instance.identifier}'),
      left: BatV3ProductionFlight.leftFor(
        stageWidth: stageWidth,
        progress: BatV3ProductionFlight.progressFor(
          elapsedMs: crossingElapsed,
          durationMs: crossingDuration,
          instance: instance,
        ),
        leftToRight: leftToRight,
      ),
      top: _presentationTop(
        BatV3ProductionFlight.topFor(
          (instance.formationY + flutterY) * flightEnvelopeScale,
        ),
      ),
      width: BatV3ProductionFlight.batWidth,
      height: BatV3ProductionFlight.batHeight,
      child: Transform.scale(
        alignment: Alignment.topCenter,
        scale: presentationScale,
        child: BatV3CanonicalFrame(
          pose: pose,
          leftToRight: leftToRight,
          inspectionScale: 1,
          flutterY: 0,
          bodyOverlay: false,
          viewportHeight: BatV3ProductionFlight.batHeight,
        ),
      ),
    );
  }

  double _presentationTop(double canonicalTop) =>
      BatV3ProductionFlight.stageHeight -
      (BatV3ProductionFlight.stageHeight - canonicalTop) * presentationScale;
}
