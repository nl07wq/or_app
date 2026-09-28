import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/operation_card.dart';
import '../../../core/widgets/section_header.dart';
import 'fox_run_v1_section.dart';

/// Session-only human authority capture for future rear-leg rendering work.
/// It never changes FOX production, pattern geometry, or source assets.
class FoxRearLegGeometryLab extends StatefulWidget {
  const FoxRearLegGeometryLab({super.key});

  static const frames = <int>[1, 3, 5, 6, 7];

  @override
  State<FoxRearLegGeometryLab> createState() => _FoxRearLegGeometryLabState();
}

enum _RearLegEditorMode { region, root, foot, preview }

enum _RegionInputMode { freeTap, trace }

class _FoxRearLegGeometryLabState extends State<FoxRearLegGeometryLab> {
  final _frames = <int, _RearLegFrameData>{
    for (final frame in FoxRearLegGeometryLab.frames)
      frame: _RearLegFrameData(),
  };
  final _candidates = <int, _RearLegCandidate>{};
  var _frame = FoxRearLegGeometryLab.frames.first;
  var _editorMode = _RearLegEditorMode.region;
  var _regionInputMode = _RegionInputMode.freeTap;
  var _pointCount = 8;
  var _zoom = 1.0;
  var _pan = Offset.zero;
  var _focus = const Offset(.5, .5);
  Size _stageSize = Size.zero;

  _RearLegFrameData get _active => _frames[_frame]!;
  _RearLegCandidate get _candidate =>
      _candidates.putIfAbsent(_frame, _RearLegCandidate.new);

  void _selectFrame(int frame) => setState(() {
    _frame = frame;
    _zoom = 1;
    _pan = Offset.zero;
    _focus = const Offset(.5, .5);
  });

  void _setMode(_RearLegEditorMode mode) => setState(() => _editorMode = mode);

  void _setFocus(Offset focus, Size size) => setState(() {
    _focus = focus;
    _stageSize = size;
    _pan = _focalPan(focus, size, _zoom);
  });

  Offset _focalPan(Offset focus, Size size, double zoom) {
    if (zoom == 1 || size.isEmpty) return Offset.zero;
    return Offset(
      (size.width * (.5 - focus.dx * zoom))
          .clamp(size.width * (1 - zoom), 0)
          .toDouble(),
      (size.height * (.5 - focus.dy * zoom))
          .clamp(size.height * (1 - zoom), 0)
          .toDouble(),
    );
  }

  void _setZoom(double zoom) => setState(() {
    _zoom = zoom;
    _pan = _focalPan(_focus, _stageSize, zoom);
  });

  void _panCanvas(Offset delta, Size size) => setState(() {
    if (_zoom == 1) return;
    _pan = Offset(
      (_pan.dx + delta.dx).clamp(-size.width * (_zoom - 1), 0).toDouble(),
      (_pan.dy + delta.dy).clamp(-size.height * (_zoom - 1), 0).toDouble(),
    );
  });

  void _addRegionPoint(Offset point) => setState(() => _candidate.add(point));

  void _startTrace(Offset point) => setState(() {
    _candidate
      ..clear()
      ..add(point);
  });

  void _extendTrace(Offset point) => setState(() => _candidate.add(point));

  void _finishTrace() => setState(() {
    if (_candidate.points.length >= 3) _candidate.closed = true;
  });

  void _applyRegion() => setState(() {
    if (!_candidate.isReady) return;
    _active.region = _candidate.sampleClosed(_pointCount);
    _candidate.clear();
    _editorMode = _RearLegEditorMode.preview;
  });

  void _setAuthority(Offset point) => setState(() {
    if (_editorMode == _RearLegEditorMode.root) {
      _active.root = point;
    } else if (_editorMode == _RearLegEditorMode.foot) {
      _active.foot = point;
    }
  });

  void _nudgeAuthority({required double dx, required double dy}) =>
      setState(() {
        final delta = Offset(
          dx / FoxRunV1ProductionGeometry.canvasSize.width,
          dy / FoxRunV1ProductionGeometry.canvasSize.height,
        );
        if (_editorMode == _RearLegEditorMode.root && _active.root != null) {
          _active.root = _active.root! + delta;
        } else if (_editorMode == _RearLegEditorMode.foot &&
            _active.foot != null) {
          _active.foot = _active.foot! + delta;
        }
      });

  void _resetFrame() => setState(() {
    _frames[_frame] = _RearLegFrameData();
    _candidates.remove(_frame);
  });

