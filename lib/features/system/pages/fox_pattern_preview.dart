import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/operation_card.dart';
import '../../../core/widgets/section_header.dart';
import 'fox_run_v1_section.dart';

/// A session-only, frame-aware mask editor. It deliberately does not feed the
/// production FOX pattern or Ambient Wildlife renderer.
class FoxPatternPreview extends StatefulWidget {
  const FoxPatternPreview({super.key});

  static const frames = <int>[1, 3, 5, 6, 7];

  @override
  State<FoxPatternPreview> createState() => _FoxPatternPreviewState();
}

enum _FoxPatternPart { tail, jaw, feet }

extension on _FoxPatternPart {
  String get label => switch (this) {
    _FoxPatternPart.tail => 'TAIL',
    _FoxPatternPart.jaw => 'JAW',
    _FoxPatternPart.feet => 'FEET',
  };

  Color get color => switch (this) {
    _FoxPatternPart.tail ||
    _FoxPatternPart.jaw => FoxRunV1ProductionStage.patternLightColor,
    _FoxPatternPart.feet => FoxRunV1ProductionStage.patternDarkColor,
  };
}

class _FoxPatternPreviewState extends State<FoxPatternPreview> {
  late final Map<int, Map<_FoxPatternPart, _MaskPath>> _initialMasks;
  late final Map<int, Map<_FoxPatternPart, _MaskPath>> _masks;
  var _frame = FoxPatternPreview.frames.first;
  var _part = _FoxPatternPart.tail;
  late String _pointId;

  @override
  void initState() {
    super.initState();
    _initialMasks = _buildInitialMasks();
    _masks = {
      for (final entry in _initialMasks.entries)
        entry.key: {
          for (final part in _FoxPatternPart.values)
            part: entry.value[part]!.copy(),
        },
    };
    _pointId = _activeMask.points.first.id;
  }

  _MaskPath get _activeMask => _masks[_frame]![_part]!;

  void _selectFrame(int frame) => setState(() {
    _frame = frame;
    _pointId = _activeMask.points.first.id;
  });

  void _selectPart(_FoxPatternPart part) => setState(() {
    _part = part;
    _pointId = _activeMask.points.first.id;
  });

  void _nudge({required double dx, required double dy}) => setState(
    () => _activeMask
        .point(_pointId)
        .nudge(
          dx: dx / FoxRunV1ProductionGeometry.canvasSize.width,
          dy: dy / FoxRunV1ProductionGeometry.canvasSize.height,
        ),
  );

  void _drag(DragUpdateDetails details, Size size) {
    if (size.isEmpty) return;
    setState(
      () => _activeMask
          .point(_pointId)
          .nudge(
            dx: details.delta.dx / size.width,
            dy: details.delta.dy / size.height,
          ),
    );
  }

  void _resetPart() => setState(() {
    _masks[_frame]![_part] = _initialMasks[_frame]![_part]!.copy();
    _pointId = _activeMask.points.first.id;
  });

  void _resetFrame() => setState(() {
    _masks[_frame] = {
      for (final part in _FoxPatternPart.values)
        part: _initialMasks[_frame]![part]!.copy(),
    };
    _pointId = _activeMask.points.first.id;
  });

