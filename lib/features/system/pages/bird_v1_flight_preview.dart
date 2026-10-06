import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:or_app/core/widgets/global_touch_ripple.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/operation_card.dart';
import '../../../core/widgets/section_header.dart';
import 'fox_run_v1_section.dart';

/// Sandbox-only source authority. The PNG cels are user supplied, untouched,
/// transparent-black silhouettes. No generated or interpolated pose exists.
abstract final class BirdV1SourceSet {
  static const assets = <String>[
    'assets/animations/sandbox/bird_v1/frame_01.png',
    'assets/animations/sandbox/bird_v1/frame_02.png',
    'assets/animations/sandbox/bird_v1/frame_03.png',
    'assets/animations/sandbox/bird_v1/frame_04.png',
    'assets/animations/sandbox/bird_v1/frame_05.png',
    'assets/animations/sandbox/bird_v1/frame_06.png',
  ];

  /// The approved six-cel forward loop: 01 → 02 → 03 → 04 → 05 → 06.
  static const cycle = <int>[0, 1, 2, 3, 4, 5];

  /// Ends at the same baseline at the 06 → 01 seam.
  static const bobOffsets = <double>[0, -1, -2, -2, -1, 0];
  static const flutterOffsets = <double>[0, -1, 1, -1, 1, 0];
}

class BirdV1Sandbox extends StatefulWidget {
  const BirdV1Sandbox({super.key});

  @override
  State<BirdV1Sandbox> createState() => _BirdV1SandboxState();
}

class _BirdV1SandboxState extends State<BirdV1Sandbox> {
  Timer? _timer;
  var _sourceExpanded = false;
  var _cycleExpanded = false;
  var _frame = 0;
  var _cycle = 0;
  var _playing = false;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _play() {
    _timer?.cancel();
    setState(() => _playing = true);
    _timer = Timer.periodic(const Duration(milliseconds: 80), (_) {
      if (!mounted) return;
      setState(() {
        _cycle = (_cycle + 1) % BirdV1SourceSet.cycle.length;
        _frame = BirdV1SourceSet.cycle[_cycle];
      });
    });
  }

  void _pause() {
    _timer?.cancel();
    setState(() => _playing = false);
  }

  Widget _frameButtons(String prefix) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (var i = 0; i < 6; i++)
        OutlinedButton(
          key: ValueKey('$prefix-${i + 1}'),
          onPressed: () {
            _pause();
            setState(() => _frame = i);
          },
          child: Text('FRAME ${(i + 1).toString().padLeft(2, '0')}'),
        ).actionableFeedback(),
    ],
  );

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _BirdDisclosure(
        'bird-v1-source-disclosure',
        Icons.document_scanner_outlined,
        'BIRD V1 — NEW 6-POSE SOURCE SET',
        _sourceExpanded,
        () => setState(() => _sourceExpanded = !_sourceExpanded),
      ),
      if (_sourceExpanded) ...[
        AppSpacing.gapSM,
        OperationCard(
          key: const ValueKey('bird-v1-source-audit'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'FRAME ${(_frame + 1).toString().padLeft(2, '0')} · USER-SUPPLIED TRANSPARENT BLACK SILHOUETTE',
              ),
              AppSpacing.gapSM,
              BirdV1Frame(frame: _frame, leftToRight: true, height: 210),
              AppSpacing.gapSM,
              _frameButtons('bird-v1-source-frame'),
              const Text(
                'SIX ORIGINAL PNG CELS · SAME FIXED RUNTIME RECT · NO POSE INTERPOLATION',
              ),
            ],
          ),
        ),
      ],
      AppSpacing.gapLG,
      _BirdDisclosure(
        'bird-v1-cycle-disclosure',
        Icons.motion_photos_on_outlined,
        'BIRD V1 BODY-REGISTERED FLAP CYCLE',
        _cycleExpanded,
        () => setState(() => _cycleExpanded = !_cycleExpanded),
      ),
      if (_cycleExpanded) ...[
        AppSpacing.gapSM,
        OperationCard(
          key: const ValueKey('bird-v1-flap-cycle'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(_playing ? 'PLAYING · 80ms / POSE' : 'PAUSED · 80ms / POSE'),
              BirdV1Frame(
                frame: _frame,
                leftToRight: true,
                height: 170,
                bob: BirdV1SourceSet.bobOffsets[_cycle],
              ),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton(
                    key: const ValueKey('bird-v1-play'),
                    onPressed: _play,
                    child: const Text('PLAY'),
                  ).actionableFeedback(),
                  OutlinedButton(
                    onPressed: _pause,
                    child: const Text('PAUSE'),
                  ).actionableFeedback(),
                  OutlinedButton(
                    key: const ValueKey('bird-v1-restart'),
                    onPressed: () {
                      _pause();
                      setState(() {
                        _frame = 0;
                        _cycle = 0;
                      });
                      _play();
                    },
                    child: const Text('RESTART'),
                  ).actionableFeedback(),
                ],
              ),
              AppSpacing.gapSM,
              _frameButtons('bird-v1-cycle-frame'),
              const Text(
                '01 → 02 → 03 → 04 → 05 → 06 → 01 → LOOP · fixed body rect registration.',
              ),
            ],
          ),
        ),
      ],
    ],
  );
}