  Future<void> _copyData() async {
    await Clipboard.setData(ClipboardData(text: _copyText()));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('FOX REAR LEG DATA COPIED')));
  }

  String _copyText() {
    final buffer = StringBuffer('FOX REAR LEG DATA\nversion: 1\n');
    for (final frame in FoxRearLegGeometryLab.frames) {
      final data = _frames[frame]!;
      buffer
        ..writeln()
        ..writeln('FRAME ${frame.toString().padLeft(2, '0')}')
        ..writeln('REGION');
      if (data.region == null) {
        buffer.writeln('NOT CONFIGURED');
      } else {
        buffer
          ..writeln('CLOSED: true')
          ..writeln('POINT_COUNT: ${data.region!.length}');
        for (var index = 0; index < data.region!.length; index++) {
          final point = data.region![index];
          buffer.writeln(
            'P$index x=${_coordinate(point.dx)} y=${_coordinate(point.dy)}',
          );
        }
      }
      buffer.writeln(
        data.root == null
            ? 'ROOT: NOT CONFIGURED'
            : 'ROOT x=${_coordinate(data.root!.dx)} y=${_coordinate(data.root!.dy)}',
      );
      buffer.writeln(
        data.foot == null
            ? 'FOOT: NOT CONFIGURED'
            : 'FOOT x=${_coordinate(data.foot!.dx)} y=${_coordinate(data.foot!.dy)}',
      );
    }
    return buffer.toString();
  }

  String _coordinate(double value) => value.toString();

  @override
  Widget build(BuildContext context) => Column(
    key: const ValueKey('fox-rear-leg-geometry-lab-section'),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SectionHeader(
        icon: Icons.hiking_outlined,
        title: 'FOX REAR LEG GEOMETRY LAB',
      ),
      AppSpacing.gapSM,
      OperationCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Human-defined, session-only rear-leg authority. Stretch '
              'rendering is not available in this lab.',
            ),
            AppSpacing.gapMD,
            const Text('FRAME'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final frame in FoxRearLegGeometryLab.frames)
                  ChoiceChip(
                    key: ValueKey('fox-rear-leg-frame-$frame'),
                    label: Text(frame.toString().padLeft(2, '0')),
                    selected: _frame == frame,
                    onSelected: (_) => _selectFrame(frame),
                  ),
              ],
            ),
            AppSpacing.gapSM,
            const Text('MODE'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final mode in _RearLegEditorMode.values)
                  ChoiceChip(
                    key: ValueKey('fox-rear-leg-mode-${mode.name}'),
                    label: Text(mode.name.toUpperCase()),
                    selected: _editorMode == mode,
                    onSelected: (_) => _setMode(mode),
                  ),
              ],
            ),
            if (_editorMode == _RearLegEditorMode.region) ...[
              AppSpacing.gapSM,
              const Text('REGION INPUT'),
              Wrap(
                spacing: 8,
                children: [
                  for (final mode in _RegionInputMode.values)
                    ChoiceChip(
                      key: ValueKey('fox-rear-leg-input-${mode.name}'),
                      label: Text(
                        mode == _RegionInputMode.freeTap ? 'FREE TAP' : 'TRACE',
                      ),
                      selected: _regionInputMode == mode,
                      onSelected: (_) =>
                          setState(() => _regionInputMode = mode),
                    ),
                ],
              ),
              const Text('POINTS'),
              Wrap(
                spacing: 8,
                children: [
                  for (final count in [6, 8, 10, 12])
                    ChoiceChip(
                      key: ValueKey('fox-rear-leg-points-$count'),
                      label: Text('$count'),
                      selected: _pointCount == count,
                      onSelected: (_) => setState(() => _pointCount = count),
                    ),
                ],
              ),
            ],
            AppSpacing.gapSM,
            const Text('ZOOM'),
            Wrap(
              spacing: 8,
              children: [
                for (final zoom in [1.0, 2.0, 3.0, 4.0])
                  ChoiceChip(
                    key: ValueKey('fox-rear-leg-zoom-$zoom'),
                    label: Text('${zoom.toInt()}×'),
                    selected: _zoom == zoom,
                    onSelected: (_) => _setZoom(zoom),
                  ),
              ],
            ),
            AppSpacing.gapMD,
            _RearLegStage(
              key: const ValueKey('fox-rear-leg-stage'),
              frame: _frame,
              data: _active,
              candidate: _candidate,
              mode: _editorMode,
              inputMode: _regionInputMode,
              zoom: _zoom,
              pan: _pan,
              onSetFocus: _setFocus,
              onPan: _panCanvas,
              onRegionTap: _addRegionPoint,
              onTraceStart: _startTrace,
              onTraceUpdate: _extendTrace,
              onTraceEnd: _finishTrace,
              onSetAuthority: _setAuthority,
            ),
            AppSpacing.gapSM,
            if (_editorMode == _RearLegEditorMode.region) ...[
              Text(
                _candidate.closed
                    ? 'CANDIDATE READY: ${_candidate.points.length} input points'
                    : 'REGION INPUT: ${_candidate.points.length} points',
                key: const ValueKey('fox-rear-leg-region-status'),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton(
                    key: const ValueKey('fox-rear-leg-undo'),
                    onPressed: _candidate.points.isEmpty
                        ? null
                        : () => setState(_candidate.undo),
                    child: const Text('UNDO'),
                  ),
                  OutlinedButton(
                    key: const ValueKey('fox-rear-leg-clear'),
                    onPressed: _candidate.points.isEmpty
                        ? null
                        : () => setState(_candidate.clear),
                    child: const Text('CLEAR'),
                  ),
                  OutlinedButton(
                    key: const ValueKey('fox-rear-leg-close'),
                    onPressed: _candidate.canClose
                        ? () => setState(() => _candidate.closed = true)
                        : null,
                    child: const Text('CLOSE AREA'),
                  ),
                  FilledButton(
                    key: const ValueKey('fox-rear-leg-apply'),
                    onPressed: _candidate.isReady ? _applyRegion : null,
                    child: const Text('APPLY REGION'),
                  ),
                ],
              ),
            ],
            if (_editorMode == _RearLegEditorMode.root ||
                _editorMode == _RearLegEditorMode.foot) ...[
              AppSpacing.gapXS,
              Text(
                _editorMode == _RearLegEditorMode.root
                    ? _active.root == null
                          ? 'ROOT: NOT CONFIGURED'
                          : 'ROOT: tap, drag, or nudge 1px'
                    : _active.foot == null
                    ? 'FOOT: NOT CONFIGURED'
                    : 'FOOT: tap, drag, or nudge 1px',
                key: const ValueKey('fox-rear-leg-authority-status'),
              ),
              _RearLegDPad(
                key: const ValueKey('fox-rear-leg-dpad'),
                onNudge: _nudgeAuthority,
              ),
            ],
            AppSpacing.gapSM,
            Text(
              'REGION: ${_active.region == null ? 'NOT CONFIGURED' : '${_active.region!.length} points'}  • '
              'ROOT: ${_active.root == null ? 'NOT CONFIGURED' : 'SET'}  • '
              'FOOT: ${_active.foot == null ? 'NOT CONFIGURED' : 'SET'}',
            ),
            AppSpacing.gapSM,
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  key: const ValueKey('fox-rear-leg-reset-frame'),
                  onPressed: _resetFrame,
                  child: const Text('RESET FRAME'),
                ),
                FilledButton.icon(
                  key: const ValueKey('fox-rear-leg-copy'),
                  onPressed: _copyData,
                  icon: const Icon(Icons.content_copy_outlined),
                  label: const Text('COPY REAR LEG DATA'),
                ),
              ],
            ),
          ],
        ),
      ),
    ],
  );
}

