import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/navigation/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/operation_card.dart';
import '../../../core/widgets/section_header.dart';
import '../../dashboard/widgets/dashboard_ambient_wildlife_stage.dart';
import 'cat_trace_decomposition_poc.dart';
import 'cat_trace_motion_poc.dart';
import 'cat_multi_pose_run_poc.dart';
import 'cat_multi_pose_trace_data.dart';
import 'cat_trace_poc_data.dart';
import 'pixel_lab_page.dart';

const _bootSequenceAssets = [
  _BootSequenceAsset(
    name: 'BACKGROUND',
    fileName: 'base_camp_background.png',
    path:
        'assets/animations/sandbox/boot_sequence/phase_01/background/'
        'base_camp_background.png',
    usage: '1',
    transparent: false,
  ),
  _BootSequenceAsset(
    name: 'JEEP BODY',
    fileName: 'jeep_body.png',
    path: 'assets/animations/sandbox/boot_sequence/phase_01/jeep/jeep_body.png',
    usage: '1',
    transparent: true,
  ),
  _BootSequenceAsset(
    name: 'WHEEL',
    fileName: 'wheel.png',
    path: 'assets/animations/sandbox/boot_sequence/phase_01/jeep/wheel.png',
    usage: 'USED ×3',
    transparent: true,
  ),
];

const _scene1FrontWheelFar = _WheelCalibration(
  localX: 0.108,
  localY: 0.618,
  scale: 0.200,
);
const _scene1RearWheel = _WheelCalibration(
  localX: 0.779,
  localY: 0.587,
  scale: 0.185,
);
const _scene1FrontWheelNear = _WheelCalibration(
  localX: 0.330,
  localY: 0.593,
  scale: 0.245,
);
const _scene1Start = _CalibrationSnapshot(
  alignment: Alignment(0.971, 0.322),
  scale: 0.100,
);
const _scene1End = _CalibrationSnapshot(
  alignment: Alignment(-0.232, 0.603),
  scale: 1.310,
);
const _scene1TravelDuration = Duration(milliseconds: 6000);
const _scene1HoldDuration = Duration(milliseconds: 750);
const _scene1TotalDuration = Duration(milliseconds: 6750);
const _scene2JeepAsset =
    'assets/animations/sandbox/boot_sequence/phase_02/jeep/jeep_side.png';
const _orloLogoAsset = 'assets/icons/orlo_icon.png';
const _orloSequenceDuration = Duration(seconds: 13);
const _orloStageTitles = [
  '波形の出現',
  '波形の収束',
  '軸の出現',
  '軸の着地',
  '帆の接近開始',
  '帆の融合直前',
  '帆の合体',
  '軌道の出現',
  '軌道の完成',
  '光の蓄積',
  '一瞬の閃光',
  '光の収束と安定',
  'O.R.L.O. 表示',
];

class _BootSequenceAsset {
  const _BootSequenceAsset({
    required this.name,
    required this.fileName,
    required this.path,
    required this.usage,
    required this.transparent,
  });

  final String name;
  final String fileName;
  final String path;
  final String usage;
  final bool transparent;
}

class AnimationsSandboxPage extends StatelessWidget {
  const AnimationsSandboxPage({super.key, this.pixelLabAssetLoader});

  final PixelLabAssetLoader? pixelLabAssetLoader;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('ANIMATIONS SANDBOX')),
    body: ListView(
      padding: AppSpacing.cardPadding,
      children: [
        const SectionHeader(
          icon: Icons.rocket_launch_outlined,
          title: 'BOOT SEQUENCE',
        ),
        AppSpacing.gapSM,
        OperationCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('起動演出の構成と再生操作を確認します。'),
              AppSpacing.gapMD,
              _SandboxActionButton(
                key: const ValueKey('open-boot-sequence-preview'),
                text: 'OPEN BOOT SEQUENCE',
                icon: Icons.play_circle_outline,
                onPressed: () =>
                    Navigator.pushNamed(context, AppRoutes.bootSequencePreview),
              ),
            ],
          ),
        ),
        AppSpacing.gapXL,
        const SectionHeader(icon: Icons.grid_on_outlined, title: 'PIXEL LAB'),
        AppSpacing.gapSM,
        OperationCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('AssetのPixelation、表示サイズ、背景、色変換をPreviewします。'),
              AppSpacing.gapMD,
              _SandboxActionButton(
                key: const ValueKey('open-pixel-lab'),
                text: 'OPEN PIXEL LAB',
                icon: Icons.grid_on_outlined,
                onPressed: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        PixelLabPage(assetLoader: pixelLabAssetLoader),
                  ),
                ),
              ),
            ],
          ),
        ),
        AppSpacing.gapXL,
        const _AmbientWildlifeSandboxSection(),
        AppSpacing.gapXL,
        const _CatTracePipelinePocSection(),
        AppSpacing.gapXL,
        const _CatTraceMotionPocSection(),
        AppSpacing.gapXL,
        const _CatMultiPoseRunPocSection(),
      ],
    ),
  );
}

class _AmbientWildlifeSandboxSection extends StatefulWidget {
  const _AmbientWildlifeSandboxSection();

  @override
  State<_AmbientWildlifeSandboxSection> createState() =>
      _AmbientWildlifeSandboxSectionState();
}