class _BirdDisclosure extends StatelessWidget {
  const _BirdDisclosure(
    this.keyName,
    this.icon,
    this.title,
    this.expanded,
    this.onTap,
  );
  final String keyName;
  final IconData icon;
  final String title;
  final bool expanded;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => OperationCard(
    child: InkWell(
      key: ValueKey(keyName),
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
    ).actionableFeedback(),
  );
}

class BirdV1Frame extends StatelessWidget {
  const BirdV1Frame({
    super.key,
    required this.frame,
    required this.leftToRight,
    required this.height,
    this.bob = 0,
    this.rotationRadians = 0,
  });

  final int frame;
  final bool leftToRight;
  final double height;
  final double bob;
  final double rotationRadians;

  @override
  Widget build(BuildContext context) => SizedBox(
    key: ValueKey('bird-v1-renderer-${frame + 1}'),
    width: height,
    height: height,
    child: Transform.translate(
      offset: Offset(0, bob),
      child: Transform.rotate(
        angle: rotationRadians,
        child: Transform(
          alignment: Alignment.center,
          transform: Matrix4.diagonal3Values(leftToRight ? 1 : -1, 1, 1),
          child: ColorFiltered(
            // The exact established Ambient Wildlife silhouette authority.
            colorFilter: const ColorFilter.mode(
              FoxRunV1ProductionStage.silhouetteColor,
              BlendMode.srcIn,
            ),
            child: Image.asset(
              BirdV1SourceSet.assets[frame],
              key: ValueKey('bird-v1-cel-${frame + 1}'),
              width: height,
              height: height,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
              gaplessPlayback: true,
            ),
          ),
        ),
      ),
    ),
  );
}

enum BirdV1Cadence { current, smooth, cruise, glide }

enum BirdV1Transition { off, ms20, ms35, overlap20 }

/// Production-preview horizontal translation only. This deliberately has no
/// relationship to flap cadence, cross-fade, bob, or flutter timing.
enum BirdV1FlightSpeed { half, one, onePointFive, two }

/// Production-preview-only timing authority. It never changes the canonical
/// source cycle, source assets, or any production Ambient registry.
abstract final class BirdV1FlightTuning {
  static const tickerIntervalMs = 20;
  static const minimumFrameCount = 2;
  static const baselineCrossingDurationMs = 2200;
  static const birdFlutterVerticalAmplitude = 0.45;
  static const birdFlutterRotationAmplitude = 0.004;

  /// Current preserves the shipped 40ms-per-pose preview reference.
  static const currentHoldsMs = <int>[40, 40, 40, 40, 40, 40];

  /// A measured, deliberate pass: turning poses remain short while the
  /// extended wing poses have room to read.
  static const smoothHoldsMs = <int>[55, 55, 60, 60, 70, 70];

  /// Cruise is the rounded midpoint between Smooth and Glide for each pose.
  /// It gives the broad-wing cels breathing room without Glide's heavy hold.
  static const cruiseHoldsMs = <int>[63, 55, 58, 68, 115, 125];

  /// Glide intentionally holds the two broad-wing poses (05/06), rather than
  /// slowing every cel by one uniform multiplier.
  static const glideHoldsMs = <int>[70, 55, 55, 75, 160, 180];

  static int transitionMs(BirdV1Transition value) => switch (value) {
    BirdV1Transition.off => 0,
    BirdV1Transition.ms20 => 20,
    BirdV1Transition.ms35 => 35,
    BirdV1Transition.overlap20 => 20,
  };