class _RearLegStage extends StatefulWidget {
  const _RearLegStage({
    super.key,
    required this.frame,
    required this.data,
    required this.candidate,
    required this.mode,
    required this.inputMode,
    required this.zoom,
    required this.pan,
    required this.onSetFocus,
    required this.onPan,
    required this.onRegionTap,
    required this.onTraceStart,
    required this.onTraceUpdate,
    required this.onTraceEnd,
    required this.onSetAuthority,
  });

  final int frame;
  final _RearLegFrameData data;
  final _RearLegCandidate candidate;
  final _RearLegEditorMode mode;
  final _RegionInputMode inputMode;
  final double zoom;
  final Offset pan;
  final void Function(Offset focus, Size size) onSetFocus;
  final void Function(Offset delta, Size size) onPan;
  final ValueChanged<Offset> onRegionTap;
  final ValueChanged<Offset> onTraceStart;
  final ValueChanged<Offset> onTraceUpdate;
  final VoidCallback onTraceEnd;
  final ValueChanged<Offset> onSetAuthority;

  @override
  State<_RearLegStage> createState() => _RearLegStageState();
}

class _RearLegStageState extends State<_RearLegStage> {
  var _draggingAuthority = false;

  Offset _canonical(Offset local, Size size) {
    final transformed = (local - widget.pan) / widget.zoom;
    return Offset(
      (transformed.dx / size.width).clamp(0.0, 1.0).toDouble(),
      (transformed.dy / size.height).clamp(0.0, 1.0).toDouble(),
    );
  }