class _AmbientWildlifeSandboxSectionState
    extends State<_AmbientWildlifeSandboxSection> {
  static const _autoKinds = [
    WildlifeKind.cat,
    WildlifeKind.birds,
    WildlifeKind.fox,
    WildlifeKind.bat,
  ];

  WildlifeEventPlan? _plan;
  var _leftToRight = true;
  var _neutral = false;
  var _neutralZoomed = false;
  var _requestId = 0;
  var _nextAutoKind = 0;

  void _start(WildlifeKind kind) {
    setState(() {
      _plan = wildlifePreviewPlan(kind: kind, leftToRight: _leftToRight);
      _requestId++;
    });
  }

  void _startAuto() {
    final kind = _autoKinds[_nextAutoKind];
    _nextAutoKind = (_nextAutoKind + 1) % _autoKinds.length;
    _start(kind);
  }

  String get _directionLabel => _leftToRight ? 'L → R' : 'R → L';

  @override
  Widget build(BuildContext context) {
    final reducedMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(
          icon: Icons.pets_outlined,
          title: 'AMBIENT WILDLIFE',
        ),
        AppSpacing.gapSM,
        OperationCard(
          key: const ValueKey('ambient-wildlife-sandbox-section'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DashboardAmbientWildlifePreviewStage(
                plan: _plan,
                requestId: _requestId,
                neutralKind: _neutral
                    ? (_plan?.kind ?? WildlifeKind.cat)
                    : null,
                neutralLeftToRight: _leftToRight,
                neutralScale:
                    _neutral &&
                        (_plan?.kind ?? WildlifeKind.cat) == WildlifeKind.cat &&
                        _neutralZoomed
                    ? 2
                    : 1,
              ),
              AppSpacing.gapMD,
              const Text('MODE'),
              AppSpacing.gapSM,
              Row(
                children: [
                  Expanded(
                    child: _WildlifePreviewOption(
                      key: const ValueKey('wildlife-preview-mode-motion'),
                      label: 'MOTION',
                      selected: !_neutral,
                      onPressed: () => setState(() => _neutral = false),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _WildlifePreviewOption(
                      key: const ValueKey('wildlife-preview-mode-neutral'),
                      label: 'NEUTRAL',
                      selected: _neutral,
                      onPressed: () => setState(() => _neutral = true),
                    ),
                  ),
                ],
              ),
              if (_neutral &&
                  (_plan?.kind ?? WildlifeKind.cat) == WildlifeKind.cat) ...[
                AppSpacing.gapMD,
                const Text('CAT NEUTRAL INSPECTION'),
                AppSpacing.gapSM,
                Row(
                  children: [
                    Expanded(
                      child: _WildlifePreviewOption(
                        key: const ValueKey('wildlife-preview-neutral-normal'),
                        label: 'NORMAL',
                        selected: !_neutralZoomed,
                        onPressed: () => setState(() => _neutralZoomed = false),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _WildlifePreviewOption(
                        key: const ValueKey('wildlife-preview-neutral-2x'),
                        label: '2× PREVIEW',
                        selected: _neutralZoomed,
                        onPressed: () => setState(() => _neutralZoomed = true),
                      ),
                    ),
                  ],
                ),
              ],
              AppSpacing.gapMD,
              const Text('DIRECTION'),
              AppSpacing.gapSM,
              Row(
                children: [
                  Expanded(
                    child: _WildlifePreviewOption(
                      key: const ValueKey('wildlife-preview-direction-ltr'),
                      label: 'L → R',
                      selected: _leftToRight,
                      onPressed: () => setState(() => _leftToRight = true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _WildlifePreviewOption(
                      key: const ValueKey('wildlife-preview-direction-rtl'),
                      label: 'R → L',
                      selected: !_leftToRight,
                      onPressed: () => setState(() => _leftToRight = false),
                    ),
                  ),
                ],
              ),
              AppSpacing.gapMD,
              const Text('SPECIES'),
              AppSpacing.gapSM,
              Row(
                children: [
                  Expanded(
                    child: _WildlifePreviewOption(
                      key: const ValueKey('wildlife-preview-cat'),
                      label: 'CAT',
                      onPressed: reducedMotion
                          ? null
                          : () => _start(WildlifeKind.cat),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _WildlifePreviewOption(
                      key: const ValueKey('wildlife-preview-fox'),
                      label: 'FOX',
                      onPressed: reducedMotion
                          ? null
                          : () => _start(WildlifeKind.fox),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _WildlifePreviewOption(
                      key: const ValueKey('wildlife-preview-birds'),
                      label: 'BIRDS',
                      onPressed: reducedMotion
                          ? null
                          : () => _start(WildlifeKind.birds),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _WildlifePreviewOption(
                      key: const ValueKey('wildlife-preview-bat'),
                      label: 'BAT',
                      onPressed: reducedMotion
                          ? null
                          : () => _start(WildlifeKind.bat),
                    ),
                  ),
                ],
              ),
              AppSpacing.gapSM,
              _SandboxActionButton(
                key: const ValueKey('wildlife-preview-auto'),
                text: 'AUTO',
                icon: Icons.autorenew,
                onPressed: reducedMotion ? null : _startAuto,
              ),
              AppSpacing.gapSM,
              Text(
                reducedMotion
                    ? 'REDUCED MOTION: PREVIEW SUPPRESSED'
                    : 'CURRENT: ${_plan?.kind.name.toUpperCase() ?? 'CAT'} / ${_neutral ? 'NEUTRAL' : 'MOTION'} / $_directionLabel',
                key: const ValueKey('ambient-wildlife-preview-state'),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WildlifePreviewOption extends StatelessWidget {
  const _WildlifePreviewOption({
    super.key,
    required this.label,
    this.selected = false,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 42,
    child: OutlinedButton(
      onPressed: onPressed,
      style: selected
          ? OutlinedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            )
          : null,
      child: Text(label),
    ),
  );
}

/// Sandbox-only calibration data for the supplied CAT silhouette reference.
/// Values are normalized against the reference's visible silhouette bounds;
/// no source image is bundled, rendered, or used by production wildlife.
@immutable
class CatTracePocFidelity {
  const CatTracePocFidelity({
    required this.headToBodyLength,
    required this.bodyDepthToLength,
    required this.tailReachPastPelvis,
    required this.curveSegmentCount,
    required this.referenceFeatures,
  });

  final double headToBodyLength;
  final double bodyDepthToLength;
  final double tailReachPastPelvis;
  final int curveSegmentCount;
  final Set<String> referenceFeatures;
}

/// The POC is deliberately separate from DashboardAmbientWildlifePainter.
/// Its metrics record broad contour relationships observed in the supplied
/// source, rather than copying an image asset or retaining pixel coordinates.
const catTracePocFidelity = CatTracePocFidelity(
  headToBodyLength: .19,
  bodyDepthToLength: .34,
  tailReachPastPelvis: .31,
  curveSegmentCount: 24,
  referenceFeatures: {
    'shortMuzzle',
    'pairedEars',
    'lowDorsalLine',
    'raisedTaperedTail',
    'articulatedForeleg',
    'articulatedHindLeg',
  },
);

class _CatTracePipelinePocSection extends StatefulWidget {
  const _CatTracePipelinePocSection();

  @override
  State<_CatTracePipelinePocSection> createState() =>
      _CatTracePipelinePocSectionState();
}

class _CatTracePipelinePocSectionState
    extends State<_CatTracePipelinePocSection> {
  var _mode = _CatTracePocMode.reconstructed;
  var _inspectionScale = 2;
  late final _decomposition = CatTraceDecomposition.medium();
  late final _reconstructionMetrics = _decomposition.measure(
    width: 256,
    height: 128,
  );
  var _articulationTarget = CatTraceArticulationTarget.foreNear;
  var _articulationPosition = CatTraceArticulationPosition.neutral;
  var _articulationDiagnostic = CatTraceArticulationDiagnostic.normal;

  @override
  Widget build(BuildContext context) {
    final level = _mode.level;
    final painter = switch (_mode) {
      _CatTracePocMode.reconstructed => CatTracePocPainter(
        presentationScale: _inspectionScale,
      ),
      _CatTracePocMode.high ||
      _CatTracePocMode.medium ||
      _CatTracePocMode.low => CatTraceVectorPainter(
        level: level!,
        presentationScale: _inspectionScale,
      ),
      _CatTracePocMode.decomposed ||
      _CatTracePocMode.overlay ||
      _CatTracePocMode.diff => CatTraceDecompositionPainter(
        decomposition: _decomposition,
        display: _mode.decompositionDisplay!,
        presentationScale: _inspectionScale,
      ),
    };
    final articulationPose = CatTraceArticulationPose(
      target: _articulationTarget,
      position: _articulationPosition,
    );
    final articulationIntegrity = CatTraceArticulationIntegrity.fromPose(
      decomposition: _decomposition,
      pose: articulationPose,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(
          icon: Icons.gesture_outlined,
          title: 'CAT TRACE PIPELINE POC',
        ),
        AppSpacing.gapSM,
        OperationCard(
          key: const ValueKey('cat-trace-poc-section'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('SANDBOX ONLY · STATIC VECTOR COMPARISON'),
              AppSpacing.gapSM,
              SizedBox(
                height: 190,
                child: CustomPaint(
                  key: const ValueKey('cat-trace-poc-canvas'),
                  painter: painter,
                ),
              ),
              AppSpacing.gapSM,
              const Text('VECTOR MODE'),
              AppSpacing.gapSM,
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final mode in _CatTracePocMode.values)
                    _TracePocChoice(
                      key: ValueKey('cat-trace-poc-${mode.name}'),
                      label: mode.label,
                      selected: _mode == mode,
                      onPressed: () => setState(() => _mode = mode),
                    ),
                ],
              ),
              AppSpacing.gapSM,
              const Text('INSPECTION SCALE'),
              AppSpacing.gapSM,
              Wrap(
                spacing: 8,
                children: [
                  for (final scale in [1, 2, 4])
                    _TracePocChoice(
                      key: ValueKey('cat-trace-poc-scale-$scale'),
                      label: '$scale×',
                      selected: _inspectionScale == scale,
                      onPressed: () => setState(() => _inspectionScale = scale),
                    ),
                ],
              ),
              AppSpacing.gapSM,
              Text(
                _mode.decompositionDisplay != null
                    ? "C vs C' · IoU ${(_reconstructionMetrics.iou * 100).toStringAsFixed(3)}% · "
                          'pixel disagreement ${(_reconstructionMetrics.disagreement * 100).toStringAsFixed(3)}%'
                    : level == null
                    ? 'RECONSTRUCTED CONTROL · authored Bezier · source metric unavailable'
                    : '${level.name} · RDP ${level.tolerance}px · '
                          '${level.sourcePointCount} points · '
                          'IoU ${(level.iou * 100).toStringAsFixed(2)}%',
                key: const ValueKey('cat-trace-poc-metrics'),
              ),
              if (_mode == _CatTracePocMode.diff) ...[
                AppSpacing.gapSM,
                const Text(
                  'RAW XOR · 4× may make anti-aliased subpixel differences appear more prominent.',
                ),
              ],
              AppSpacing.gapSM,
              const Text(
                'Original asset is not bundled. Production Wildlife is not connected.',
              ),
            ],
          ),
        ),
        AppSpacing.gapMD,
        OperationCard(
          key: const ValueKey('cat-trace-articulation-poc-section'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('ARTICULATION POC · SINGLE COMPONENT · STATIC'),
              AppSpacing.gapSM,
              SizedBox(
                height: 190,
                child: CustomPaint(
                  key: const ValueKey('cat-trace-articulation-canvas'),
                  painter: CatTraceArticulationPainter(
                    decomposition: _decomposition,
                    pose: articulationPose,
                    diagnostic: _articulationDiagnostic,
                    presentationScale: _inspectionScale,
                  ),
                ),
              ),
              AppSpacing.gapSM,
              const Text('TARGET'),
              AppSpacing.gapSM,
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final target in CatTraceArticulationTarget.values)
                    _TracePocChoice(
                      key: ValueKey('cat-trace-articulation-${target.name}'),
                      label: target.label,
                      selected: _articulationTarget == target,
                      onPressed: () => setState(() {
                        _articulationTarget = target;
                        _articulationPosition =
                            CatTraceArticulationPosition.neutral;
                      }),
                    ),
                ],
              ),
              AppSpacing.gapSM,
              const Text('ANGLE'),
              AppSpacing.gapSM,
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final position in CatTraceArticulationPosition.values)
                    _TracePocChoice(
                      key: ValueKey('cat-trace-articulation-${position.name}'),
                      label: position.label,
                      selected: _articulationPosition == position,
                      onPressed: () =>
                          setState(() => _articulationPosition = position),
                    ),
                  _TracePocChoice(
                    key: const ValueKey('cat-trace-articulation-reset'),
                    label: 'NEUTRAL RESET',
                    selected: false,
                    onPressed: () => setState(() {
                      _articulationTarget = CatTraceArticulationTarget.foreNear;
                      _articulationPosition =
                          CatTraceArticulationPosition.neutral;
                    }),
                  ),
                ],
              ),
              AppSpacing.gapSM,
              const Text('DIAGNOSTIC'),
              AppSpacing.gapSM,
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final diagnostic
                      in CatTraceArticulationDiagnostic.values)
                    _TracePocChoice(
                      key: ValueKey(
                        'cat-trace-articulation-${diagnostic.name}',
                      ),
                      label: diagnostic.label,
                      selected: _articulationDiagnostic == diagnostic,
                      onPressed: () =>
                          setState(() => _articulationDiagnostic = diagnostic),
                    ),
                ],
              ),
              AppSpacing.gapSM,
              const Text('ARTICULATION SCALE'),
              AppSpacing.gapSM,
              Wrap(
                spacing: 8,
                children: [
                  for (final scale in [1, 2, 4])
                    _TracePocChoice(
                      key: ValueKey('cat-trace-articulation-scale-$scale'),
                      label: '$scale×',
                      selected: _inspectionScale == scale,
                      onPressed: () => setState(() => _inspectionScale = scale),
                    ),
                ],
              ),
              AppSpacing.gapSM,
              Text(
                '${_articulationTarget.label} · '
                '${articulationPose.angleDegrees.toStringAsFixed(0)}° · '
                '${articulationIntegrity.isStructurallyValid ? 'ROOT OVERLAP OK' : 'ROOT OVERLAP FAIL'}',
                key: const ValueKey('cat-trace-articulation-metrics'),
              ),
              AppSpacing.gapSM,
              const Text(
                'Rigid pivot test only. No gait, interpolation, or Production Wildlife connection.',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CatTraceMotionPocSection extends StatefulWidget {
  const _CatTraceMotionPocSection();

  @override
  State<_CatTraceMotionPocSection> createState() =>
      _CatTraceMotionPocSectionState();
}

class _CatTraceMotionPocSectionState extends State<_CatTraceMotionPocSection>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final CatTraceMotionPoc _motion = CatTraceMotionPoc();
  var _playing = false;
  var _neutral = true;
  var _speed = 1.0;
  var _scale = 1;
  var _diagnostic = CatTraceMotionDiagnostic.normal;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _durationForSpeed);
    _controller.addListener(() {
      if (mounted && _playing) setState(() {});
    });
  }

  Duration get _durationForSpeed => Duration(
    milliseconds: (CatTraceMotionPoc.cycleDuration.inMilliseconds / _speed)
        .round(),
  );

  void _playPause() {
    setState(() {
      _neutral = false;
      _playing = !_playing;
      if (_playing) {
        _controller.repeat();
      } else {
        _controller.stop();
      }
    });
  }

  void _setSpeed(double speed) {
    setState(() {
      final wasPlaying = _playing;
      _controller.stop();
      _speed = speed;
      _controller.duration = _durationForSpeed;
      if (wasPlaying) _controller.repeat();
    });
  }

  void _resetNeutral() {
    setState(() {
      _controller.stop();
      _controller.value = 0;
      _playing = false;
      _neutral = true;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sample = _neutral
        ? CatTraceMotionSample.neutral()
        : CatTraceMotionSample.at(_controller.value);
    final integrity = CatTraceMotionIntegrity.fromSample(
      motion: _motion,
      sample: sample,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(
          icon: Icons.directions_walk_outlined,
          title: 'CAT TRACE MOTION POC',
        ),
        AppSpacing.gapSM,
        OperationCard(
          key: const ValueKey('cat-trace-motion-poc-section'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('SANDBOX ONLY · ARTICULATED BRISK WALK'),
              AppSpacing.gapSM,
              SizedBox(
                height: 190,
                child: CustomPaint(
                  key: const ValueKey('cat-trace-motion-canvas'),
                  painter: CatTraceMotionPainter(
                    motion: _motion,
                    sample: sample,
                    diagnostic: _diagnostic,
                    presentationScale: _scale,
                  ),
                ),
              ),
              AppSpacing.gapSM,
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _TracePocChoice(
                    key: const ValueKey('cat-trace-motion-play-pause'),
                    label: _playing ? 'PAUSE' : 'PLAY',
                    selected: _playing,
                    onPressed: _playPause,
                  ),
                  _TracePocChoice(
                    key: const ValueKey('cat-trace-motion-neutral'),
                    label: 'NEUTRAL',
                    selected: _neutral,
                    onPressed: _resetNeutral,
                  ),
                ],
              ),
              AppSpacing.gapSM,
              const Text('PLAYBACK'),
              AppSpacing.gapSM,
              Wrap(
                spacing: 8,
                children: [
                  for (final speed in [0.5, 1.0])
                    _TracePocChoice(
                      key: ValueKey('cat-trace-motion-speed-$speed'),
                      label: '${speed.toStringAsFixed(1)}×',
                      selected: _speed == speed,
                      onPressed: () => _setSpeed(speed),
                    ),
                ],
              ),
              AppSpacing.gapSM,
              const Text('INSPECTION SCALE'),
              AppSpacing.gapSM,
              Wrap(
                spacing: 8,
                children: [
                  for (final scale in [1, 2, 4])
                    _TracePocChoice(
                      key: ValueKey('cat-trace-motion-scale-$scale'),
                      label: '$scale×',
                      selected: _scale == scale,
                      onPressed: () => setState(() => _scale = scale),
                    ),
                ],
              ),
              AppSpacing.gapSM,
              const Text('DIAGNOSTIC'),
              AppSpacing.gapSM,
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final diagnostic in CatTraceMotionDiagnostic.values)
                    _TracePocChoice(
                      key: ValueKey('cat-trace-motion-${diagnostic.name}'),
                      label: diagnostic.label,
                      selected: _diagnostic == diagnostic,
                      onPressed: () => setState(() => _diagnostic = diagnostic),
                    ),
                ],
              ),
              AppSpacing.gapSM,
              Text(
                '${_neutral ? 'NEUTRAL' : 'PHASE ${(_controller.value * 100).round()}%'} · '
                '${integrity.isStructurallyValid ? 'ROOT OVERLAP OK' : 'ROOT OVERLAP FAIL'} · '
                '${CatTraceMotionPoc.cycleDuration.inMilliseconds}ms at 1.0×',
                key: const ValueKey('cat-trace-motion-metrics'),
              ),
              AppSpacing.gapSM,
              const Text(
                'Canonical traced C is immutable. Production Wildlife is not connected.',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CatMultiPoseRunPocSection extends StatefulWidget {
  const _CatMultiPoseRunPocSection();
  @override
  State<_CatMultiPoseRunPocSection> createState() =>
      _CatMultiPoseRunPocSectionState();
}

class _CatMultiPoseRunPocSectionState extends State<_CatMultiPoseRunPocSection>
    with SingleTickerProviderStateMixin {
  final _run = CatMultiPoseRun();
  late final AnimationController _controller;
  CatMultiPose? _pose = CatMultiPose.a;
  var _speed = 1.0;
  var _scale = 1;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: CatMultiPoseRun.cycleDuration,
    )..addListener(() => mounted ? setState(() {}) : null);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final points = _pose == null
        ? _run.pointsAt(_controller.value)
        : _run.pointsForPose(_pose!);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(
          icon: Icons.directions_run,
          title: 'CAT MULTI-POSE TRACE RUN POC',
        ),
        AppSpacing.gapSM,
        OperationCard(
          key: const ValueKey('cat-multipose-run-poc'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 190,
                child: CustomPaint(
                  key: const ValueKey('cat-multipose-canvas'),
                  painter: _CatMultiPosePainter(points, _scale),
                ),
              ),
              AppSpacing.gapSM,
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final pose in CatMultiPose.values)
                    _TracePocChoice(
                      label: 'POSE ${pose.name.toUpperCase()}',
                      selected: _pose == pose,
                      onPressed: () => setState(() => _pose = pose),
                    ),
                  _TracePocChoice(
                    label: 'MOTION',
                    selected: _pose == null,
                    onPressed: () => setState(() => _pose = null),
                  ),
                ],
              ),
              AppSpacing.gapSM,
              Wrap(
                spacing: 8,
                children: [
                  _TracePocChoice(
                    label: _controller.isAnimating ? 'PAUSE' : 'PLAY',
                    selected: _controller.isAnimating,
                    onPressed: () => setState(() {
                      _pose = null;
                      _controller.isAnimating
                          ? _controller.stop()
                          : _controller.repeat();
                    }),
                  ),
                  for (final s in [0.5, 1.0])
                    _TracePocChoice(
                      label: '${s}×',
                      selected: _speed == s,
                      onPressed: () => setState(() {
                        _speed = s;
                        _controller.duration = Duration(
                          milliseconds: (720 / s).round(),
                        );
                        if (_controller.isAnimating) _controller.repeat();
                      }),
                    ),
                  for (final s in [1, 2, 4])
                    _TracePocChoice(
                      label: '$s×',
                      selected: _scale == s,
                      onPressed: () => setState(() => _scale = s),
                    ),
                ],
              ),
              AppSpacing.gapSM,
              Text(
                _pose == null
                    ? 'A → B → C → D → A · vector interpolation'
                    : '${_pose!.name.toUpperCase()} · ${catMultiPoseTraces.singleWhere((x) => x.pose == _pose).pointCount} points',
              ),
              const Text(
                'SANDBOX ONLY · source rasters are not runtime assets.',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CatMultiPosePainter extends CustomPainter {
  const _CatMultiPosePainter(this.points, this.scale);
  final List<Offset> points;
  final int scale;
  @override
  void paint(Canvas c, Size s) {
    c.drawRect(Offset.zero & s, Paint()..color = const Color(0xFF101010));
    final p = Path()..addPolygon(points, true);
    final k = math.min(s.width * .88, s.height * .75) * scale;
    c.save();
    c.translate((s.width - k) / 2, (s.height - k * .48) / 2);
    c.scale(k);
    c.drawPath(
      p,
      Paint()
        ..color = const Color(0xFFB8B8B8)
        ..isAntiAlias = true,
    );
    c.restore();
  }

  @override
  bool shouldRepaint(_CatMultiPosePainter o) =>
      o.points != points || o.scale != scale;
}

enum _CatTracePocMode {
  reconstructed,
  high,
  medium,
  low,
  decomposed,
  overlay,
  diff,
}

extension on _CatTracePocMode {
  String get name => switch (this) {
    _CatTracePocMode.reconstructed => 'reconstructed',
    _CatTracePocMode.high => 'high',
    _CatTracePocMode.medium => 'medium',
    _CatTracePocMode.low => 'low',
    _CatTracePocMode.decomposed => 'decomposed',
    _CatTracePocMode.overlay => 'overlay',
    _CatTracePocMode.diff => 'diff',
  };

  String get label => switch (this) {
    _CatTracePocMode.reconstructed => 'A · RECONSTRUCTED',
    _CatTracePocMode.high => 'B · TRACE HIGH',
    _CatTracePocMode.medium => 'C · TRACE MEDIUM',
    _CatTracePocMode.low => 'D · TRACE LOW',
    _CatTracePocMode.decomposed => "C' · RECONSTRUCTED",
    _CatTracePocMode.overlay => 'C / C′ · OVERLAY',
    _CatTracePocMode.diff => 'C / C′ · DIFF',
  };

  CatTraceVectorLevel? get level => switch (this) {
    _CatTracePocMode.reconstructed => null,
    _CatTracePocMode.high => generatedCatTraceVectorLevels[0],
    _CatTracePocMode.medium => generatedCatTraceVectorLevels[1],
    _CatTracePocMode.low => generatedCatTraceVectorLevels[2],
    _CatTracePocMode.decomposed ||
    _CatTracePocMode.overlay ||
    _CatTracePocMode.diff => null,
  };

  CatTraceDecompositionDisplay? get decompositionDisplay => switch (this) {
    _CatTracePocMode.decomposed => CatTraceDecompositionDisplay.reconstructed,
    _CatTracePocMode.overlay => CatTraceDecompositionDisplay.overlay,
    _CatTracePocMode.diff => CatTraceDecompositionDisplay.diff,
    _ => null,
  };
}

class _TracePocChoice extends StatelessWidget {
  const _TracePocChoice({
    super.key,
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => OutlinedButton(
    onPressed: onPressed,
    style: selected
        ? OutlinedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          )
        : null,
    child: Text(label),
  );
}

/// Simplified original Bezier reconstruction of the user-supplied walking CAT
/// silhouette. This POC has no dependency on production wildlife geometry.
class CatTracePocPainter extends CustomPainter {
  const CatTracePocPainter({this.presentationScale = 4});

  final int presentationScale;

  @override
  void paint(Canvas canvas, Size size) {
    final background = Paint()
      ..color = const Color(0xFF101010)
      ..isAntiAlias = true;
    final silhouette = Paint()
      ..color = const Color(0xFFB8B8B8)
      ..isAntiAlias = true;
    canvas.drawRect(Offset.zero & size, background);
    canvas.drawPath(_outline(size), silhouette);
  }

  Path _outline(Size size) {
    final path = Path()
      // Nose, short muzzle, chin, and the descending throat.
      ..moveTo(size.width * .075, size.height * .555)
      ..cubicTo(
        size.width * .064,
        size.height * .535,
        size.width * .072,
        size.height * .505,
        size.width * .102,
        size.height * .465,
      )
      ..cubicTo(
        size.width * .108,
        size.height * .400,
        size.width * .126,
        size.height * .335,
        size.width * .166,
        size.height * .300,
      )
      // Two pointed ears flow back into a compact skull.
      ..lineTo(size.width * .145, size.height * .130)
      ..quadraticBezierTo(
        size.width * .185,
        size.height * .170,
        size.width * .205,
        size.height * .255,
      )
      ..lineTo(size.width * .190, size.height * .075)
      ..quadraticBezierTo(
        size.width * .245,
        size.height * .175,
        size.width * .260,
        size.height * .265,
      )
      // Neck, shoulder, and restrained low dorsal contour.
      ..cubicTo(
        size.width * .318,
        size.height * .295,
        size.width * .345,
        size.height * .410,
        size.width * .390,
        size.height * .430,
      )
      ..cubicTo(
        size.width * .535,
        size.height * .440,
        size.width * .645,
        size.height * .345,
        size.width * .760,
        size.height * .425,
      )
      // Pelvis through the tail's raised, tapered outer envelope.
      ..cubicTo(
        size.width * .825,
        size.height * .470,
        size.width * .845,
        size.height * .565,
        size.width * .905,
        size.height * .585,
      )
      ..cubicTo(
        size.width * .948,
        size.height * .600,
        size.width * .968,
        size.height * .520,
        size.width * .982,
        size.height * .455,
      )
      ..quadraticBezierTo(
        size.width * .997,
        size.height * .385,
        size.width * .962,
        size.height * .370,
      )
      ..cubicTo(
        size.width * .925,
        size.height * .405,
        size.width * .904,
        size.height * .485,
        size.width * .848,
        size.height * .500,
      )
      ..cubicTo(
        size.width * .812,
        size.height * .510,
        size.width * .780,
        size.height * .470,
        size.width * .734,
        size.height * .435,
      )
      // Near hind leg: thigh, hock, compact paw.
      ..cubicTo(
        size.width * .715,
        size.height * .535,
        size.width * .730,
        size.height * .625,
        size.width * .760,
        size.height * .690,
      )
      ..cubicTo(
        size.width * .785,
        size.height * .745,
        size.width * .805,
        size.height * .790,
        size.width * .800,
        size.height * .845,
      )
      ..quadraticBezierTo(
        size.width * .782,
        size.height * .885,
        size.width * .747,
        size.height * .875,
      )
      ..quadraticBezierTo(
        size.width * .735,
        size.height * .855,
        size.width * .758,
        size.height * .825,
      )
      ..cubicTo(
        size.width * .727,
        size.height * .765,
        size.width * .692,
        size.height * .700,
        size.width * .661,
        size.height * .640,
      )
      // Curved abdominal return and planted far hind leg.
      ..cubicTo(
        size.width * .565,
        size.height * .625,
        size.width * .475,
        size.height * .625,
        size.width * .382,
        size.height * .640,
      )
      ..cubicTo(
        size.width * .385,
        size.height * .720,
        size.width * .392,
        size.height * .790,
        size.width * .390,
        size.height * .845,
      )
      ..quadraticBezierTo(
        size.width * .382,
        size.height * .885,
        size.width * .340,
        size.height * .878,
      )
      ..quadraticBezierTo(
        size.width * .325,
        size.height * .855,
        size.width * .348,
        size.height * .825,
      )
      ..cubicTo(
        size.width * .340,
        size.height * .755,
        size.width * .315,
        size.height * .695,
        size.width * .292,
        size.height * .650,
      )
      // Chest into a reaching foreleg and rounded paw.
      ..cubicTo(
        size.width * .270,
        size.height * .630,
        size.width * .250,
        size.height * .655,
        size.width * .230,
        size.height * .690,
      )
      ..cubicTo(
        size.width * .185,
        size.height * .735,
        size.width * .132,
        size.height * .760,
        size.width * .110,
        size.height * .820,
      )
      ..quadraticBezierTo(
        size.width * .085,
        size.height * .875,
        size.width * .065,
        size.height * .862,
      )
      ..quadraticBezierTo(
        size.width * .052,
        size.height * .846,
        size.width * .078,
        size.height * .815,
      )
      ..cubicTo(
        size.width * .095,
        size.height * .750,
        size.width * .135,
        size.height * .700,
        size.width * .190,
        size.height * .640,
      )
      ..cubicTo(
        size.width * .225,
        size.height * .600,
        size.width * .230,
        size.height * .555,
        size.width * .202,
        size.height * .525,
      )
      ..cubicTo(
        size.width * .170,
        size.height * .515,
        size.width * .130,
        size.height * .540,
        size.width * .075,
        size.height * .555,
      )
      ..close();
    return path;
  }

  @override
  bool shouldRepaint(covariant CatTracePocPainter oldDelegate) => false;
}

/// Mechanically-derived POC-B renderer. Its cubic handles are calculated from
/// adjacent traced contour samples; no anatomy landmarks are authored here.
class CatTraceVectorPainter extends CustomPainter {
  const CatTraceVectorPainter({
    required this.level,
    required this.presentationScale,
  });

  final CatTraceVectorLevel level;
  final int presentationScale;

  @override
  void paint(Canvas canvas, Size size) {
    final background = Paint()
      ..color = const Color(0xFF101010)
      ..isAntiAlias = true;
    final silhouette = Paint()
      ..color = const Color(0xFFB8B8B8)
      ..isAntiAlias = true;
    canvas.drawRect(Offset.zero & size, background);
    canvas.drawPath(_pathFor(size), silhouette);
  }

  Path _pathFor(Size size) {
    final points = level.points;
    final maxY = points.map((point) => point.dy).reduce(math.max);
    final base = math.min(size.width * .88 / 4, size.height * .82 / (maxY * 4));
    final scale = base * presentationScale;
    final offset = Offset(
      (size.width - scale) / 2,
      (size.height - maxY * scale) / 2,
    );
    Offset at(Offset point) =>
        Offset(offset.dx + point.dx * scale, offset.dy + point.dy * scale);
    final path = Path()..moveTo(at(points.first).dx, at(points.first).dy);
    for (var index = 0; index < points.length; index++) {
      final previous = at(points[(index - 1 + points.length) % points.length]);
      final current = at(points[index]);
      final next = at(points[(index + 1) % points.length]);
      final afterNext = at(points[(index + 2) % points.length]);
      final firstControl = current + (next - previous) / 6;
      final secondControl = next - (afterNext - current) / 6;
      path.cubicTo(
        firstControl.dx,
        firstControl.dy,
        secondControl.dx,
        secondControl.dy,
        next.dx,
        next.dy,
      );
    }
    return path..close();
  }

  @override
  bool shouldRepaint(covariant CatTraceVectorPainter oldDelegate) =>
      oldDelegate.level != level ||
      oldDelegate.presentationScale != presentationScale;
}

enum CatTraceDecompositionDisplay { reconstructed, overlay, diff }

/// Sandbox-only C/C' comparison. It draws neutral component paths only; no
/// joint transform or wildlife production renderer is involved.
class CatTraceDecompositionPainter extends CustomPainter {
  const CatTraceDecompositionPainter({
    required this.decomposition,
    required this.display,
    required this.presentationScale,
  });

  final CatTraceDecomposition decomposition;
  final CatTraceDecompositionDisplay display;
  final int presentationScale;

  @override
  void paint(Canvas canvas, Size size) {
    final background = Paint()
      ..color = const Color(0xFF101010)
      ..isAntiAlias = true;
    final silhouette = Paint()
      ..color = const Color(0xFFB8B8B8)
      ..isAntiAlias = true;
    canvas.drawRect(Offset.zero & size, background);

    final points = decomposition.sourceLevel.points;
    final maxY = points.map((point) => point.dy).reduce(math.max);
    final base = math.min(size.width * .88 / 4, size.height * .82 / (maxY * 4));
    final scale = base * presentationScale;
    canvas.save();
    canvas.translate(
      (size.width - scale) / 2,
      (size.height - maxY * scale) / 2,
    );
    canvas.scale(scale);

    final original = decomposition.originalPath();
    final reconstructed = decomposition.reconstructedPath();
    switch (display) {
      case CatTraceDecompositionDisplay.reconstructed:
        for (final component in decomposition.componentPaths()) {
          canvas.drawPath(component, silhouette);
        }
      case CatTraceDecompositionDisplay.overlay:
        canvas.drawPath(
          original,
          Paint()
            ..color = const Color(0x704ECDC4)
            ..isAntiAlias = true,
        );
        canvas.drawPath(
          reconstructed,
          Paint()
            ..color = const Color(0xFFF6C445)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1 / scale
            ..isAntiAlias = true,
        );
      case CatTraceDecompositionDisplay.diff:
        canvas.drawPath(
          original,
          Paint()
            ..color = const Color(0x443A506B)
            ..isAntiAlias = true,
        );
        final difference = Path.combine(
          PathOperation.xor,
          original,
          reconstructed,
        );
        canvas.drawPath(
          difference,
          Paint()
            ..color = const Color(0xFFFF7043)
            ..isAntiAlias = true,
        );
        canvas.drawPath(
          original,
          Paint()
            ..color = const Color(0xFFB8B8B8)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1 / scale
            ..isAntiAlias = true,
        );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CatTraceDecompositionPainter oldDelegate) =>
      oldDelegate.decomposition != decomposition ||
      oldDelegate.display != display ||
      oldDelegate.presentationScale != presentationScale;
}

enum CatTraceMotionDiagnostic { normal, joints, seamOverlap }

extension on CatTraceMotionDiagnostic {
  String get label => switch (this) {
    CatTraceMotionDiagnostic.normal => 'NORMAL',
    CatTraceMotionDiagnostic.joints => 'SKELETON / JOINTS',
    CatTraceMotionDiagnostic.seamOverlap => 'SEAM / OVERLAP',
  };
}

/// Renders the same normalized articulated geometry at every inspection scale.
class CatTraceMotionPainter extends CustomPainter {
  const CatTraceMotionPainter({
    required this.motion,
    required this.sample,
    required this.diagnostic,
    required this.presentationScale,
  });

  final CatTraceMotionPoc motion;
  final CatTraceMotionSample sample;
  final CatTraceMotionDiagnostic diagnostic;
  final int presentationScale;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..color = const Color(0xFF101010)
        ..isAntiAlias = true,
    );
    final points = motion.decomposition.sourceLevel.points;
    final maxY = points.map((point) => point.dy).reduce(math.max);
    final base = math.min(size.width * .88 / 4, size.height * .82 / (maxY * 4));
    final scale = base * presentationScale;
    final paths = motion.pathsFor(sample);
    canvas.save();
    canvas.translate(
      (size.width - scale) / 2,
      (size.height - maxY * scale) / 2,
    );
    canvas.scale(scale);
    const far = [
      CatTraceMotionSegment.foreFarUpper,
      CatTraceMotionSegment.foreFarLower,
      CatTraceMotionSegment.hindFarUpper,
      CatTraceMotionSegment.hindFarLower,
    ];
    const core = [
      CatTraceMotionSegment.torso,
      CatTraceMotionSegment.headNeck,
      CatTraceMotionSegment.tailRoot,
      CatTraceMotionSegment.tailMid,
      CatTraceMotionSegment.tailTip,
    ];
    const near = [
      CatTraceMotionSegment.foreNearUpper,
      CatTraceMotionSegment.foreNearLower,
      CatTraceMotionSegment.hindNearUpper,
      CatTraceMotionSegment.hindNearLower,
    ];
    final silhouette = Paint()
      ..color = const Color(0xFFB8B8B8)
      ..isAntiAlias = true;
    if (sample.isNeutral) {
      canvas.drawPath(motion.canonicalNeutralPath(), silhouette);
    } else {
      for (final segment in [...far, ...core, ...near]) {
        canvas.drawPath(paths[segment]!, silhouette);
      }
    }
    if (diagnostic == CatTraceMotionDiagnostic.joints) {
      final dots = [
        CatTraceMotionSegment.foreNearUpper.pivot,
        const Offset(.125, .360),
        CatTraceMotionSegment.hindNearUpper.pivot,
        const Offset(.750, .350),
        CatTraceMotionSegment.tailRoot.pivot,
        const Offset(.800, .225),
        const Offset(.895, .215),
      ];
      for (final dot in dots) {
        canvas.drawCircle(
          dot,
          2.5 / scale,
          Paint()
            ..color = const Color(0xFF4ECDC4)
            ..isAntiAlias = true,
        );
      }
    }
    if (diagnostic == CatTraceMotionDiagnostic.seamOverlap) {
      const colors = [
        Color(0xFF4ECDC4),
        Color(0xFFF6C445),
        Color(0xFFB388FF),
        Color(0xFFFF8A65),
        Color(0xFF80CBC4),
        Color(0xFFFFCC80),
      ];
      var index = 0;
      for (final segment in CatTraceMotionSegment.values) {
        canvas.drawPath(
          paths[segment]!,
          Paint()
            ..color = colors[index++ % colors.length]
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1 / scale
            ..isAntiAlias = true,
        );
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CatTraceMotionPainter oldDelegate) =>
      oldDelegate.motion != motion ||
      oldDelegate.sample != sample ||
      oldDelegate.diagnostic != diagnostic ||
      oldDelegate.presentationScale != presentationScale;
}

enum CatTraceArticulationDiagnostic { normal, rootPivot, seamOverlap }

extension on CatTraceArticulationDiagnostic {
  String get label => switch (this) {
    CatTraceArticulationDiagnostic.normal => 'NORMAL',
    CatTraceArticulationDiagnostic.rootPivot => 'ROOT / PIVOT',
    CatTraceArticulationDiagnostic.seamOverlap => 'SEAM / OVERLAP',
  };
}

/// Sandbox-only rigid articulation view. A single selected component receives
/// a pivot transform; every other C' component stays at its neutral geometry.
class CatTraceArticulationPainter extends CustomPainter {
  const CatTraceArticulationPainter({
    required this.decomposition,
    required this.pose,
    required this.diagnostic,
    required this.presentationScale,
  });

  final CatTraceDecomposition decomposition;
  final CatTraceArticulationPose pose;
  final CatTraceArticulationDiagnostic diagnostic;
  final int presentationScale;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..color = const Color(0xFF101010)
        ..isAntiAlias = true,
    );
    final points = decomposition.sourceLevel.points;
    final maxY = points.map((point) => point.dy).reduce(math.max);
    final base = math.min(size.width * .88 / 4, size.height * .82 / (maxY * 4));
    final scale = base * presentationScale;
    canvas.save();
    canvas.translate(
      (size.width - scale) / 2,
      (size.height - maxY * scale) / 2,
    );
    canvas.scale(scale);

    final original = decomposition.originalPath();
    final paths = [
      for (final component in decomposition.components)
        pose.componentPath(component: component, original: original),
    ];
    final silhouette = Paint()
      ..color = const Color(0xFFB8B8B8)
      ..isAntiAlias = true;
    for (final path in paths) {
      canvas.drawPath(path, silhouette);
    }

    if (diagnostic == CatTraceArticulationDiagnostic.rootPivot) {
      final integrity = CatTraceArticulationIntegrity.fromPose(
        decomposition: decomposition,
        pose: pose,
      );
      canvas.drawRect(
        integrity.rootOverlapBounds,
        Paint()
          ..color = const Color(0xFFF6C445)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1 / scale
          ..isAntiAlias = true,
      );
      canvas.drawCircle(
        pose.target.pivot,
        3 / scale,
        Paint()
          ..color = const Color(0xFF4ECDC4)
          ..isAntiAlias = true,
      );
    }
    if (diagnostic == CatTraceArticulationDiagnostic.seamOverlap) {
      const colors = [
        Color(0xFF4ECDC4),
        Color(0xFFF6C445),
        Color(0xFFB388FF),
        Color(0xFFFF8A65),
        Color(0xFF80CBC4),
        Color(0xFFFFCC80),
        Color(0xFF90CAF9),
      ];
      for (var index = 0; index < paths.length; index++) {
        canvas.drawPath(
          paths[index],
          Paint()
            ..color = colors[index]
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1 / scale
            ..isAntiAlias = true,
        );
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CatTraceArticulationPainter oldDelegate) =>
      oldDelegate.decomposition != decomposition ||
      oldDelegate.pose != pose ||
      oldDelegate.diagnostic != diagnostic ||
      oldDelegate.presentationScale != presentationScale;
}

class BootSequencePreviewPage extends StatefulWidget {
  const BootSequencePreviewPage({super.key});

  @override
  State<BootSequencePreviewPage> createState() =>
      _BootSequencePreviewPageState();
}

class _BootSequencePreviewPageState extends State<BootSequencePreviewPage>
    with TickerProviderStateMixin {
  static const _sceneCount = 8;
  static const _prototypeDuration = _scene1TotalDuration;
  static const _placeholderDuration = Duration(seconds: 8);

  int _selectedSceneIndex = 0;
  final _effectLabSession = _EffectLabSession();
  final _scene2Session = Scene2CalibrationSession();
  final _firedImpulsePoints = <int>{};
  late final Future<void> _effectSettingsReady;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _prototypeDuration,
  )..addListener(_evaluateScene1Timeline);
  late final AnimationController _suspensionController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1),
  );

  @override
  void initState() {
    super.initState();
    _effectSettingsReady = _effectLabSession.restore().then((_) {
      if (!mounted) return;
      _syncSuspensionDuration();
      setState(() {});
    });
  }

  @override
  void dispose() {
    _suspensionController.dispose();
    _controller.dispose();
    super.dispose();
  }

  String _sceneLabel(int index) =>
      index == _sceneCount - 1 ? 'FINAL' : 'SCENE ${index + 1}';

  Duration get _activeDuration => switch (_selectedSceneIndex) {
    0 => _prototypeDuration,
    1 => _scene2Session.totalDuration ?? _placeholderDuration,
    _ => _placeholderDuration,
  };

  void _syncSuspensionDuration() {
    final suspension = _effectLabSession.suspension;
    _suspensionController.duration = suspension == null
        ? const Duration(milliseconds: 1)
        : Duration(
            milliseconds:
                suspension.impulseDurationMs + suspension.settleDurationMs,
          );
  }

  void _evaluateScene1Timeline() {
    if (_selectedSceneIndex != 0) return;
    final suspension = _effectLabSession.suspension;
    if (suspension == null) return;
    final elapsed = (_controller.value * _scene1TotalDuration.inMilliseconds)
        .round()
        .clamp(0, _scene1TravelDuration.inMilliseconds);
    for (final timeMs in suspension.impulseTimeline) {
      if (timeMs <= elapsed && _firedImpulsePoints.add(timeMs)) {
        _syncSuspensionDuration();
        _suspensionController.forward(from: 0);
      }
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void _play() {
    if (_controller.isCompleted) _controller.value = 0;
    _controller.forward();
    if (_suspensionController.value > 0 && !_suspensionController.isCompleted) {
      _suspensionController.forward();
    }
  }

  void _pause() {
    _controller.stop(canceled: false);
    _suspensionController.stop(canceled: false);
    setState(() {});
  }

  void _stop() {
    _controller.stop(canceled: false);
    _suspensionController.stop(canceled: false);
    _controller.value = 0;
    _suspensionController.value = 0;
    _firedImpulsePoints.clear();
  }

  void _replay() {
    _suspensionController.value = 0;
    _firedImpulsePoints.clear();
    _controller.forward(from: 0);
  }

  void _selectScene(int index) {
    _controller.stop(canceled: false);
    _suspensionController.stop(canceled: false);
    _controller.reset();
    _suspensionController.reset();
    _firedImpulsePoints.clear();
    setState(() {
      _selectedSceneIndex = index;
      _controller.duration = _activeDuration;
    });
  }

  Future<void> _openCalibration() async {
    await _effectSettingsReady;
    if (!mounted) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            BootSequenceCalibrationPage(scene2Session: _scene2Session),
      ),
    );
    await _effectLabSession.reload();
    if (!mounted) return;
    _syncSuspensionDuration();
    _controller.duration = _activeDuration;
    _stop();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('BOOT SEQUENCE')),
    body: AnimatedBuilder(
      animation: Listenable.merge([_controller, _suspensionController]),
      builder: (context, _) {
        final elapsed = Duration(
          milliseconds: (_activeDuration.inMilliseconds * _controller.value)
              .round(),
        );
        return ListView(
          padding: AppSpacing.cardPadding,
          children: [
            const SectionHeader(
              icon: Icons.account_tree_outlined,
              title: 'SEQUENCES',
            ),
            AppSpacing.gapSM,
            OperationCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'JEEP PROTOTYPE',
                    key: ValueKey('jeep-prototype-entry'),
                  ),
                  AppSpacing.gapMD,
                  _SandboxActionButton(
                    key: const ValueKey('open-orlo-logo-sequence'),
                    text: 'ORLO LOGO SEQUENCE',
                    icon: Icons.animation_outlined,
                    onPressed: () => Navigator.push<void>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const OrloLogoSequencePage(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            AppSpacing.gapXL,
            const SectionHeader(
              icon: Icons.tune_outlined,
              title: 'CALIBRATION TEST',
            ),
            AppSpacing.gapSM,
            OperationCard(
              child: _SandboxActionButton(
                key: const ValueKey('open-boot-sequence-calibration'),
                text: 'CALIBRATION TEST',
                icon: Icons.straighten_outlined,
                onPressed: _openCalibration,
              ),
            ),
            AppSpacing.gapXL,
            const SectionHeader(icon: Icons.preview_outlined, title: 'PREVIEW'),
            AppSpacing.gapSM,
            OperationCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _BootSequencePreview(
                    key: const ValueKey('boot-sequence-placeholder'),
                    sceneIndex: _selectedSceneIndex,
                    progress: _controller.value,
                    backgroundAsset: _bootSequenceAssets[0].path,
                    jeepBodyAsset: _bootSequenceAssets[1].path,
                    wheelAsset: _bootSequenceAssets[2].path,
                    sceneLabel: _sceneLabel(_selectedSceneIndex),
                    headlight: _effectLabSession.headlight,
                    dust: _effectLabSession.dust,
                    suspension: _effectLabSession.suspension,
                    suspensionProgress: _suspensionController.value,
                    scene2Session: _scene2Session,
                    scene2JeepAsset: _scene2JeepAsset,
                  ),
                  AppSpacing.gapMD,
                  LinearProgressIndicator(value: _controller.value),
                  AppSpacing.gapSM,
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.xs,
                    children: [
                      Text('CURRENT  ${_sceneLabel(_selectedSceneIndex)}'),
                      Text(
                        '${_formatDuration(elapsed)} / '
                        '${_formatDuration(_activeDuration)}',
                        key: const ValueKey('preview-time'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            AppSpacing.gapXL,
            const SectionHeader(icon: Icons.tune_outlined, title: 'CONTROLS'),
            AppSpacing.gapSM,
            OperationCard(
              child: Column(
                children: [
                  _SandboxActionButton(
                    key: const ValueKey('preview-play'),
                    text: 'PLAY',
                    icon: Icons.play_arrow,
                    onPressed: _controller.isAnimating ? null : _play,
                  ),
                  AppSpacing.gapSM,
                  _SandboxActionButton(
                    key: const ValueKey('preview-pause'),
                    text: 'PAUSE',
                    icon: Icons.pause,
                    onPressed: _controller.isAnimating ? _pause : null,
                  ),
                  AppSpacing.gapSM,
                  _SandboxActionButton(
                    key: const ValueKey('preview-stop'),
                    text: 'STOP',
                    icon: Icons.stop,
                    onPressed: _stop,
                  ),
                  AppSpacing.gapSM,
                  _SandboxActionButton(
                    key: const ValueKey('preview-replay'),
                    text: 'REPLAY',
                    icon: Icons.replay,
                    onPressed: _replay,
                  ),
                ],
              ),
            ),
            AppSpacing.gapXL,
            const SectionHeader(
              icon: Icons.view_timeline_outlined,
              title: 'SCENES',
            ),
            AppSpacing.gapSM,
            OperationCard(
              child: Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (var index = 0; index < _sceneCount; index++)
                    ChoiceChip(
                      key: ValueKey('preview-scene-$index'),
                      label: Text(_sceneLabel(index)),
                      selected: _selectedSceneIndex == index,
                      onSelected: (_) => _selectScene(index),
                    ),
                ],
              ),
            ),
            AppSpacing.gapXL,
            const SectionHeader(
              icon: Icons.photo_library_outlined,
              title: 'ASSETS',
            ),
            AppSpacing.gapSM,
            Column(
              key: const ValueKey('boot-asset-list'),
              children: [
                for (
                  var index = 0;
                  index < _bootSequenceAssets.length;
                  index++
                ) ...[
                  _BootAssetCard(
                    key: ValueKey('boot-asset-card-$index'),
                    asset: _bootSequenceAssets[index],
                    onTap: () => _showAssetPreview(_bootSequenceAssets[index]),
                  ),
                  if (index != _bootSequenceAssets.length - 1) AppSpacing.gapSM,
                ],
              ],
            ),
            AppSpacing.gapLG,
          ],
        );
      },
    ),
  );

  Future<void> _showAssetPreview(_BootSequenceAsset asset) => showDialog<void>(
    context: context,
    builder: (context) => _BootAssetPreviewDialog(asset: asset),
  );
}

class OrloLogoSequencePage extends StatefulWidget {
  const OrloLogoSequencePage({super.key});

  @override
  State<OrloLogoSequencePage> createState() => _OrloLogoSequencePageState();
}

class _OrloLogoSequencePageState extends State<OrloLogoSequencePage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _orloSequenceDuration,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _play() {
    if (_controller.isCompleted) _controller.value = 0;
    _controller.forward();
  }

  void _pause() {
    _controller.stop(canceled: false);
    setState(() {});
  }

  void _stop() {
    _controller.stop(canceled: false);
    _controller.value = 0;
  }

  void _replay() => _controller.forward(from: 0);

  void _selectStage(int index) {
    _controller.stop(canceled: false);
    _controller.value = index / _orloSequenceDuration.inSeconds;
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('ORLO LOGO SEQUENCE')),
    body: AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final elapsed = Duration(
          milliseconds:
              (_orloSequenceDuration.inMilliseconds * _controller.value)
                  .round(),
        );
        final stageIndex = (_controller.value * 13).floor().clamp(0, 12);
        return ListView(
          key: const ValueKey('orlo-logo-sequence-content'),
          padding: AppSpacing.cardPadding,
          children: [
            const SectionHeader(
              icon: Icons.animation_outlined,
              title: 'ORLO LOGO SEQUENCE',
            ),
            AppSpacing.gapSM,
            OperationCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _OrloLogoSequencePreview(progress: _controller.value),
                  AppSpacing.gapMD,
                  LinearProgressIndicator(value: _controller.value),
                  AppSpacing.gapSM,
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.xs,
                    children: [
                      Text(
                        'STAGE ${(stageIndex + 1).toString().padLeft(2, '0')}  '
                        '${_orloStageTitles[stageIndex]}',
                        key: const ValueKey('orlo-current-stage'),
                      ),
                      Text(
                        '${_formatDuration(elapsed)} / '
                        '${_formatDuration(_orloSequenceDuration)}',
                        key: const ValueKey('orlo-preview-time'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            AppSpacing.gapXL,
            const SectionHeader(icon: Icons.tune_outlined, title: 'CONTROLS'),
            AppSpacing.gapSM,
            OperationCard(
              child: Column(
                children: [
                  _SandboxActionButton(
                    key: const ValueKey('orlo-play'),
                    text: 'PLAY',
                    icon: Icons.play_arrow,
                    onPressed: _controller.isAnimating ? null : _play,
                  ),
                  AppSpacing.gapSM,
                  _SandboxActionButton(
                    key: const ValueKey('orlo-pause'),
                    text: 'PAUSE',
                    icon: Icons.pause,
                    onPressed: _controller.isAnimating ? _pause : null,
                  ),
                  AppSpacing.gapSM,
                  _SandboxActionButton(
                    key: const ValueKey('orlo-stop'),
                    text: 'STOP',
                    icon: Icons.stop,
                    onPressed: _stop,
                  ),
                  AppSpacing.gapSM,
                  _SandboxActionButton(
                    key: const ValueKey('orlo-replay'),
                    text: 'REPLAY',
                    icon: Icons.replay,
                    onPressed: _replay,
                  ),
                ],
              ),
            ),
            AppSpacing.gapXL,
            const SectionHeader(
              icon: Icons.view_timeline_outlined,
              title: 'STAGES',
            ),
            AppSpacing.gapSM,
            OperationCard(
              child: Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (var index = 0; index < _orloStageTitles.length; index++)
                    ChoiceChip(
                      key: ValueKey('orlo-stage-${index + 1}'),
                      label: Text((index + 1).toString().padLeft(2, '0')),
                      selected: stageIndex == index,
                      onSelected: (_) => _selectStage(index),
                    ),
                ],
              ),
            ),
            AppSpacing.gapLG,
          ],
        );
      },
    ),
  );
}

class _OrloLogoSequencePreview extends StatelessWidget {
  const _OrloLogoSequencePreview({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final officialAssetOpacity = ((progress - (12 / 13)) * 13).clamp(0.0, 1.0);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: AspectRatio(
          aspectRatio: 4 / 3,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: ColoredBox(
              color: Colors.black,
              child: Stack(
                key: const ValueKey('orlo-sequence-canvas'),
                fit: StackFit.expand,
                children: [
                  CustomPaint(
                    key: const ValueKey('orlo-sequence-painter'),
                    painter: _OrloLogoSequencePainter(progress: progress),
                  ),
                  IgnorePointer(
                    child: Opacity(
                      opacity: officialAssetOpacity,
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Image.asset(
                          _orloLogoAsset,
                          key: const ValueKey('orlo-official-logo-asset'),
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OrloLogoSequencePainter extends CustomPainter {
  const _OrloLogoSequencePainter({required this.progress});

  final double progress;

  double _stage(double start) => ((progress * 13) - start).clamp(0.0, 1.0);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.47);
    final unit = math.min(size.width, size.height) * 0.26;
    final cyan = const Color(0xff79d5ff);
    final blue = const Color(0xff1598ef);
    final glow = Paint()
      ..color = cyan.withValues(alpha: 0.24)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = math.max(1.2, unit * 0.014)
      ..color = cyan;

    final waveAppear = _stage(0);
    final convergence = _stage(1);
    if (waveAppear > 0 && convergence < 1) {
      final span = _lerp(size.width * 0.72, size.width * 0.14, convergence);
      final wave = Path()..moveTo(center.dx - span / 2, center.dy);
      const samples = 42;
      for (var index = 1; index <= samples; index++) {
        final fraction = index / samples;
        final distance = (fraction - 0.5).abs() * 2;
        final envelope = math.pow(1 - distance, 2).toDouble();
        final amplitude = unit * 0.18 * envelope * waveAppear;
        final y = center.dy + math.sin(fraction * math.pi * 15) * amplitude;
        wave.lineTo(center.dx - span / 2 + span * fraction, y);
      }
      canvas.drawPath(wave, glow);
      canvas.drawPath(wave, line);
      final particle = Paint()..color = cyan.withValues(alpha: 0.65);
      for (var index = 0; index < 11; index++) {
        final x = center.dx + ((index - 5) * span / 14);
        final y = center.dy + unit * 0.12 + convergence * unit * 0.28;
        canvas.drawCircle(Offset(x, y), 1.2, particle);
      }
    }

    final axisAppear = _stage(2);
    if (axisAppear > 0) {
      final top = center.dy - unit * 1.25;
      final endY = _lerp(top, center.dy + unit * 0.76, axisAppear);
      final axisPath = Path()
        ..moveTo(center.dx, top)
        ..lineTo(center.dx, endY);
      canvas.drawPath(axisPath, glow);
      canvas.drawPath(axisPath, line..strokeWidth = math.max(1.8, unit * 0.02));
    }

    final landing = _stage(3);
    if (landing > 0) {
      final ripple = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = blue.withValues(alpha: 0.65 * (1 - landing * 0.45));
      for (var ring = 0; ring < 3; ring++) {
        final radius = unit * (0.1 + (landing * 0.24) + ring * 0.1);
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(center.dx, center.dy + unit * 0.76),
            width: radius * 2,
            height: radius * 0.36,
          ),
          ripple,
        );
      }
    }

    final sailApproach = _stage(4);
    final sailMerge = _stage(5);
    final symbol = _stage(6);
    if (sailApproach > 0) {
      final approach = Curves.easeOutCubic.transform(sailApproach);
      final merge = Curves.easeInOutCubic.transform(sailMerge);
      final outside = unit * 1.75;
      final target = unit * 0.62;
      final distance = _lerp(outside, target, approach);
      final mergedDistance = _lerp(distance, target, merge);
      _drawSail(canvas, center, unit, -1, mergedDistance, line, glow, symbol);
      _drawSail(canvas, center, unit, 1, mergedDistance, line, glow, symbol);
    }

    if (symbol > 0) {
      final lower = Path()
        ..moveTo(center.dx - unit * 0.9, center.dy + unit * 0.48)
        ..lineTo(center.dx, center.dy + unit * 0.22)
        ..lineTo(center.dx + unit * 0.9, center.dy + unit * 0.48);
      canvas.drawPath(lower, glow);
      canvas.drawPath(lower, line);
    }

    final orbitAppear = _stage(7);
    final orbitComplete = _stage(8);
    if (orbitAppear > 0) {
      final orbitPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..color = cyan.withValues(alpha: 0.78);
      for (var ring = 0; ring < 3; ring++) {
        final rect = Rect.fromCenter(
          center: center,
          width: unit * (2.1 + ring * 0.28),
          height: unit * (1.7 + ring * 0.24),
        );
        final sweep = math.pi * 2 * orbitAppear;
        canvas.drawArc(rect, -math.pi / 2, sweep, false, orbitPaint);
        if (orbitComplete > 0) {
          for (var point = 0; point < 3; point++) {
            final angle = (point / 3) * math.pi * 2 + ring * 0.7;
            final dot = Offset(
              center.dx + math.cos(angle) * rect.width / 2,
              center.dy + math.sin(angle) * rect.height / 2,
            );
            canvas.drawCircle(dot, 1.4 + orbitComplete, line);
          }
        }
      }
    }

    final accumulation = _stage(9);
    if (accumulation > 0) {
      canvas.drawCircle(
        center,
        unit * (0.08 + accumulation * 0.14),
        Paint()
          ..color = cyan.withValues(alpha: 0.22 + accumulation * 0.28)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
      );
    }

    final flash = _stage(10);
    if (flash > 0 && flash < 0.34) {
      final flashStrength = math.sin((flash / 0.34) * math.pi);
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = Colors.white.withValues(alpha: flashStrength * 0.48),
      );
    }

    if (_stage(11) > 0) {
      canvas.drawCircle(center, unit * 0.05, Paint()..color = Colors.white);
    }
  }

  void _drawSail(
    Canvas canvas,
    Offset center,
    double unit,
    int direction,
    double distance,
    Paint line,
    Paint glow,
    double formation,
  ) {
    final innerX = center.dx + direction * distance;
    final sail = Path()
      ..moveTo(innerX, center.dy - unit * 0.72)
      ..lineTo(center.dx + direction * unit * 0.42, center.dy + unit * 0.28)
      ..lineTo(center.dx + direction * unit * 0.78, center.dy + unit * 0.12)
      ..close();
    canvas.drawPath(sail, glow);
    canvas.drawPath(sail, line);
    if (formation > 0) {
      canvas.drawLine(
        Offset(innerX, center.dy - unit * 0.72),
        Offset(center.dx, center.dy + unit * 0.78),
        line,
      );
    }
  }

  double _lerp(double start, double end, double value) =>
      start + (end - start) * value;

  @override
  bool shouldRepaint(_OrloLogoSequencePainter oldDelegate) =>
      progress != oldDelegate.progress;
}

class BootSequenceCalibrationPage extends StatefulWidget {
  const BootSequenceCalibrationPage({super.key, this.scene2Session});

  final Scene2CalibrationSession? scene2Session;

  @override
  State<BootSequenceCalibrationPage> createState() =>
      _BootSequenceCalibrationPageState();
}

class _BootSequenceCalibrationPageState
    extends State<BootSequenceCalibrationPage> {
  final _session = _CalibrationSession();
  final _effectLabSession = _EffectLabSession();
  late final Scene2CalibrationSession _scene2Session =
      widget.scene2Session ?? Scene2CalibrationSession();
  late final Future<void> _effectSettingsReady;

  @override
  void initState() {
    super.initState();
    _effectSettingsReady = _effectLabSession.restore();
  }

  Future<void> _openEffectLab() async {
    await _effectSettingsReady;
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => _EffectLabPage(session: _effectLabSession),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('CALIBRATION')),
    body: ListView(
      padding: AppSpacing.cardPadding,
      children: [
        const SectionHeader(
          icon: Icons.build_outlined,
          title: 'ASSEMBLY CALIBRATION',
        ),
        AppSpacing.gapSM,
        OperationCard(
          child: _SandboxActionButton(
            key: const ValueKey('open-assembly-calibration'),
            text: 'ASSEMBLY CALIBRATION',
            icon: Icons.build_outlined,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => _AssemblyCalibrationPage(session: _session),
              ),
            ),
          ),
        ),
        AppSpacing.gapXL,
        const SectionHeader(
          icon: Icons.animation_outlined,
          title: 'MOTION CALIBRATION',
        ),
        AppSpacing.gapSM,
        OperationCard(
          child: _SandboxActionButton(
            key: const ValueKey('open-motion-calibration'),
            text: 'MOTION CALIBRATION',
            icon: Icons.animation_outlined,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => _MotionCalibrationPage(session: _session),
              ),
            ),
          ),
        ),
        AppSpacing.gapXL,
        const SectionHeader(icon: Icons.science_outlined, title: 'EFFECT LAB'),
        AppSpacing.gapSM,
        OperationCard(
          child: _SandboxActionButton(
            key: const ValueKey('open-effect-lab'),
            text: 'EFFECT LAB',
            icon: Icons.science_outlined,
            onPressed: _openEffectLab,
          ),
        ),
        AppSpacing.gapXL,
        const SectionHeader(
          icon: Icons.video_settings_outlined,
          title: 'SCENE 2 CALIBRATION',
        ),
        AppSpacing.gapSM,
        OperationCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SandboxActionButton(
                key: const ValueKey('open-scene-2-layout-test'),
                text: 'LAYOUT TEST',
                icon: Icons.open_with_outlined,
                onPressed: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        _Scene2LayoutTestPage(session: _scene2Session),
                  ),
                ),
              ),
              AppSpacing.gapSM,
              _SandboxActionButton(
                key: const ValueKey('open-scene-2-zoom-test'),
                text: 'ZOOM TEST',
                icon: Icons.zoom_in_outlined,
                onPressed: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        _Scene2ZoomTestPage(session: _scene2Session),
                  ),
                ),
              ),
              AppSpacing.gapSM,
              _SandboxActionButton(
                key: const ValueKey('open-scene-2-composite-test'),
                text: 'COMPOSITE TEST',
                icon: Icons.layers_outlined,
                onPressed: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        _Scene2CompositeTestPage(session: _scene2Session),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _EffectLabPage extends StatelessWidget {
  const _EffectLabPage({required this.session});

  final _EffectLabSession session;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('EFFECT LAB')),
    body: ListView(
      padding: AppSpacing.cardPadding,
      children: [
        for (var index = 0; index < _effectLabEntries.length; index++) ...[
          SectionHeader(
            icon: _effectLabEntries[index].icon,
            title: _effectLabEntries[index].label,
          ),
          AppSpacing.gapSM,
          OperationCard(
            child: _SandboxActionButton(
              key: ValueKey('open-${_effectLabEntries[index].key}-test'),
              text: _effectLabEntries[index].label,
              icon: _effectLabEntries[index].icon,
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => switch (_effectLabEntries[index].key) {
                    'headlight' => _HeadlightTestPage(session: session),
                    'dust' => _DustTestPage(session: session),
                    'suspension' => _SuspensionTestPage(session: session),
                    'composite' => _CompositeTestPage(session: session),
                    _ => throw StateError('Unknown effect lab entry'),
                  },
                ),
              ),
            ),
          ),
          if (index != _effectLabEntries.length - 1) AppSpacing.gapXL,
        ],
      ],
    ),
  );
}

