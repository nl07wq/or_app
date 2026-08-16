import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/operation_card.dart';
import '../../../core/widgets/section_header.dart';

const pixelLabAssetPrefix = 'assets/animations/sandbox/pixel_lab/';
const pixelLabPixelSizes = <int>[1, 2, 4, 8, 12, 16, 24, 32];

typedef PixelLabAssetLoader = Future<List<String>> Function();

Future<List<String>> loadPixelLabAssetPaths() async {
  final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
  return filterPixelLabAssetPaths(manifest.listAssets());
}

@visibleForTesting
List<String> filterPixelLabAssetPaths(Iterable<String> paths) {
  final result =
      paths
          .where(
            (path) =>
                path.startsWith(pixelLabAssetPrefix) &&
                path.toLowerCase().endsWith('.png'),
          )
          .toSet()
          .toList()
        ..sort();
  return result;
}

enum PixelLabBackground { black, white, checker }

enum PixelLabColorMode { original, tint, monochromeTint }

enum PixelLabPresetColor { white, red, blue, green, amber, cyan }

class PixelLabPage extends StatefulWidget {
  const PixelLabPage({super.key, this.assetLoader});

  final PixelLabAssetLoader? assetLoader;

  @override
  State<PixelLabPage> createState() => _PixelLabPageState();
}

class _PixelLabPageState extends State<PixelLabPage> {
  late final Future<List<String>> _assets =
      (widget.assetLoader ?? loadPixelLabAssetPaths)();

  String? _selectedAsset;
  bool _pixelationEnabled = false;
  int _pixelSize = 8;
  double _imageScale = 1;
  PixelLabBackground _background = PixelLabBackground.black;
  PixelLabColorMode _colorMode = PixelLabColorMode.original;
  PixelLabPresetColor _targetColor = PixelLabPresetColor.white;
  double _intensity = 0.5;
  double _brightness = 1;
  double _contrast = 1;
  double _saturation = 1;

  void _reset() {
    setState(() {
      _pixelationEnabled = false;
      _pixelSize = 8;
      _imageScale = 1;
      _background = PixelLabBackground.black;
      _colorMode = PixelLabColorMode.original;
      _targetColor = PixelLabPresetColor.white;
      _intensity = 0.5;
      _brightness = 1;
      _contrast = 1;
      _saturation = 1;
    });
  }

  Color get _targetColorValue => switch (_targetColor) {
    PixelLabPresetColor.white => Colors.white,
    PixelLabPresetColor.red => AppColors.danger,
    PixelLabPresetColor.blue => AppColors.primary,
    PixelLabPresetColor.green => AppColors.success,
    PixelLabPresetColor.amber => AppColors.warning,
    PixelLabPresetColor.cyan => AppColors.information,
  };

  String _hex(Color color) =>
      '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';

  String _parametersJson(String? asset) =>
      const JsonEncoder.withIndent('  ').convert({
        'labType': 'pixel_asset_test',
        'asset': asset,
        'pixelation': {'enabled': _pixelationEnabled, 'pixelSize': _pixelSize},
        'display': {'scale': _rounded(_imageScale), 'aspectLocked': true},
        'background': {'mode': _background.name},
        'color': {
          'mode': switch (_colorMode) {
            PixelLabColorMode.original => 'original',
            PixelLabColorMode.tint => 'tint',
            PixelLabColorMode.monochromeTint => 'monochrome_tint',
          },
          'targetColor': _hex(_targetColorValue),
          'intensity': _rounded(_intensity),
          'brightness': _rounded(_brightness),
          'contrast': _rounded(_contrast),
          'saturation': _rounded(_saturation),
        },
      });