  Offset _screenPoint(Offset canonical, Size size) =>
      Offset(canonical.dx * size.width, canonical.dy * size.height) *
          widget.zoom +
      widget.pan;

  Offset? get _authority => switch (widget.mode) {
    _RearLegEditorMode.root => widget.data.root,
    _RearLegEditorMode.foot => widget.data.foot,
    _ => null,
  };

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final size = Size(
        constraints.maxWidth,
        constraints.maxWidth /
            FoxRunV1ProductionGeometry.canvasSize.aspectRatio,
      );
      final asset =
          'assets/animations/sandbox/fox_v1/canonical/'
          'frame_${widget.frame.toString().padLeft(2, '0')}.png';
      return SizedBox(
        width: size.width,
        height: size.height,
        child: ClipRect(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (details) {
              final point = _canonical(details.localPosition, size);
              widget.onSetFocus(point, size);
              if (widget.mode == _RearLegEditorMode.region &&
                  widget.inputMode == _RegionInputMode.freeTap) {
                widget.onRegionTap(point);
              } else if (widget.mode == _RearLegEditorMode.root ||
                  widget.mode == _RearLegEditorMode.foot) {
                widget.onSetAuthority(point);
              }
            },
            onPanStart: (details) {
              final point = _canonical(details.localPosition, size);
              widget.onSetFocus(point, size);
              if (widget.mode == _RearLegEditorMode.region &&
                  widget.inputMode == _RegionInputMode.trace) {
                widget.onTraceStart(point);
                return;
              }
              final authority = _authority;
              _draggingAuthority =
                  authority != null &&
                  (_screenPoint(authority, size) - details.localPosition)
                          .distance <=
                      28;
            },
            onPanUpdate: (details) {
              final point = _canonical(details.localPosition, size);
              if (widget.mode == _RearLegEditorMode.region &&
                  widget.inputMode == _RegionInputMode.trace) {
                widget.onTraceUpdate(point);
              } else if (_draggingAuthority) {
                widget.onSetAuthority(point);
              } else {
                widget.onPan(details.delta, size);
              }
            },
            onPanEnd: (_) {
              if (widget.mode == _RearLegEditorMode.region &&
                  widget.inputMode == _RegionInputMode.trace) {
                widget.onTraceEnd();
              }
              _draggingAuthority = false;
            },
            child: Transform.scale(
              alignment: Alignment.topLeft,
              scale: widget.zoom,
              transformHitTests: false,
              child: Transform.translate(
                offset: widget.pan / widget.zoom,
                transformHitTests: false,
                child: SizedBox(
                  width: size.width,
                  height: size.height,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset(asset, fit: BoxFit.fill),
                      Positioned(
                        left: 0,
                        right: 0,
                        top:
                            size.height *
                            FoxRunV1ProductionGeometry.virtualGround /
                            FoxRunV1ProductionGeometry.canvasSize.height,
                        child: Divider(
                          height: 1,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                      if (widget.data.region != null)
                        _RegionOverlay(
                          points: widget.data.region!,
                          color: Colors.amberAccent,
                          alphaAsset: asset,
                        ),
                      if (widget.mode == _RearLegEditorMode.region &&
                          widget.candidate.points.isNotEmpty)
                        _RegionOverlay(
                          points: widget.candidate.points,
                          closed: widget.candidate.closed,
                          color: Colors.cyanAccent,
                          markers: true,
                        ),
                      if (widget.data.root != null)
                        _AuthorityMarker(
                          point: widget.data.root!,
                          color: Colors.cyanAccent,
                          label: 'ROOT',
                        ),
                      if (widget.data.foot != null)
                        _AuthorityMarker(
                          point: widget.data.foot!,
                          color: Colors.orangeAccent,
                          label: 'FOOT',
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

class _RegionOverlay extends StatelessWidget {
  const _RegionOverlay({
    required this.points,
    required this.color,
    this.alphaAsset,
    this.closed = true,
    this.markers = false,
  });

  final List<Offset> points;
  final Color color;
  final String? alphaAsset;
  final bool closed;
  final bool markers;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      if (alphaAsset != null && closed)
        ClipPath(
          clipper: _PolygonClipper(points),
          child: ShaderMask(
            blendMode: BlendMode.srcIn,
            shaderCallback: (bounds) => LinearGradient(
              colors: [color.withValues(alpha: .26), color],
            ).createShader(bounds),
            child: Image.asset(alphaAsset!, fit: BoxFit.fill),
          ),
        ),
      CustomPaint(
        painter: _RegionPainter(
          points: points,
          color: color,
          closed: closed,
          markers: markers,
          fill: alphaAsset == null,
        ),
      ),
    ],
  );
}

class _PolygonClipper extends CustomClipper<Path> {
  const _PolygonClipper(this.points);

  final List<Offset> points;

  @override
  Path getClip(Size size) {
    final path = Path();
    if (points.isEmpty) return path;
    path.moveTo(points.first.dx * size.width, points.first.dy * size.height);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx * size.width, point.dy * size.height);
    }
    return path..close();
  }

  @override
  bool shouldReclip(covariant _PolygonClipper oldClipper) => true;
}

class _RegionPainter extends CustomPainter {
  const _RegionPainter({
    required this.points,
    required this.color,
    required this.closed,
    required this.markers,
    required this.fill,
  });

  final List<Offset> points;
  final Color color;
  final bool closed;
  final bool markers;
  final bool fill;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    final path = Path()
      ..moveTo(points.first.dx * size.width, points.first.dy * size.height);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx * size.width, point.dy * size.height);
    }
    if (closed) path.close();
    if (fill) {
      canvas.drawPath(path, Paint()..color = color.withValues(alpha: .20));
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    if (!markers) return;
    for (final point in points) {
      canvas.drawCircle(
        Offset(point.dx * size.width, point.dy * size.height),
        5,
        Paint()..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RegionPainter oldDelegate) => true;
}

class _AuthorityMarker extends StatelessWidget {
  const _AuthorityMarker({
    required this.point,
    required this.color,
    required this.label,
  });

  final Offset point;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment(point.dx * 2 - 1, point.dy * 2 - 1),
    child: IgnorePointer(
      child: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Text(
          label,
          style: const TextStyle(fontSize: 7, color: Colors.black),
        ),
      ),
    ),
  );
}

class _RearLegDPad extends StatefulWidget {
  const _RearLegDPad({super.key, required this.onNudge});

  final void Function({required double dx, required double dy}) onNudge;

  @override
  State<_RearLegDPad> createState() => _RearLegDPadState();
}

class _RearLegDPadState extends State<_RearLegDPad> {
  Timer? _timer;

  void _start(double dx, double dy) {
    widget.onNudge(dx: dx, dy: dy);
    _timer = Timer.periodic(const Duration(milliseconds: 80), (_) {
      widget.onNudge(dx: dx, dy: dy);
    });
  }

  void _stop() => _timer?.cancel();

  @override
  void dispose() {
    _stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 4,
    children: [
      _button('↑', 0, -1),
      _button('←', -1, 0),
      _button('→', 1, 0),
      _button('↓', 0, 1),
    ],
  );

  Widget _button(String label, double dx, double dy) => GestureDetector(
    onTap: () => widget.onNudge(dx: dx, dy: dy),
    onLongPressStart: (_) => _start(dx, dy),
    onLongPressEnd: (_) => _stop(),
    child: OutlinedButton(onPressed: null, child: Text(label)),
  );
}

class _RearLegFrameData {
  List<Offset>? region;
  Offset? root;
  Offset? foot;
}

class _RearLegCandidate {
  final points = <Offset>[];
  var closed = false;

  bool get canClose => points.length >= 3 && !closed;
  bool get isReady => closed && points.length >= 3;

  void add(Offset point) {
    points.add(point);
    closed = false;
  }

  void undo() {
    if (points.isNotEmpty) points.removeLast();
    if (points.length < 3) closed = false;
  }

  void clear() {
    points.clear();
    closed = false;
  }

  List<Offset> sampleClosed(int count) {
    if (points.length == count) return List.of(points);
    final lengths = <double>[];
    var perimeter = 0.0;
    for (var index = 0; index < points.length; index++) {
      final length =
          (points[(index + 1) % points.length] - points[index]).distance;
      lengths.add(length);
      perimeter += length;
    }
    if (perimeter == 0) return List.of(points.take(count));
    final sampled = <Offset>[];
    for (var sample = 0; sample < count; sample++) {
      var remaining = perimeter * sample / count;
      for (var index = 0; index < points.length; index++) {
        if (remaining <= lengths[index]) {
          final ratio = lengths[index] == 0 ? 0.0 : remaining / lengths[index];
          sampled.add(
            Offset.lerp(
              points[index],
              points[(index + 1) % points.length],
              ratio,
            )!,
          );
          break;
        }
        remaining -= lengths[index];
      }
    }
    return sampled;
  }
}