const _effectLabEntries = [
  _EffectLabEntry('headlight', 'HEADLIGHT TEST', Icons.light_mode_outlined),
  _EffectLabEntry('dust', 'DUST TEST', Icons.air_outlined),
  _EffectLabEntry('suspension', 'SUSPENSION TEST', Icons.swap_vert),
  _EffectLabEntry('composite', 'COMPOSITE TEST', Icons.layers_outlined),
];

class _EffectLabEntry {
  const _EffectLabEntry(this.key, this.label, this.icon);

  final String key;
  final String label;
  final IconData icon;
}

class _EffectLabSession {
  final _settings = const _EffectLabSettingsStore();
  _HeadlightParameters? headlight;
  _DustParameters? dust;
  _SuspensionParameters? suspension;
  Future<void>? _restoreFuture;

  Future<void> restore() => _restoreFuture ??= _restore();

  Future<void> reload() {
    _restoreFuture = null;
    return restore();
  }

  Future<void> _restore() async {
    final restored = await _settings.load();
    headlight = restored.headlight;
    dust = restored.dust;
    suspension = restored.suspension;
  }

  Future<void> saveHeadlight(_HeadlightParameters value) async {
    headlight = value;
    await _settings.saveHeadlight(value);
  }

  Future<void> saveDust(_DustParameters value) async {
    dust = value;
    await _settings.saveDust(value);
  }

  Future<void> saveSuspension(_SuspensionParameters value) async {
    suspension = value;
    await _settings.saveSuspension(value);
  }
}

class _HeadlightParameters {
  const _HeadlightParameters({
    required this.left,
    required this.right,
    required this.glowSize,
    required this.opacity,
  });

  static const factoryDefault = _HeadlightParameters(
    left: Offset(0.033, 0.582),
    right: Offset(0.262, 0.596),
    glowSize: 0.165,
    opacity: 0.46,
  );

  static const currentApproved = _HeadlightParameters(
    left: Offset(0.052, 0.582),
    right: Offset(0.288, 0.591),
    glowSize: 0.195,
    opacity: 0.87,
  );

  final Offset left;
  final Offset right;
  final double glowSize;
  final double opacity;

  _HeadlightParameters copyWith({
    Offset? left,
    Offset? right,
    double? glowSize,
    double? opacity,
  }) => _HeadlightParameters(
    left: left ?? this.left,
    right: right ?? this.right,
    glowSize: glowSize ?? this.glowSize,
    opacity: opacity ?? this.opacity,
  );

  Map<String, Object?> toJson() => {
    'effectType': 'headlight',
    'coordinateSystem': 'jeep_local_normalized',
    'left': {'x': _effectRounded(left.dx), 'y': _effectRounded(left.dy)},
    'right': {'x': _effectRounded(right.dx), 'y': _effectRounded(right.dy)},
    'glowSize': _effectRounded(glowSize),
    'opacity': _effectRounded(opacity),
    'beamEnabled': false,
  };

  factory _HeadlightParameters.fromJson(Map<String, Object?> json) {
    _requireExactKeys(json, const {
      'effectType',
      'coordinateSystem',
      'left',
      'right',
      'glowSize',
      'opacity',
      'beamEnabled',
    });
    if (json['effectType'] != 'headlight' ||
        json['coordinateSystem'] != 'jeep_local_normalized' ||
        json['beamEnabled'] != false) {
      throw const FormatException('Invalid headlight setting contract.');
    }
    final left = _settingOffset(json['left']);
    final right = _settingOffset(json['right']);
    final glowSize = _settingDouble(json['glowSize']);
    final opacity = _settingDouble(json['opacity']);
    if (!_normalizedOffset(left) ||
        !_normalizedOffset(right) ||
        glowSize < 0.02 ||
        glowSize > 0.25 ||
        opacity < 0 ||
        opacity > 1) {
      throw const FormatException('Headlight setting is out of range.');
    }
    return _HeadlightParameters(
      left: left,
      right: right,
      glowSize: glowSize,
      opacity: opacity,
    );
  }
}

class _DustParameters {
  const _DustParameters({
    required this.emitter,
    required this.spread,
    required this.direction,
    required this.size,
    required this.opacity,
    required this.lifetimeMs,
    required this.emissionRate,
  });

  static const factoryDefault = _DustParameters(
    emitter: Offset(0.82, 0.72),
    spread: 0.35,
    direction: 0,
    size: 0.18,
    opacity: 0.45,
    lifetimeMs: 1400,
    emissionRate: 7,
  );

  static const currentApproved = _DustParameters(
    emitter: Offset(0.996, 0.684),
    spread: 0.35,
    direction: -20,
    size: 0.24,
    opacity: 0.47,
    lifetimeMs: 1500,
    emissionRate: 7,
  );

