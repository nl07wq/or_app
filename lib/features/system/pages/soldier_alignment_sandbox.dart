import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:or_app/core/widgets/operation_card.dart';
import 'package:or_app/core/widgets/section_header.dart';
import 'package:or_app/features/themes/base_camp/base_camp_dashboard_page.dart';

/// Sandbox-only alignment data. It is deliberately never read by the BASE
/// CAMP terminal; users copy the validated JSON when a calibration is ready.
@immutable
class SoldierAlignmentData {
  const SoldierAlignmentData({
    this.frameOffsets = const [
      Offset.zero,
      Offset.zero,
      Offset.zero,
      Offset.zero,
      Offset.zero,
      Offset.zero,
    ],
    this.offsetXdp = 0,
    this.offsetYdp = 0,
    this.scale = 1,
    this.breathingOpacity = .5,
    this.brightness = 0,
    this.contrast = 1,
    this.saturation = 1,
    this.warmth = 0,
  });

  final List<Offset> frameOffsets;
  final double offsetXdp;
  final double offsetYdp;
  final double scale;
  final double breathingOpacity;
  final double brightness;
  final double contrast;
  final double saturation;
  final double warmth;

  SoldierAlignmentData copyWith({
    List<Offset>? frameOffsets,
    double? offsetXdp,
    double? offsetYdp,
    double? scale,
    double? breathingOpacity,
    double? brightness,
    double? contrast,
    double? saturation,
    double? warmth,
  }) => SoldierAlignmentData(
    frameOffsets: frameOffsets ?? this.frameOffsets,
    offsetXdp: offsetXdp ?? this.offsetXdp,
    offsetYdp: offsetYdp ?? this.offsetYdp,
    scale: scale ?? this.scale,
    breathingOpacity: breathingOpacity ?? this.breathingOpacity,
    brightness: brightness ?? this.brightness,
    contrast: contrast ?? this.contrast,
    saturation: saturation ?? this.saturation,
    warmth: warmth ?? this.warmth,
  );

  Map<String, Object> toJson(Size viewport) => {
    'schema': 'soldier_alignment_v2',
    'reference': 'breathing_soldier',
    'target': 'rifle_regrip',
    'sourceAssetIds': baseCampRifleRegripSourceAssets,
    'sourceCanvasPx': [512, 512],
    'previewViewportDp': {'width': viewport.width, 'height': viewport.height},
    'drawingAnchor': 'normal_visible_foot_center',
    'colorTransformVersion': 'rgba_hsbc_warmth_v1',
    'sourceMaterialVersion': 'approved_rifle_regrip_rgba_v1',
    'frameOffsetsPx': [
      for (var index = 0; index < frameOffsets.length; index++)
        {
          'frame': index,
          'x': frameOffsets[index].dx,
          'y': frameOffsets[index].dy,
        },
    ],
    'alignment': {
      'offsetXdp': offsetXdp,
      'offsetYdp': offsetYdp,
      'scale': scale,
      'breathingOpacity': breathingOpacity,
    },
    'color': {
      'brightness': brightness,
      'contrast': contrast,
      'saturation': saturation,
      'warmth': warmth,
    },
    'frameDurationsMs': baseCampRifleRegripFrameDurations,
  };

  static SoldierAlignmentData? tryParse(Object? value) {
    if (value is! Map || value['schema'] != 'soldier_alignment_v2') return null;
    final offsets = value['frameOffsetsPx'];
    final alignment = value['alignment'];
    final color = value['color'];
    final durations = value['frameDurationsMs'];
    if (offsets is! List ||
        offsets.length != 6 ||
        alignment is! Map ||
        color is! Map ||
        durations is! List ||
        durations.join(',') != baseCampRifleRegripFrameDurations.join(',')) {
      return null;
    }
    double? number(Object? input) =>
        input is num && input.isFinite ? input.toDouble() : null;
    final parsedOffsets = <Offset>[];
    for (var index = 0; index < offsets.length; index++) {
      final item = offsets[index];
      if (item is! Map || item['frame'] != index) return null;
      final x = number(item['x']);
      final y = number(item['y']);
      if (x == null || y == null || x.abs() > 40 || y.abs() > 40) return null;
      parsedOffsets.add(Offset(x, y));
    }
    final x = number(alignment['offsetXdp']);
    final y = number(alignment['offsetYdp']);
    final scale = number(alignment['scale']);
    final breathingOpacity = number(alignment['breathingOpacity']) ?? .5;
    final brightness = number(color['brightness']);
    final contrast = number(color['contrast']);
    final saturation = number(color['saturation']);
    final warmth = number(color['warmth']);
    if (x == null ||
        y == null ||
        scale == null ||
        brightness == null ||
        contrast == null ||
        saturation == null ||
        warmth == null ||
        x.abs() > 100 ||
        y.abs() > 100 ||
        scale < .5 ||
        scale > 1.5 ||
        breathingOpacity < 0 ||
        breathingOpacity > 1 ||
        brightness.abs() > .3 ||
        contrast < .7 ||
        contrast > 1.3 ||
        saturation < .7 ||
        saturation > 1.3 ||
        warmth.abs() > 30) {
      return null;
    }
    return SoldierAlignmentData(
      frameOffsets: parsedOffsets,
      offsetXdp: x,
      offsetYdp: y,
      scale: scale,
      breathingOpacity: breathingOpacity,
      brightness: brightness,
      contrast: contrast,
      saturation: saturation,
      warmth: warmth,
    );
  }
}

