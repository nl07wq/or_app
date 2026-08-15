import 'package:flutter/material.dart';

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
    usage: 'USED ×2',
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