  Future<void> _copyPatternData() async {
    await Clipboard.setData(ClipboardData(text: _copyText()));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('FOX PATTERN DATA COPIED')));
  }

  String _copyText() {
    final buffer = StringBuffer('FOX PATTERN DATA\nversion: 1\n');
    for (final frame in FoxPatternPreview.frames) {
      buffer.writeln();
      buffer.writeln('FRAME ${frame.toString().padLeft(2, '0')}');
      for (final part in _FoxPatternPart.values) {
        buffer.writeln(part.label);
        buffer.writeln(_masks[frame]![part]!.serialize());
      }
    }
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    final point = _activeMask.point(_pointId);
    return Column(
      key: const ValueKey('fox-pattern-preview-section'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(
          icon: Icons.gesture_outlined,
          title: 'FOX PATTERN PREVIEW',
        ),
        AppSpacing.gapSM,
        OperationCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Frame-aware, session-only mask editor. These values do not '
                'apply to Ambient Wildlife or the FOX production preview.',
              ),
              AppSpacing.gapMD,
              const Text('FRAME'),
              AppSpacing.gapXS,
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final frame in FoxPatternPreview.frames)
                    ChoiceChip(
                      key: ValueKey('fox-pattern-preview-frame-$frame'),
                      label: Text(frame.toString().padLeft(2, '0')),
                      selected: _frame == frame,
                      onSelected: (_) => _selectFrame(frame),
                    ),
                ],
              ),
              AppSpacing.gapMD,
              const Text('EDIT PART'),
              AppSpacing.gapXS,
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final part in _FoxPatternPart.values)
                    ChoiceChip(
                      key: ValueKey('fox-pattern-preview-part-${part.name}'),
                      label: Text(part.label),
                      selected: _part == part,
                      onSelected: (_) => _selectPart(part),
                    ),
                ],
              ),
              AppSpacing.gapMD,
              _MaskEditorStage(
                key: const ValueKey('fox-pattern-preview-stage'),
                frame: _frame,
                masks: _masks[_frame]!,
                activeMask: _activeMask,
                selectedPointId: _pointId,
                onDrag: _drag,
              ),
              AppSpacing.gapSM,
              const Text('CONTROL POINT'),
              DropdownButton<String>(
                key: const ValueKey('fox-pattern-preview-point-selector'),
                value: _pointId,
                isExpanded: true,
                items: [
                  for (final candidate in _activeMask.points)
                    DropdownMenuItem(
                      value: candidate.id,
                      child: Text(candidate.id),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _pointId = value);
                },
              ),
              AppSpacing.gapSM,
              Text(
                'X ${point.x.toStringAsFixed(5)}  •  '
                'Y ${point.y.toStringAsFixed(5)}  •  drag preview or nudge 1px',
                key: const ValueKey('fox-pattern-preview-point-value'),
              ),
              AppSpacing.gapXS,
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _nudgeButton('X -1', -1, 0),
                  _nudgeButton('X +1', 1, 0),
                  _nudgeButton('Y -1', 0, -1),
                  _nudgeButton('Y +1', 0, 1),
                  OutlinedButton(
                    key: const ValueKey('fox-pattern-preview-reset-part'),
                    onPressed: _resetPart,
                    child: const Text('RESET PART'),
                  ),
                  OutlinedButton(
                    key: const ValueKey('fox-pattern-preview-reset-frame'),
                    onPressed: _resetFrame,
                    child: const Text('RESET FRAME'),
                  ),
                ],
              ),
              AppSpacing.gapMD,
              FilledButton.icon(
                key: const ValueKey('fox-pattern-preview-copy'),
                onPressed: _copyPatternData,
                icon: const Icon(Icons.content_copy_outlined),
                label: const Text('COPY PATTERN DATA'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _nudgeButton(String label, double dx, double dy) => OutlinedButton(
    key: ValueKey(
      'fox-pattern-preview-nudge-${label.replaceAll(' ', '-').toLowerCase()}',
    ),
    onPressed: () => _nudge(dx: dx, dy: dy),
    child: Text(label),
  );
}

class _MaskEditorStage extends StatelessWidget {
  const _MaskEditorStage({
    super.key,
    required this.frame,
    required this.masks,
    required this.activeMask,
    required this.selectedPointId,
    required this.onDrag,
  });

  final int frame;
  final Map<_FoxPatternPart, _MaskPath> masks;
  final _MaskPath activeMask;
  final String selectedPointId;
  final void Function(DragUpdateDetails details, Size size) onDrag;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth;
      final size = Size(
        width,
        width / FoxRunV1ProductionGeometry.canvasSize.aspectRatio,
      );
      return Center(
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: GestureDetector(
            onPanUpdate: (details) => onDrag(details, size),
            child: Stack(
              fit: StackFit.expand,
              children: [
                const ColoredBox(
                  color: FoxRunV1ProductionStage.previewBackgroundColor,
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top:
                      size.height *
                      FoxRunV1ProductionGeometry.virtualGround /
                      FoxRunV1ProductionGeometry.canvasSize.height,
                  child: const Divider(height: 1),
                ),
                _PreviewPatternCel(frame: frame, masks: masks),
                IgnorePointer(
                  child: CustomPaint(
                    painter: _MaskControlPointPainter(
                      path: activeMask,
                      selectedPointId: selectedPointId,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _PreviewPatternCel extends StatelessWidget {
  const _PreviewPatternCel({required this.frame, required this.masks});

  final int frame;
  final Map<_FoxPatternPart, _MaskPath> masks;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      _cel(FoxRunV1ProductionStage.silhouetteColor),
      for (final part in _FoxPatternPart.values)
        ClipPath(
          clipper: _MaskPathClipper(masks[part]!),
          child: _cel(part.color),
        ),
    ],
  );

  Widget _cel(Color color) => ColorFiltered(
    colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    child: Image.asset(
      'assets/animations/sandbox/fox_v1/canonical/'
      'frame_${frame.toString().padLeft(2, '0')}.png',
      fit: BoxFit.fill,
      filterQuality: FilterQuality.low,
    ),
  );
}

class _MaskPathClipper extends CustomClipper<Path> {
  const _MaskPathClipper(this.mask);

  final _MaskPath mask;

  @override
  Path getClip(Size size) => mask.toPath(size);

  @override
  bool shouldReclip(covariant _MaskPathClipper oldClipper) => true;
}

class _MaskControlPointPainter extends CustomPainter {
  const _MaskControlPointPainter({
    required this.path,
    required this.selectedPointId,
  });

  final _MaskPath path;
  final String selectedPointId;

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = Colors.cyanAccent.withValues(alpha: .72)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final pointPaint = Paint()..color = Colors.cyanAccent;
    final selectedPaint = Paint()..color = Colors.amberAccent;
    for (final segment in path.segments) {
      final anchor = segment.anchor.toOffset(size);
      canvas.drawLine(segment.control1.toOffset(size), anchor, line);
      canvas.drawLine(segment.control2.toOffset(size), anchor, line);
    }
    for (final point in path.points) {
      canvas.drawCircle(
        point.toOffset(size),
        point.id == selectedPointId ? 5 : 3,
        point.id == selectedPointId ? selectedPaint : pointPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MaskControlPointPainter oldDelegate) => true;
}

class _MaskPoint {
  _MaskPoint(this.id, this.x, this.y);

  final String id;
  double x;
  double y;

  Offset toOffset(Size size) => Offset(x * size.width, y * size.height);

  void nudge({required double dx, required double dy}) {
    x = (x + dx).clamp(-.25, 1.25).toDouble();
    y = (y + dy).clamp(-.25, 1.25).toDouble();
  }

  _MaskPoint copy() => _MaskPoint(id, x, y);

  String serialize() => '$id ${x.toStringAsFixed(6)} ${y.toStringAsFixed(6)}';
}

class _MaskCubicSegment {
  _MaskCubicSegment(this.control1, this.control2, this.anchor);

  final _MaskPoint control1;
  final _MaskPoint control2;
  final _MaskPoint anchor;

  _MaskCubicSegment copy() =>
      _MaskCubicSegment(control1.copy(), control2.copy(), anchor.copy());
}

class _MaskPath {
  _MaskPath(this.start, this.segments);

  final _MaskPoint start;
  final List<_MaskCubicSegment> segments;

  List<_MaskPoint> get points => [
    start,
    for (final segment in segments) ...[
      segment.control1,
      segment.control2,
      segment.anchor,
    ],
  ];

  _MaskPoint point(String id) => points.firstWhere((point) => point.id == id);

  Path toPath(Size size) {
    final path = Path()..moveTo(start.x * size.width, start.y * size.height);
    for (final segment in segments) {
      path.cubicTo(
        segment.control1.x * size.width,
        segment.control1.y * size.height,
        segment.control2.x * size.width,
        segment.control2.y * size.height,
        segment.anchor.x * size.width,
        segment.anchor.y * size.height,
      );
    }
    return path..close();
  }

  _MaskPath copy() =>
      _MaskPath(start.copy(), [for (final segment in segments) segment.copy()]);

  String serialize() => [
    'MOVE ${start.serialize()}',
    for (final segment in segments)
      'CUBIC ${segment.control1.serialize()} | '
          '${segment.control2.serialize()} | ${segment.anchor.serialize()}',
    'CLOSE',
  ].join('\n');
}

Map<int, Map<_FoxPatternPart, _MaskPath>> _buildInitialMasks() => {
  for (final frame in FoxPatternPreview.frames)
    frame: {
      _FoxPatternPart.tail: _tailMask(),
      _FoxPatternPart.jaw: _jawMask(),
      _FoxPatternPart.feet: _feetMask(),
    },
};

_MaskPoint _point(String id, double x, double y) => _MaskPoint(id, x, y);

_MaskPath _tailMask() => _MaskPath(_point('A0', .035, .50), [
  _MaskCubicSegment(
    _point('C1', .058, .43),
    _point('C2', .092, .365),
    _point('A1', .125, .34),
  ),
  _MaskCubicSegment(
    _point('C3', .148, .322),
    _point('C4', .17, .31),
    _point('A2', .18, .302),
  ),
  _MaskCubicSegment(
    _point('C5', .198, .35),
    _point('C6', .198, .402),
    _point('A3', .192, .445),
  ),
  _MaskCubicSegment(
    _point('C7', .186, .49),
    _point('C8', .172, .528),
    _point('A4', .153, .55),
  ),
  _MaskCubicSegment(
    _point('C9', .112, .56),
    _point('C10', .073, .54),
    _point('A5', .035, .50),
  ),
]);

_MaskPath _jawMask() => _MaskPath(_point('A0', .982, .382), [
  _MaskCubicSegment(
    _point('C1', .968, .4),
    _point('C2', .951, .409),
    _point('A1', .932, .414),
  ),
  _MaskCubicSegment(
    _point('C3', .905, .423),
    _point('C4', .892, .445),
    _point('A2', .877, .473),
  ),
  _MaskCubicSegment(
    _point('C5', .855, .504),
    _point('C6', .835, .536),
    _point('A3', .806, .568),
  ),
  _MaskCubicSegment(
    _point('C7', .784, .588),
    _point('C8', .77, .588),
    _point('A4', .76, .583),
  ),
  _MaskCubicSegment(
    _point('C9', .779, .555),
    _point('C10', .795, .526),
    _point('A5', .812, .502),
  ),
  _MaskCubicSegment(
    _point('C11', .83, .479),
    _point('C12', .845, .455),
    _point('A6', .861, .431),
  ),
  _MaskCubicSegment(
    _point('C13', .883, .404),
    _point('C14', .91, .385),
    _point('A7', .937, .374),
  ),
  _MaskCubicSegment(
    _point('C15', .954, .365),
    _point('C16', .97, .368),
    _point('A8', .982, .382),
  ),
]);

_MaskPath _feetMask() => _MaskPath(_point('A0', .34, .62), [
  _MaskCubicSegment(
    _point('C1', .47, .62),
    _point('C2', .61, .62),
    _point('A1', .74, .62),
  ),
  _MaskCubicSegment(
    _point('C3', .74, .72),
    _point('C4', .74, .83),
    _point('A2', .74, .93),
  ),
  _MaskCubicSegment(
    _point('C5', .61, .93),
    _point('C6', .47, .93),
    _point('A3', .34, .93),
  ),
  _MaskCubicSegment(
    _point('C7', .34, .83),
    _point('C8', .34, .72),
    _point('A4', .34, .62),
  ),
]);