  Future<void> _copyParameters(String json) async {
    await Clipboard.setData(ClipboardData(text: json));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('CODEX PARAMETERS COPIED')));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('PIXEL LAB')),
    body: FutureBuilder<List<String>>(
      future: _assets,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final assets = snapshot.data ?? const <String>[];
        final selected = assets.contains(_selectedAsset)
            ? _selectedAsset
            : assets.firstOrNull;
        final json = _parametersJson(selected);
        return ListView(
          key: const ValueKey('pixel-lab-scroll'),
          padding: AppSpacing.cardPadding,
          children: [
            const SectionHeader(
              icon: Icons.image_search_outlined,
              title: 'ASSET SELECTOR',
            ),
            AppSpacing.gapSM,
            OperationCard(
              child: assets.isEmpty
                  ? const Text(
                      'NO PNG ASSETS\n'
                      'assets/animations/sandbox/pixel_lab/ にPNGを配置してください。',
                      key: ValueKey('pixel-lab-empty-state'),
                    )
                  : _AssetSelector(
                      assets: assets,
                      selected: selected!,
                      onSelected: (path) =>
                          setState(() => _selectedAsset = path),
                    ),
            ),
            AppSpacing.gapXL,
            const SectionHeader(
              icon: Icons.preview_outlined,
              title: 'MAIN PREVIEW',
            ),
            AppSpacing.gapSM,
            OperationCard(
              child: _PixelLabCanvas(
                key: const ValueKey('pixel-lab-main-preview'),
                assetPath: selected,
                background: _background,
                pixelationEnabled: _pixelationEnabled,
                pixelSize: _pixelSize,
                imageScale: _imageScale,
                colorMode: _colorMode,
                targetColor: _targetColorValue,
                intensity: _intensity,
                brightness: _brightness,
                contrast: _contrast,
                saturation: _saturation,
              ),
            ),
            AppSpacing.gapXL,
            const SectionHeader(
              icon: Icons.tune_outlined,
              title: 'PIXEL CONTROLS',
            ),
            AppSpacing.gapSM,
            OperationCard(child: _buildPixelControls()),
            AppSpacing.gapXL,
            const SectionHeader(
              icon: Icons.palette_outlined,
              title: 'COLOR CONTROLS',
            ),
            AppSpacing.gapSM,
            OperationCard(child: _buildColorControls()),
            AppSpacing.gapXL,
            const SectionHeader(
              icon: Icons.monitor_outlined,
              title: 'CURRENT VALUES',
            ),
            AppSpacing.gapSM,
            OperationCard(child: _CurrentValues(json: json)),
            AppSpacing.gapXL,
            const SectionHeader(
              icon: Icons.layers_outlined,
              title: 'COMPOSITE PREVIEW',
            ),
            AppSpacing.gapSM,
            OperationCard(
              child: _PixelLabCanvas(
                key: const ValueKey('pixel-lab-composite-preview'),
                assetPath: selected,
                background: PixelLabBackground.black,
                pixelationEnabled: _pixelationEnabled,
                pixelSize: _pixelSize,
                imageScale: _imageScale,
                colorMode: _colorMode,
                targetColor: _targetColorValue,
                intensity: _intensity,
                brightness: _brightness,
                contrast: _contrast,
                saturation: _saturation,
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
                    json,
                    key: const ValueKey('pixel-lab-parameters-json'),
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
                  ),
                  AppSpacing.gapMD,
                  OutlinedButton.icon(
                    key: const ValueKey('pixel-lab-copy-parameters'),
                    onPressed: () => _copyParameters(json),
                    icon: const Icon(Icons.copy_outlined),
                    label: const Text('COPY PARAMETERS'),
                  ),
                  AppSpacing.gapSM,
                  OutlinedButton.icon(
                    key: const ValueKey('pixel-lab-reset'),
                    onPressed: _reset,
                    icon: const Icon(Icons.restart_alt_outlined),
                    label: const Text('RESET TO DEFAULT'),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    ),
  );

  Widget _buildPixelControls() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SwitchListTile(
        key: const ValueKey('pixel-lab-pixelation-toggle'),
        contentPadding: EdgeInsets.zero,
        title: const Text('PIXELATION'),
        subtitle: Text(_pixelationEnabled ? 'ON' : 'OFF'),
        value: _pixelationEnabled,
        onChanged: (value) => setState(() => _pixelationEnabled = value),
      ),
      _PixelLabSlider(
        sliderKey: 'pixel-lab-pixel-size',
        label: 'PIXEL SIZE',
        value: pixelLabPixelSizes.indexOf(_pixelSize).toDouble(),
        min: 0,
        max: (pixelLabPixelSizes.length - 1).toDouble(),
        divisions: pixelLabPixelSizes.length - 1,
        displayValue: '$_pixelSize',
        enabled: _pixelationEnabled,
        onChanged: (value) =>
            setState(() => _pixelSize = pixelLabPixelSizes[value.round()]),
      ),
      _PixelLabSlider(
        sliderKey: 'pixel-lab-image-scale',
        label: 'IMAGE SCALE',
        value: _imageScale,
        min: 0.25,
        max: 2,
        divisions: 35,
        displayValue: _imageScale.toStringAsFixed(2),
        onChanged: (value) => setState(() => _imageScale = value),
      ),
      const Text('ASPECT RATIO  LOCKED'),
      AppSpacing.gapMD,
      const Text('BACKGROUND'),
      AppSpacing.gapSM,
      _ChoiceWrap<PixelLabBackground>(
        values: PixelLabBackground.values,
        selected: _background,
        label: (value) => value.name.toUpperCase(),
        keyFor: (value) => 'pixel-lab-background-${value.name}',
        onSelected: (value) => setState(() => _background = value),
      ),
    ],
  );

  Widget _buildColorControls() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text('COLOR MODE'),
      AppSpacing.gapSM,
      _ChoiceWrap<PixelLabColorMode>(
        values: PixelLabColorMode.values,
        selected: _colorMode,
        label: (value) => switch (value) {
          PixelLabColorMode.original => 'ORIGINAL',
          PixelLabColorMode.tint => 'TINT',
          PixelLabColorMode.monochromeTint => 'MONOCHROME TINT',
        },
        keyFor: (value) => 'pixel-lab-color-mode-${value.name}',
        onSelected: (value) => setState(() => _colorMode = value),
      ),
      AppSpacing.gapMD,
      const Text('TARGET COLOR'),
      AppSpacing.gapSM,
      _ChoiceWrap<PixelLabPresetColor>(
        values: PixelLabPresetColor.values,
        selected: _targetColor,
        label: (value) => value.name.toUpperCase(),
        keyFor: (value) => 'pixel-lab-color-${value.name}',
        onSelected: (value) => setState(() => _targetColor = value),
      ),
      AppSpacing.gapMD,
      _PixelLabSlider(
        sliderKey: 'pixel-lab-intensity',
        label: 'INTENSITY',
        value: _intensity,
        min: 0,
        max: 1,
        divisions: 20,
        displayValue: _intensity.toStringAsFixed(2),
        enabled: _colorMode != PixelLabColorMode.original,
        onChanged: (value) => setState(() => _intensity = value),
      ),
      _PixelLabSlider(
        sliderKey: 'pixel-lab-brightness',
        label: 'BRIGHTNESS',
        value: _brightness,
        min: 0.5,
        max: 1.5,
        divisions: 20,
        displayValue: _brightness.toStringAsFixed(2),
        onChanged: (value) => setState(() => _brightness = value),
      ),
      _PixelLabSlider(
        sliderKey: 'pixel-lab-contrast',
        label: 'CONTRAST',
        value: _contrast,
        min: 0.5,
        max: 2,
        divisions: 30,
        displayValue: _contrast.toStringAsFixed(2),
        onChanged: (value) => setState(() => _contrast = value),
      ),
      _PixelLabSlider(
        sliderKey: 'pixel-lab-saturation',
        label: 'SATURATION',
        value: _saturation,
        min: 0,
        max: 2,
        divisions: 40,
        displayValue: _saturation.toStringAsFixed(2),
        enabled: _colorMode != PixelLabColorMode.monochromeTint,
        onChanged: (value) => setState(() => _saturation = value),
      ),
    ],
  );
}