  final Offset emitter;
  final double spread;
  final double direction;
  final double size;
  final double opacity;
  final int lifetimeMs;
  final double emissionRate;

  _DustParameters copyWith({
    Offset? emitter,
    double? spread,
    double? direction,
    double? size,
    double? opacity,
    int? lifetimeMs,
    double? emissionRate,
  }) => _DustParameters(
    emitter: emitter ?? this.emitter,
    spread: spread ?? this.spread,
    direction: direction ?? this.direction,
    size: size ?? this.size,
    opacity: opacity ?? this.opacity,
    lifetimeMs: lifetimeMs ?? this.lifetimeMs,
    emissionRate: emissionRate ?? this.emissionRate,
  );

  Map<String, Object?> toJson() => {
    'effectType': 'dust',
    'coordinateSystem': 'jeep_local_normalized',
    'emitter': {
      'x': _effectRounded(emitter.dx),
      'y': _effectRounded(emitter.dy),
    },
    'spread': _effectRounded(spread),
    'direction': _effectRounded(direction),
    'size': _effectRounded(size),
    'opacity': _effectRounded(opacity),
    'lifetimeMs': lifetimeMs,
    'emissionRate': _effectRounded(emissionRate),
  };

  factory _DustParameters.fromJson(Map<String, Object?> json) {
    _requireExactKeys(json, const {
      'effectType',
      'coordinateSystem',
      'emitter',
      'spread',
      'direction',
      'size',
      'opacity',
      'lifetimeMs',
      'emissionRate',
    });
    if (json['effectType'] != 'dust' ||
        json['coordinateSystem'] != 'jeep_local_normalized') {
      throw const FormatException('Invalid dust setting contract.');
    }
    final emitter = _settingOffset(json['emitter']);
    final spread = _settingDouble(json['spread']);
    final direction = _settingDouble(json['direction']);
    final size = _settingDouble(json['size']);
    final opacity = _settingDouble(json['opacity']);
    final lifetimeMs = _settingInt(json['lifetimeMs']);
    final emissionRate = _settingDouble(json['emissionRate']);
    if (!_normalizedOffset(emitter) ||
        spread < 0 ||
        spread > 1 ||
        direction < -180 ||
        direction > 180 ||
        size < 0.04 ||
        size > 0.4 ||
        opacity < 0 ||
        opacity > 1 ||
        lifetimeMs < 250 ||
        lifetimeMs > 3000 ||
        emissionRate < 1 ||
        emissionRate > 16) {
      throw const FormatException('Dust setting is out of range.');
    }
    return _DustParameters(
      emitter: emitter,
      spread: spread,
      direction: direction,
      size: size,
      opacity: opacity,
      lifetimeMs: lifetimeMs,
      emissionRate: emissionRate,
    );
  }
}

class _SuspensionParameters {
  const _SuspensionParameters({
    required this.bodyYResponse,
    required this.impulseStrength,
    required this.impulseDurationMs,
    required this.settleDurationMs,
    this.impulseTimeline = const [],
  });

  static const factoryDefault = _SuspensionParameters(
    bodyYResponse: 0.08,
    impulseStrength: 0.65,
    impulseDurationMs: 180,
    settleDurationMs: 650,
  );

  static const currentApproved = _SuspensionParameters(
    bodyYResponse: 0.05,
    impulseStrength: 0.5,
    impulseDurationMs: 400,
    settleDurationMs: 700,
  );

  final double bodyYResponse;
  final double impulseStrength;
  final int impulseDurationMs;
  final int settleDurationMs;
  final List<int> impulseTimeline;

  _SuspensionParameters copyWith({
    double? bodyYResponse,
    double? impulseStrength,
    int? impulseDurationMs,
    int? settleDurationMs,
    List<int>? impulseTimeline,
  }) => _SuspensionParameters(
    bodyYResponse: bodyYResponse ?? this.bodyYResponse,
    impulseStrength: impulseStrength ?? this.impulseStrength,
    impulseDurationMs: impulseDurationMs ?? this.impulseDurationMs,
    settleDurationMs: settleDurationMs ?? this.settleDurationMs,
    impulseTimeline: impulseTimeline ?? this.impulseTimeline,
  );

  Map<String, Object?> toJson() => {
    'effectType': 'suspension',
    'bodyYResponse': _effectRounded(bodyYResponse),
    'impulseStrength': _effectRounded(impulseStrength),
    'impulseDurationMs': impulseDurationMs,
    'settleDurationMs': settleDurationMs,
    'impulseTimeline': [
      for (final timeMs in impulseTimeline) {'timeMs': timeMs},
    ],
  };

  factory _SuspensionParameters.fromJson(Map<String, Object?> json) {
    const legacyKeys = {
      'effectType',
      'bodyYResponse',
      'impulseStrength',
      'impulseDurationMs',
      'settleDurationMs',
    };
    const currentKeys = {...legacyKeys, 'impulseTimeline'};
    final keys = json.keys.toSet();
    final isLegacy =
        keys.length == legacyKeys.length && keys.containsAll(legacyKeys);
    final isCurrent =
        keys.length == currentKeys.length && keys.containsAll(currentKeys);
    if (!isLegacy && !isCurrent) {
      throw const FormatException('Suspension setting fields do not match.');
    }
    if (json['effectType'] != 'suspension') {
      throw const FormatException('Invalid suspension setting contract.');
    }
    final bodyYResponse = _settingDouble(json['bodyYResponse']);
    final impulseStrength = _settingDouble(json['impulseStrength']);
    final impulseDurationMs = _settingInt(json['impulseDurationMs']);
    final settleDurationMs = _settingInt(json['settleDurationMs']);
    final timelineJson = json['impulseTimeline'];
    final impulseTimeline = <int>[];
    if (timelineJson != null) {
      if (timelineJson is! List) {
        throw const FormatException('Invalid impulse timeline.');
      }
      for (final item in timelineJson) {
        if (item is! Map) {
          throw const FormatException('Invalid impulse point.');
        }
        final point = Map<String, Object?>.from(item);
        _requireExactKeys(point, const {'timeMs'});
        final timeMs = _settingInt(point['timeMs']);
        if (timeMs < 0 || timeMs > _scene1TravelDuration.inMilliseconds) {
          throw const FormatException('Impulse point is out of range.');
        }
        impulseTimeline.add(timeMs);
      }
      if (impulseTimeline.toSet().length != impulseTimeline.length) {
        throw const FormatException('Duplicate impulse point.');
      }
      impulseTimeline.sort();
    }
    if (bodyYResponse < 0.01 ||
        bodyYResponse > 0.25 ||
        impulseStrength < 0.05 ||
        impulseStrength > 1 ||
        impulseDurationMs < 50 ||
        impulseDurationMs > 600 ||
        settleDurationMs < 100 ||
        settleDurationMs > 2000) {
      throw const FormatException('Suspension setting is out of range.');
    }
    return _SuspensionParameters(
      bodyYResponse: bodyYResponse,
      impulseStrength: impulseStrength,
      impulseDurationMs: impulseDurationMs,
      settleDurationMs: settleDurationMs,
      impulseTimeline: List.unmodifiable(impulseTimeline),
    );
  }
}

class _EffectLabSettings {
  const _EffectLabSettings({
    required this.headlight,
    required this.dust,
    required this.suspension,
  });

  const _EffectLabSettings.factoryDefaults()
    : headlight = _HeadlightParameters.factoryDefault,
      dust = _DustParameters.factoryDefault,
      suspension = _SuspensionParameters.factoryDefault;

  final _HeadlightParameters headlight;
  final _DustParameters dust;
  final _SuspensionParameters suspension;
}

class _EffectLabSettingsStore {
  const _EffectLabSettingsStore();

  static const headlightKey =
      'or_app.animations_sandbox.effect_lab.headlight.v1';
  static const dustKey = 'or_app.animations_sandbox.effect_lab.dust.v1';
  static const suspensionKey =
      'or_app.animations_sandbox.effect_lab.suspension.v1';

  Future<_EffectLabSettings> load() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      return _EffectLabSettings(
        headlight: await _readOrSeed(
          preferences,
          key: headlightKey,
          seed: _HeadlightParameters.currentApproved,
          factoryDefault: _HeadlightParameters.factoryDefault,
          decode: _HeadlightParameters.fromJson,
        ),
        dust: await _readOrSeed(
          preferences,
          key: dustKey,
          seed: _DustParameters.currentApproved,
          factoryDefault: _DustParameters.factoryDefault,
          decode: _DustParameters.fromJson,
        ),
        suspension: await _readOrSeed(
          preferences,
          key: suspensionKey,
          seed: _SuspensionParameters.currentApproved,
          factoryDefault: _SuspensionParameters.factoryDefault,
          decode: _SuspensionParameters.fromJson,
        ),
      );
    } catch (_) {
      return const _EffectLabSettings.factoryDefaults();
    }
  }

  Future<void> saveHeadlight(_HeadlightParameters value) =>
      _save(headlightKey, value.toJson());

  Future<void> saveDust(_DustParameters value) =>
      _save(dustKey, value.toJson());

  Future<void> saveSuspension(_SuspensionParameters value) =>
      _save(suspensionKey, value.toJson());

  Future<void> _save(String key, Map<String, Object?> value) async {
    final preferences = await SharedPreferences.getInstance();
    final saved = await preferences.setString(key, jsonEncode(value));
    if (!saved) throw StateError('Unable to save Effect Lab settings.');
  }

  Future<T> _readOrSeed<T>(
    SharedPreferences preferences, {
    required String key,
    required T seed,
    required T factoryDefault,
    required T Function(Map<String, Object?> json) decode,
  }) async {
    final raw = preferences.getString(key);
    if (raw == null) {
      final json = switch (seed) {
        _HeadlightParameters value => value.toJson(),
        _DustParameters value => value.toJson(),
        _SuspensionParameters value => value.toJson(),
        _ => throw StateError('Unsupported Effect Lab setting.'),
      };
      final saved = await preferences.setString(key, jsonEncode(json));
      if (!saved) return factoryDefault;
      return seed;
    }
    try {
      final value = jsonDecode(raw);
      if (value is! Map) return factoryDefault;
      return decode(Map<String, Object?>.from(value));
    } catch (_) {
      return factoryDefault;
    }
  }
}

void _requireExactKeys(Map<String, Object?> json, Set<String> expected) {
  if (json.keys.toSet().length != expected.length ||
      !json.keys.toSet().containsAll(expected)) {
    throw const FormatException('Effect Lab setting fields do not match.');
  }
}

Offset _settingOffset(Object? value) {
  if (value is! Map) throw const FormatException('Invalid effect position.');
  final json = Map<String, Object?>.from(value);
  _requireExactKeys(json, const {'x', 'y'});
  return Offset(_settingDouble(json['x']), _settingDouble(json['y']));
}

double _settingDouble(Object? value) {
  if (value is! num || !value.toDouble().isFinite) {
    throw const FormatException('Invalid effect number.');
  }
  return value.toDouble();
}

int _settingInt(Object? value) {
  if (value is! int) throw const FormatException('Invalid effect integer.');
  return value;
}

bool _normalizedOffset(Offset value) =>
    value.dx >= 0 && value.dx <= 1 && value.dy >= 0 && value.dy <= 1;

double _effectRounded(double value) => double.parse(value.toStringAsFixed(3));

String _effectJson(Map<String, Object?> value) =>
    const JsonEncoder.withIndent('  ').convert(value);

Future<void> _copyEffectParameters(BuildContext context, String json) async {
  await Clipboard.setData(ClipboardData(text: json));
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(const SnackBar(content: Text('CODEX PARAMETERSをコピーしました')));
}

class _EffectParametersOutput extends StatelessWidget {
  const _EffectParametersOutput({
    required this.json,
    required this.jsonKey,
    required this.copyKey,
  });

  final String json;
  final String jsonKey;
  final String copyKey;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SectionHeader(icon: Icons.data_object, title: 'CODEX PARAMETERS'),
      AppSpacing.gapSM,
      OperationCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SelectableText(
              json,
              key: ValueKey(jsonKey),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
            ),
            AppSpacing.gapMD,
            _SandboxActionButton(
              key: ValueKey(copyKey),
              text: 'COPY PARAMETERS',
              icon: Icons.copy_outlined,
              onPressed: () => _copyEffectParameters(context, json),
            ),
          ],
        ),
      ),
    ],
  );
}

class _EffectJeepCanvas extends StatelessWidget {
  const _EffectJeepCanvas({
    required this.canvasKey,
    required this.overlay,
    this.onMove,
    this.assemblyOffset = Offset.zero,
  });

  final String canvasKey;
  final Widget overlay;
  final void Function(Offset delta, Size assemblySize)? onMove;
  final Offset assemblyOffset;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 800),
      child: AspectRatio(
        aspectRatio: 3 / 2,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final assemblyWidth = (constraints.maxWidth * 0.68)
                  .clamp(170.0, 520.0)
                  .toDouble();
              final assemblySize = Size(
                assemblyWidth,
                assemblyWidth * (941 / 1672),
              );
              return Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(_bootSequenceAssets[0].path, fit: BoxFit.cover),
                  Center(
                    child: Transform.translate(
                      key: ValueKey('$canvasKey-assembly-offset'),
                      offset: assemblyOffset,
                      child: Listener(
                        key: ValueKey(canvasKey),
                        behavior: HitTestBehavior.opaque,
                        onPointerMove: onMove == null
                            ? null
                            : (event) => onMove!(event.delta, assemblySize),
                        child: SizedBox.fromSize(
                          size: assemblySize,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              _JeepAssembly(
                                width: assemblyWidth,
                                bodyAsset: _bootSequenceAssets[1].path,
                                wheelAsset: _bootSequenceAssets[2].path,
                              ),
                              Positioned.fill(child: overlay),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    ),
  );
}

class _EffectAnchor extends StatelessWidget {
  const _EffectAnchor({required this.keyName, required this.position});

  final String keyName;
  final Offset position;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment((position.dx * 2) - 1, (position.dy * 2) - 1),
    child: IgnorePointer(
      child: Container(
        key: ValueKey(keyName),
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.32),
          shape: BoxShape.circle,
          border: Border.all(color: Theme.of(context).colorScheme.primary),
        ),
      ),
    ),
  );
}

class _HeadlightTestPage extends StatefulWidget {
  const _HeadlightTestPage({required this.session});

  final _EffectLabSession session;

  @override
  State<_HeadlightTestPage> createState() => _HeadlightTestPageState();
}

class _HeadlightTestPageState extends State<_HeadlightTestPage> {
  late _HeadlightParameters _parameters;
  bool _leftSelected = true;
  bool _enabled = true;

  @override
  void initState() {
    super.initState();
    _parameters =
        widget.session.headlight ?? _HeadlightParameters.currentApproved;
  }

  void _moveAnchor(Offset delta, Size assemblySize) {
    final current = _leftSelected ? _parameters.left : _parameters.right;
    final updated = Offset(
      (current.dx + (delta.dx / assemblySize.width)).clamp(0.0, 1.0),
      (current.dy + (delta.dy / assemblySize.height)).clamp(0.0, 1.0),
    );
    setState(() {
      _parameters = _leftSelected
          ? _parameters.copyWith(left: updated)
          : _parameters.copyWith(right: updated);
    });
  }

  Future<void> _apply() async {
    await widget.session.saveHeadlight(_parameters);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('HEADLIGHTをLABへ適用しました')));
  }

  Future<void> _reset() async {
    const value = _HeadlightParameters.factoryDefault;
    setState(() => _parameters = value);
    await widget.session.saveHeadlight(value);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('HEADLIGHTをFactory Defaultへ戻しました')),
      );
  }

  @override
  Widget build(BuildContext context) {
    final json = _effectJson(_parameters.toJson());
    return Scaffold(
      appBar: AppBar(title: const Text('HEADLIGHT TEST')),
      body: ListView(
        padding: AppSpacing.cardPadding,
        children: [
          const SectionHeader(
            icon: Icons.light_mode_outlined,
            title: 'PREVIEW',
          ),
          AppSpacing.gapSM,
          OperationCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _EffectJeepCanvas(
                  canvasKey: 'headlight-canvas-drag-target',
                  onMove: _moveAnchor,
                  overlay: _HeadlightOverlay(
                    parameters: _parameters,
                    enabled: _enabled,
                  ),
                ),
                AppSpacing.gapMD,
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    ChoiceChip(
                      key: const ValueKey('headlight-select-left'),
                      label: const Text('LEFT HEADLIGHT'),
                      selected: _leftSelected,
                      onSelected: (_) => setState(() => _leftSelected = true),
                    ),
                    ChoiceChip(
                      key: const ValueKey('headlight-select-right'),
                      label: const Text('RIGHT HEADLIGHT'),
                      selected: !_leftSelected,
                      onSelected: (_) => setState(() => _leftSelected = false),
                    ),
                  ],
                ),
                SwitchListTile(
                  key: const ValueKey('headlight-test-toggle'),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('TEST ON / OFF'),
                  value: _enabled,
                  onChanged: (value) => setState(() => _enabled = value),
                ),
              ],
            ),
          ),
          AppSpacing.gapXL,
          const SectionHeader(icon: Icons.tune_outlined, title: 'PARAMETERS'),
          AppSpacing.gapSM,
          OperationCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: AppSpacing.lg,
                  runSpacing: AppSpacing.sm,
                  children: [
                    Text('LEFT X  ${_parameters.left.dx.toStringAsFixed(3)}'),
                    Text('LEFT Y  ${_parameters.left.dy.toStringAsFixed(3)}'),
                    Text('RIGHT X  ${_parameters.right.dx.toStringAsFixed(3)}'),
                    Text('RIGHT Y  ${_parameters.right.dy.toStringAsFixed(3)}'),
                  ],
                ),
                _CalibrationSlider(
                  key: const ValueKey('headlight-glow-size-slider'),
                  label: 'GLOW SIZE',
                  value: _parameters.glowSize,
                  min: 0.02,
                  max: 0.25,
                  divisions: 46,
                  onChanged: (value) => setState(
                    () => _parameters = _parameters.copyWith(glowSize: value),
                  ),
                ),
                _CalibrationSlider(
                  key: const ValueKey('headlight-opacity-slider'),
                  label: 'OPACITY',
                  value: _parameters.opacity,
                  min: 0,
                  max: 1,
                  divisions: 100,
                  onChanged: (value) => setState(
                    () => _parameters = _parameters.copyWith(opacity: value),
                  ),
                ),
                AppSpacing.gapMD,
                _SandboxActionButton(
                  key: const ValueKey('apply-headlight-to-lab'),
                  text: 'APPLY TO LAB',
                  icon: Icons.check_circle_outline,
                  onPressed: _apply,
                ),
                AppSpacing.gapSM,
                _SandboxActionButton(
                  key: const ValueKey('reset-headlight-to-default'),
                  text: 'RESET TO DEFAULT',
                  icon: Icons.restart_alt,
                  onPressed: _reset,
                ),
              ],
            ),
          ),
          AppSpacing.gapXL,
          _EffectParametersOutput(
            json: json,
            jsonKey: 'headlight-parameters-json',
            copyKey: 'copy-headlight-parameters',
          ),
          AppSpacing.gapLG,
        ],
      ),
    );
  }
}

class _HeadlightOverlay extends StatelessWidget {
  const _HeadlightOverlay({required this.parameters, required this.enabled});

  final _HeadlightParameters parameters;
  final bool enabled;

  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    children: [
      if (enabled)
        Positioned.fill(
          child: _HeadlightGlow(
            key: const ValueKey('headlight-effect-preview'),
            keyPrefix: 'headlight',
            parameters: parameters,
          ),
        ),
      _EffectAnchor(
        keyName: 'headlight-left-anchor',
        position: parameters.left,
      ),
      _EffectAnchor(
        keyName: 'headlight-right-anchor',
        position: parameters.right,
      ),
    ],
  );
}

class _HeadlightGlow extends StatelessWidget {
  const _HeadlightGlow({
    super.key,
    required this.keyPrefix,
    required this.parameters,
  });

  final String keyPrefix;
  final _HeadlightParameters parameters;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      CustomPaint(
        key: ValueKey('$keyPrefix-outer-glow'),
        painter: _HeadlightGlowPainter(
          parameters: parameters,
          layer: _HeadlightGlowLayer.outer,
        ),
      ),
      CustomPaint(
        key: ValueKey('$keyPrefix-inner-glow'),
        painter: _HeadlightGlowPainter(
          parameters: parameters,
          layer: _HeadlightGlowLayer.inner,
        ),
      ),
    ],
  );
}

enum _HeadlightGlowLayer { outer, inner }

class _HeadlightGlowPainter extends CustomPainter {
  const _HeadlightGlowPainter({required this.parameters, required this.layer});

  final _HeadlightParameters parameters;
  final _HeadlightGlowLayer layer;

  static const innerSizeRatio = 0.42;
  static const outerOpacityRatio = 0.55;
  static const innerOpacityRatio = 1.35;

  @override
  void paint(Canvas canvas, Size size) {
    for (final anchor in [parameters.left, parameters.right]) {
      final source = Offset(anchor.dx * size.width, anchor.dy * size.height);
      final outerRadiusX = parameters.glowSize * size.width;
      final radiusX = layer == _HeadlightGlowLayer.inner
          ? outerRadiusX * innerSizeRatio
          : outerRadiusX;
      final radiusY = radiusX * 0.72;
      final opacity = layer == _HeadlightGlowLayer.inner
          ? (parameters.opacity * innerOpacityRatio).clamp(0.0, 1.0)
          : (parameters.opacity * outerOpacityRatio).clamp(0.0, 1.0);
      final bounds = Rect.fromCenter(
        center: source,
        width: radiusX * 2,
        height: radiusY * 2,
      );
      final colors = layer == _HeadlightGlowLayer.inner
          ? [
              const Color(0xFFFFFBE8).withValues(alpha: opacity),
              const Color(0xFFFFF4C2).withValues(alpha: opacity * 0.46),
              const Color(0x00FFF4C2),
            ]
          : [
              const Color(0xFFFFF4C2).withValues(alpha: opacity),
              const Color(0xFFFFE9A8).withValues(alpha: opacity * 0.35),
              const Color(0x00FFE9A8),
            ];
      canvas.drawOval(
        bounds,
        Paint()
          ..shader = RadialGradient(
            colors: colors,
            stops: layer == _HeadlightGlowLayer.inner
                ? const [0, 0.42, 1]
                : const [0, 0.5, 1],
          ).createShader(bounds)
          ..maskFilter = MaskFilter.blur(
            BlurStyle.normal,
            layer == _HeadlightGlowLayer.inner ? 3 : 9,
          ),
      );
    }
  }

  @override
  bool shouldRepaint(_HeadlightGlowPainter oldDelegate) =>
      parameters != oldDelegate.parameters || layer != oldDelegate.layer;
}

class _DustTestPage extends StatefulWidget {
  const _DustTestPage({required this.session});

  final _EffectLabSession session;

  @override
  State<_DustTestPage> createState() => _DustTestPageState();
}