  static String transitionLabel(BirdV1Transition value) => switch (value) {
    BirdV1Transition.off => 'OFF',
    BirdV1Transition.ms20 => 'CROSS 20',
    BirdV1Transition.ms35 => 'CROSS 35',
    BirdV1Transition.overlap20 => 'OVERLAP 20',
  };

  /// Returns outgoing/incoming sprite alpha within the current frame hold.
  /// Overlap is intentionally sequential: one cel remains fully visible
  /// throughout each half so the two cels are never simultaneously dim.
  static ({double outgoing, double incoming}) transitionOpacities(
    BirdV1Transition transition,
    int elapsedMs,
  ) {
    final durationMs = transitionMs(transition);
    if (durationMs == 0 || elapsedMs >= durationMs) {
      return (outgoing: 0, incoming: 1);
    }
    if (transition != BirdV1Transition.overlap20) {
      final blend = elapsedMs / durationMs;
      return (outgoing: 1 - blend, incoming: blend);
    }

    const halfMs = 10;
    if (elapsedMs <= halfMs) {
      return (outgoing: 1, incoming: elapsedMs / halfMs);
    }
    return (outgoing: 1 - ((elapsedMs - halfMs) / halfMs), incoming: 1);
  }

  static double flightSpeedMultiplier(BirdV1FlightSpeed value) =>
      switch (value) {
        BirdV1FlightSpeed.half => 0.5,
        BirdV1FlightSpeed.one => 1,
        BirdV1FlightSpeed.onePointFive => 1.5,
        BirdV1FlightSpeed.two => 2,
      };

  static String flightSpeedLabel(BirdV1FlightSpeed value) => switch (value) {
    BirdV1FlightSpeed.half => '0.5×',
    BirdV1FlightSpeed.one => '1×',
    BirdV1FlightSpeed.onePointFive => '1.5×',
    BirdV1FlightSpeed.two => '2×',
  };

  static int crossingDurationMs(BirdV1FlightSpeed value) =>
      (baselineCrossingDurationMs / flightSpeedMultiplier(value)).round();

  static List<int> holdsFor(BirdV1Cadence cadence) => switch (cadence) {
    BirdV1Cadence.current => currentHoldsMs,
    BirdV1Cadence.smooth => smoothHoldsMs,
    BirdV1Cadence.cruise => cruiseHoldsMs,
    BirdV1Cadence.glide => glideHoldsMs,
  };

  static int cycleDurationMs(BirdV1Cadence cadence) =>
      holdsFor(cadence).fold(0, (sum, hold) => sum + hold);

  static List<int> filteredForwardCycle(List<bool> selected) => [
    for (var frame = 0; frame < BirdV1SourceSet.cycle.length; frame++)
      if (selected[frame]) BirdV1SourceSet.cycle[frame],
  ];

  static int nextFrame(List<int> activeFrames, int frame) {
    final position = activeFrames.indexOf(frame);
    return activeFrames[(position + 1) % activeFrames.length];
  }

  /// Continuous and seam-safe. It is deliberately independent of a filtered
  /// cel set, so skipping a cel cannot create a vertical position jump.
  static double bobForElapsed(int elapsedMs, BirdV1Cadence cadence) {
    final phase =
        (elapsedMs % cycleDurationMs(cadence)) / cycleDurationMs(cadence);
    return -1.4 * math.sin(phase * math.pi * 2);
  }

  /// Bird flutter is much smaller/slower than BAT's 8px preview flutter.
  static double flutterYForElapsed(int elapsedMs, BirdV1Cadence cadence) {
    final phase =
        (elapsedMs % cycleDurationMs(cadence)) / cycleDurationMs(cadence);
    return birdFlutterVerticalAmplitude * math.sin(phase * math.pi);
  }

  static double flutterRotationForElapsed(
    int elapsedMs,
    BirdV1Cadence cadence,
  ) {
    final phase =
        (elapsedMs % cycleDurationMs(cadence)) / cycleDurationMs(cadence);
    return birdFlutterRotationAmplitude * math.sin(phase * math.pi);
  }
}

class BirdV1ProductionPreview extends StatefulWidget {
  const BirdV1ProductionPreview({super.key});

  @override
  State<BirdV1ProductionPreview> createState() =>
      _BirdV1ProductionPreviewState();
}