class _AssetSelector extends StatelessWidget {
  const _AssetSelector({
    required this.assets,
    required this.selected,
    required this.onSelected,
  });

  final List<String> assets;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final itemWidth = constraints.maxWidth < 560
          ? constraints.maxWidth
          : (constraints.maxWidth - AppSpacing.md) / 2;
      return Wrap(
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.md,
        children: [
          for (final path in assets)
            SizedBox(
              width: itemWidth,
              child: InkWell(
                key: ValueKey('pixel-lab-asset-$path'),
                borderRadius: BorderRadius.circular(12),
                onTap: () => onSelected(path),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: path == selected
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.outlineVariant,
                      width: path == selected ? 2 : 1,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    child: Row(
                      children: [
                        SizedBox(
                          key: ValueKey('pixel-lab-thumbnail-$path'),
                          width: 72,
                          height: 56,
                          child: _CheckerBackground(
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Image.asset(
                                path,
                                fit: BoxFit.contain,
                                filterQuality: FilterQuality.medium,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                path.split('/').last,
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              AppSpacing.gapXS,
                              Text(
                                path,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              AppSpacing.gapXS,
                              Text(path == selected ? 'SELECTED' : 'SELECT'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );
}

class _PixelLabCanvas extends StatelessWidget {
  const _PixelLabCanvas({
    super.key,
    required this.assetPath,
    required this.background,
    required this.pixelationEnabled,
    required this.pixelSize,
    required this.imageScale,
    required this.colorMode,
    required this.targetColor,
    required this.intensity,
    required this.brightness,
    required this.contrast,
    required this.saturation,
  });

  final String? assetPath;
  final PixelLabBackground background;
  final bool pixelationEnabled;
  final int pixelSize;
  final double imageScale;
  final PixelLabColorMode colorMode;
  final Color targetColor;
  final double intensity;
  final double brightness;
  final double contrast;
  final double saturation;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth;
      final height = (width * 0.62).clamp(220.0, 420.0).toDouble();
      final baseImageWidth = (width * 0.55).clamp(120.0, 320.0).toDouble();
      final displayWidth = (baseImageWidth * imageScale)
          .clamp(40.0, width * 0.96)
          .toDouble();
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: _PreviewBackground(
            mode: background,
            child: Center(
              child: assetPath == null
                  ? const Text('NO ASSET SELECTED')
                  : SizedBox(
                      width: displayWidth,
                      height: height * 0.84,
                      child: _PixelatedAssetImage(
                        assetPath: assetPath!,
                        pixelationEnabled: pixelationEnabled,
                        pixelSize: pixelSize,
                        colorMode: colorMode,
                        targetColor: targetColor,
                        intensity: intensity,
                        brightness: brightness,
                        contrast: contrast,
                        saturation: saturation,
                      ),
                    ),
            ),
          ),
        ),
      );
    },
  );
}

class _PixelatedAssetImage extends StatefulWidget {
  const _PixelatedAssetImage({
    required this.assetPath,
    required this.pixelationEnabled,
    required this.pixelSize,
    required this.colorMode,
    required this.targetColor,
    required this.intensity,
    required this.brightness,
    required this.contrast,
    required this.saturation,
  });

  final String assetPath;
  final bool pixelationEnabled;
  final int pixelSize;
  final PixelLabColorMode colorMode;
  final Color targetColor;
  final double intensity;
  final double brightness;
  final double contrast;
  final double saturation;

  @override
  State<_PixelatedAssetImage> createState() => _PixelatedAssetImageState();
}

class _PixelatedAssetImageState extends State<_PixelatedAssetImage> {
  ui.Image? _image;
  String? _requestKey;

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }

  Future<void> _decode(int targetWidth, String requestKey) async {
    try {
      final data = await rootBundle.load(widget.assetPath);
      final bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
      final codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: widget.pixelationEnabled ? targetWidth : null,
        allowUpscaling: false,
      );
      final frame = await codec.getNextFrame();
      codec.dispose();
      if (!mounted || requestKey != _requestKey) {
        frame.image.dispose();
        return;
      }
      final previous = _image;
      setState(() => _image = frame.image);
      previous?.dispose();
    } catch (_) {
      if (mounted && requestKey == _requestKey) setState(() => _image = null);
    }
  }

  void _ensureImage(double displayWidth) {
    if (!widget.pixelationEnabled) return;
    final targetWidth = widget.pixelationEnabled
        ? (displayWidth / widget.pixelSize).round().clamp(1, 4096)
        : 0;
    final requestKey = '${widget.assetPath}|$targetWidth';
    if (_requestKey == requestKey) return;
    _requestKey = requestKey;
    _decode(targetWidth, requestKey);
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      _ensureImage(constraints.maxWidth);
      final image = _image;
      Widget result = widget.pixelationEnabled && image != null
          ? RawImage(
              key: ValueKey(
                'pixel-lab-render-${widget.assetPath}-${widget.pixelSize}',
              ),
              image: image,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.none,
            )
          : Image.asset(
              widget.assetPath,
              key: ValueKey('pixel-lab-render-${widget.assetPath}-off'),
              fit: BoxFit.contain,
              filterQuality: widget.pixelationEnabled
                  ? FilterQuality.none
                  : FilterQuality.medium,
            );
      result = ColorFiltered(
        colorFilter: ColorFilter.matrix(
          _adjustmentMatrix(
            brightness: widget.brightness,
            contrast: widget.contrast,
            saturation: widget.saturation,
          ),
        ),
        child: result,
      );
      if (widget.colorMode != PixelLabColorMode.original) {
        result = ColorFiltered(
          colorFilter: ColorFilter.matrix(
            widget.colorMode == PixelLabColorMode.tint
                ? _tintMatrix(widget.targetColor, widget.intensity)
                : _monochromeTintMatrix(widget.targetColor, widget.intensity),
          ),
          child: result,
        );
      }
      return result;
    },
  );
}

class _PreviewBackground extends StatelessWidget {
  const _PreviewBackground({required this.mode, required this.child});

  final PixelLabBackground mode;
  final Widget child;

  @override
  Widget build(BuildContext context) => switch (mode) {
    PixelLabBackground.black => ColoredBox(color: Colors.black, child: child),
    PixelLabBackground.white => ColoredBox(color: Colors.white, child: child),
    PixelLabBackground.checker => _CheckerBackground(child: child),
  };
}

class _CheckerBackground extends StatelessWidget {
  const _CheckerBackground({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _CheckerPainter(
      light: Theme.of(context).colorScheme.surfaceContainerHighest,
      dark: Theme.of(context).colorScheme.outlineVariant,
    ),
    child: child,
  );
}

class _CheckerPainter extends CustomPainter {
  const _CheckerPainter({required this.light, required this.dark});

  final Color light;
  final Color dark;

  @override
  void paint(Canvas canvas, Size size) {
    const cell = 12.0;
    for (var y = 0.0; y < size.height; y += cell) {
      for (var x = 0.0; x < size.width; x += cell) {
        final even = ((x / cell).floor() + (y / cell).floor()).isEven;
        canvas.drawRect(
          Rect.fromLTWH(x, y, cell, cell),
          Paint()..color = even ? light : dark,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_CheckerPainter oldDelegate) =>
      light != oldDelegate.light || dark != oldDelegate.dark;
}

class _PixelLabSlider extends StatelessWidget {
  const _PixelLabSlider({
    required this.sliderKey,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.displayValue,
    required this.onChanged,
    this.enabled = true,
  });

  final String sliderKey;
  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String displayValue;
  final ValueChanged<double> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text('$label  $displayValue'),
      Slider(
        key: ValueKey(sliderKey),
        value: value,
        min: min,
        max: max,
        divisions: divisions,
        label: displayValue,
        onChanged: enabled ? onChanged : null,
      ),
    ],
  );
}

class _ChoiceWrap<T> extends StatelessWidget {
  const _ChoiceWrap({
    required this.values,
    required this.selected,
    required this.label,
    required this.keyFor,
    required this.onSelected,
  });

  final List<T> values;
  final T selected;
  final String Function(T value) label;
  final String Function(T value) keyFor;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: AppSpacing.sm,
    runSpacing: AppSpacing.sm,
    children: [
      for (final value in values)
        ChoiceChip(
          key: ValueKey(keyFor(value)),
          label: Text(label(value)),
          selected: value == selected,
          onSelected: (_) => onSelected(value),
        ),
    ],
  );
}

class _CurrentValues extends StatelessWidget {
  const _CurrentValues({required this.json});

  final String json;

  @override
  Widget build(BuildContext context) {
    final decoded = jsonDecode(json) as Map<String, Object?>;
    final pixelation = decoded['pixelation']! as Map<String, Object?>;
    final display = decoded['display']! as Map<String, Object?>;
    final background = decoded['background']! as Map<String, Object?>;
    final color = decoded['color']! as Map<String, Object?>;
    final values = <String>[
      'SELECTED ASSET  ${decoded['asset'] ?? 'NOT SELECTED'}',
      'PIXELATION ENABLED  ${pixelation['enabled']}',
      'PIXEL SIZE  ${pixelation['pixelSize']}',
      'IMAGE SCALE  ${display['scale']}',
      'BACKGROUND MODE  ${background['mode']}',
      'COLOR MODE  ${color['mode']}',
      'TARGET COLOR  ${color['targetColor']}',
      'INTENSITY  ${color['intensity']}',
      'BRIGHTNESS  ${color['brightness']}',
      'CONTRAST  ${color['contrast']}',
      'SATURATION  ${color['saturation']}',
    ];
    return Wrap(
      key: const ValueKey('pixel-lab-current-values'),
      spacing: AppSpacing.lg,
      runSpacing: AppSpacing.sm,
      children: [for (final value in values) Text(value)],
    );
  }
}

List<double> _adjustmentMatrix({
  required double brightness,
  required double contrast,
  required double saturation,
}) {
  const red = 0.2126;
  const green = 0.7152;
  const blue = 0.0722;
  final inverseSaturation = 1 - saturation;
  final offset = 128 * (1 - contrast) + 255 * (brightness - 1);
  return [
    contrast * (red * inverseSaturation + saturation),
    contrast * green * inverseSaturation,
    contrast * blue * inverseSaturation,
    0,
    offset,
    contrast * red * inverseSaturation,
    contrast * (green * inverseSaturation + saturation),
    contrast * blue * inverseSaturation,
    0,
    offset,
    contrast * red * inverseSaturation,
    contrast * green * inverseSaturation,
    contrast * (blue * inverseSaturation + saturation),
    0,
    offset,
    0,
    0,
    0,
    1,
    0,
  ];
}

List<double> _tintMatrix(Color color, double intensity) {
  final keep = 1 - intensity;
  return [
    keep,
    0,
    0,
    0,
    color.r * 255 * intensity,
    0,
    keep,
    0,
    0,
    color.g * 255 * intensity,
    0,
    0,
    keep,
    0,
    color.b * 255 * intensity,
    0,
    0,
    0,
    1,
    0,
  ];
}

List<double> _monochromeTintMatrix(Color color, double intensity) {
  const luminance = [0.2126, 0.7152, 0.0722];
  final keep = 1 - intensity;
  List<double> row(double channel, int identityIndex) => [
    for (var index = 0; index < 3; index++)
      luminance[index] * channel * intensity +
          (index == identityIndex ? keep : 0),
    0,
    0,
  ];
  return [
    ...row(color.r, 0),
    ...row(color.g, 1),
    ...row(color.b, 2),
    0,
    0,
    0,
    1,
    0,
  ];
}

double _rounded(double value) => double.parse(value.toStringAsFixed(3));