class _DustTestPageState extends State<_DustTestPage>
    with SingleTickerProviderStateMixin {
  late _DustParameters _parameters;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  );

  @override
  void initState() {
    super.initState();
    _parameters = widget.session.dust ?? _DustParameters.currentApproved;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _moveEmitter(Offset delta, Size assemblySize) => setState(() {
    _parameters = _parameters.copyWith(
      emitter: Offset(
        (_parameters.emitter.dx + (delta.dx / assemblySize.width)).clamp(
          0.0,
          1.0,
        ),
        (_parameters.emitter.dy + (delta.dy / assemblySize.height)).clamp(
          0.0,
          1.0,
        ),
      ),
    );
  });

  void _play() {
    _controller.repeat();
    setState(() {});
  }

  void _stop() {
    _controller.stop(canceled: false);
    _controller.value = 0;
    setState(() {});
  }

  void _replay() {
    _controller.value = 0;
    _controller.repeat();
    setState(() {});
  }

  Future<void> _apply() async {
    await widget.session.saveDust(_parameters);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('DUSTをLABへ適用しました')));
  }

  Future<void> _reset() async {
    const value = _DustParameters.factoryDefault;
    setState(() => _parameters = value);
    await widget.session.saveDust(value);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('DUSTをFactory Defaultへ戻しました')),
      );
  }

  @override
  Widget build(BuildContext context) {
    final json = _effectJson(_parameters.toJson());
    return Scaffold(
      appBar: AppBar(title: const Text('DUST TEST')),
      body: ListView(
        padding: AppSpacing.cardPadding,
        children: [
          const SectionHeader(icon: Icons.air_outlined, title: 'PREVIEW'),
          AppSpacing.gapSM,
          OperationCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) => _EffectJeepCanvas(
                    canvasKey: 'dust-canvas-drag-target',
                    onMove: _moveEmitter,
                    overlay: _DustOverlay(
                      parameters: _parameters,
                      progress: _controller.value,
                      visible: _controller.isAnimating,
                    ),
                  ),
                ),
                AppSpacing.gapMD,
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    _CompactActionButton(
                      key: const ValueKey('dust-test-play'),
                      label: 'TEST PLAY',
                      icon: Icons.play_arrow,
                      onPressed: _controller.isAnimating ? null : _play,
                    ),
                    _CompactActionButton(
                      key: const ValueKey('dust-test-stop'),
                      label: 'STOP',
                      icon: Icons.stop,
                      onPressed: _stop,
                    ),
                    _CompactActionButton(
                      key: const ValueKey('dust-test-replay'),
                      label: 'REPLAY',
                      icon: Icons.replay,
                      onPressed: _replay,
                    ),
                  ],
                ),
              ],
            ),
          ),
          AppSpacing.gapXL,
          const SectionHeader(icon: Icons.tune_outlined, title: 'PARAMETERS'),
          AppSpacing.gapSM,
          OperationCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: AppSpacing.lg,
                  runSpacing: AppSpacing.sm,
                  children: [
                    Text(
                      'EMITTER X  ${_parameters.emitter.dx.toStringAsFixed(3)}',
                    ),
                    Text(
                      'EMITTER Y  ${_parameters.emitter.dy.toStringAsFixed(3)}',
                    ),
                  ],
                ),
                _CalibrationSlider(
                  key: const ValueKey('dust-spread-slider'),
                  label: 'SPREAD',
                  value: _parameters.spread,
                  min: 0,
                  max: 1,
                  divisions: 100,
                  onChanged: (value) => setState(
                    () => _parameters = _parameters.copyWith(spread: value),
                  ),
                ),
                _CalibrationSlider(
                  key: const ValueKey('dust-direction-slider'),
                  label: 'DIRECTION',
                  value: _parameters.direction,
                  min: -180,
                  max: 180,
                  divisions: 72,
                  unit: '°',
                  onChanged: (value) => setState(
                    () => _parameters = _parameters.copyWith(direction: value),
                  ),
                ),
                _CalibrationSlider(
                  key: const ValueKey('dust-size-slider'),
                  label: 'SIZE',
                  value: _parameters.size,
                  min: 0.04,
                  max: 0.4,
                  divisions: 36,
                  onChanged: (value) => setState(
                    () => _parameters = _parameters.copyWith(size: value),
                  ),
                ),
                _CalibrationSlider(
                  key: const ValueKey('dust-opacity-slider'),
                  label: 'OPACITY',
                  value: _parameters.opacity,
                  min: 0,
                  max: 1,
                  divisions: 100,
                  onChanged: (value) => setState(
                    () => _parameters = _parameters.copyWith(opacity: value),
                  ),
                ),
                _CalibrationSlider(
                  key: const ValueKey('dust-lifetime-slider'),
                  label: 'LIFETIME',
                  value: _parameters.lifetimeMs.toDouble(),
                  min: 250,
                  max: 3000,
                  divisions: 55,
                  unit: 'ms',
                  onChanged: (value) => setState(
                    () => _parameters = _parameters.copyWith(
                      lifetimeMs: value.round(),
                    ),
                  ),
                ),
                _CalibrationSlider(
                  key: const ValueKey('dust-emission-rate-slider'),
                  label: 'EMISSION RATE',
                  value: _parameters.emissionRate,
                  min: 1,
                  max: 16,
                  divisions: 30,
                  onChanged: (value) => setState(
                    () =>
                        _parameters = _parameters.copyWith(emissionRate: value),
                  ),
                ),
                AppSpacing.gapMD,
                _SandboxActionButton(
                  key: const ValueKey('apply-dust-to-lab'),
                  text: 'APPLY TO LAB',
                  icon: Icons.check_circle_outline,
                  onPressed: _apply,
                ),
                AppSpacing.gapSM,
                _SandboxActionButton(
                  key: const ValueKey('reset-dust-to-default'),
                  text: 'RESET TO DEFAULT',
                  icon: Icons.restart_alt,
                  onPressed: _reset,
                ),
              ],
            ),
          ),
          AppSpacing.gapXL,
          _EffectParametersOutput(
            json: json,
            jsonKey: 'dust-parameters-json',
            copyKey: 'copy-dust-parameters',
          ),
          AppSpacing.gapLG,
        ],
      ),
    );
  }
}

class _DustOverlay extends StatelessWidget {
  const _DustOverlay({
    required this.parameters,
    required this.progress,
    required this.visible,
  });

  final _DustParameters parameters;
  final double progress;
  final bool visible;

  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    children: [
      if (visible)
        Positioned.fill(
          child: CustomPaint(
            key: const ValueKey('dust-effect-preview'),
            painter: _DustCloudPainter(
              parameters: parameters,
              elapsedMs: progress * 2000,
            ),
          ),
        ),
      _EffectAnchor(
        keyName: 'dust-emitter-anchor',
        position: parameters.emitter,
      ),
    ],
  );
}

class _DustCloudPainter extends CustomPainter {
  const _DustCloudPainter({
    required this.parameters,
    required this.elapsedMs,
    this.emissionEndMs,
  });

  final _DustParameters parameters;
  final double elapsedMs;
  final double? emissionEndMs;

  @override
  void paint(Canvas canvas, Size size) {
    final effectiveElapsed = emissionEndMs == null
        ? elapsedMs
        : math.min(elapsedMs, emissionEndMs!);
    final tailOpacity = emissionEndMs == null || elapsedMs <= emissionEndMs!
        ? 1.0
        : (1 - ((elapsedMs - emissionEndMs!) / parameters.lifetimeMs)).clamp(
            0.0,
            1.0,
          );
    final radians = parameters.direction * math.pi / 180;
    final direction = Offset(math.cos(radians), math.sin(radians));
    final origin = Offset(
      parameters.emitter.dx * size.width,
      parameters.emitter.dy * size.height,
    );
    final cloudCount = parameters.emissionRate.round().clamp(3, 16);
    for (var index = 0; index < cloudCount; index++) {
      final phase =
          ((effectiveElapsed / parameters.lifetimeMs) + (index / cloudCount)) %
          1;
      final cross = math.sin((index + 1) * 2.17) * parameters.spread;
      final normal = Offset(-direction.dy, direction.dx);
      final center =
          origin +
          (direction * (phase * size.width * 0.48)) +
          (normal * (cross * phase * size.height * 0.42));
      final radius = parameters.size * size.width * (0.45 + phase);
      final alpha = parameters.opacity * (1 - phase) * 0.52 * tailOpacity;
      final path = Path()
        ..moveTo(center.dx - (radius * 1.4), center.dy)
        ..cubicTo(
          center.dx - radius,
          center.dy - (radius * 0.72),
          center.dx + (radius * 0.30),
          center.dy - (radius * 0.55),
          center.dx + (radius * 1.35),
          center.dy - (radius * 0.06),
        )
        ..cubicTo(
          center.dx + (radius * 0.92),
          center.dy + (radius * 0.70),
          center.dx - (radius * 0.62),
          center.dy + (radius * 0.62),
          center.dx - (radius * 1.4),
          center.dy,
        )
        ..close();
      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFF9A866C).withValues(alpha: alpha)
          ..maskFilter = MaskFilter.blur(
            BlurStyle.normal,
            2 + (parameters.spread * 7),
          ),
      );
    }
  }

  @override
  bool shouldRepaint(_DustCloudPainter oldDelegate) =>
      parameters != oldDelegate.parameters ||
      elapsedMs != oldDelegate.elapsedMs ||
      emissionEndMs != oldDelegate.emissionEndMs;
}

double _suspensionYOffset(_SuspensionParameters parameters, double progress) {
  final total = parameters.impulseDurationMs + parameters.settleDurationMs;
  if (total <= 0 || progress <= 0 || progress >= 1) return 0;
  final impulseFraction = parameters.impulseDurationMs / total;
  final response = progress <= impulseFraction
      ? math.sin((progress / impulseFraction) * math.pi / 2)
      : math.cos(
          ((progress - impulseFraction) / (1 - impulseFraction)) * math.pi / 2,
        );
  return response * parameters.bodyYResponse * parameters.impulseStrength * 100;
}

class _SuspensionTestPage extends StatefulWidget {
  const _SuspensionTestPage({required this.session});

  final _EffectLabSession session;

  @override
  State<_SuspensionTestPage> createState() => _SuspensionTestPageState();
}

class _SuspensionTestPageState extends State<_SuspensionTestPage>
    with TickerProviderStateMixin {
  late _SuspensionParameters _parameters;
  final _pointController = TextEditingController();
  final _firedPoints = <int>{};

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _duration,
  );
  late final AnimationController _timelineController = AnimationController(
    vsync: this,
    duration: _scene1TravelDuration,
  )..addListener(_evaluateTimeline);

  @override
  void initState() {
    super.initState();
    _parameters =
        widget.session.suspension ?? _SuspensionParameters.currentApproved;
  }

  Duration get _duration => Duration(
    milliseconds: _parameters.impulseDurationMs + _parameters.settleDurationMs,
  );

  @override
  void dispose() {
    _pointController.dispose();
    _timelineController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _evaluateTimeline() {
    final elapsed =
        (_timelineController.value * _scene1TravelDuration.inMilliseconds)
            .round();
    for (final timeMs in _parameters.impulseTimeline) {
      if (timeMs <= elapsed && _firedPoints.add(timeMs)) _trigger();
    }
  }

  void _trigger() {
    _controller.duration = _duration;
    _controller.forward(from: 0);
  }

  void _playTimeline() {
    if (_timelineController.isCompleted) {
      _timelineController.value = 0;
      _firedPoints.clear();
      _controller.value = 0;
    }
    _timelineController.forward();
    if (_controller.value > 0 && !_controller.isCompleted) {
      _controller.forward();
    }
    setState(() {});
  }

  void _pauseTimeline() {
    _timelineController.stop(canceled: false);
    _controller.stop(canceled: false);
    setState(() {});
  }

  void _stopTimeline() {
    _timelineController.stop(canceled: false);
    _controller.stop(canceled: false);
    _timelineController.value = 0;
    _controller.value = 0;
    _firedPoints.clear();
    setState(() {});
  }

  void _replayTimeline() {
    _firedPoints.clear();
    _controller.value = 0;
    _timelineController.forward(from: 0);
    setState(() {});
  }

  void _addImpulsePoint() {
    final timeMs = int.tryParse(_pointController.text.trim());
    if (timeMs == null ||
        timeMs < 0 ||
        timeMs > _scene1TravelDuration.inMilliseconds) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('0〜6000msで入力してください')));
      return;
    }
    if (_parameters.impulseTimeline.contains(timeMs)) return;
    final timeline = [..._parameters.impulseTimeline, timeMs]..sort();
    _stopTimeline();
    setState(() {
      _parameters = _parameters.copyWith(
        impulseTimeline: List.unmodifiable(timeline),
      );
      _pointController.clear();
    });
  }

  void _updateImpulsePoint(int index, int updated) {
    final current = _parameters.impulseTimeline[index];
    if (current != updated && _parameters.impulseTimeline.contains(updated)) {
      return;
    }
    final timeline = [..._parameters.impulseTimeline];
    timeline[index] = updated;
    timeline.sort();
    _stopTimeline();
    setState(() {
      _parameters = _parameters.copyWith(
        impulseTimeline: List.unmodifiable(timeline),
      );
    });
  }

  void _removeImpulsePoint(int timeMs) {
    final timeline = [..._parameters.impulseTimeline]..remove(timeMs);
    _stopTimeline();
    setState(() {
      _parameters = _parameters.copyWith(
        impulseTimeline: List.unmodifiable(timeline),
      );
    });
  }

  Future<void> _apply() async {
    await widget.session.saveSuspension(_parameters);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('SUSPENSIONをLABへ適用しました')));
  }

  Future<void> _reset() async {
    const value = _SuspensionParameters.factoryDefault;
    setState(() => _parameters = value);
    await widget.session.saveSuspension(value);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('SUSPENSIONをFactory Defaultへ戻しました')),
      );
  }

  @override
  Widget build(BuildContext context) {
    final json = _effectJson(_parameters.toJson());
    return Scaffold(
      appBar: AppBar(title: const Text('SUSPENSION TEST')),
      body: ListView(
        padding: AppSpacing.cardPadding,
        children: [
          const SectionHeader(icon: Icons.swap_vert, title: 'PREVIEW'),
          AppSpacing.gapSM,
          OperationCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) => _EffectJeepCanvas(
                    canvasKey: 'suspension-test-canvas',
                    assemblyOffset: Offset(
                      0,
                      _suspensionYOffset(_parameters, _controller.value),
                    ),
                    overlay: const SizedBox.expand(),
                  ),
                ),
                AppSpacing.gapMD,
                _CompactActionButton(
                  key: const ValueKey('suspension-trigger-impulse'),
                  label: 'TRIGGER IMPULSE',
                  icon: Icons.vertical_align_center,
                  onPressed: _trigger,
                ),
                AppSpacing.gapSM,
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    _CompactActionButton(
                      key: const ValueKey('suspension-timeline-play'),
                      label: 'TEST PLAY',
                      icon: Icons.play_arrow,
                      onPressed: _timelineController.isAnimating
                          ? null
                          : _playTimeline,
                    ),
                    _CompactActionButton(
                      key: const ValueKey('suspension-timeline-pause'),
                      label: 'PAUSE',
                      icon: Icons.pause,
                      onPressed: _timelineController.isAnimating
                          ? _pauseTimeline
                          : null,
                    ),
                    _CompactActionButton(
                      key: const ValueKey('suspension-timeline-stop'),
                      label: 'STOP',
                      icon: Icons.stop,
                      onPressed: _stopTimeline,
                    ),
                    _CompactActionButton(
                      key: const ValueKey('suspension-timeline-replay'),
                      label: 'REPLAY',
                      icon: Icons.replay,
                      onPressed: _replayTimeline,
                    ),
                  ],
                ),
              ],
            ),
          ),
          AppSpacing.gapXL,
          const SectionHeader(
            icon: Icons.view_timeline_outlined,
            title: 'IMPULSE TIMELINE',
          ),
          AppSpacing.gapSM,
          OperationCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  key: const ValueKey('suspension-new-point-time'),
                  controller: _pointController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'TIME MS (0–6000)',
                  ),
                ),
                AppSpacing.gapSM,
                _SandboxActionButton(
                  key: const ValueKey('suspension-add-point'),
                  text: 'ADD IMPULSE POINT',
                  icon: Icons.add,
                  onPressed: _addImpulsePoint,
                ),
                if (_parameters.impulseTimeline.isEmpty) ...[
                  AppSpacing.gapMD,
                  const Text('NO IMPULSE POINTS'),
                ],
                for (
                  var index = 0;
                  index < _parameters.impulseTimeline.length;
                  index++
                ) ...[
                  Builder(
                    builder: (context) {
                      final timeMs = _parameters.impulseTimeline[index];
                      return Column(
                        children: [
                          AppSpacing.gapMD,
                          Row(
                            children: [
                              Expanded(child: Text('$timeMs ms')),
                              IconButton(
                                key: ValueKey(
                                  'suspension-remove-point-$timeMs',
                                ),
                                tooltip: 'REMOVE',
                                onPressed: () => _removeImpulsePoint(timeMs),
                                icon: const Icon(Icons.delete_outline),
                              ),
                            ],
                          ),
                          Slider(
                            key: ValueKey('suspension-point-slider-$index'),
                            value: timeMs.toDouble(),
                            min: 0,
                            max: _scene1TravelDuration.inMilliseconds
                                .toDouble(),
                            divisions: 60,
                            label: '$timeMs ms',
                            onChanged: (value) =>
                                _updateImpulsePoint(index, value.round()),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
          AppSpacing.gapXL,
          const SectionHeader(icon: Icons.tune_outlined, title: 'PARAMETERS'),
          AppSpacing.gapSM,
          OperationCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _CalibrationSlider(
                  key: const ValueKey('suspension-body-y-response-slider'),
                  label: 'BODY Y RESPONSE',
                  value: _parameters.bodyYResponse,
                  min: 0.01,
                  max: 0.25,
                  divisions: 48,
                  onChanged: (value) => setState(
                    () => _parameters = _parameters.copyWith(
                      bodyYResponse: value,
                    ),
                  ),
                ),
                _CalibrationSlider(
                  key: const ValueKey('suspension-impulse-strength-slider'),
                  label: 'IMPULSE STRENGTH',
                  value: _parameters.impulseStrength,
                  min: 0.05,
                  max: 1,
                  divisions: 38,
                  onChanged: (value) => setState(
                    () => _parameters = _parameters.copyWith(
                      impulseStrength: value,
                    ),
                  ),
                ),
                _CalibrationSlider(
                  key: const ValueKey('suspension-impulse-duration-slider'),
                  label: 'IMPULSE DURATION',
                  value: _parameters.impulseDurationMs.toDouble(),
                  min: 50,
                  max: 600,
                  divisions: 55,
                  unit: 'ms',
                  onChanged: (value) => setState(
                    () => _parameters = _parameters.copyWith(
                      impulseDurationMs: value.round(),
                    ),
                  ),
                ),
                _CalibrationSlider(
                  key: const ValueKey('suspension-settle-duration-slider'),
                  label: 'SETTLE DURATION',
                  value: _parameters.settleDurationMs.toDouble(),
                  min: 100,
                  max: 2000,
                  divisions: 38,
                  unit: 'ms',
                  onChanged: (value) => setState(
                    () => _parameters = _parameters.copyWith(
                      settleDurationMs: value.round(),
                    ),
                  ),
                ),
                AppSpacing.gapMD,
                _SandboxActionButton(
                  key: const ValueKey('apply-suspension-to-lab'),
                  text: 'APPLY TO LAB',
                  icon: Icons.check_circle_outline,
                  onPressed: _apply,
                ),
                AppSpacing.gapSM,
                _SandboxActionButton(
                  key: const ValueKey('reset-suspension-to-default'),
                  text: 'RESET TO DEFAULT',
                  icon: Icons.restart_alt,
                  onPressed: _reset,
                ),
              ],
            ),
          ),
          AppSpacing.gapXL,
          _EffectParametersOutput(
            json: json,
            jsonKey: 'suspension-parameters-json',
            copyKey: 'copy-suspension-parameters',
          ),
          AppSpacing.gapLG,
        ],
      ),
    );
  }
}

Map<String, Object?> _scene1AssemblyParameters() => {
  'calibrationType': 'boot_sequence_assembly',
  'prototype': 'scene_1_prototype',
  'coordinateSystem': 'jeep_local_normalized',
  'jeepBody': {'asset': _bootSequenceAssets[1].path},
  'frontWheelFar': {
    'asset': _bootSequenceAssets[2].path,
    'localX': _scene1FrontWheelFar.localX,
    'localY': _scene1FrontWheelFar.localY,
    'scale': _scene1FrontWheelFar.scale,
  },
  'rearWheel': {
    'asset': _bootSequenceAssets[2].path,
    'localX': _scene1RearWheel.localX,
    'localY': _scene1RearWheel.localY,
    'scale': _scene1RearWheel.scale,
  },
  'frontWheelNear': {
    'asset': _bootSequenceAssets[2].path,
    'localX': _scene1FrontWheelNear.localX,
    'localY': _scene1FrontWheelNear.localY,
    'scale': _scene1FrontWheelNear.scale,
  },
  'layerOrder': ['frontWheelFar', 'jeepBody', 'rearWheel', 'frontWheelNear'],
};

Map<String, Object?> _scene1MotionParameters() => {
  'calibrationType': 'boot_sequence_motion',
  'prototype': 'scene_1_prototype',
  'coordinateSystem': 'alignment_normalized',
  'background': {'asset': _bootSequenceAssets[0].path},
  'jeepAssembly': {
    'start': {
      'x': _scene1Start.alignment.x,
      'y': _scene1Start.alignment.y,
      'scale': _scene1Start.scale,
    },
    'end': {
      'x': _scene1End.alignment.x,
      'y': _scene1End.alignment.y,
      'scale': _scene1End.scale,
    },
  },
  'motion': {
    'travelDurationMs': _scene1TravelDuration.inMilliseconds,
    'holdDurationMs': _scene1HoldDuration.inMilliseconds,
    'curve': 'linear',
  },
};

class _CompositeTestPage extends StatefulWidget {
  const _CompositeTestPage({required this.session});

  final _EffectLabSession session;

  @override
  State<_CompositeTestPage> createState() => _CompositeTestPageState();
}

class _CompositeTestPageState extends State<_CompositeTestPage>
    with TickerProviderStateMixin {
  bool _headlightEnabled = true;
  bool _dustEnabled = true;
  bool _suspensionEnabled = true;
  final _firedImpulsePoints = <int>{};

  late final AnimationController _motionController = AnimationController(
    vsync: this,
    duration: _scene1TotalDuration,
  )..addListener(_evaluateSuspensionTimeline);
  late final AnimationController _suspensionController = AnimationController(
    vsync: this,
    duration: _compositeSuspensionDuration,
  );

  Duration get _compositeSuspensionDuration {
    final parameters = widget.session.suspension;
    if (parameters == null) return const Duration(milliseconds: 1);
    return Duration(
      milliseconds: parameters.impulseDurationMs + parameters.settleDurationMs,
    );
  }

  @override
  void dispose() {
    _motionController.dispose();
    _suspensionController.dispose();
    super.dispose();
  }

  void _play() {
    if (_motionController.isCompleted) {
      _motionController.value = 0;
      _firedImpulsePoints.clear();
    }
    _motionController.forward();
    if (_suspensionController.value > 0 && !_suspensionController.isCompleted) {
      _suspensionController.forward();
    }
    setState(() {});
  }

  void _pause() {
    _motionController.stop(canceled: false);
    _suspensionController.stop(canceled: false);
    setState(() {});
  }

  void _stop() {
    _motionController.stop(canceled: false);
    _suspensionController.stop(canceled: false);
    _motionController.value = 0;
    _suspensionController.value = 0;
    _firedImpulsePoints.clear();
    setState(() {});
  }

  void _replay() {
    _suspensionController.value = 0;
    _firedImpulsePoints.clear();
    _motionController.forward(from: 0);
    setState(() {});
  }

  void _evaluateSuspensionTimeline() {
    final parameters = widget.session.suspension;
    if (parameters == null || !_suspensionEnabled) return;
    final elapsed =
        (_motionController.value * _scene1TotalDuration.inMilliseconds)
            .round()
            .clamp(0, _scene1TravelDuration.inMilliseconds);
    for (final timeMs in parameters.impulseTimeline) {
      if (timeMs <= elapsed && _firedImpulsePoints.add(timeMs)) {
        _triggerSuspension();
      }
    }
  }

  void _triggerSuspension() {
    if (widget.session.suspension == null || !_suspensionEnabled) return;
    _suspensionController.duration = _compositeSuspensionDuration;
    _suspensionController.forward(from: 0);
  }

  Map<String, Object?> get _parameters => {
    'calibrationType': 'boot_sequence_composite',
    'prototype': 'scene_1_prototype',
    'assembly': _scene1AssemblyParameters(),
    'motion': _scene1MotionParameters(),
    'effects': {
      'headlight': widget.session.headlight?.toJson(),
      'dust': widget.session.dust?.toJson(),
      'suspension': widget.session.suspension?.toJson(),
    },
  };

  @override
  Widget build(BuildContext context) {
    final json = _effectJson(_parameters);
    return Scaffold(
      appBar: AppBar(title: const Text('COMPOSITE TEST')),
      body: ListView(
        padding: AppSpacing.cardPadding,
        children: [
          const SectionHeader(icon: Icons.layers_outlined, title: 'PREVIEW'),
          AppSpacing.gapSM,
          OperationCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AnimatedBuilder(
                  animation: Listenable.merge([
                    _motionController,
                    _suspensionController,
                  ]),
                  builder: (context, _) => _CompositeEffectPreview(
                    progress: _motionController.value,
                    suspensionProgress: _suspensionController.value,
                    headlight: _headlightEnabled
                        ? widget.session.headlight
                        : null,
                    dust: _dustEnabled ? widget.session.dust : null,
                    suspension: _suspensionEnabled
                        ? widget.session.suspension
                        : null,
                  ),
                ),
                AppSpacing.gapMD,
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    _CompactActionButton(
                      key: const ValueKey('composite-test-play'),
                      label: 'TEST PLAY',
                      icon: Icons.play_arrow,
                      onPressed: _motionController.isAnimating ? null : _play,
                    ),
                    _CompactActionButton(
                      key: const ValueKey('composite-pause'),
                      label: 'PAUSE',
                      icon: Icons.pause,
                      onPressed: _motionController.isAnimating ? _pause : null,
                    ),
                    _CompactActionButton(
                      key: const ValueKey('composite-stop'),
                      label: 'STOP',
                      icon: Icons.stop,
                      onPressed: _stop,
                    ),
                    _CompactActionButton(
                      key: const ValueKey('composite-replay'),
                      label: 'REPLAY',
                      icon: Icons.replay,
                      onPressed: _replay,
                    ),
                    _CompactActionButton(
                      key: const ValueKey('composite-trigger-impulse'),
                      label: 'TRIGGER IMPULSE',
                      icon: Icons.vertical_align_center,
                      onPressed:
                          widget.session.suspension != null &&
                              _suspensionEnabled
                          ? _triggerSuspension
                          : null,
                    ),
                  ],
                ),
              ],
            ),
          ),
          AppSpacing.gapXL,
          const SectionHeader(icon: Icons.tune_outlined, title: 'EFFECTS'),
          AppSpacing.gapSM,
          OperationCard(
            child: Column(
              children: [
                _CompositeEffectToggle(
                  key: const ValueKey('composite-headlight-toggle'),
                  label: 'HEADLIGHT',
                  applied: widget.session.headlight != null,
                  value: _headlightEnabled,
                  onChanged: (value) =>
                      setState(() => _headlightEnabled = value),
                ),
                _CompositeEffectToggle(
                  key: const ValueKey('composite-dust-toggle'),
                  label: 'DUST',
                  applied: widget.session.dust != null,
                  value: _dustEnabled,
                  onChanged: (value) => setState(() => _dustEnabled = value),
                ),
                _CompositeEffectToggle(
                  key: const ValueKey('composite-suspension-toggle'),
                  label: 'SUSPENSION',
                  applied: widget.session.suspension != null,
                  value: _suspensionEnabled,
                  onChanged: (value) =>
                      setState(() => _suspensionEnabled = value),
                ),
              ],
            ),
          ),
          AppSpacing.gapXL,
          _EffectParametersOutput(
            json: json,
            jsonKey: 'composite-parameters-json',
            copyKey: 'copy-composite-parameters',
          ),
          AppSpacing.gapLG,
        ],
      ),
    );
  }
}