class _BirdV1ProductionPreviewState extends State<BirdV1ProductionPreview> {
  Timer? _ticker;
  var _flightElapsed = 0;
  var _flapElapsed = 0;
  var _bobElapsed = 0;
  var _frame = 0;
  var _playing = false;
  var _flutter = true;
  var _leftToRight = true;
  var _speed = BirdV1FlightSpeed.one;
  var _count = 1;
  var _cadence = BirdV1Cadence.current;
  var _transition = BirdV1Transition.off;
  var _previousFrame = 0;
  final _frameSet = List<bool>.filled(BirdV1SourceSet.cycle.length, true);
  String? _frameSetFeedback;

  int get _crossingDuration => BirdV1FlightTuning.crossingDurationMs(_speed);
  List<int> get _activeFrames =>
      BirdV1FlightTuning.filteredForwardCycle(_frameSet);
  List<int> get _holds => BirdV1FlightTuning.holdsFor(_cadence);

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _play() {
    _ticker?.cancel();
    setState(() {
      _playing = true;
      _flightElapsed = 0;
      _flapElapsed = 0;
      _bobElapsed = 0;
      _frame = _activeFrames.first;
      _previousFrame = _frame;
    });
    _ticker = Timer.periodic(
      const Duration(milliseconds: BirdV1FlightTuning.tickerIntervalMs),
      (_) {
        if (!mounted) return;
        setState(_tick);
      },
    );
  }

  void _tick() {
    _flightElapsed += BirdV1FlightTuning.tickerIntervalMs;
    _flapElapsed += BirdV1FlightTuning.tickerIntervalMs;
    _bobElapsed += BirdV1FlightTuning.tickerIntervalMs;
    if (_flightElapsed >= _crossingDuration) _flightElapsed = 0;
    while (_flapElapsed >= _holds[_frame]) {
      _flapElapsed -= _holds[_frame];
      _previousFrame = _frame;
      _frame = BirdV1FlightTuning.nextFrame(_activeFrames, _frame);
    }
  }

  void _toggleFrame(int frame) {
    if (_frameSet[frame] &&
        _activeFrames.length == BirdV1FlightTuning.minimumFrameCount) {
      setState(() => _frameSetFeedback = 'MIN 2 FRAMES');
      return;
    }
    setState(() {
      _frameSet[frame] = !_frameSet[frame];
      _frameSetFeedback = null;
      if (!_frameSet[_frame]) _frame = _activeFrames.first;
      _flapElapsed = 0;
    });
  }

  void _setCadence(BirdV1Cadence cadence) {
    setState(() {
      _cadence = cadence;
      _flapElapsed = 0;
    });
  }

