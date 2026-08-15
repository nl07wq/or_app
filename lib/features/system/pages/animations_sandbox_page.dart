import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/navigation/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/operation_card.dart';
import '../../../core/widgets/section_header.dart';

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
  const AnimationsSandboxPage({super.key});

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
      ],
    ),
  );
}

class BootSequencePreviewPage extends StatefulWidget {
  const BootSequencePreviewPage({super.key});

  @override
  State<BootSequencePreviewPage> createState() =>
      _BootSequencePreviewPageState();
}

class _BootSequencePreviewPageState extends State<BootSequencePreviewPage>
    with SingleTickerProviderStateMixin {
  static const _sceneCount = 8;
  static const _prototypeDuration = Duration(seconds: 6);
  static const _placeholderDuration = Duration(seconds: 8);

  int _selectedSceneIndex = 0;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _prototypeDuration,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _sceneLabel(int index) =>
      index == _sceneCount - 1 ? 'FINAL' : 'SCENE ${index + 1}';

  Duration get _activeDuration =>
      _selectedSceneIndex == 0 ? _prototypeDuration : _placeholderDuration;

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
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

  void _selectScene(int index) {
    _controller.stop(canceled: false);
    _controller.reset();
    setState(() {
      _selectedSceneIndex = index;
      _controller.duration = _activeDuration;
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('BOOT SEQUENCE')),
    body: AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final elapsed = Duration(
          milliseconds: (_activeDuration.inMilliseconds * _controller.value)
              .round(),
        );
        return ListView(
          padding: AppSpacing.cardPadding,
          children: [
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
                onPressed: () => Navigator.pushNamed(
                  context,
                  AppRoutes.bootSequenceCalibration,
                ),
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

class BootSequenceCalibrationPage extends StatefulWidget {
  const BootSequenceCalibrationPage({super.key});

  @override
  State<BootSequenceCalibrationPage> createState() =>
      _BootSequenceCalibrationPageState();
}

class _BootSequenceCalibrationPageState
    extends State<BootSequenceCalibrationPage> {
  final _session = _CalibrationSession();

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
      ],
    ),
  );
}

class _CalibrationSession {
  _WheelCalibration? frontWheelFar;
  _WheelCalibration rearWheel = const _WheelCalibration(
    localX: 0.779,
    localY: 0.587,
    scale: 0.185,
  );
  _WheelCalibration frontWheelNear = const _WheelCalibration(
    localX: 0.330,
    localY: 0.593,
    scale: 0.245,
  );

  _WheelCalibration get frontWheelFarDisplay =>
      frontWheelFar ??
      const _WheelCalibration(localX: 0.5, localY: 0.5, scale: 0.2);
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
    _CalibrationTarget.frontWheelFar => widget.session.frontWheelFarDisplay,
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

  Map<String, Object?> _wheelJson(_WheelCalibration? value) => {
    'asset': _bootSequenceAssets[2].path,
    'localX': value == null ? null : _rounded(value.localX),
    'localY': value == null ? null : _rounded(value.localY),
    'scale': value == null ? null : _rounded(value.scale),
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
                if (_selectedTarget == _CalibrationTarget.frontWheelFar &&
                    widget.session.frontWheelFar == null) ...[
                  AppSpacing.gapSM,
                  const Text(
                    'NOT SET',
                    key: ValueKey('front-wheel-far-not-set'),
                  ),
                ],
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
                _CalibrationTarget.frontWheelFar =>
                  session.frontWheelFarDisplay,
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
                        frontWheelFar: session.frontWheelFarDisplay,
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

class _MotionCalibrationPageState extends State<_MotionCalibrationPage>
    with SingleTickerProviderStateMixin {
  static const _initialStart = _CalibrationSnapshot(
    alignment: Alignment(0.997, 0.452),
    scale: 0.320,
  );
  static const _initialEnd = _CalibrationSnapshot(
    alignment: Alignment(-0.367, 0.940),
    scale: 1.190,
  );

  Alignment _jeepAlignment = _initialStart.alignment;
  double _jeepScale = _initialStart.scale;
  _CalibrationSnapshot _start = _initialStart;
  _CalibrationSnapshot _end = _initialEnd;
  double _travelDurationSeconds = 4.5;
  double _holdDurationSeconds = 1.5;
  _CalibrationCurveOption _curve = _CalibrationCurveOption.easeOut;

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
                  wheelTurns: -4 * _travelProgress,
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
    required this.wheelTurns,
    required this.onMoveJeep,
  });

  final Alignment alignment;
  final double scale;
  final _CalibrationSession session;
  final double wheelTurns;
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
                          frontWheelFar: session.frontWheelFarDisplay,
                          rearWheel: session.rearWheel,
                          frontWheelNear: session.frontWheelNear,
                          wheelTurns: wheelTurns,
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
    this.wheelTurns = 0,
  });

  final double width;
  final _CalibrationTarget selectedTarget;
  final _WheelCalibration frontWheelFar;
  final _WheelCalibration rearWheel;
  final _WheelCalibration frontWheelNear;
  final double wheelTurns;

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
            turns: wheelTurns,
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
            turns: wheelTurns,
          ),
          _CalibrationWheel(
            key: const ValueKey('calibration-front-wheel-near-layer'),
            imageKey: const ValueKey('calibration-front-wheel-near'),
            width: width,
            height: height,
            calibration: frontWheelNear,
            selected: selectedTarget == _CalibrationTarget.frontWheelNear,
            turns: wheelTurns,
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
    required this.turns,
  });

  final Key imageKey;
  final double width;
  final double height;
  final _WheelCalibration calibration;
  final bool selected;
  final double turns;

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
        child: RotationTransition(
          turns: AlwaysStoppedAnimation(turns),
          child: Image.asset(
            _bootSequenceAssets[2].path,
            key: imageKey,
            fit: BoxFit.contain,
          ),
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

class _BootSequencePreview extends StatelessWidget {
  const _BootSequencePreview({
    super.key,
    required this.sceneIndex,
    required this.progress,
    required this.backgroundAsset,
    required this.jeepBodyAsset,
    required this.wheelAsset,
    required this.sceneLabel,
  });

  final int sceneIndex;
  final double progress;
  final String backgroundAsset;
  final String jeepBodyAsset;
  final String wheelAsset;
  final String sceneLabel;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 800),
      child: AspectRatio(
        aspectRatio: 3 / 2,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: sceneIndex == 0
              ? _JeepApproachPrototype(
                  progress: progress,
                  backgroundAsset: backgroundAsset,
                  jeepBodyAsset: jeepBodyAsset,
                  wheelAsset: wheelAsset,
                )
              : _ScenePlaceholder(label: sceneLabel),
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
  });

  static const _motionEnd = 0.75;

  final double progress;
  final String backgroundAsset;
  final String jeepBodyAsset;
  final String wheelAsset;

  @override
  Widget build(BuildContext context) {
    final motionProgress = Curves.easeOutCubic.transform(
      (progress / _motionEnd).clamp(0.0, 1.0).toDouble(),
    );
    final alignment = Alignment.lerp(
      const Alignment(0.88, -0.58),
      const Alignment(-0.32, 0.62),
      motionProgress,
    )!;
    final scale = 0.22 + (0.70 * motionProgress);

    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          backgroundAsset,
          key: const ValueKey('boot-sequence-background'),
          fit: BoxFit.cover,
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final assemblyWidth = (constraints.maxWidth * 0.38)
                .clamp(150.0, 320.0)
                .toDouble();
            return Align(
              key: const ValueKey('jeep-assembly-position'),
              alignment: alignment,
              child: Transform.scale(
                key: const ValueKey('jeep-assembly-scale'),
                scale: scale,
                child: _JeepAssembly(
                  width: assemblyWidth,
                  bodyAsset: jeepBodyAsset,
                  wheelAsset: wheelAsset,
                  wheelTurns: -4 * motionProgress,
                ),
              ),
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
    required this.wheelTurns,
  });

  final double width;
  final String bodyAsset;
  final String wheelAsset;
  final double wheelTurns;

  @override
  Widget build(BuildContext context) {
    final height = width * (941 / 1672);
    final frontWheelSize = width * 0.205;
    final rearWheelSize = width * 0.195;
    return SizedBox(
      key: const ValueKey('jeep-assembly'),
      width: width,
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: width * 0.226,
            top: height * 0.546,
            width: frontWheelSize,
            height: frontWheelSize,
            child: RotationTransition(
              key: const ValueKey('jeep-front-wheel-rotation'),
              turns: AlwaysStoppedAnimation(wheelTurns),
              child: Image.asset(
                wheelAsset,
                key: const ValueKey('jeep-front-wheel'),
              ),
            ),
          ),
          Positioned(
            left: width * 0.760,
            top: height * 0.558,
            width: rearWheelSize,
            height: rearWheelSize,
            child: RotationTransition(
              key: const ValueKey('jeep-rear-wheel-rotation'),
              turns: AlwaysStoppedAnimation(wheelTurns),
              child: Image.asset(
                wheelAsset,
                key: const ValueKey('jeep-rear-wheel'),
              ),
            ),
          ),
          Positioned.fill(
            child: Image.asset(
              bodyAsset,
              key: const ValueKey('jeep-body'),
              fit: BoxFit.contain,
            ),
          ),
        ],
      ),
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