class _CompositeEffectToggle extends StatelessWidget {
  const _CompositeEffectToggle({
    super.key,
    required this.label,
    required this.applied,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool applied;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => SwitchListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(label),
    subtitle: Text(applied ? 'APPLIED TO LAB' : 'NOT APPLIED'),
    value: value,
    onChanged: onChanged,
  );
}

class _CompositeEffectPreview extends StatelessWidget {
  const _CompositeEffectPreview({
    required this.progress,
    required this.suspensionProgress,
    required this.headlight,
    required this.dust,
    required this.suspension,
  });

  final double progress;
  final double suspensionProgress;
  final _HeadlightParameters? headlight;
  final _DustParameters? dust;
  final _SuspensionParameters? suspension;

  @override
  Widget build(BuildContext context) {
    final travelFraction =
        _scene1TravelDuration.inMilliseconds /
        _scene1TotalDuration.inMilliseconds;
    final motionProgress = (progress / travelFraction).clamp(0.0, 1.0);
    final alignment = Alignment.lerp(
      _scene1Start.alignment,
      _scene1End.alignment,
      motionProgress,
    )!;
    final scale =
        _scene1Start.scale +
        ((_scene1End.scale - _scene1Start.scale) * motionProgress);
    final suspensionY = suspension == null
        ? 0.0
        : _suspensionYOffset(suspension!, suspensionProgress);
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          key: const ValueKey('composite-canvas'),
          fit: StackFit.expand,
          children: [
            Image.asset(_bootSequenceAssets[0].path, fit: BoxFit.cover),
            LayoutBuilder(
              builder: (context, constraints) {
                final assemblyWidth = (constraints.maxWidth * 0.38)
                    .clamp(120.0, 320.0)
                    .toDouble();
                final assemblyHeight = assemblyWidth * (941 / 1672);
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    Positioned(
                      key: const ValueKey('composite-jeep-position'),
                      left:
                          (((alignment.x + 1) / 2) * constraints.maxWidth) -
                          (assemblyWidth / 2),
                      top:
                          (((alignment.y + 1) / 2) * constraints.maxHeight) -
                          (assemblyHeight / 2),
                      width: assemblyWidth,
                      height: assemblyHeight,
                      child: Transform.translate(
                        key: const ValueKey('composite-suspension-offset'),
                        offset: Offset(0, suspensionY),
                        child: Transform.scale(
                          key: const ValueKey('composite-jeep-scale'),
                          scale: scale,
                          child: _CompositeJeepAssembly(
                            width: assemblyWidth,
                            bodyAsset: _bootSequenceAssets[1].path,
                            wheelAsset: _bootSequenceAssets[2].path,
                            headlight: headlight,
                            dust: dust,
                            dustProgress: progress,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _CompositeJeepAssembly extends StatelessWidget {
  const _CompositeJeepAssembly({
    required this.width,
    required this.bodyAsset,
    required this.wheelAsset,
    required this.headlight,
    required this.dust,
    required this.dustProgress,
  });

  final double width;
  final String bodyAsset;
  final String wheelAsset;
  final _HeadlightParameters? headlight;
  final _DustParameters? dust;
  final double dustProgress;

  @override
  Widget build(BuildContext context) {
    final height = width * (941 / 1672);
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (dust != null && dustProgress > 0)
            Positioned.fill(
              child: CustomPaint(
                key: const ValueKey('composite-dust-effect'),
                painter: _DustCloudPainter(
                  parameters: dust!,
                  elapsedMs: dustProgress * _scene1TotalDuration.inMilliseconds,
                  emissionEndMs: _scene1TravelDuration.inMilliseconds
                      .toDouble(),
                ),
              ),
            ),
          _JeepAssembly(
            width: width,
            bodyAsset: bodyAsset,
            wheelAsset: wheelAsset,
          ),
          if (headlight != null)
            Positioned.fill(
              child: _HeadlightGlow(
                key: const ValueKey('composite-headlight-effect'),
                keyPrefix: 'composite',
                parameters: headlight!,
              ),
            ),
        ],
      ),
    );
  }
}

class _CompactActionButton extends StatelessWidget {
  const _CompactActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: onPressed,
    icon: Icon(icon),
    label: Text(label),
  );
}

class _CalibrationSession {
  _WheelCalibration frontWheelFar = _scene1FrontWheelFar;
  _WheelCalibration rearWheel = _scene1RearWheel;
  _WheelCalibration frontWheelNear = _scene1FrontWheelNear;
}

class _WheelCalibration {
  const _WheelCalibration({
    required this.localX,
    required this.localY,
    required this.scale,
  });

  final double localX;
  final double localY;
  final double scale;

  _WheelCalibration copyWith({double? localX, double? localY, double? scale}) =>
      _WheelCalibration(
        localX: localX ?? this.localX,
        localY: localY ?? this.localY,
        scale: scale ?? this.scale,
      );
}

class _AssemblyCalibrationPage extends StatefulWidget {
  const _AssemblyCalibrationPage({required this.session});

  final _CalibrationSession session;

  @override
  State<_AssemblyCalibrationPage> createState() =>
      _AssemblyCalibrationPageState();
}

class _AssemblyCalibrationPageState extends State<_AssemblyCalibrationPage> {
  _CalibrationTarget _selectedTarget = _CalibrationTarget.frontWheelFar;

  _WheelCalibration get _selectedWheel => switch (_selectedTarget) {
    _CalibrationTarget.frontWheelFar => widget.session.frontWheelFar,
    _CalibrationTarget.rearWheel => widget.session.rearWheel,
    _CalibrationTarget.frontWheelNear => widget.session.frontWheelNear,
    _CalibrationTarget.jeepAssembly => throw StateError('Invalid target'),
  };

  void _updateSelected({double? localX, double? localY, double? scale}) {
    setState(() {
      final updated = _selectedWheel.copyWith(
        localX: localX,
        localY: localY,
        scale: scale,
      );
      switch (_selectedTarget) {
        case _CalibrationTarget.frontWheelFar:
          widget.session.frontWheelFar = updated;
        case _CalibrationTarget.rearWheel:
          widget.session.rearWheel = updated;
        case _CalibrationTarget.frontWheelNear:
          widget.session.frontWheelNear = updated;
        case _CalibrationTarget.jeepAssembly:
          throw StateError('Invalid target');
      }
    });
  }

  void _moveSelected(Offset delta, Size assemblySize) {
    final current = _selectedWheel;
    _updateSelected(
      localX: current.localX + (delta.dx / assemblySize.width),
      localY: current.localY + (delta.dy / assemblySize.height),
    );
  }

  Map<String, Object?> get _parameters => {
    'calibrationType': 'boot_sequence_assembly',
    'prototype': 'scene_1_prototype',
    'coordinateSystem': 'jeep_local_normalized',
    'jeepBody': {'asset': _bootSequenceAssets[1].path},
    'frontWheelFar': _wheelJson(widget.session.frontWheelFar),
    'rearWheel': _wheelJson(widget.session.rearWheel),
    'frontWheelNear': _wheelJson(widget.session.frontWheelNear),
    'layerOrder': ['frontWheelFar', 'jeepBody', 'rearWheel', 'frontWheelNear'],
  };

  Map<String, Object?> _wheelJson(_WheelCalibration value) => {
    'asset': _bootSequenceAssets[2].path,
    'localX': _rounded(value.localX),
    'localY': _rounded(value.localY),
    'scale': _rounded(value.scale),
  };

  double _rounded(double value) => double.parse(value.toStringAsFixed(3));

  String get _parametersJson =>
      const JsonEncoder.withIndent('  ').convert(_parameters);

  Future<void> _copyParameters() async {
    await Clipboard.setData(ClipboardData(text: _parametersJson));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('ASSEMBLY PARAMETERSをコピーしました')),
      );
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selectedWheel;
    return Scaffold(
      appBar: AppBar(title: const Text('ASSEMBLY CALIBRATION')),
      body: ListView(
        padding: AppSpacing.cardPadding,
        children: [
          const SectionHeader(
            icon: Icons.grid_4x4_outlined,
            title: 'ASSEMBLY CANVAS',
          ),
          AppSpacing.gapSM,
          OperationCard(
            child: _AssemblyCalibrationCanvas(
              session: widget.session,
              selectedTarget: _selectedTarget,
              onMove: _moveSelected,
            ),
          ),
          AppSpacing.gapXL,
          const SectionHeader(icon: Icons.ads_click_outlined, title: 'TARGET'),
          AppSpacing.gapSM,
          OperationCard(
            child: Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final target in const [
                  _CalibrationTarget.frontWheelFar,
                  _CalibrationTarget.rearWheel,
                  _CalibrationTarget.frontWheelNear,
                ])
                  ChoiceChip(
                    key: ValueKey('assembly-target-${target.name}'),
                    label: Text(_targetLabel(target)),
                    selected: _selectedTarget == target,
                    onSelected: (_) => setState(() => _selectedTarget = target),
                  ),
              ],
            ),
          ),
          AppSpacing.gapXL,
          const SectionHeader(icon: Icons.tune_outlined, title: 'PARAMETERS'),
          AppSpacing.gapSM,
          OperationCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _LiveValues(
                  xLabel: 'LOCAL X',
                  x: selected.localX,
                  yLabel: 'LOCAL Y',
                  y: selected.localY,
                  scale: selected.scale,
                ),
                _CalibrationSlider(
                  key: const ValueKey('assembly-wheel-scale-slider'),
                  label: 'SCALE',
                  value: selected.scale,
                  min: 0.05,
                  max: 0.5,
                  divisions: 90,
                  onChanged: (value) => _updateSelected(scale: value),
                ),
              ],
            ),
          ),
          AppSpacing.gapXL,
          const SectionHeader(
            icon: Icons.layers_outlined,
            title: 'LAYER ORDER',
          ),
          AppSpacing.gapSM,
          const OperationCard(
            child: Text(
              'FRONT WHEEL FAR\n↓\nJEEP BODY\n↓\nREAR WHEEL\n↓\nFRONT WHEEL NEAR',
              key: ValueKey('assembly-layer-order'),
            ),
          ),
          AppSpacing.gapXL,
          const SectionHeader(
            icon: Icons.data_object,
            title: 'CODEX PARAMETERS',
          ),
          AppSpacing.gapSM,
          OperationCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SelectableText(
                  _parametersJson,
                  key: const ValueKey('assembly-parameters-json'),
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
                ),
                AppSpacing.gapMD,
                _SandboxActionButton(
                  key: const ValueKey('copy-assembly-parameters'),
                  text: 'COPY PARAMETERS',
                  icon: Icons.copy_outlined,
                  onPressed: _copyParameters,
                ),
              ],
            ),
          ),
          AppSpacing.gapLG,
        ],
      ),
    );
  }

  String _targetLabel(_CalibrationTarget target) => switch (target) {
    _CalibrationTarget.frontWheelFar => 'FRONT WHEEL FAR',
    _CalibrationTarget.rearWheel => 'REAR WHEEL',
    _CalibrationTarget.frontWheelNear => 'FRONT WHEEL NEAR',
    _CalibrationTarget.jeepAssembly => 'JEEP ASSEMBLY',
  };
}

class _AssemblyCalibrationCanvas extends StatelessWidget {
  const _AssemblyCalibrationCanvas({
    required this.session,
    required this.selectedTarget,
    required this.onMove,
  });

  final _CalibrationSession session;
  final _CalibrationTarget selectedTarget;
  final void Function(Offset delta, Size assemblySize) onMove;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 800),
      child: AspectRatio(
        aspectRatio: 3 / 2,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final assemblyWidth = (constraints.maxWidth * 0.78)
                  .clamp(180.0, 560.0)
                  .toDouble();
              final assemblyHeight = assemblyWidth * (941 / 1672);
              final selected = switch (selectedTarget) {
                _CalibrationTarget.frontWheelFar => session.frontWheelFar,
                _CalibrationTarget.rearWheel => session.rearWheel,
                _CalibrationTarget.frontWheelNear => session.frontWheelNear,
                _CalibrationTarget.jeepAssembly => throw StateError(
                  'Invalid target',
                ),
              };
              return Listener(
                key: const ValueKey('assembly-canvas-drag-target'),
                behavior: HitTestBehavior.opaque,
                onPointerMove: (event) =>
                    onMove(event.delta, Size(assemblyWidth, assemblyHeight)),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ColoredBox(
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                    ),
                    CustomPaint(
                      key: const ValueKey('assembly-calibration-grid'),
                      painter: _CalibrationGridPainter(
                        color: Theme.of(
                          context,
                        ).colorScheme.outline.withValues(alpha: 0.35),
                      ),
                    ),
                    const Positioned(
                      left: 0,
                      right: 0,
                      top: 0,
                      bottom: 0,
                      child: _CalibrationCenterOverlay(prefix: 'assembly'),
                    ),
                    Center(
                      child: _CalibrationJeepAssembly(
                        width: assemblyWidth,
                        selectedTarget: selectedTarget,
                        frontWheelFar: session.frontWheelFar,
                        rearWheel: session.rearWheel,
                        frontWheelNear: session.frontWheelNear,
                      ),
                    ),
                    Positioned(
                      right: 8,
                      top: 8,
                      child: _CalibrationValueBadge(
                        x: selected.localX,
                        y: selected.localY,
                        scale: selected.scale,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    ),
  );
}

class _MotionCalibrationPage extends StatefulWidget {
  const _MotionCalibrationPage({required this.session});

  final _CalibrationSession session;

  @override
  State<_MotionCalibrationPage> createState() => _MotionCalibrationPageState();
}

enum _CalibrationTarget {
  jeepAssembly,
  frontWheelFar,
  rearWheel,
  frontWheelNear,
}

enum _CalibrationCurveOption {
  linear('LINEAR', 'linear', Curves.linear),
  easeIn('EASE IN', 'easeInCubic', Curves.easeInCubic),
  easeOut('EASE OUT', 'easeOutCubic', Curves.easeOutCubic),
  easeInOut('EASE IN/OUT', 'easeInOutCubic', Curves.easeInOutCubic);

  const _CalibrationCurveOption(this.label, this.parameterName, this.curve);

  final String label;
  final String parameterName;
  final Curve curve;
}

class _CalibrationSnapshot {
  const _CalibrationSnapshot({required this.alignment, required this.scale});

  final Alignment alignment;
  final double scale;
}

const _scene2CameraMinScale = 0.1;
const _scene2CameraMaxScale = 5.0;
const _scene2CameraTransformOrigin = Alignment.center;

Matrix4 _scene2CameraTransform(Size canvasSize, _CalibrationSnapshot view) {
  final matrix = Matrix4.identity();
  matrix.setEntry(0, 0, view.scale);
  matrix.setEntry(1, 1, view.scale);
  matrix.setEntry(0, 3, view.alignment.x * canvasSize.width / 2);
  matrix.setEntry(1, 3, view.alignment.y * canvasSize.height / 2);
  return matrix;
}

class _MotionCalibrationPageState extends State<_MotionCalibrationPage>
    with SingleTickerProviderStateMixin {
  static const _initialStart = _scene1Start;
  static const _initialEnd = _scene1End;

  Alignment _jeepAlignment = _initialStart.alignment;
  double _jeepScale = _initialStart.scale;
  _CalibrationSnapshot _start = _initialStart;
  _CalibrationSnapshot _end = _initialEnd;
  double _travelDurationSeconds = _scene1TravelDuration.inMilliseconds / 1000;
  double _holdDurationSeconds = _scene1HoldDuration.inMilliseconds / 1000;
  _CalibrationCurveOption _curve = _CalibrationCurveOption.linear;

  late final AnimationController _motionController = AnimationController(
    vsync: this,
    duration: _motionDuration,
  );

  Duration get _motionDuration => Duration(
    milliseconds: ((_travelDurationSeconds + _holdDurationSeconds) * 1000)
        .round(),
  );

  @override
  void dispose() {
    _motionController.dispose();
    super.dispose();
  }

  Alignment get _displayAlignment {
    if (_motionController.value == 0) return _jeepAlignment;
    return Alignment.lerp(_start.alignment, _end.alignment, _travelProgress)!;
  }

  double get _displayScale {
    if (_motionController.value == 0) return _jeepScale;
    return _start.scale + ((_end.scale - _start.scale) * _travelProgress);
  }

  double get _travelProgress {
    final total = _travelDurationSeconds + _holdDurationSeconds;
    final travelFraction = total == 0 ? 1.0 : _travelDurationSeconds / total;
    final raw = travelFraction == 0
        ? 1.0
        : (_motionController.value / travelFraction).clamp(0.0, 1.0);
    return _curve.curve.transform(raw.toDouble());
  }

  void _resetMotionForEdit() {
    _motionController.stop(canceled: false);
    _motionController.value = 0;
  }

  void _moveJeep(Offset delta, Size canvasSize) {
    _resetMotionForEdit();
    setState(() {
      _jeepAlignment = Alignment(
        (_jeepAlignment.x + ((delta.dx * 2) / canvasSize.width)).clamp(
          -1.0,
          1.0,
        ),
        (_jeepAlignment.y + ((delta.dy * 2) / canvasSize.height)).clamp(
          -1.0,
          1.0,
        ),
      );
    });
  }

  void _setStart() => setState(() {
    _resetMotionForEdit();
    _start = _CalibrationSnapshot(alignment: _jeepAlignment, scale: _jeepScale);
  });

  void _setEnd() => setState(() {
    _resetMotionForEdit();
    _end = _CalibrationSnapshot(alignment: _jeepAlignment, scale: _jeepScale);
  });

  void _updateMotionDuration() {
    _motionController.duration = _motionDuration;
    _motionController.reset();
  }

  void _playMotion() {
    _motionController.duration = _motionDuration;
    _motionController.forward(from: 0);
  }

  void _stopMotion() {
    _motionController.stop(canceled: false);
    setState(() {
      _jeepAlignment = _start.alignment;
      _jeepScale = _start.scale;
      _motionController.value = 0;
    });
  }

  Map<String, Object?> get _parameters => {
    'calibrationType': 'boot_sequence_motion',
    'prototype': 'scene_1_prototype',
    'coordinateSystem': 'alignment_normalized',
    'background': {'asset': _bootSequenceAssets[0].path},
    'jeepAssembly': {
      'start': _snapshotJson(_start),
      'end': _snapshotJson(_end),
    },
    'motion': {
      'travelDurationMs': (_travelDurationSeconds * 1000).round(),
      'holdDurationMs': (_holdDurationSeconds * 1000).round(),
      'curve': _curve.parameterName,
    },
  };

  Map<String, Object>? _snapshotJson(_CalibrationSnapshot? snapshot) =>
      snapshot == null
      ? null
      : {
          'x': _rounded(snapshot.alignment.x),
          'y': _rounded(snapshot.alignment.y),
          'scale': _rounded(snapshot.scale),
        };

  double _rounded(double value) => double.parse(value.toStringAsFixed(3));

  String get _parametersJson =>
      const JsonEncoder.withIndent('  ').convert(_parameters);

  Future<void> _copyParameters() async {
    await Clipboard.setData(ClipboardData(text: _parametersJson));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('CODEX PARAMETERSをコピーしました')));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('MOTION CALIBRATION')),
    body: AnimatedBuilder(
      animation: _motionController,
      builder: (context, _) => ListView(
        padding: AppSpacing.cardPadding,
        children: [
          const SectionHeader(
            icon: Icons.grid_4x4_outlined,
            title: 'CALIBRATION CANVAS',
          ),
          AppSpacing.gapSM,
          OperationCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _CalibrationCanvas(
                  alignment: _displayAlignment,
                  scale: _displayScale,
                  session: widget.session,
                  onMoveJeep: _moveJeep,
                ),
                AppSpacing.gapMD,
                _buildPlaybackControls(),
              ],
            ),
          ),
          AppSpacing.gapXL,
          const SectionHeader(icon: Icons.tune_outlined, title: 'PARAMETERS'),
          AppSpacing.gapSM,
          OperationCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildParameterControls(),
                AppSpacing.gapMD,
                _buildMotionControls(),
              ],
            ),
          ),
          AppSpacing.gapXL,
          const SectionHeader(
            icon: Icons.data_object,
            title: 'CODEX PARAMETERS',
          ),
          AppSpacing.gapSM,
          OperationCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SelectableText(
                  _parametersJson,
                  key: const ValueKey('motion-parameters-json'),
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
                ),
                AppSpacing.gapMD,
                _SandboxActionButton(
                  key: const ValueKey('copy-motion-parameters'),
                  text: 'COPY PARAMETERS',
                  icon: Icons.copy_outlined,
                  onPressed: _copyParameters,
                ),
              ],
            ),
          ),
          AppSpacing.gapLG,
        ],
      ),
    ),
  );

  Widget _buildParameterControls() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _LiveValues(
          xLabel: 'X',
          x: _jeepAlignment.x,
          yLabel: 'Y',
          y: _jeepAlignment.y,
          scale: _jeepScale,
        ),
        _CalibrationSlider(
          key: const ValueKey('jeep-scale-slider'),
          label: 'SCALE',
          value: _jeepScale,
          min: 0.1,
          max: 1.5,
          divisions: 140,
          onChanged: (value) => setState(() {
            _resetMotionForEdit();
            _jeepScale = value;
          }),
        ),
        AppSpacing.gapSM,
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            ElevatedButton(
              key: const ValueKey('set-calibration-start'),
              onPressed: _setStart,
              child: const Text('SET START'),
            ),
            ElevatedButton(
              key: const ValueKey('set-calibration-end'),
              onPressed: _setEnd,
              child: const Text('SET END'),
            ),
          ],
        ),
        AppSpacing.gapMD,
        _SnapshotDisplay(label: 'START', snapshot: _start),
        AppSpacing.gapSM,
        _SnapshotDisplay(label: 'END', snapshot: _end),
      ],
    );
  }

  Widget _buildPlaybackControls() => Wrap(
    key: const ValueKey('motion-playback-controls'),
    spacing: AppSpacing.sm,
    runSpacing: AppSpacing.sm,
    children: [
      ElevatedButton.icon(
        key: const ValueKey('calibration-test-play'),
        onPressed: _playMotion,
        icon: const Icon(Icons.play_arrow),
        label: const Text('TEST PLAY'),
      ),
      ElevatedButton.icon(
        key: const ValueKey('calibration-test-stop'),
        onPressed: _stopMotion,
        icon: const Icon(Icons.stop),
        label: const Text('STOP'),
      ),
      ElevatedButton.icon(
        key: const ValueKey('calibration-test-replay'),
        onPressed: _playMotion,
        icon: const Icon(Icons.replay),
        label: const Text('REPLAY'),
      ),
    ],
  );

  Widget _buildMotionControls() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _CalibrationSlider(
        key: const ValueKey('travel-duration-slider'),
        label: 'TRAVEL DURATION',
        value: _travelDurationSeconds,
        min: 1,
        max: 12,
        divisions: 22,
        unit: 's',
        onChanged: (value) => setState(() {
          _travelDurationSeconds = value;
          _updateMotionDuration();
        }),
      ),
      _CalibrationSlider(
        key: const ValueKey('hold-duration-slider'),
        label: 'HOLD DURATION',
        value: _holdDurationSeconds,
        min: 0,
        max: 5,
        divisions: 20,
        unit: 's',
        onChanged: (value) => setState(() {
          _holdDurationSeconds = value;
          _updateMotionDuration();
        }),
      ),
      DropdownButtonFormField<_CalibrationCurveOption>(
        key: const ValueKey('calibration-curve-selector'),
        initialValue: _curve,
        decoration: const InputDecoration(labelText: 'CURVE'),
        items: [
          for (final option in _CalibrationCurveOption.values)
            DropdownMenuItem(value: option, child: Text(option.label)),
        ],
        onChanged: (value) {
          if (value == null) return;
          setState(() {
            _curve = value;
            _motionController.reset();
          });
        },
      ),
    ],
  );
}

class _CalibrationCanvas extends StatelessWidget {
  const _CalibrationCanvas({
    required this.alignment,
    required this.scale,
    required this.session,
    required this.onMoveJeep,
  });