class SoldierAlignmentSandboxSection extends StatefulWidget {
  const SoldierAlignmentSandboxSection({super.key});

  @override
  State<SoldierAlignmentSandboxSection> createState() =>
      _SoldierAlignmentSandboxSectionState();
}

class _SoldierAlignmentSandboxSectionState
    extends State<SoldierAlignmentSandboxSection>
    with SingleTickerProviderStateMixin {
  late final AnimationController _playback;
  SoldierAlignmentData _data = const SoldierAlignmentData();
  var _selectedFrame = 0;
  var _comparisonFrame = 0;
  var _showBreathing = true;
  var _showRifle = true;
  var _showGrid = true;
  var _showCorrected = true;
  var _playing = false;
  var _showBeforeColor = false;
  Size _previewViewport = const Size(320, 320);
  double _scaleAtGestureStart = 1;

  @override
  void initState() {
    super.initState();
    _playback = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: baseCampRifleRegripAnimationMs),
    )..addListener(_advancePlayback);
  }

  void _advancePlayback() {
    final elapsed = (_playback.value * baseCampRifleRegripAnimationMs).floor();
    final frame = _rifleFrameAtElapsed(elapsed);
    if (frame != _selectedFrame && mounted) {
      setState(() => _selectedFrame = frame);
    }
  }

  int _rifleFrameAtElapsed(int elapsed) {
    var local = elapsed;
    for (
      var index = 0;
      index < baseCampRifleRegripFrameDurations.length;
      index++
    ) {
      final duration = baseCampRifleRegripFrameDurations[index];
      if (local < duration) return index;
      local -= duration;
    }
    return 5;
  }

  @override
  void dispose() {
    _playback.dispose();
    super.dispose();
  }

  void _setFrameOffset(int frame, Offset offset) {
    final offsets = [..._data.frameOffsets];
    offsets[frame] = Offset(offset.dx.clamp(-40, 40), offset.dy.clamp(-40, 40));
    setState(() => _data = _data.copyWith(frameOffsets: offsets));
  }

  void _resetMotion() => setState(
    () => _data = _data.copyWith(
      frameOffsets: List<Offset>.filled(6, Offset.zero),
    ),
  );

  Future<void> _copyData() async {
    await Clipboard.setData(
      ClipboardData(
        text: const JsonEncoder.withIndent(
          '  ',
        ).convert(_data.toJson(_previewViewport)),
      ),
    );
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('ALIGNMENT DATA COPIED')));
    }
  }

  Future<void> _importData() async {
    final text = (await Clipboard.getData(Clipboard.kTextPlain))?.text;
    Object? decoded;
    try {
      decoded = text == null ? null : jsonDecode(text);
    } catch (_) {}
    final parsed = SoldierAlignmentData.tryParse(decoded);
    if (parsed == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('INVALID ALIGNMENT DATA — NO CHANGES APPLIED'),
          ),
        );
      }
      return;
    }
    setState(() => _data = parsed);
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SectionHeader(icon: Icons.tune, title: 'SOLDIER ALIGNMENT'),
      const SizedBox(height: 8),
      OperationCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _layerToggles(),
            const SizedBox(height: 8),
            _preview(),
            const SizedBox(height: 10),
            _phaseOne(),
            const Divider(),
            _phaseTwo(),
            const Divider(),
            _phaseThree(),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                OutlinedButton.icon(
                  key: const ValueKey('copy-soldier-alignment-data'),
                  onPressed: _copyData,
                  icon: const Icon(Icons.content_copy_outlined),
                  label: const Text('COPY ALIGNMENT DATA'),
                ),
                OutlinedButton.icon(
                  key: const ValueKey('import-soldier-alignment-data'),
                  onPressed: _importData,
                  icon: const Icon(Icons.content_paste_outlined),
                  label: const Text('IMPORT ALIGNMENT DATA'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Sandbox values never alter BASE CAMP production animation.',
              style: TextStyle(fontSize: 11),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _layerToggles() => Wrap(
    spacing: 4,
    runSpacing: 4,
    children: [
      _eyeToggle(
        'BREATHING',
        _showBreathing,
        () => setState(() => _showBreathing = !_showBreathing),
      ),
      _eyeToggle(
        'RIFLE REGRIP',
        _showRifle,
        () => setState(() => _showRifle = !_showRifle),
      ),
      _eyeToggle(
        'TACTICAL GRID',
        _showGrid,
        () => setState(() => _showGrid = !_showGrid),
      ),
      FilterChip(
        label: const Text('CORRECTED ASSET'),
        selected: _showCorrected,
        onSelected: (value) => setState(() => _showCorrected = value),
      ),
    ],
  );

  Widget _eyeToggle(String label, bool visible, VoidCallback onPressed) =>
      TextButton.icon(
        onPressed: onPressed,
        icon: Icon(
          visible ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        ),
        label: Text(label),
      );

  Widget _preview() => LayoutBuilder(
    builder: (context, constraints) {
      final side = math.min(constraints.maxWidth, 360.0);
      _previewViewport = Size(side, side);
      return Center(
        child: SizedBox.square(
          key: const ValueKey('soldier-alignment-preview'),
          dimension: side,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xff161b12),
              border: Border.all(color: const Color(0xff718268)),
            ),
            child: GestureDetector(
              onScaleStart: (_) => _scaleAtGestureStart = _data.scale,
              onScaleUpdate: (details) => setState(() {
                _data = _data.copyWith(
                  offsetXdp: (_data.offsetXdp + details.focalPointDelta.dx)
                      .clamp(-100, 100),
                  offsetYdp: (_data.offsetYdp + details.focalPointDelta.dy)
                      .clamp(-100, 100),
                  scale: (_scaleAtGestureStart * details.scale).clamp(.5, 1.5),
                );
              }),
              child: LayoutBuilder(
                builder: (context, bounds) {
                  final layout = baseCampRifleRegripLayout(bounds.biggest);
                  return Stack(
                    clipBehavior: Clip.hardEdge,
                    children: [
                      if (_showGrid)
                        const Positioned.fill(
                          child: CustomPaint(
                            painter: BaseCampSoldierGridPainter(),
                          ),
                        ),
                      if (_showBreathing)
                        Opacity(
                          opacity: _data.breathingOpacity,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.asset(
                                baseCampBreathingSoldierLowerAsset,
                                fit: BoxFit.contain,
                                filterQuality: FilterQuality.none,
                              ),
                              Image.asset(
                                baseCampBreathingSoldierUpperAsset,
                                fit: BoxFit.contain,
                                filterQuality: FilterQuality.none,
                              ),
                            ],
                          ),
                        ),
                      if (_showRifle)
                        _rifleLayer(
                          layout: layout,
                          frame: _comparisonFrame,
                          opacity: _comparisonFrame == _selectedFrame ? 0 : .35,
                        ),
                      if (_showRifle)
                        _rifleLayer(layout: layout, frame: _selectedFrame),
                      Positioned.fill(
                        child: IgnorePointer(
                          child: CustomPaint(painter: _AlignmentGuidePainter()),
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
    },
  );

  Widget _rifleLayer({
    required BaseCampRifleRegripLayout layout,
    required int frame,
    double opacity = 1,
  }) {
    final offset = _data.frameOffsets[frame];
    final sourceScale = layout.specialDimension / 512;
    final asset = (_showCorrected
        ? baseCampRifleRegripAssets
        : baseCampRifleRegripSourceAssets)[frame];
    return Positioned(
      left: layout.specialLeft + _data.offsetXdp + offset.dx * sourceScale,
      top: layout.specialTop + _data.offsetYdp + offset.dy * sourceScale,
      width: layout.specialDimension * _data.scale,
      height: layout.specialDimension * _data.scale,
      child: Opacity(
        opacity: opacity,
        child: ColorFiltered(
          colorFilter: _showBeforeColor
              ? const ColorFilter.mode(Colors.transparent, BlendMode.srcOver)
              : ColorFilter.matrix(_colorMatrix(_data)),
          child: Image.asset(
            asset,
            fit: BoxFit.fill,
            filterQuality: FilterQuality.none,
          ),
        ),
      ),
    );
  }

  Widget _phaseOne() {
    final offset = _data.frameOffsets[_selectedFrame];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'PHASE 1 — MOTION STABILIZER',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        Wrap(
          spacing: 4,
          children: [
            for (var frame = 0; frame < 6; frame++)
              ChoiceChip(
                label: Text('F$frame'),
                selected: _selectedFrame == frame,
                onSelected: (_) => setState(() => _selectedFrame = frame),
              ),
            IconButton(
              onPressed: () =>
                  setState(() => _selectedFrame = (_selectedFrame + 5) % 6),
              icon: const Icon(Icons.skip_previous),
            ),
            IconButton(
              onPressed: () =>
                  setState(() => _selectedFrame = (_selectedFrame + 1) % 6),
              icon: const Icon(Icons.skip_next),
            ),
            IconButton(
              onPressed: () => setState(() {
                _playing = !_playing;
                _playing ? _playback.repeat() : _playback.stop();
              }),
              icon: Icon(_playing ? Icons.stop : Icons.play_arrow),
            ),
          ],
        ),
        DropdownButton<int>(
          value: _comparisonFrame,
          items: [
            for (var frame = 0; frame < 6; frame++)
              DropdownMenuItem(value: frame, child: Text('COMPARE F$frame')),
          ],
          onChanged: (value) => setState(() => _comparisonFrame = value ?? 0),
        ),
        _slider(
          'FRAME X ${offset.dx.toStringAsFixed(1)} px',
          offset.dx,
          -40,
          40,
          160,
          (value) => _setFrameOffset(_selectedFrame, Offset(value, offset.dy)),
        ),
        _slider(
          'FRAME Y ${offset.dy.toStringAsFixed(1)} px',
          offset.dy,
          -40,
          40,
          160,
          (value) => _setFrameOffset(_selectedFrame, Offset(offset.dx, value)),
        ),
        Wrap(
          spacing: 8,
          children: [
            _numericInput(
              'X PX',
              offset.dx,
              -40,
              40,
              (value) =>
                  _setFrameOffset(_selectedFrame, Offset(value, offset.dy)),
            ),
            _numericInput(
              'Y PX',
              offset.dy,
              -40,
              40,
              (value) =>
                  _setFrameOffset(_selectedFrame, Offset(offset.dx, value)),
            ),
          ],
        ),
        Wrap(
          spacing: 4,
          children: [
            OutlinedButton(
              onPressed: () => _setFrameOffset(
                _selectedFrame,
                Offset(offset.dx - .5, offset.dy),
              ),
              child: const Text('X −0.5'),
            ),
            OutlinedButton(
              onPressed: () => _setFrameOffset(
                _selectedFrame,
                Offset(offset.dx + .5, offset.dy),
              ),
              child: const Text('X +0.5'),
            ),
            OutlinedButton(
              onPressed: () => _setFrameOffset(
                _selectedFrame,
                Offset(offset.dx, offset.dy - .5),
              ),
              child: const Text('Y −0.5'),
            ),
            OutlinedButton(
              onPressed: () => _setFrameOffset(
                _selectedFrame,
                Offset(offset.dx, offset.dy + .5),
              ),
              child: const Text('Y +0.5'),
            ),
            TextButton(onPressed: _resetMotion, child: const Text('RESET')),
          ],
        ),
      ],
    );
  }

  Widget _phaseTwo() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'PHASE 2 — ALIGNMENT',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      _slider(
        'OFFSET X ${_data.offsetXdp.toStringAsFixed(1)} dp',
        _data.offsetXdp,
        -100,
        100,
        400,
        (value) => setState(() => _data = _data.copyWith(offsetXdp: value)),
      ),
      _slider(
        'OFFSET Y ${_data.offsetYdp.toStringAsFixed(1)} dp',
        _data.offsetYdp,
        -100,
        100,
        400,
        (value) => setState(() => _data = _data.copyWith(offsetYdp: value)),
      ),
      Wrap(
        spacing: 8,
        children: [
          _numericInput(
            'OFFSET X DP',
            _data.offsetXdp,
            -100,
            100,
            (value) => setState(() => _data = _data.copyWith(offsetXdp: value)),
          ),
          _numericInput(
            'OFFSET Y DP',
            _data.offsetYdp,
            -100,
            100,
            (value) => setState(() => _data = _data.copyWith(offsetYdp: value)),
          ),
        ],
      ),
      _slider(
        'SCALE ${(_data.scale * 100).toStringAsFixed(1)}%',
        _data.scale,
        .5,
        1.5,
        200,
        (value) => setState(() => _data = _data.copyWith(scale: value)),
      ),
      _slider(
        'BREATHING OPACITY ${(_data.breathingOpacity * 100).round()}%',
        _data.breathingOpacity,
        0,
        1,
        20,
        (value) =>
            setState(() => _data = _data.copyWith(breathingOpacity: value)),
      ),
    ],
  );

  Widget _phaseThree() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'PHASE 3 — COLOR MATCHING',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('SHOW BEFORE COLOR'),
        value: _showBeforeColor,
        onChanged: (value) => setState(() => _showBeforeColor = value),
      ),
      _slider(
        'BRIGHTNESS ${(_data.brightness * 100).round()}%',
        _data.brightness,
        -.3,
        .3,
        60,
        (value) => setState(() => _data = _data.copyWith(brightness: value)),
      ),
      _slider(
        'CONTRAST ${(_data.contrast * 100).round()}%',
        _data.contrast,
        .7,
        1.3,
        60,
        (value) => setState(() => _data = _data.copyWith(contrast: value)),
      ),
      _slider(
        'SATURATION ${(_data.saturation * 100).round()}%',
        _data.saturation,
        .7,
        1.3,
        60,
        (value) => setState(() => _data = _data.copyWith(saturation: value)),
      ),
      _slider(
        'WARMTH ${_data.warmth.round()}',
        _data.warmth,
        -30,
        30,
        60,
        (value) => setState(() => _data = _data.copyWith(warmth: value)),
      ),
      TextButton(
        onPressed: () => setState(
          () => _data = _data.copyWith(
            brightness: 0,
            contrast: 1,
            saturation: 1,
            warmth: 0,
          ),
        ),
        child: const Text('RESET COLOR'),
      ),
    ],
  );

  Widget _slider(
    String label,
    double value,
    double min,
    double max,
    int divisions,
    ValueChanged<double> onChanged,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(fontSize: 11)),
      Slider(
        value: value.clamp(min, max),
        min: min,
        max: max,
        divisions: divisions,
        onChanged: onChanged,
      ),
    ],
  );

  Widget _numericInput(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onSubmitted,
  ) => SizedBox(
    width: 116,
    child: TextFormField(
      key: ValueKey('soldier-alignment-$label'),
      initialValue: value.toStringAsFixed(1),
      keyboardType: const TextInputType.numberWithOptions(
        decimal: true,
        signed: true,
      ),
      decoration: InputDecoration(labelText: label, isDense: true),
      onFieldSubmitted: (text) {
        final parsed = double.tryParse(text);
        if (parsed != null) onSubmitted(parsed.clamp(min, max));
      },
    ),
  );
}

class _AlignmentGuidePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xffc7d6a0).withValues(alpha: .55)
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(0, size.height * .985),
      Offset(size.width, size.height * .985),
      paint,
    );
    canvas.drawRect(Offset.zero & size, paint..style = PaintingStyle.stroke);
  }

  @override
  bool shouldRepaint(covariant _AlignmentGuidePainter oldDelegate) => false;
}

List<double> _colorMatrix(SoldierAlignmentData value) {
  final contrast = value.contrast;
  final brightness = value.brightness * 255;
  final saturation = value.saturation;
  const r = .2126, g = .7152, b = .0722;
  final warmth = value.warmth;
  final sr = (1 - saturation) * r;
  final sg = (1 - saturation) * g;
  final sb = (1 - saturation) * b;
  return [
    contrast * (sr + saturation),
    contrast * sg,
    contrast * sb,
    0,
    brightness + warmth,
    contrast * sr,
    contrast * (sg + saturation),
    contrast * sb,
    0,
    brightness,
    contrast * sr,
    contrast * sg,
    contrast * (sb + saturation),
    0,
    brightness - warmth,
    0,
    0,
    0,
    1,
    0,
  ];
}
