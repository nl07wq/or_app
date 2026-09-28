import 'dart:async';

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
  final Map<String, _AreaCandidate> _candidates = {};
  var _frame = FoxPatternPreview.frames.first;
  var _part = _FoxPatternPart.tail;
  late String _pointId;
  var _areaMode = _AreaMode.fineTune;
  var _areaPointCount = 8;
  var _zoom = 1.0;
  var _pan = Offset.zero;
  var _showControls = false;
  var _copySourceFrame = 3;

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
  String get _candidateKey => '$_frame:${_part.name}';
  _AreaCandidate get _activeCandidate =>
      _candidates.putIfAbsent(_candidateKey, _AreaCandidate.new);

  void _selectPoint(String pointId) => setState(() => _pointId = pointId);

  void _selectFrame(int frame) => setState(() {
    _frame = frame;
    _pointId = _activeMask.points.first.id;
    if (_copySourceFrame == frame) {
      _copySourceFrame = FoxPatternPreview.frames.firstWhere(
        (candidate) => candidate != frame,
      );
    }
  });

  void _selectPart(_FoxPatternPart part) => setState(() {
    _part = part;
    _pointId = _activeMask.points.first.id;
  });

  void _setAreaMode(_AreaMode mode) => setState(() => _areaMode = mode);

  void _setZoom(double zoom) => setState(() {
    _zoom = zoom;
    _pan = Offset.zero;
  });

  void _panCanvas(Offset delta, Size size) => setState(() {
    if (_zoom == 1) return;
    _pan = Offset(
      (_pan.dx + delta.dx).clamp(-size.width * (_zoom - 1), 0).toDouble(),
      (_pan.dy + delta.dy).clamp(-size.height * (_zoom - 1), 0).toDouble(),
    );
  });

  void _addAreaPoint(Offset point) => setState(() {
    final candidate = _activeCandidate;
    if (_areaMode == _AreaMode.freeTap) candidate.add(point);
  });

  void _startTrace(Offset point) => setState(() {
    final candidate = _activeCandidate;
    candidate.clear();
    candidate.add(point);
  });

  void _extendTrace(Offset point) =>
      setState(() => _activeCandidate.add(point));

  void _finishTrace() => setState(() {
    final candidate = _activeCandidate;
    if (candidate.points.length >= 3) candidate.closed = true;
  });

  void _undoAreaPoint() => setState(_activeCandidate.undo);
  void _clearArea() => setState(_activeCandidate.clear);
  void _closeArea() => setState(() => _activeCandidate.closed = true);

  void _applyArea() => setState(() {
    final candidate = _activeCandidate;
    if (!candidate.isReady) return;
    _masks[_frame]![_part] = candidate.toMaskPath(_areaPointCount);
    _pointId = _activeMask.points.first.id;
    candidate.clear();
    _areaMode = _AreaMode.fineTune;
  });

  void _copyFromFrame() => setState(() {
    _masks[_frame]![_part] = _masks[_copySourceFrame]![_part]!.copy();
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

  void _addPoint() =>
      setState(() => _pointId = _activeMask.insertAnchorAfter(_pointId));

  void _deletePoint() =>
      setState(() => _pointId = _activeMask.deletePoint(_pointId));

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
    final buffer = StringBuffer('FOX PATTERN DATA\nversion: 3\n');
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
              const Text('AREA DEFINE'),
              AppSpacing.gapXS,
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    key: const ValueKey('fox-pattern-preview-mode-free-tap'),
                    label: const Text('FREE TAP'),
                    selected: _areaMode == _AreaMode.freeTap,
                    onSelected: (_) => _setAreaMode(_AreaMode.freeTap),
                  ),
                  ChoiceChip(
                    key: const ValueKey('fox-pattern-preview-mode-trace'),
                    label: const Text('TRACE'),
                    selected: _areaMode == _AreaMode.trace,
                    onSelected: (_) => _setAreaMode(_AreaMode.trace),
                  ),
                  ChoiceChip(
                    key: const ValueKey('fox-pattern-preview-mode-fine-tune'),
                    label: const Text('FINE TUNE'),
                    selected: _areaMode == _AreaMode.fineTune,
                    onSelected: (_) => _setAreaMode(_AreaMode.fineTune),
                  ),
                ],
              ),
              AppSpacing.gapSM,
              const Text('POINTS'),
              Wrap(
                spacing: 8,
                children: [
                  for (final count in [6, 8, 10, 12])
                    ChoiceChip(
                      key: ValueKey('fox-pattern-preview-area-points-$count'),
                      label: Text('$count'),
                      selected: _areaPointCount == count,
                      onSelected: (_) =>
                          setState(() => _areaPointCount = count),
                    ),
                ],
              ),
              AppSpacing.gapSM,
              const Text('ZOOM'),
              Wrap(
                spacing: 8,
                children: [
                  for (final zoom in [1.0, 2.0, 3.0, 4.0])
                    ChoiceChip(
                      key: ValueKey('fox-pattern-preview-zoom-$zoom'),
                      label: Text('${zoom.toInt()}×'),
                      selected: _zoom == zoom,
                      onSelected: (_) => _setZoom(zoom),
                    ),
                ],
              ),
              if (_areaMode != _AreaMode.fineTune) ...[
                AppSpacing.gapSM,
                Text(
                  _activeCandidate.closed
                      ? 'CANDIDATE READY: ${_activeCandidate.points.length} input points'
                      : 'AREA INPUT: ${_activeCandidate.points.length} points',
                  key: const ValueKey('fox-pattern-preview-area-status'),
                ),
              ],
              AppSpacing.gapMD,
              _MaskEditorStage(
                key: const ValueKey('fox-pattern-preview-stage'),
                frame: _frame,
                part: _part,
                masks: _masks[_frame]!,
                activeMask: _activeMask,
                selectedPointId: _pointId,
                candidate: _activeCandidate,
                areaPointCount: _areaPointCount,
                areaMode: _areaMode,
                zoom: _zoom,
                pan: _pan,
                showControls: _showControls,
                onSelectPoint: _selectPoint,
                onDrag: _drag,
                onAreaTap: _addAreaPoint,
                onTraceStart: _startTrace,
                onTraceUpdate: _extendTrace,
                onTraceEnd: _finishTrace,
                onPanCanvas: _panCanvas,
              ),
              AppSpacing.gapSM,
              if (_areaMode != _AreaMode.fineTune)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton(
                      key: const ValueKey('fox-pattern-preview-undo-area'),
                      onPressed: _activeCandidate.points.isEmpty
                          ? null
                          : _undoAreaPoint,
                      child: const Text('UNDO POINT'),
                    ),
                    OutlinedButton(
                      key: const ValueKey('fox-pattern-preview-clear-area'),
                      onPressed: _activeCandidate.points.isEmpty
                          ? null
                          : _clearArea,
                      child: const Text('CLEAR AREA'),
                    ),
                    OutlinedButton(
                      key: const ValueKey('fox-pattern-preview-close-area'),
                      onPressed: _activeCandidate.canClose ? _closeArea : null,
                      child: const Text('CLOSE AREA'),
                    ),
                    FilledButton(
                      key: const ValueKey('fox-pattern-preview-apply-area'),
                      onPressed: _activeCandidate.isReady ? _applyArea : null,
                      child: const Text('APPLY AREA'),
                    ),
                  ],
                ),
              if (_areaMode != _AreaMode.fineTune) AppSpacing.gapMD,
              const Text('FINE TUNE'),
              const Text('CONTROL POINT'),
              DropdownButton<String>(
                key: const ValueKey('fox-pattern-preview-point-selector'),
                value: _pointId,
                isExpanded: true,
                items: [
                  for (final candidate in _activeMask.points)
                    DropdownMenuItem(
                      value: candidate.id,
                      child: Text(candidate.displayName),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _pointId = value);
                },
              ),
              AppSpacing.gapSM,
              Text(
                '${point.displayName}  •  X ${point.x.toStringAsFixed(5)}  •  '
                'Y ${point.y.toStringAsFixed(5)}  •  drag preview or nudge 1px',
                key: const ValueKey('fox-pattern-preview-point-value'),
              ),
              Text(
                'POINT COUNT: ${_activeMask.points.length}',
                key: const ValueKey('fox-pattern-preview-point-count'),
              ),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    key: const ValueKey('fox-pattern-preview-controls-off'),
                    label: const Text('CONTROLS OFF'),
                    selected: !_showControls,
                    onSelected: (_) => setState(() => _showControls = false),
                  ),
                  ChoiceChip(
                    key: const ValueKey('fox-pattern-preview-controls-on'),
                    label: const Text('CONTROLS ON'),
                    selected: _showControls,
                    onSelected: (_) => setState(() => _showControls = true),
                  ),
                ],
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
                  _DPad(
                    onNudge: _nudge,
                    key: const ValueKey('fox-pattern-preview-dpad'),
                  ),
                  OutlinedButton(
                    key: const ValueKey('fox-pattern-preview-add-point'),
                    onPressed: _addPoint,
                    child: const Text('ADD POINT'),
                  ),
                  OutlinedButton(
                    key: const ValueKey('fox-pattern-preview-delete-point'),
                    onPressed: _activeMask.canDelete(_pointId)
                        ? _deletePoint
                        : null,
                    child: const Text('DELETE POINT'),
                  ),
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
              AppSpacing.gapSM,
              const Text('COPY FROM FRAME'),
              DropdownButton<int>(
                key: const ValueKey('fox-pattern-preview-copy-source'),
                value: _copySourceFrame,
                isExpanded: true,
                items: [
                  for (final frame in FoxPatternPreview.frames)
                    DropdownMenuItem(
                      value: frame,
                      enabled: frame != _frame,
                      child: Text(frame.toString().padLeft(2, '0')),
                    ),
                ],
                onChanged: (value) {
                  if (value != null && value != _frame) {
                    setState(() => _copySourceFrame = value);
                  }
                },
              ),
              OutlinedButton(
                key: const ValueKey('fox-pattern-preview-copy-from-frame'),
                onPressed: _copySourceFrame == _frame ? null : _copyFromFrame,
                child: Text(
                  'COPY ${_part.label} FRAME ${_copySourceFrame.toString().padLeft(2, '0')} '
                  '→ ${_frame.toString().padLeft(2, '0')}',
                ),
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
    required this.part,
    required this.masks,
    required this.activeMask,
    required this.selectedPointId,
    required this.candidate,
    required this.areaPointCount,
    required this.areaMode,
    required this.zoom,
    required this.pan,
    required this.showControls,
    required this.onSelectPoint,
    required this.onDrag,
    required this.onAreaTap,
    required this.onTraceStart,
    required this.onTraceUpdate,
    required this.onTraceEnd,
    required this.onPanCanvas,
  });

  final int frame;
  final _FoxPatternPart part;
  final Map<_FoxPatternPart, _MaskPath> masks;
  final _MaskPath activeMask;
  final String selectedPointId;
  final _AreaCandidate candidate;
  final int areaPointCount;
  final _AreaMode areaMode;
  final double zoom;
  final Offset pan;
  final bool showControls;
  final ValueChanged<String> onSelectPoint;
  final void Function(DragUpdateDetails details, Size size) onDrag;
  final ValueChanged<Offset> onAreaTap;
  final ValueChanged<Offset> onTraceStart;
  final ValueChanged<Offset> onTraceUpdate;
  final VoidCallback onTraceEnd;
  final void Function(Offset delta, Size size) onPanCanvas;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth;
      final size = Size(
        width,
        width / FoxRunV1ProductionGeometry.canvasSize.aspectRatio,
      );
      return SizedBox(
        width: size.width,
        height: size.height,
        child: ClipRect(
          child: _EditorGestureLayer(
            path: activeMask,
            size: size,
            selectedPointId: selectedPointId,
            areaMode: areaMode,
            zoom: zoom,
            pan: pan,
            onSelectPoint: onSelectPoint,
            onDrag: onDrag,
            onAreaTap: onAreaTap,
            onTraceStart: onTraceStart,
            onTraceUpdate: onTraceUpdate,
            onTraceEnd: onTraceEnd,
            onPanCanvas: onPanCanvas,
            child: Transform.scale(
              alignment: Alignment.topLeft,
              scale: zoom,
              transformHitTests: false,
              child: Transform.translate(
                offset: pan / zoom,
                transformHitTests: false,
                child: SizedBox(
                  width: size.width,
                  height: size.height,
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
                      if (candidate.isReady)
                        ClipPath(
                          clipper: _MaskPathClipper(
                            candidate.toMaskPath(areaPointCount),
                          ),
                          child: _PreviewPatternCel.single(
                            frame: frame,
                            color: part.color,
                          ),
                        ),
                      IgnorePointer(
                        child: CustomPaint(
                          painter: _MaskControlPointPainter(
                            path: activeMask,
                            selectedPointId: selectedPointId,
                            showControls: showControls,
                          ),
                        ),
                      ),
                      if (areaMode != _AreaMode.fineTune)
                        IgnorePointer(
                          child: CustomPaint(
                            painter: _AreaCandidatePainter(
                              candidate: candidate,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _EditorGestureLayer extends StatefulWidget {
  const _EditorGestureLayer({
    required this.path,
    required this.size,
    required this.selectedPointId,
    required this.areaMode,
    required this.zoom,
    required this.pan,
    required this.onSelectPoint,
    required this.onDrag,
    required this.onAreaTap,
    required this.onTraceStart,
    required this.onTraceUpdate,
    required this.onTraceEnd,
    required this.onPanCanvas,
    required this.child,
  });

  final _MaskPath path;
  final Size size;
  final String selectedPointId;
  final _AreaMode areaMode;
  final double zoom;
  final Offset pan;
  final ValueChanged<String> onSelectPoint;
  final void Function(DragUpdateDetails details, Size size) onDrag;
  final ValueChanged<Offset> onAreaTap;
  final ValueChanged<Offset> onTraceStart;
  final ValueChanged<Offset> onTraceUpdate;
  final VoidCallback onTraceEnd;
  final void Function(Offset delta, Size size) onPanCanvas;
  final Widget child;

  @override
  State<_EditorGestureLayer> createState() => _EditorGestureLayerState();
}

class _EditorGestureLayerState extends State<_EditorGestureLayer> {
  String? _dragPointId;

  Offset _canvas(Offset position) => (position - widget.pan) / widget.zoom;
  Offset _normalized(Offset position) {
    final canvas = _canvas(position);
    return Offset(
      canvas.dx / widget.size.width,
      canvas.dy / widget.size.height,
    );
  }

  void _selectAt(Offset position) {
    final point = widget.path.nextHitPoint(
      _canvas(position),
      widget.size,
      afterId: widget.selectedPointId,
    );
    if (point != null) widget.onSelectPoint(point.id);
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTapUp: (details) {
      if (widget.areaMode == _AreaMode.freeTap) {
        widget.onAreaTap(_normalized(details.localPosition));
      } else if (widget.areaMode == _AreaMode.fineTune) {
        _selectAt(details.localPosition);
      }
    },
    onPanStart: (details) {
      if (widget.areaMode == _AreaMode.trace) {
        widget.onTraceStart(_normalized(details.localPosition));
        return;
      }
      if (widget.areaMode != _AreaMode.fineTune) return;
      final point = widget.path.nextHitPoint(
        _canvas(details.localPosition),
        widget.size,
        afterId: widget.selectedPointId,
      );
      _dragPointId = point?.id;
      if (point != null) widget.onSelectPoint(point.id);
    },
    onPanUpdate: (details) {
      if (widget.areaMode == _AreaMode.trace) {
        widget.onTraceUpdate(_normalized(details.localPosition));
      } else if (_dragPointId != null) {
        widget.onDrag(
          DragUpdateDetails(
            globalPosition: details.globalPosition,
            localPosition: _canvas(details.localPosition),
            delta: details.delta / widget.zoom,
            primaryDelta: details.primaryDelta,
          ),
          widget.size,
        );
      } else if (widget.areaMode == _AreaMode.fineTune && widget.zoom > 1) {
        widget.onPanCanvas(details.delta, widget.size);
      }
    },
    onPanEnd: (_) {
      if (widget.areaMode == _AreaMode.trace) widget.onTraceEnd();
      _dragPointId = null;
    },
    onPanCancel: () {
      _dragPointId = null;
    },
    child: widget.child,
  );
}

class _PreviewPatternCel extends StatelessWidget {
  const _PreviewPatternCel({required this.frame, required this.masks})
    : _singleColor = null;

  final int frame;
  final Map<_FoxPatternPart, _MaskPath> masks;

  const _PreviewPatternCel.single({required this.frame, required Color color})
    : masks = const {},
      _singleColor = color;

  final Color? _singleColor;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      if (_singleColor case final color?)
        _cel(color)
      else
        _cel(FoxRunV1ProductionStage.silhouetteColor),
      if (_singleColor == null)
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

class _AreaCandidatePainter extends CustomPainter {
  const _AreaCandidatePainter({required this.candidate});

  final _AreaCandidate candidate;

  @override
  void paint(Canvas canvas, Size size) {
    if (candidate.points.isEmpty) return;
    final points = candidate.points
        .map((point) => Offset(point.dx * size.width, point.dy * size.height))
        .toList();
    final line = Paint()
      ..color = Colors.orangeAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    if (candidate.closed) path.close();
    canvas.drawPath(path, line);
    final marker = Paint()..color = Colors.orangeAccent;
    for (final point in points) {
      canvas.drawCircle(point, 6, marker);
    }
  }

  @override
  bool shouldRepaint(covariant _AreaCandidatePainter oldDelegate) => true;
}

class _MaskControlPointPainter extends CustomPainter {
  const _MaskControlPointPainter({
    required this.path,
    required this.selectedPointId,
    required this.showControls,
  });

  final _MaskPath path;
  final String selectedPointId;
  final bool showControls;

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
      if (segment.control1 case final control1?) {
        canvas.drawLine(control1.toOffset(size), anchor, line);
      }
      if (segment.control2 case final control2?) {
        canvas.drawLine(control2.toOffset(size), anchor, line);
      }
    }
    for (final point in path.points) {
      if (!showControls && point.role == _MaskPointRole.control) continue;
      final selected = point.id == selectedPointId;
      final paint = selected ? selectedPaint : pointPaint;
      final offset = point.toOffset(size);
      if (point.role == _MaskPointRole.anchor) {
        canvas.drawCircle(offset, selected ? 10 : 7, paint);
      } else {
        final radius = selected ? 6 : 4;
        final diamond = Path()
          ..moveTo(offset.dx, offset.dy - radius)
          ..lineTo(offset.dx + radius, offset.dy)
          ..lineTo(offset.dx, offset.dy + radius)
          ..lineTo(offset.dx - radius, offset.dy)
          ..close();
        canvas.drawPath(diamond, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MaskControlPointPainter oldDelegate) => true;
}

enum _AreaMode { fineTune, freeTap, trace }

class _AreaCandidate {
  final List<Offset> points = [];
  bool closed = false;

  bool get canClose => points.length >= 3 && !closed;
  bool get isReady => closed && points.length >= 3;

  void add(Offset point) {
    final normalized = Offset(
      point.dx.clamp(-.25, 1.25).toDouble(),
      point.dy.clamp(-.25, 1.25).toDouble(),
    );
    if (points.isEmpty || (points.last - normalized).distance > .002) {
      points.add(normalized);
    }
    closed = false;
  }

  void undo() {
    if (points.isNotEmpty) points.removeLast();
    closed = false;
  }

  void clear() {
    points.clear();
    closed = false;
  }

  _MaskPath toMaskPath(int anchorCount) {
    final anchors = _resampleClosed(points, anchorCount);
    final bounds = _Bounds.fromPoints(anchors);
    clampPoint(Offset point) => Offset(
      point.dx.clamp(bounds.minX, bounds.maxX).toDouble(),
      point.dy.clamp(bounds.minY, bounds.maxY).toDouble(),
    );
    pointFor(int index) => anchors[index % anchors.length];
    control1(int from, int to) {
      final previous = pointFor(from - 1);
      final current = pointFor(from);
      final next = pointFor(to);
      return clampPoint(current + (next - previous) / 6);
    }

    control2(int from, int to) {
      final current = pointFor(from);
      final next = pointFor(to);
      final after = pointFor(to + 1);
      return clampPoint(next - (after - current) / 6);
    }

    final start = _MaskPoint(
      'A0',
      anchors.first.dx,
      anchors.first.dy,
      _MaskPointRole.anchor,
    );
    final segments = <_MaskCubicSegment>[];
    for (var index = 1; index < anchors.length; index++) {
      final c1 = control1(index - 1, index);
      final c2 = control2(index - 1, index);
      segments.add(
        _MaskCubicSegment(
          _MaskPoint('C${index * 2 - 1}', c1.dx, c1.dy, _MaskPointRole.control),
          _MaskPoint('C${index * 2}', c2.dx, c2.dy, _MaskPointRole.control),
          _MaskPoint(
            'A$index',
            anchors[index].dx,
            anchors[index].dy,
            _MaskPointRole.anchor,
          ),
        ),
      );
    }
    return _MaskPath(start, segments);
  }
}

class _Bounds {
  const _Bounds(this.minX, this.maxX, this.minY, this.maxY);

  final double minX;
  final double maxX;
  final double minY;
  final double maxY;

  factory _Bounds.fromPoints(List<Offset> points) => _Bounds(
    points.map((point) => point.dx).reduce((a, b) => a < b ? a : b),
    points.map((point) => point.dx).reduce((a, b) => a > b ? a : b),
    points.map((point) => point.dy).reduce((a, b) => a < b ? a : b),
    points.map((point) => point.dy).reduce((a, b) => a > b ? a : b),
  );
}

List<Offset> _resampleClosed(List<Offset> input, int count) {
  final contour = [...input, input.first];
  final lengths = <double>[0];
  for (var index = 1; index < contour.length; index++) {
    lengths.add(lengths.last + (contour[index] - contour[index - 1]).distance);
  }
  final total = lengths.last;
  if (total == 0) return List.filled(count, input.first);
  return List.generate(count, (index) {
    final target = total * index / count;
    var segment = 1;
    while (segment < lengths.length && lengths[segment] < target) {
      segment++;
    }
    final begin = lengths[segment - 1];
    final end = lengths[segment];
    final t = end == begin ? 0.0 : (target - begin) / (end - begin);
    return Offset.lerp(contour[segment - 1], contour[segment], t)!;
  });
}

class _DPad extends StatelessWidget {
  const _DPad({super.key, required this.onNudge});

  final void Function({required double dx, required double dy}) onNudge;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 128,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _RepeatNudgeButton(
          icon: Icons.keyboard_arrow_up,
          dx: 0,
          dy: -1,
          onNudge: onNudge,
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _RepeatNudgeButton(
              icon: Icons.keyboard_arrow_left,
              dx: -1,
              dy: 0,
              onNudge: onNudge,
            ),
            const SizedBox(width: 32, height: 32),
            _RepeatNudgeButton(
              icon: Icons.keyboard_arrow_right,
              dx: 1,
              dy: 0,
              onNudge: onNudge,
            ),
          ],
        ),
        _RepeatNudgeButton(
          icon: Icons.keyboard_arrow_down,
          dx: 0,
          dy: 1,
          onNudge: onNudge,
        ),
      ],
    ),
  );
}

class _RepeatNudgeButton extends StatefulWidget {
  const _RepeatNudgeButton({
    required this.icon,
    required this.dx,
    required this.dy,
    required this.onNudge,
  });

  final IconData icon;
  final double dx;
  final double dy;
  final void Function({required double dx, required double dy}) onNudge;

  @override
  State<_RepeatNudgeButton> createState() => _RepeatNudgeButtonState();
}

class _RepeatNudgeButtonState extends State<_RepeatNudgeButton> {
  Timer? _delay;
  Timer? _repeat;

  void _start() {
    widget.onNudge(dx: widget.dx, dy: widget.dy);
    _delay = Timer(const Duration(milliseconds: 300), () {
      _repeat = Timer.periodic(const Duration(milliseconds: 80), (_) {
        widget.onNudge(dx: widget.dx, dy: widget.dy);
      });
    });
  }

  void _stop() {
    _delay?.cancel();
    _repeat?.cancel();
  }

  @override
  void dispose() {
    _stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: (_) => _start(),
    onPointerUp: (_) => _stop(),
    onPointerCancel: (_) => _stop(),
    child: IconButton(icon: Icon(widget.icon), onPressed: () {}),
  );
}

enum _MaskPointRole { anchor, control }

class _MaskPoint {
  _MaskPoint(this.id, this.x, this.y, this.role);

  final String id;
  double x;
  double y;
  final _MaskPointRole role;

  String get displayName => switch (role) {
    _MaskPointRole.anchor => 'ANCHOR ${id.substring(1)}',
    _MaskPointRole.control => 'CONTROL ${id.substring(1)}',
  };

  Offset toOffset(Size size) => Offset(x * size.width, y * size.height);

  void nudge({required double dx, required double dy}) {
    x = (x + dx).clamp(-.25, 1.25).toDouble();
    y = (y + dy).clamp(-.25, 1.25).toDouble();
  }

  _MaskPoint copy() => _MaskPoint(id, x, y, role);

  String serialize() =>
      '$id role=${role.name} x=${x.toStringAsFixed(6)} '
      'y=${y.toStringAsFixed(6)}';
}

class _MaskCubicSegment {
  _MaskCubicSegment(this.control1, this.control2, this.anchor);

  _MaskPoint? control1;
  _MaskPoint? control2;
  final _MaskPoint anchor;

  _MaskCubicSegment copy() =>
      _MaskCubicSegment(control1?.copy(), control2?.copy(), anchor.copy());
}

class _MaskPath {
  _MaskPath(this.start, this.segments);

  final _MaskPoint start;
  final List<_MaskCubicSegment> segments;

  List<_MaskPoint> get points => [
    start,
    for (final segment in segments) ...[
      if (segment.control1 != null) segment.control1!,
      if (segment.control2 != null) segment.control2!,
      segment.anchor,
    ],
  ];

  _MaskPoint point(String id) => points.firstWhere((point) => point.id == id);

  Path toPath(Size size) {
    final path = Path()..moveTo(start.x * size.width, start.y * size.height);
    for (final segment in segments) {
      final control1 = segment.control1;
      final control2 = segment.control2;
      final anchor = segment.anchor;
      if (control1 != null && control2 != null) {
        path.cubicTo(
          control1.x * size.width,
          control1.y * size.height,
          control2.x * size.width,
          control2.y * size.height,
          anchor.x * size.width,
          anchor.y * size.height,
        );
      } else if (control1 != null || control2 != null) {
        final control = control1 ?? control2!;
        path.quadraticBezierTo(
          control.x * size.width,
          control.y * size.height,
          anchor.x * size.width,
          anchor.y * size.height,
        );
      } else {
        path.lineTo(anchor.x * size.width, anchor.y * size.height);
      }
    }
    return path..close();
  }

  _MaskPath copy() =>
      _MaskPath(start.copy(), [for (final segment in segments) segment.copy()]);

  bool canDelete(String pointId) {
    final candidate = point(pointId);
    return candidate.role == _MaskPointRole.control || anchorCount > 3;
  }

  int get anchorCount =>
      1 +
      segments
          .where((segment) => segment.anchor.role == _MaskPointRole.anchor)
          .length;

  _MaskPoint? nextHitPoint(
    Offset position,
    Size size, {
    required String afterId,
  }) {
    const hitRadius = 18.0;
    final candidates =
        points
            .map(
              (point) => (
                point: point,
                distance: (point.toOffset(size) - position).distance,
              ),
            )
            .where((candidate) => candidate.distance <= hitRadius)
            .toList()
          ..sort((left, right) => left.distance.compareTo(right.distance));
    if (candidates.isEmpty) return null;

    // Closed paths can intentionally share their start/end coordinate. Repeated
    // direct taps cycle only points at that exact visual location, keeping every
    // point editable without treating either endpoint as a hidden fixed anchor.
    const overlapTolerance = .5;
    final nearestDistance = candidates.first.distance;
    final overlapping = candidates
        .where(
          (candidate) =>
              (candidate.distance - nearestDistance).abs() <= overlapTolerance,
        )
        .map((candidate) => candidate.point)
        .toList();
    final selectedIndex = overlapping.indexWhere(
      (point) => point.id == afterId,
    );
    if (selectedIndex >= 0) {
      return overlapping[(selectedIndex + 1) % overlapping.length];
    }
    return overlapping.first;
  }

  String insertAnchorAfter(String pointId) {
    final index = _segmentIndexFor(pointId);
    final preceding = index < 0 ? start : segments[index].anchor;
    final following = index + 1 < segments.length
        ? segments[index + 1].anchor
        : start;
    final id = 'A${_nextAnchorOrdinal()}';
    final anchor = _MaskPoint(
      id,
      (preceding.x + following.x) / 2,
      (preceding.y + following.y) / 2,
      _MaskPointRole.anchor,
    );
    segments.insert(index + 1, _MaskCubicSegment(null, null, anchor));
    return id;
  }

  String deletePoint(String pointId) {
    assert(canDelete(pointId));
    if (start.id == pointId) {
      final next = segments.removeAt(0);
      start.x = next.anchor.x;
      start.y = next.anchor.y;
      return start.id;
    }
    for (var index = 0; index < segments.length; index++) {
      final segment = segments[index];
      if (segment.control1?.id == pointId) {
        segment.control1 = null;
        return _fallbackPointId(index);
      }
      if (segment.control2?.id == pointId) {
        segment.control2 = null;
        return _fallbackPointId(index);
      }
      if (segment.anchor.id == pointId) {
        segments.removeAt(index);
        return _fallbackPointId(index - 1);
      }
    }
    throw StateError('Unknown mask point $pointId');
  }

  int _segmentIndexFor(String pointId) {
    if (pointId == start.id) return -1;
    return segments.indexWhere(
      (segment) =>
          segment.anchor.id == pointId ||
          segment.control1?.id == pointId ||
          segment.control2?.id == pointId,
    );
  }

  String _fallbackPointId(int preferredSegment) {
    if (segments.isEmpty) return start.id;
    final safe = preferredSegment.clamp(0, segments.length - 1);
    return segments[safe].anchor.id;
  }

  int _nextAnchorOrdinal() {
    final existing = points
        .where((point) => point.id.startsWith('A'))
        .map((point) => int.tryParse(point.id.substring(1)) ?? -1);
    return existing.reduce(
          (maximum, value) => maximum > value ? maximum : value,
        ) +
        1;
  }

  String serialize() => [
    'CLOSED: true',
    'POINT_COUNT: ${points.length}',
    'ANCHOR_COUNT: $anchorCount',
    'MOVE ${start.serialize()}',
    for (var index = 0; index < segments.length; index++)
      _serializeSegment(index, segments[index]),
    'CLOSE',
  ].join('\n');

  String _serializeSegment(int index, _MaskCubicSegment segment) {
    final control1 = segment.control1;
    final control2 = segment.control2;
    if (control1 != null && control2 != null) {
      return 'SEGMENT $index CUBIC ${control1.serialize()} | '
          '${control2.serialize()} | ${segment.anchor.serialize()}';
    }
    final control = control1 ?? control2;
    if (control != null) {
      return 'SEGMENT $index QUADRATIC ${control.serialize()} | '
          '${segment.anchor.serialize()}';
    }
    return 'SEGMENT $index LINE ${segment.anchor.serialize()}';
  }
}

Map<int, Map<_FoxPatternPart, _MaskPath>> _buildInitialMasks() => {
  for (final frame in FoxPatternPreview.frames)
    frame: {
      _FoxPatternPart.tail: _tailMask(),
      _FoxPatternPart.jaw: _jawMask(),
      _FoxPatternPart.feet: _feetMask(),
    },
};

_MaskPoint _point(String id, double x, double y) => _MaskPoint(
  id,
  x,
  y,
  id.startsWith('A') ? _MaskPointRole.anchor : _MaskPointRole.control,
);

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