  final Alignment alignment;
  final double scale;
  final _CalibrationSession session;
  final void Function(Offset delta, Size canvasSize) onMoveJeep;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 800),
      child: AspectRatio(
        aspectRatio: 3 / 2,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final canvasSize = constraints.biggest;
              final assemblyWidth = (constraints.maxWidth * 0.38)
                  .clamp(120.0, 320.0)
                  .toDouble();
              final assemblyHeight = assemblyWidth * (941 / 1672);
              return Listener(
                key: const ValueKey('calibration-canvas-drag-target'),
                behavior: HitTestBehavior.opaque,
                onPointerMove: (event) => onMoveJeep(event.delta, canvasSize),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(
                      _bootSequenceAssets[0].path,
                      key: const ValueKey('calibration-background'),
                      fit: BoxFit.cover,
                    ),
                    CustomPaint(
                      key: const ValueKey('calibration-grid'),
                      painter: _CalibrationGridPainter(
                        color: Colors.white.withValues(alpha: 0.30),
                      ),
                    ),
                    Positioned(
                      key: const ValueKey('calibration-vertical-center-line'),
                      left: (canvasSize.width / 2) - 0.5,
                      top: 0,
                      bottom: 0,
                      width: 1,
                      child: const ColoredBox(color: Colors.white70),
                    ),
                    Positioned(
                      key: const ValueKey('calibration-horizontal-center-line'),
                      left: 0,
                      right: 0,
                      top: (canvasSize.height / 2) - 0.5,
                      height: 1,
                      child: const ColoredBox(color: Colors.white70),
                    ),
                    Center(
                      child: Container(
                        key: const ValueKey('calibration-center-marker'),
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                    Positioned(
                      key: const ValueKey('calibration-jeep-position'),
                      left:
                          (((alignment.x + 1) / 2) * canvasSize.width) -
                          (assemblyWidth / 2),
                      top:
                          (((alignment.y + 1) / 2) * canvasSize.height) -
                          (assemblyHeight / 2),
                      width: assemblyWidth,
                      height: assemblyHeight,
                      child: Transform.scale(
                        key: const ValueKey('calibration-jeep-scale'),
                        scale: scale,
                        child: _CalibrationJeepAssembly(
                          width: assemblyWidth,
                          selectedTarget: _CalibrationTarget.jeepAssembly,
                          frontWheelFar: session.frontWheelFar,
                          rearWheel: session.rearWheel,
                          frontWheelNear: session.frontWheelNear,
                        ),
                      ),
                    ),
                    Positioned(
                      right: 8,
                      top: 8,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.68),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: Text(
                            'X ${alignment.x.toStringAsFixed(3)}\n'
                            'Y ${alignment.y.toStringAsFixed(3)}\n'
                            'SCALE ${scale.toStringAsFixed(3)}',
                            key: const ValueKey('calibration-canvas-values'),
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    ),
  );
}

class _CalibrationJeepAssembly extends StatelessWidget {
  const _CalibrationJeepAssembly({
    required this.width,
    required this.selectedTarget,
    required this.frontWheelFar,
    required this.rearWheel,
    required this.frontWheelNear,
  });

  final double width;
  final _CalibrationTarget selectedTarget;
  final _WheelCalibration frontWheelFar;
  final _WheelCalibration rearWheel;
  final _WheelCalibration frontWheelNear;

  @override
  Widget build(BuildContext context) {
    final height = width * (941 / 1672);
    return SizedBox(
      key: const ValueKey('calibration-jeep-assembly'),
      width: width,
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          _CalibrationWheel(
            key: const ValueKey('calibration-front-wheel-far-layer'),
            imageKey: const ValueKey('calibration-front-wheel-far'),
            width: width,
            height: height,
            calibration: frontWheelFar,
            selected: selectedTarget == _CalibrationTarget.frontWheelFar,
          ),
          Positioned.fill(
            child: DecoratedBox(
              key: selectedTarget == _CalibrationTarget.jeepAssembly
                  ? const ValueKey('calibration-selected-bounds')
                  : null,
              decoration: BoxDecoration(
                border: selectedTarget == _CalibrationTarget.jeepAssembly
                    ? Border.all(color: Colors.amber, width: 2)
                    : null,
              ),
              child: Image.asset(
                _bootSequenceAssets[1].path,
                key: const ValueKey('calibration-jeep-body'),
                fit: BoxFit.contain,
              ),
            ),
          ),
          _CalibrationWheel(
            key: const ValueKey('calibration-rear-wheel-layer'),
            imageKey: const ValueKey('calibration-rear-wheel'),
            width: width,
            height: height,
            calibration: rearWheel,
            selected: selectedTarget == _CalibrationTarget.rearWheel,
          ),
          _CalibrationWheel(
            key: const ValueKey('calibration-front-wheel-near-layer'),
            imageKey: const ValueKey('calibration-front-wheel-near'),
            width: width,
            height: height,
            calibration: frontWheelNear,
            selected: selectedTarget == _CalibrationTarget.frontWheelNear,
          ),
        ],
      ),
    );
  }
}

class _CalibrationWheel extends StatelessWidget {
  const _CalibrationWheel({
    super.key,
    required this.imageKey,
    required this.width,
    required this.height,
    required this.calibration,
    required this.selected,
  });

  final Key imageKey;
  final double width;
  final double height;
  final _WheelCalibration calibration;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final size = width * calibration.scale;
    return Positioned(
      left: width * calibration.localX,
      top: height * calibration.localY,
      width: size,
      height: size,
      child: DecoratedBox(
        key: selected ? const ValueKey('calibration-selected-bounds') : null,
        decoration: BoxDecoration(
          border: selected ? Border.all(color: Colors.amber, width: 2) : null,
        ),
        child: Image.asset(
          _bootSequenceAssets[2].path,
          key: imageKey,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}

class _CalibrationCenterOverlay extends StatelessWidget {
  const _CalibrationCenterOverlay({required this.prefix});

  final String prefix;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Stack(
      children: [
        Positioned(
          key: ValueKey('$prefix-vertical-center-line'),
          left: (constraints.maxWidth / 2) - 0.5,
          top: 0,
          bottom: 0,
          width: 1,
          child: ColoredBox(color: Theme.of(context).colorScheme.outline),
        ),
        Positioned(
          key: ValueKey('$prefix-horizontal-center-line'),
          left: 0,
          right: 0,
          top: (constraints.maxHeight / 2) - 0.5,
          height: 1,
          child: ColoredBox(color: Theme.of(context).colorScheme.outline),
        ),
        Center(
          child: Container(
            key: ValueKey('$prefix-center-marker'),
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Theme.of(context).colorScheme.onSurface,
                width: 2,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _CalibrationValueBadge extends StatelessWidget {
  const _CalibrationValueBadge({
    required this.x,
    required this.y,
    required this.scale,
  });

  final double x;
  final double y;
  final double scale;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.68),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Padding(
      padding: const EdgeInsets.all(6),
      child: Text(
        'X ${x.toStringAsFixed(3)}\n'
        'Y ${y.toStringAsFixed(3)}\n'
        'SCALE ${scale.toStringAsFixed(3)}',
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: Colors.white),
      ),
    ),
  );
}

class _CalibrationGridPainter extends CustomPainter {
  const _CalibrationGridPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    for (var index = 1; index < 4; index++) {
      final x = size.width * index / 4;
      final y = size.height * index / 4;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_CalibrationGridPainter oldDelegate) =>
      color != oldDelegate.color;
}

class _LiveValues extends StatelessWidget {
  const _LiveValues({
    required this.xLabel,
    required this.x,
    required this.yLabel,
    required this.y,
    required this.scale,
  });

  final String xLabel;
  final double x;
  final String yLabel;
  final double y;
  final double scale;

  @override
  Widget build(BuildContext context) => Wrap(
    key: const ValueKey('calibration-live-values'),
    spacing: AppSpacing.lg,
    runSpacing: AppSpacing.sm,
    children: [
      Text('$xLabel  ${x.toStringAsFixed(3)}'),
      Text('$yLabel  ${y.toStringAsFixed(3)}'),
      Text('SCALE  ${scale.toStringAsFixed(3)}'),
    ],
  );
}

class _CalibrationSlider extends StatelessWidget {
  const _CalibrationSlider({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
    this.unit = '',
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;
  final String unit;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text('$label  ${value.toStringAsFixed(2)}$unit'),
      Slider(
        value: value,
        min: min,
        max: max,
        divisions: divisions,
        label: '${value.toStringAsFixed(2)}$unit',
        onChanged: onChanged,
      ),
    ],
  );
}

class _SnapshotDisplay extends StatelessWidget {
  const _SnapshotDisplay({required this.label, required this.snapshot});

  final String label;
  final _CalibrationSnapshot? snapshot;

  @override
  Widget build(BuildContext context) => Text(
    snapshot == null
        ? '$label  NOT SET'
        : '$label  X ${snapshot!.alignment.x.toStringAsFixed(3)}  '
              'Y ${snapshot!.alignment.y.toStringAsFixed(3)}  '
              'SCALE ${snapshot!.scale.toStringAsFixed(3)}',
    key: ValueKey('calibration-${label.toLowerCase()}-display'),
  );
}

class _BootAssetCard extends StatelessWidget {
  const _BootAssetCard({super.key, required this.asset, required this.onTap});

  final _BootSequenceAsset asset;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => OperationCard(
    selectable: true,
    onTap: onTap,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          key: ValueKey('boot-asset-thumbnail-${asset.fileName}'),
          width: 80,
          height: 64,
          child: _AssetImageFrame(asset: asset, thumbnail: true),
        ),
        SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(asset.name, style: Theme.of(context).textTheme.titleMedium),
              AppSpacing.gapXS,
              Text('FILE NAME  ${asset.fileName}'),
              AppSpacing.gapXS,
              Text('ASSET PATH  ${asset.path}', softWrap: true),
              AppSpacing.gapXS,
              Text('USAGE  ${asset.usage}'),
            ],
          ),
        ),
      ],
    ),
  );
}

class _BootAssetPreviewDialog extends StatelessWidget {
  const _BootAssetPreviewDialog({required this.asset});

  final _BootSequenceAsset asset;

  @override
  Widget build(BuildContext context) {
    final previewHeight = (MediaQuery.sizeOf(context).height * 0.48)
        .clamp(180.0, 520.0)
        .toDouble();
    return AlertDialog(
      key: const ValueKey('boot-asset-preview-dialog'),
      insetPadding: const EdgeInsets.all(16),
      title: Text(asset.name),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 880),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                key: ValueKey('boot-asset-preview-image-${asset.fileName}'),
                width: double.infinity,
                height: previewHeight,
                child: _AssetImageFrame(asset: asset),
              ),
              AppSpacing.gapMD,
              Text('ASSET NAME  ${asset.name}'),
              AppSpacing.gapSM,
              Text('FILE NAME  ${asset.fileName}'),
              AppSpacing.gapSM,
              Text('ASSET PATH  ${asset.path}', softWrap: true),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('close-boot-asset-preview'),
          onPressed: () => Navigator.pop(context),
          child: const Text('CLOSE'),
        ),
      ],
    );
  }
}

class _AssetImageFrame extends StatelessWidget {
  const _AssetImageFrame({required this.asset, this.thumbnail = false});

  final _BootSequenceAsset asset;
  final bool thumbnail;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(8),
    child: _AssetBackdrop(
      key: asset.transparent
          ? ValueKey(
              'transparent-asset-backdrop-'
              '${thumbnail ? 'thumbnail' : 'preview'}-${asset.fileName}',
            )
          : null,
      transparent: asset.transparent,
      child: Padding(
        padding: EdgeInsets.all(thumbnail ? 4 : 12),
        child: Image.asset(
          asset.path,
          key: ValueKey(
            thumbnail
                ? 'boot-asset-thumbnail-image-${asset.fileName}'
                : 'boot-asset-preview-source-${asset.fileName}',
          ),
          fit: asset.transparent ? BoxFit.contain : BoxFit.cover,
        ),
      ),
    ),
  );
}

class _AssetBackdrop extends StatelessWidget {
  const _AssetBackdrop({
    super.key,
    required this.transparent,
    required this.child,
  });

  final bool transparent;
  final Widget child;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      if (transparent)
        CustomPaint(
          painter: _TransparencyGridPainter(
            light: Theme.of(context).colorScheme.surfaceContainerHighest,
            dark: Theme.of(context).colorScheme.outlineVariant,
          ),
        )
      else
        ColoredBox(color: Theme.of(context).colorScheme.surfaceContainer),
      child,
    ],
  );
}

class _TransparencyGridPainter extends CustomPainter {
  const _TransparencyGridPainter({required this.light, required this.dark});

  final Color light;
  final Color dark;

  @override
  void paint(Canvas canvas, Size size) {
    const cellSize = 12.0;
    final paint = Paint();
    for (var y = 0.0, row = 0; y < size.height; y += cellSize, row++) {
      for (var x = 0.0, column = 0; x < size.width; x += cellSize, column++) {
        paint.color = (row + column).isEven ? light : dark;
        canvas.drawRect(Rect.fromLTWH(x, y, cellSize, cellSize), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_TransparencyGridPainter oldDelegate) =>
      light != oldDelegate.light || dark != oldDelegate.dark;
}

class Scene2CalibrationSession {
  Alignment? _jeepAlignment;
  double? _jeepScale;
  Offset? _logoTarget;
  _CalibrationSnapshot? _cameraStart;
  _CalibrationSnapshot? _cameraEnd;
  int? _travelDurationMs;
  int? _holdDurationMs;
  _CalibrationCurveOption? _curve;

  bool get hasLayout =>
      _jeepAlignment != null && _jeepScale != null && _logoTarget != null;

  bool get hasMotion {
    final start = _cameraStart;
    final end = _cameraEnd;
    final travel = _travelDurationMs;
    final hold = _holdDurationMs;
    return start != null &&
        end != null &&
        start.alignment.x >= -1 &&
        start.alignment.x <= 1 &&
        start.alignment.y >= -1 &&
        start.alignment.y <= 1 &&
        end.alignment.x >= -1 &&
        end.alignment.x <= 1 &&
        end.alignment.y >= -1 &&
        end.alignment.y <= 1 &&
        start.scale >= _scene2CameraMinScale &&
        start.scale <= _scene2CameraMaxScale &&
        end.scale >= _scene2CameraMinScale &&
        end.scale <= _scene2CameraMaxScale &&
        travel != null &&
        travel > 0 &&
        hold != null &&
        hold >= 0 &&
        _curve != null;
  }

  bool get isComplete => hasLayout && hasMotion;

  Duration? get totalDuration => hasMotion
      ? Duration(milliseconds: _travelDurationMs! + _holdDurationMs!)
      : null;

  Map<String, Object?> get layoutParameters => {
    'calibrationType': 'boot_sequence_scene_2_layout',
    'prototype': 'scene_2_logo_zoom',
    'coordinateSystem': 'alignment_normalized',
    'background': {'asset': _bootSequenceAssets[0].path},
    'jeep': {
      'asset': _scene2JeepAsset,
      'alignment': {
        'x': _roundOrNull(_jeepAlignment?.x),
        'y': _roundOrNull(_jeepAlignment?.y),
      },
      'scale': _roundOrNull(_jeepScale),
    },
    'logoTarget': {
      'coordinateSystem': 'jeep_local_normalized',
      'x': _roundOrNull(_logoTarget?.dx),
      'y': _roundOrNull(_logoTarget?.dy),
    },
  };

  Map<String, Object?> get motionParameters => {
    'calibrationType': 'boot_sequence_scene_2_motion',
    'prototype': 'scene_2_logo_zoom',
    'camera': {
      'start': _scene2SnapshotJson(_cameraStart),
      'end': _scene2SnapshotJson(_cameraEnd),
    },
    'motion': {
      'travelDurationMs': _travelDurationMs,
      'holdDurationMs': _holdDurationMs,
      'curve': _curve?.parameterName,
    },
  };

  Map<String, Object?> get compositeParameters => {
    'layout': layoutParameters,
    'motion': motionParameters,
  };

  static double? _roundOrNull(double? value) =>
      value == null ? null : double.parse(value.toStringAsFixed(3));

  static Map<String, Object?>? _scene2SnapshotJson(
    _CalibrationSnapshot? snapshot,
  ) => snapshot == null
      ? null
      : {
          'x': _roundOrNull(snapshot.alignment.x),
          'y': _roundOrNull(snapshot.alignment.y),
          'scale': _roundOrNull(snapshot.scale),
        };
}

enum _Scene2LayoutTarget { jeep, logo }

class _Scene2LayoutTestPage extends StatefulWidget {
  const _Scene2LayoutTestPage({required this.session});

  final Scene2CalibrationSession session;

  @override
  State<_Scene2LayoutTestPage> createState() => _Scene2LayoutTestPageState();
}

class _Scene2LayoutTestPageState extends State<_Scene2LayoutTestPage> {
  _Scene2LayoutTarget _target = _Scene2LayoutTarget.jeep;

  String get _parametersJson => const JsonEncoder.withIndent(
    '  ',
  ).convert(widget.session.layoutParameters);

  void _moveJeep(Offset delta, Size canvasSize) {
    final current = widget.session._jeepAlignment ?? Alignment.center;
    setState(() {
      widget.session._jeepAlignment = Alignment(
        (current.x + ((delta.dx * 2) / canvasSize.width)).clamp(-1.0, 1.0),
        (current.y + ((delta.dy * 2) / canvasSize.height)).clamp(-1.0, 1.0),
      );
    });
  }

  void _setLogoTarget(Offset point, Size canvasSize) {
    final geometry = _scene2JeepGeometry(
      canvasSize,
      widget.session._jeepAlignment ?? Alignment.center,
      widget.session._jeepScale ?? 1,
    );
    setState(() {
      widget.session._logoTarget = Offset(
        ((point.dx - geometry.left) / geometry.width).clamp(0.0, 1.0),
        ((point.dy - geometry.top) / geometry.height).clamp(0.0, 1.0),
      );
    });
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _parametersJson));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('CODEX PARAMETERSをコピーしました')));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('SCENE 2 LAYOUT TEST')),
    body: ListView(
      padding: AppSpacing.cardPadding,
      children: [
        const SectionHeader(
          icon: Icons.open_with_outlined,
          title: 'LAYOUT TEST',
        ),
        AppSpacing.gapSM,
        OperationCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                key: const ValueKey('scene-2-layout-target'),
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  ChoiceChip(
                    label: const Text('JEEP POSITION'),
                    selected: _target == _Scene2LayoutTarget.jeep,
                    onSelected: (_) =>
                        setState(() => _target = _Scene2LayoutTarget.jeep),
                  ),
                  ChoiceChip(
                    label: const Text('LOGO TARGET'),
                    selected: _target == _Scene2LayoutTarget.logo,
                    onSelected: (_) =>
                        setState(() => _target = _Scene2LayoutTarget.logo),
                  ),
                ],
              ),
              AppSpacing.gapMD,
              _Scene2LayoutCanvas(
                session: widget.session,
                target: _target,
                onMoveJeep: _moveJeep,
                onSetLogoTarget: _setLogoTarget,
              ),
              AppSpacing.gapMD,
              _Scene2NullableValues(
                session: widget.session,
                includeMotion: false,
              ),
              _CalibrationSlider(
                key: const ValueKey('scene-2-jeep-scale'),
                label: 'JEEP SCALE',
                value: widget.session._jeepScale ?? 1,
                min: 0.1,
                max: 2,
                divisions: 190,
                onChanged: (value) =>
                    setState(() => widget.session._jeepScale = value),
              ),
            ],
          ),
        ),
        AppSpacing.gapXL,
        _Scene2ParametersCard(
          json: _parametersJson,
          jsonKey: 'scene-2-layout-parameters-json',
          copyKey: 'copy-scene-2-layout-parameters',
          onCopy: _copy,
        ),
        AppSpacing.gapLG,
      ],
    ),
  );
}

class _Scene2LayoutCanvas extends StatelessWidget {
  const _Scene2LayoutCanvas({
    required this.session,
    required this.target,
    required this.onMoveJeep,
    required this.onSetLogoTarget,
  });

  final Scene2CalibrationSession session;
  final _Scene2LayoutTarget target;
  final void Function(Offset, Size) onMoveJeep;
  final void Function(Offset, Size) onSetLogoTarget;

  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: 3 / 2,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        return Listener(
          key: const ValueKey('scene-2-layout-canvas'),
          behavior: HitTestBehavior.opaque,
          onPointerDown: target == _Scene2LayoutTarget.logo
              ? (event) => onSetLogoTarget(event.localPosition, size)
              : null,
          onPointerMove: (event) {
            if (target == _Scene2LayoutTarget.jeep) {
              onMoveJeep(event.delta, size);
            } else {
              onSetLogoTarget(event.localPosition, size);
            }
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: _Scene2StaticComposition(session: session, showTarget: true),
          ),
        );
      },
    ),
  );
}

class _Scene2ZoomTestPage extends StatefulWidget {
  const _Scene2ZoomTestPage({required this.session});

  final Scene2CalibrationSession session;

  @override
  State<_Scene2ZoomTestPage> createState() => _Scene2ZoomTestPageState();
}

enum _Scene2ViewMode { start, end }