  Widget _option(String id, String label, bool selected, VoidCallback action) =>
      OutlinedButton(
        key: ValueKey(id),
        style: selected
            ? OutlinedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              )
            : null,
        onPressed: action,
        child: Text(label),
      ).actionableFeedback();

  Widget _controlRow(String label, List<Widget> children) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        AppSpacing.gapXS,
        Wrap(spacing: 8, runSpacing: 8, children: children),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final bob = BirdV1FlightTuning.bobForElapsed(_bobElapsed, _cadence);
    final flutterY = _flutter
        ? BirdV1FlightTuning.flutterYForElapsed(_bobElapsed, _cadence)
        : 0.0;
    final flutterRotation = _flutter
        ? BirdV1FlightTuning.flutterRotationForElapsed(_bobElapsed, _cadence)
        : 0.0;
    final setReadout = _activeFrames
        .map((frame) => (frame + 1).toString().padLeft(2, '0'))
        .join('·');
    final transitionMs = BirdV1FlightTuning.transitionMs(_transition);
    final blending = transitionMs > 0 && _flapElapsed < transitionMs;
    final opacities = BirdV1FlightTuning.transitionOpacities(
      _transition,
      _flapElapsed,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(
          icon: Icons.flight_outlined,
          title: 'BIRD FLIGHT — PRODUCTION PREVIEW V1',
        ),
        AppSpacing.gapSM,
        OperationCard(
          key: const ValueKey('bird-v1-production-preview'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'FRAME ${(_frame + 1).toString().padLeft(2, '0')} · '
                'SET $setReadout · ${_cadence.name.toUpperCase()} · '
                'TRANSITION ${BirdV1FlightTuning.transitionLabel(_transition)} · '
                'BOB ${bob.toStringAsFixed(1)}px · '
                'FLUTTER ${_flutter ? 'ON' : 'OFF'} · '
                'FLIGHT ${BirdV1FlightTuning.flightSpeedLabel(_speed)} · '
                '×$_count · '
                '${_leftToRight ? 'L→R' : 'R→L'}',
              ),
              SizedBox(
                height: 112,
                child: LayoutBuilder(
                  builder: (context, constraints) => ClipRect(
                    child: Stack(
                      children: [
                        for (var index = 0; index < _count; index++)
                          Positioned(
                            left: _birdLeft(constraints.maxWidth, index),
                            top: 24 + bob + flutterY + (index * 10),
                            width: 56,
                            height: 56,
                            child: Stack(
                              children: [
                                if (blending)
                                  Opacity(
                                    opacity: opacities.outgoing,
                                    child: BirdV1Frame(
                                      frame: _previousFrame,
                                      leftToRight: _leftToRight,
                                      height: 56,
                                      rotationRadians: flutterRotation,
                                    ),
                                  ),
                                Opacity(
                                  opacity: opacities.incoming,
                                  child: BirdV1Frame(
                                    frame:
                                        _activeFrames[(_activeFrames.indexOf(
                                                  _frame,
                                                ) +
                                                index) %
                                            _activeFrames.length],
                                    leftToRight: _leftToRight,
                                    height: 56,
                                    rotationRadians: flutterRotation,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              _controlRow('FLIGHT', [
                _option(
                  'bird-v1-production-play-restart',
                  'PLAY / RESTART',
                  _playing,
                  _play,
                ),
              ]),
              _controlRow('FLUTTER', [
                _option(
                  'bird-v1-production-flutter-off',
                  'FLUTTER OFF',
                  !_flutter,
                  () => setState(() => _flutter = false),
                ),
                _option(
                  'bird-v1-production-flutter-on',
                  'FLUTTER ON',
                  _flutter,
                  () => setState(() => _flutter = true),
                ),
              ]),
              _controlRow('DIRECTION', [
                _option(
                  'bird-v1-production-ltr',
                  'L→R',
                  _leftToRight,
                  () => setState(() => _leftToRight = true),
                ),
                _option(
                  'bird-v1-production-rtl',
                  'R→L',
                  !_leftToRight,
                  () => setState(() => _leftToRight = false),
                ),
              ]),
              _controlRow('FLIGHT SPEED', [
                for (final speed in BirdV1FlightSpeed.values)
                  _option(
                    'bird-v1-production-speed-${speed.name}',
                    BirdV1FlightTuning.flightSpeedLabel(speed),
                    _speed == speed,
                    () => setState(() => _speed = speed),
                  ),
              ]),
              _controlRow('COUNT', [
                for (final count in [1, 2, 3])
                  _option(
                    'bird-v1-production-count-$count',
                    '×$count',
                    _count == count,
                    () => setState(() => _count = count),
                  ),
              ]),
              _controlRow('FRAME SET', [
                for (
                  var frame = 0;
                  frame < BirdV1SourceSet.cycle.length;
                  frame++
                )
                  _option(
                    'bird-v1-production-frame-${frame + 1}',
                    (frame + 1).toString().padLeft(2, '0'),
                    _frameSet[frame],
                    () => _toggleFrame(frame),
                  ),
              ]),
              if (_frameSetFeedback != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(_frameSetFeedback!),
                ),
              _controlRow('CADENCE', [
                for (final cadence in BirdV1Cadence.values)
                  _option(
                    'bird-v1-production-cadence-${cadence.name}',
                    cadence.name.toUpperCase(),
                    _cadence == cadence,
                    () => _setCadence(cadence),
                  ),
              ]),
              _controlRow('TRANSITION', [
                for (final value in BirdV1Transition.values)
                  _option(
                    'bird-v1-production-transition-${value.name}',
                    switch (value) {
                      BirdV1Transition.off => 'OFF',
                      BirdV1Transition.ms20 => 'CROSS 20',
                      BirdV1Transition.ms35 => 'CROSS 35',
                      BirdV1Transition.overlap20 => 'OVERLAP 20',
                    },
                    _transition == value,
                    () => setState(() => _transition = value),
                  ),
              ]),
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Sandbox-only tuning bench · frame selection and cadence do '
                  'not alter the 6-frame source cycle or Ambient production.',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  double _birdLeft(double width, int instance) {
    final progress =
        (_flightElapsed - instance * 160).clamp(0, _crossingDuration) /
        _crossingDuration;
    final x = -60.0 + (width + 64) * progress;
    return _leftToRight ? x : width - 56 - x;
  }
}