class _Scene2ZoomTestPageState extends State<_Scene2ZoomTestPage>
    with SingleTickerProviderStateMixin {
  static const _previewOnlyView = _CalibrationSnapshot(
    alignment: Alignment.center,
    scale: 1,
  );

  _Scene2ViewMode _mode = _Scene2ViewMode.start;
  late _CalibrationSnapshot? _startDraft = widget.session._cameraStart;
  late _CalibrationSnapshot? _endDraft = widget.session._cameraEnd;
  final _viewTransformation = TransformationController();
  Size _canvasSize = Size.zero;
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.session.totalDuration ?? const Duration(milliseconds: 1),
  );

  _CalibrationSnapshot? get _selectedDraft =>
      _mode == _Scene2ViewMode.start ? _startDraft : _endDraft;

  _CalibrationSnapshot get _workingView => _selectedDraft ?? _previewOnlyView;

  @override
  void dispose() {
    _viewTransformation.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _syncDuration() {
    _controller
      ..stop(canceled: false)
      ..duration =
          widget.session.totalDuration ?? const Duration(milliseconds: 1)
      ..value = 0;
  }

  void _updateDraft(_CalibrationSnapshot value) {
    _controller
      ..stop(canceled: false)
      ..value = 0;
    setState(() {
      if (_mode == _Scene2ViewMode.start) {
        _startDraft = value;
      } else {
        _endDraft = value;
      }
    });
  }

  void _syncViewTransformation() {
    if (_canvasSize.isEmpty) return;
    _viewTransformation.value = _scene2CameraTransform(
      _canvasSize,
      _workingView,
    );
  }

  void _updateDraftFromTransformation() {
    if (_canvasSize.isEmpty) return;
    final matrix = _viewTransformation.value;
    _updateDraft(
      _CalibrationSnapshot(
        alignment: Alignment(
          (matrix.entry(0, 3) * 2 / _canvasSize.width).clamp(-1.0, 1.0),
          (matrix.entry(1, 3) * 2 / _canvasSize.height).clamp(-1.0, 1.0),
        ),
        scale: matrix.getMaxScaleOnAxis().clamp(
          _scene2CameraMinScale,
          _scene2CameraMaxScale,
        ),
      ),
    );
  }

  void _updateDraftField(String field, String value) {
    final parsed = double.tryParse(value);
    if (parsed == null) return;
    final current = _workingView;
    final x = field == 'x' ? parsed : current.alignment.x;
    final y = field == 'y' ? parsed : current.alignment.y;
    final scale = field == 'scale' ? parsed : current.scale;
    if (x < -1 ||
        x > 1 ||
        y < -1 ||
        y > 1 ||
        scale < _scene2CameraMinScale ||
        scale > _scene2CameraMaxScale) {
      return;
    }
    _updateDraft(
      _CalibrationSnapshot(alignment: Alignment(x, y), scale: scale),
    );
  }

  void _setSelectedView() {
    setState(() {
      if (_mode == _Scene2ViewMode.start) {
        widget.session._cameraStart = _workingView;
        _startDraft = widget.session._cameraStart;
      } else {
        widget.session._cameraEnd = _workingView;
        _endDraft = widget.session._cameraEnd;
      }
      _syncDuration();
    });
  }

  void _updateDuration(bool travel, int value) {
    setState(() {
      if (travel) {
        widget.session._travelDurationMs = value;
      } else {
        widget.session._holdDurationMs = value;
      }
      _syncDuration();
    });
  }

  void _play({bool restart = false}) {
    if (!widget.session.isComplete) return;
    if (restart || _controller.value == 0) {
      setState(() => _mode = _Scene2ViewMode.start);
    }
    _controller.duration = widget.session.totalDuration;
    _controller.forward(from: restart ? 0 : null);
  }

  void _stop() {
    _controller
      ..stop(canceled: false)
      ..value = 0;
    setState(() => _mode = _Scene2ViewMode.start);
    _syncViewTransformation();
  }

  void _selectMode(_Scene2ViewMode mode) {
    _controller
      ..stop(canceled: false)
      ..value = 0;
    setState(() => _mode = mode);
    _syncViewTransformation();
  }

  String get _parametersJson => const JsonEncoder.withIndent(
    '  ',
  ).convert(widget.session.motionParameters);

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _parametersJson));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('CODEX PARAMETERSをコピーしました')));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('SCENE 2 ZOOM TEST')),
    body: AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => ListView(
        padding: AppSpacing.cardPadding,
        children: [
          const SectionHeader(icon: Icons.zoom_in_outlined, title: 'ZOOM TEST'),
          AppSpacing.gapSM,
          OperationCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildModeSelector(),
                AppSpacing.gapMD,
                _buildDirectManipulationCanvas(),
                AppSpacing.gapMD,
                _buildScaleControl(),
                AppSpacing.gapSM,
                _buildSetViewAction(),
                AppSpacing.gapMD,
                _Scene2PlaybackControls(
                  enabled: widget.session.isComplete,
                  onPlay: _play,
                  onPause: () {
                    _controller.stop(canceled: false);
                    setState(() {});
                  },
                  onStop: _stop,
                  onReplay: () => _play(restart: true),
                ),
              ],
            ),
          ),
          AppSpacing.gapXL,
          const SectionHeader(icon: Icons.tune_outlined, title: 'PARAMETERS'),
          AppSpacing.gapSM,
          OperationCard(child: _buildParameters()),
          AppSpacing.gapXL,
          _Scene2ParametersCard(
            json: _parametersJson,
            jsonKey: 'scene-2-zoom-parameters-json',
            copyKey: 'copy-scene-2-zoom-parameters',
            onCopy: _copy,
          ),
          AppSpacing.gapLG,
        ],
      ),
    ),
  );

  Widget _buildModeSelector() => Wrap(
    key: const ValueKey('scene-2-view-mode'),
    spacing: AppSpacing.sm,
    runSpacing: AppSpacing.sm,
    children: [
      ChoiceChip(
        key: const ValueKey('scene-2-start-view-mode'),
        label: const Text('START VIEW'),
        selected: _mode == _Scene2ViewMode.start,
        onSelected: (_) => _selectMode(_Scene2ViewMode.start),
      ),
      ChoiceChip(
        key: const ValueKey('scene-2-end-view-mode'),
        label: const Text('END VIEW'),
        selected: _mode == _Scene2ViewMode.end,
        onSelected: (_) => _selectMode(_Scene2ViewMode.end),
      ),
    ],
  );

  Widget _buildDirectManipulationCanvas() => AspectRatio(
    aspectRatio: 3 / 2,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (_canvasSize != constraints.biggest) {
            _canvasSize = constraints.biggest;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _syncViewTransformation();
            });
          }
          return Stack(
            fit: StackFit.expand,
            children: [
              if ((_controller.isAnimating || _controller.value > 0) &&
                  widget.session.isComplete)
                _Scene2Preview(
                  progress: _controller.value,
                  session: widget.session,
                  jeepAsset: _scene2JeepAsset,
                  showTarget: _mode == _Scene2ViewMode.end,
                )
              else
                InteractiveViewer(
                  key: const ValueKey('scene-2-zoom-canvas'),
                  transformationController: _viewTransformation,
                  alignment: _scene2CameraTransformOrigin,
                  minScale: _scene2CameraMinScale,
                  maxScale: _scene2CameraMaxScale,
                  boundaryMargin: const EdgeInsets.all(1000),
                  onInteractionUpdate: (_) => _updateDraftFromTransformation(),
                  child: _Scene2StaticComposition(
                    session: widget.session,
                    showTarget: _mode == _Scene2ViewMode.end,
                  ),
                ),
              if (_mode == _Scene2ViewMode.end)
                const IgnorePointer(child: _Scene2CenterGuide()),
            ],
          );
        },
      ),
    ),
  );

  Widget _buildScaleControl() => _CalibrationSlider(
    key: const ValueKey('scene-2-view-scale'),
    label: '${_mode == _Scene2ViewMode.start ? 'START' : 'END'} SCALE',
    value: _workingView.scale,
    min: _scene2CameraMinScale,
    max: _scene2CameraMaxScale,
    divisions: 490,
    unit: 'x',
    onChanged: (value) {
      _updateDraft(
        _CalibrationSnapshot(alignment: _workingView.alignment, scale: value),
      );
      _syncViewTransformation();
    },
  );

  Widget _buildSetViewAction() => _SandboxActionButton(
    key: ValueKey(
      _mode == _Scene2ViewMode.start ? 'scene-2-set-start' : 'scene-2-set-end',
    ),
    text: _mode == _Scene2ViewMode.start ? 'SET START' : 'SET END',
    icon: Icons.check_circle_outline,
    onPressed: _setSelectedView,
  );

  Widget _buildParameters() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text('PARAMETER DISPLAY'),
      AppSpacing.gapSM,
      _SnapshotDisplay(label: 'START', snapshot: widget.session._cameraStart),
      AppSpacing.gapSM,
      _SnapshotDisplay(label: 'END', snapshot: widget.session._cameraEnd),
      AppSpacing.gapMD,
      _buildDurationSlider(travel: true),
      _buildDurationSlider(travel: false),
      AppSpacing.gapSM,
      DropdownButtonFormField<_CalibrationCurveOption>(
        key: const ValueKey('scene-2-curve'),
        initialValue: widget.session._curve,
        decoration: const InputDecoration(labelText: 'CURVE'),
        hint: const Text('NOT SET'),
        items: [
          for (final option in _CalibrationCurveOption.values)
            DropdownMenuItem(value: option, child: Text(option.label)),
        ],
        onChanged: (value) => setState(() {
          widget.session._curve = value;
          _syncDuration();
        }),
      ),
      AppSpacing.gapMD,
      ExpansionTile(
        key: const ValueKey('scene-2-fine-tune'),
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.zero,
        title: const Text('FINE TUNE'),
        children: [
          _Scene2SnapshotFields(
            label: 'START VIEW',
            snapshot: _startDraft,
            onChanged: (field, value) {
              final previousMode = _mode;
              _mode = _Scene2ViewMode.start;
              _updateDraftField(field, value);
              _mode = previousMode;
              _syncViewTransformation();
            },
          ),
          AppSpacing.gapMD,
          _Scene2SnapshotFields(
            label: 'END VIEW',
            snapshot: _endDraft,
            onChanged: (field, value) {
              final previousMode = _mode;
              _mode = _Scene2ViewMode.end;
              _updateDraftField(field, value);
              _mode = previousMode;
              _syncViewTransformation();
            },
          ),
        ],
      ),
    ],
  );

  Widget _buildDurationSlider({required bool travel}) {
    final valueMs = travel
        ? widget.session._travelDurationMs
        : widget.session._holdDurationMs;
    final min = travel ? 1.0 : 0.0;
    final max = travel ? 12.0 : 5.0;
    final fallback = min;
    return Column(
      key: ValueKey(
        travel ? 'scene-2-travel-duration' : 'scene-2-hold-duration',
      ),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${travel ? 'TRAVEL DURATION' : 'HOLD DURATION'}  '
          '${valueMs == null ? 'NOT SET' : '${(valueMs / 1000).toStringAsFixed(2)}s'}',
        ),
        Slider(
          value: valueMs == null ? fallback : valueMs / 1000,
          min: min,
          max: max,
          divisions: travel ? 22 : 20,
          label: valueMs == null
              ? 'NOT SET'
              : '${(valueMs / 1000).toStringAsFixed(2)}s',
          onChanged: (value) => _updateDuration(travel, (value * 1000).round()),
        ),
      ],
    );
  }
}

class _Scene2CompositeTestPage extends StatefulWidget {
  const _Scene2CompositeTestPage({required this.session});

  final Scene2CalibrationSession session;

  @override
  State<_Scene2CompositeTestPage> createState() =>
      _Scene2CompositeTestPageState();
}

class _Scene2CompositeTestPageState extends State<_Scene2CompositeTestPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.session.totalDuration ?? const Duration(milliseconds: 1),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _play({bool restart = false}) {
    if (!widget.session.isComplete) return;
    _controller.duration = widget.session.totalDuration;
    _controller.forward(from: restart ? 0 : null);
  }

  void _stop() {
    _controller
      ..stop(canceled: false)
      ..value = 0;
    setState(() {});
  }

  String get _parametersJson => const JsonEncoder.withIndent(
    '  ',
  ).convert(widget.session.compositeParameters);

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _parametersJson));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('CODEX PARAMETERSをコピーしました')));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('SCENE 2 COMPOSITE TEST')),
    body: AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => ListView(
        padding: AppSpacing.cardPadding,
        children: [
          const SectionHeader(
            icon: Icons.layers_outlined,
            title: 'COMPOSITE TEST',
          ),
          AppSpacing.gapSM,
          OperationCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AspectRatio(
                  aspectRatio: 3 / 2,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: widget.session.isComplete
                        ? _Scene2Preview(
                            key: const ValueKey('scene-2-composite-preview'),
                            progress: _controller.value,
                            session: widget.session,
                            jeepAsset: _scene2JeepAsset,
                            showTarget: true,
                          )
                        : const _ScenePlaceholder(
                            label: 'SCENE 2 PARAMETERS NOT SET',
                          ),
                  ),
                ),
                AppSpacing.gapMD,
                _Scene2PlaybackControls(
                  enabled: widget.session.isComplete,
                  onPlay: _play,
                  onPause: () {
                    _controller.stop(canceled: false);
                    setState(() {});
                  },
                  onStop: _stop,
                  onReplay: () => _play(restart: true),
                ),
              ],
            ),
          ),
          AppSpacing.gapXL,
          _Scene2ParametersCard(
            json: _parametersJson,
            jsonKey: 'scene-2-composite-parameters-json',
            copyKey: 'copy-scene-2-composite-parameters',
            onCopy: _copy,
          ),
          AppSpacing.gapLG,
        ],
      ),
    ),
  );
}

class _Scene2PlaybackControls extends StatelessWidget {
  const _Scene2PlaybackControls({
    required this.enabled,
    required this.onPlay,
    required this.onPause,
    required this.onStop,
    required this.onReplay,
  });

  final bool enabled;
  final VoidCallback onPlay;
  final VoidCallback onPause;
  final VoidCallback onStop;
  final VoidCallback onReplay;

  @override
  Widget build(BuildContext context) => Wrap(
    key: const ValueKey('scene-2-playback-controls'),
    spacing: AppSpacing.sm,
    runSpacing: AppSpacing.sm,
    children: [
      ElevatedButton(
        onPressed: enabled ? onPlay : null,
        child: const Text('TEST PLAY'),
      ),
      ElevatedButton(
        onPressed: enabled ? onPause : null,
        child: const Text('PAUSE'),
      ),
      ElevatedButton(
        onPressed: enabled ? onStop : null,
        child: const Text('STOP'),
      ),
      ElevatedButton(
        onPressed: enabled ? onReplay : null,
        child: const Text('REPLAY'),
      ),
    ],
  );
}

class _Scene2SnapshotFields extends StatelessWidget {
  const _Scene2SnapshotFields({
    required this.label,
    required this.snapshot,
    required this.onChanged,
  });

  final String label;
  final _CalibrationSnapshot? snapshot;
  final void Function(String, String) onChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(label, style: Theme.of(context).textTheme.titleSmall),
      AppSpacing.gapSM,
      Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          for (final entry in <String, double?>{
            'x': snapshot?.alignment.x,
            'y': snapshot?.alignment.y,
            'scale': snapshot?.scale,
          }.entries)
            SizedBox(
              width: 150,
              child: _Scene2NumberField(
                key: ValueKey(
                  'scene-2-${label.toLowerCase().replaceAll(' ', '-')}-${entry.key}',
                ),
                label: entry.key.toUpperCase(),
                value: entry.value,
                onChanged: (value) => onChanged(entry.key, value),
              ),
            ),
        ],
      ),
    ],
  );
}

class _Scene2NumberField extends StatefulWidget {
  const _Scene2NumberField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final num? value;
  final ValueChanged<String> onChanged;

  @override
  State<_Scene2NumberField> createState() => _Scene2NumberFieldState();
}

class _Scene2NumberFieldState extends State<_Scene2NumberField> {
  final _focusNode = FocusNode();
  late final TextEditingController _controller = TextEditingController(
    text: widget.value?.toString() ?? '',
  );

  @override
  void didUpdateWidget(covariant _Scene2NumberField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && !_focusNode.hasFocus) {
      _controller.text = widget.value?.toString() ?? '';
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
    controller: _controller,
    focusNode: _focusNode,
    keyboardType: const TextInputType.numberWithOptions(
      decimal: true,
      signed: true,
    ),
    decoration: InputDecoration(labelText: widget.label, hintText: 'NOT SET'),
    onChanged: widget.onChanged,
  );
}

class _Scene2NullableValues extends StatelessWidget {
  const _Scene2NullableValues({
    required this.session,
    required this.includeMotion,
  });

  final Scene2CalibrationSession session;
  final bool includeMotion;

  @override
  Widget build(BuildContext context) => Text(
    'JEEP X ${session._jeepAlignment?.x.toStringAsFixed(3) ?? 'NOT SET'}  '
    'Y ${session._jeepAlignment?.y.toStringAsFixed(3) ?? 'NOT SET'}\n'
    'LOGO X ${session._logoTarget?.dx.toStringAsFixed(3) ?? 'NOT SET'}  '
    'Y ${session._logoTarget?.dy.toStringAsFixed(3) ?? 'NOT SET'}',
    key: const ValueKey('scene-2-layout-live-values'),
    style: Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
  );
}

class _Scene2ParametersCard extends StatelessWidget {
  const _Scene2ParametersCard({
    required this.json,
    required this.jsonKey,
    required this.copyKey,
    required this.onCopy,
  });

  final String json;
  final String jsonKey;
  final String copyKey;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SectionHeader(icon: Icons.data_object, title: 'CODEX PARAMETERS'),
      AppSpacing.gapSM,
      OperationCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SelectableText(
              json,
              key: ValueKey(jsonKey),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
            ),
            AppSpacing.gapMD,
            _SandboxActionButton(
              key: ValueKey(copyKey),
              text: 'COPY PARAMETERS',
              icon: Icons.copy_outlined,
              onPressed: onCopy,
            ),
          ],
        ),
      ),
    ],
  );
}

Rect _scene2JeepGeometry(Size canvasSize, Alignment alignment, double scale) {
  final baseWidth = (canvasSize.width * 0.62).clamp(120.0, 520.0);
  final width = baseWidth * scale;
  final height = width * (887 / 1774);
  final center = Offset(
    ((alignment.x + 1) / 2) * canvasSize.width,
    ((alignment.y + 1) / 2) * canvasSize.height,
  );
  return Rect.fromCenter(center: center, width: width, height: height);
}

class _Scene2StaticComposition extends StatelessWidget {
  const _Scene2StaticComposition({
    required this.session,
    required this.showTarget,
  });

  final Scene2CalibrationSession session;
  final bool showTarget;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      Image.asset(
        _bootSequenceAssets[0].path,
        key: const ValueKey('scene-2-background'),
        fit: BoxFit.cover,
      ),
      LayoutBuilder(
        builder: (context, constraints) {
          final geometry = _scene2JeepGeometry(
            constraints.biggest,
            session._jeepAlignment ?? Alignment.center,
            session._jeepScale ?? 1,
          );
          return Stack(
            children: [
              Positioned.fromRect(
                rect: geometry,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(
                      _scene2JeepAsset,
                      key: const ValueKey('scene-2-jeep-side'),
                      fit: BoxFit.contain,
                    ),
                    if (showTarget && session._logoTarget != null)
                      Positioned(
                        key: const ValueKey('scene-2-logo-target'),
                        left: (session._logoTarget!.dx * geometry.width) - 10,
                        top: (session._logoTarget!.dy * geometry.height) - 10,
                        child: const Icon(
                          Icons.adjust,
                          color: Colors.cyanAccent,
                          size: 20,
                        ),
                      ),
                  ],
                ),
              ),
              if (!session.hasLayout)
                const Positioned(
                  left: 8,
                  top: 8,
                  child: _CalibrationStatusBadge(text: 'LAYOUT NOT SET'),
                ),
            ],
          );
        },
      ),
    ],
  );
}

class _CalibrationStatusBadge extends StatelessWidget {
  const _CalibrationStatusBadge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.68),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Text(text),
    ),
  );
}

class _Scene2CenterGuide extends StatelessWidget {
  const _Scene2CenterGuide();

  @override
  Widget build(BuildContext context) => Center(
    child: SizedBox(
      key: const ValueKey('scene-2-center-guide'),
      width: 32,
      height: 32,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(width: 1, color: Colors.cyanAccent.withValues(alpha: 0.8)),
          Container(height: 1, color: Colors.cyanAccent.withValues(alpha: 0.8)),
        ],
      ),
    ),
  );
}

class _Scene2CameraPreview extends StatelessWidget {
  const _Scene2CameraPreview({
    required this.view,
    required this.session,
    required this.showTarget,
  });

  final _CalibrationSnapshot view;
  final Scene2CalibrationSession session;
  final bool showTarget;

  @override
  Widget build(BuildContext context) => ClipRect(
    child: LayoutBuilder(
      builder: (context, constraints) => Transform(
        key: const ValueKey('scene-2-camera-transform'),
        alignment: _scene2CameraTransformOrigin,
        transform: _scene2CameraTransform(constraints.biggest, view),
        child: _Scene2StaticComposition(
          session: session,
          showTarget: showTarget,
        ),
      ),
    ),
  );
}

class _Scene2Preview extends StatelessWidget {
  const _Scene2Preview({
    super.key,
    required this.progress,
    required this.session,
    required this.jeepAsset,
    required this.showTarget,
  });

  final double progress;
  final Scene2CalibrationSession session;
  final String jeepAsset;
  final bool showTarget;

  @override
  Widget build(BuildContext context) {
    final totalMs = session._travelDurationMs! + session._holdDurationMs!;
    final travelFraction = totalMs == 0
        ? 1.0
        : session._travelDurationMs! / totalMs;
    final raw = travelFraction == 0
        ? 1.0
        : (progress / travelFraction).clamp(0.0, 1.0);
    final eased = session._curve!.curve.transform(raw.toDouble());
    final start = session._cameraStart!;
    final end = session._cameraEnd!;
    final cameraAlignment = Alignment.lerp(
      start.alignment,
      end.alignment,
      eased,
    )!;
    final cameraScale = start.scale + ((end.scale - start.scale) * eased);

    return _Scene2CameraPreview(
      view: _CalibrationSnapshot(
        alignment: cameraAlignment,
        scale: cameraScale,
      ),
      session: session,
      showTarget: showTarget,
    );
  }
}

class _BootSequencePreview extends StatelessWidget {
  const _BootSequencePreview({
    super.key,
    required this.sceneIndex,
    required this.progress,
    required this.backgroundAsset,
    required this.jeepBodyAsset,
    required this.wheelAsset,
    required this.sceneLabel,
    required this.headlight,
    required this.dust,
    required this.suspension,
    required this.suspensionProgress,
    required this.scene2Session,
    required this.scene2JeepAsset,
  });

  final int sceneIndex;
  final double progress;
  final String backgroundAsset;
  final String jeepBodyAsset;
  final String wheelAsset;
  final String sceneLabel;
  final _HeadlightParameters? headlight;
  final _DustParameters? dust;
  final _SuspensionParameters? suspension;
  final double suspensionProgress;
  final Scene2CalibrationSession scene2Session;
  final String scene2JeepAsset;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 800),
      child: AspectRatio(
        aspectRatio: 3 / 2,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: switch (sceneIndex) {
            0 => _JeepApproachPrototype(
              progress: progress,
              backgroundAsset: backgroundAsset,
              jeepBodyAsset: jeepBodyAsset,
              wheelAsset: wheelAsset,
              headlight: headlight,
              dust: dust,
              suspension: suspension,
              suspensionProgress: suspensionProgress,
            ),
            1 when scene2Session.isComplete => _Scene2Preview(
              key: const ValueKey('scene-2-normal-preview'),
              progress: progress,
              session: scene2Session,
              jeepAsset: scene2JeepAsset,
              showTarget: false,
            ),
            _ => _ScenePlaceholder(label: sceneLabel),
          },
        ),
      ),
    ),
  );
}

class _ScenePlaceholder extends StatelessWidget {
  const _ScenePlaceholder({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('scene-placeholder-content'),
    alignment: Alignment.center,
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.animation_outlined,
          size: 40,
          color: Theme.of(context).colorScheme.primary,
        ),
        AppSpacing.gapSM,
        Text(
          label,
          key: const ValueKey('current-scene'),
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ],
    ),
  );
}

class _JeepApproachPrototype extends StatelessWidget {
  const _JeepApproachPrototype({
    required this.progress,
    required this.backgroundAsset,
    required this.jeepBodyAsset,
    required this.wheelAsset,
    required this.headlight,
    required this.dust,
    required this.suspension,
    required this.suspensionProgress,
  });

  final double progress;
  final String backgroundAsset;
  final String jeepBodyAsset;
  final String wheelAsset;
  final _HeadlightParameters? headlight;
  final _DustParameters? dust;
  final _SuspensionParameters? suspension;
  final double suspensionProgress;

  @override
  Widget build(BuildContext context) {
    final travelFraction =
        _scene1TravelDuration.inMilliseconds /
        _scene1TotalDuration.inMilliseconds;
    final motionProgress = (progress / travelFraction).clamp(0.0, 1.0);
    final alignment = Alignment.lerp(
      _scene1Start.alignment,
      _scene1End.alignment,
      motionProgress,
    )!;
    final scale =
        _scene1Start.scale +
        ((_scene1End.scale - _scene1Start.scale) * motionProgress);
    final suspensionY = suspension == null
        ? 0.0
        : _suspensionYOffset(suspension!, suspensionProgress);
    final elapsedMs = progress * _scene1TotalDuration.inMilliseconds;
    final dustVisible =
        dust != null &&
        progress > 0 &&
        elapsedMs <= _scene1TravelDuration.inMilliseconds + dust!.lifetimeMs;

    return Stack(
      key: const ValueKey('jeep-scene-canvas'),
      fit: StackFit.expand,
      children: [
        Image.asset(
          backgroundAsset,
          key: const ValueKey('boot-sequence-background'),
          fit: BoxFit.cover,
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final canvasSize = constraints.biggest;
            final assemblyWidth = (constraints.maxWidth * 0.38)
                .clamp(120.0, 320.0)
                .toDouble();
            final assemblyHeight = assemblyWidth * (941 / 1672);
            return Stack(
              fit: StackFit.expand,
              children: [
                Positioned(
                  key: const ValueKey('jeep-assembly-position'),
                  left:
                      (((alignment.x + 1) / 2) * canvasSize.width) -
                      (assemblyWidth / 2),
                  top:
                      (((alignment.y + 1) / 2) * canvasSize.height) -
                      (assemblyHeight / 2),
                  width: assemblyWidth,
                  height: assemblyHeight,
                  child: Transform.translate(
                    key: const ValueKey('scene-1-suspension-offset'),
                    offset: Offset(0, suspensionY),
                    child: Transform.scale(
                      key: const ValueKey('jeep-assembly-scale'),
                      scale: scale,
                      child: _CompositeJeepAssembly(
                        width: assemblyWidth,
                        bodyAsset: jeepBodyAsset,
                        wheelAsset: wheelAsset,
                        headlight: headlight,
                        dust: dustVisible ? dust : null,
                        dustProgress: progress,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        const Positioned(left: 8, top: 8, child: _SceneBadge()),
      ],
    );
  }
}

class _SceneBadge extends StatelessWidget {
  const _SceneBadge();

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.64),
      borderRadius: BorderRadius.circular(8),
    ),
    child: const Padding(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Text('SCENE 1', key: ValueKey('current-scene')),
    ),
  );
}

class _JeepAssembly extends StatelessWidget {
  const _JeepAssembly({
    required this.width,
    required this.bodyAsset,
    required this.wheelAsset,
  });

  final double width;
  final String bodyAsset;
  final String wheelAsset;

  @override
  Widget build(BuildContext context) {
    final height = width * (941 / 1672);
    return SizedBox(
      key: const ValueKey('jeep-assembly'),
      width: width,
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          _SceneWheel(
            key: const ValueKey('jeep-front-wheel-far-layer'),
            imageKey: const ValueKey('jeep-front-wheel-far'),
            width: width,
            height: height,
            asset: wheelAsset,
            calibration: _scene1FrontWheelFar,
          ),
          Positioned.fill(
            key: const ValueKey('jeep-body-layer'),
            child: Image.asset(
              bodyAsset,
              key: const ValueKey('jeep-body'),
              fit: BoxFit.contain,
            ),
          ),
          _SceneWheel(
            key: const ValueKey('jeep-rear-wheel-layer'),
            imageKey: const ValueKey('jeep-rear-wheel'),
            width: width,
            height: height,
            asset: wheelAsset,
            calibration: _scene1RearWheel,
          ),
          _SceneWheel(
            key: const ValueKey('jeep-front-wheel-near-layer'),
            imageKey: const ValueKey('jeep-front-wheel-near'),
            width: width,
            height: height,
            asset: wheelAsset,
            calibration: _scene1FrontWheelNear,
          ),
        ],
      ),
    );
  }
}

class _SceneWheel extends StatelessWidget {
  const _SceneWheel({
    super.key,
    required this.imageKey,
    required this.width,
    required this.height,
    required this.asset,
    required this.calibration,
  });

  final Key imageKey;
  final double width;
  final double height;
  final String asset;
  final _WheelCalibration calibration;

  @override
  Widget build(BuildContext context) {
    final size = width * calibration.scale;
    return Positioned(
      left: width * calibration.localX,
      top: height * calibration.localY,
      width: size,
      height: size,
      child: Image.asset(asset, key: imageKey, fit: BoxFit.contain),
    );
  }
}

class _SandboxActionButton extends StatelessWidget {
  const _SandboxActionButton({
    super.key,
    required this.text,
    required this.icon,
    required this.onPressed,
  });

  final String text;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    height: 52,
    child: ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      label: FittedBox(fit: BoxFit.scaleDown, child: Text(text)),
    ),
  );
}
