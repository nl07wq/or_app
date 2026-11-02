import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'base_camp_map_configuration.dart';
import 'base_camp_map_export.dart';
import 'widgets/base_camp_map.dart';

enum _BaseCampEditorSection { routes, buildings, soldierSize }

/// Developer-only calibration surface opened by a long press on the existing
/// map framing reset button. It edits a working copy until SAVE is chosen.
class BaseCampMapEditorPage extends StatefulWidget {
  const BaseCampMapEditorPage({super.key});

  @override
  State<BaseCampMapEditorPage> createState() => _BaseCampMapEditorPageState();
}

class _BaseCampMapEditorPageState extends State<BaseCampMapEditorPage> {
  late BaseCampMapConfiguration _working;
  final List<BaseCampMapConfiguration> _undo = <BaseCampMapConfiguration>[];
  _BaseCampEditorSection _section = _BaseCampEditorSection.routes;
  String _routeId = 'route-a';
  String _facilityId = 'status';
  int _pointIndex = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await baseCampMapConfigurationController.load();
    if (!mounted) return;
    setState(() {
      _working = _clone(baseCampMapConfigurationController.value);
      _loading = false;
    });
  }

  BaseCampMapConfiguration _clone(BaseCampMapConfiguration source) =>
      BaseCampMapConfiguration(
        routes: source.routes.map(
          (id, points) => MapEntry(id, List<Offset>.of(points)),
        ),
        facilityOutlines: source.facilityOutlines.map(
          (id, points) => MapEntry(id, List<Offset>.of(points)),
        ),
        soldierScale: source.soldierScale,
      );

  bool get _dirty =>
      _working.encode() != baseCampMapConfigurationController.value.encode();

  void _mutate(BaseCampMapConfiguration next) {
    setState(() {
      _undo.add(_clone(_working));
      _working = next;
    });
  }

  void _updatePoint(Offset point, {bool recordUndo = true}) {
    final normalized = _section == _BaseCampEditorSection.buildings;
    final safe = Offset(
      point.dx
          .clamp(0.0, normalized ? 1.0 : baseCampMapSourceSize.width)
          .toDouble(),
      point.dy
          .clamp(0.0, normalized ? 1.0 : baseCampMapSourceSize.height)
          .toDouble(),
    );
    if (normalized) {
      final points = List<Offset>.of(_working.facilityOutlines[_facilityId]!);
      points[_pointIndex.clamp(0, points.length - 1)] = safe;
      final next = _working.copyWith(
        facilityOutlines: <String, List<Offset>>{
          ..._working.facilityOutlines,
          _facilityId: points,
        },
      );
      if (recordUndo) {
        _mutate(next);
      } else {
        setState(() => _working = next);
      }
    } else {
      final points = List<Offset>.of(_working.routes[_routeId]!);
      points[_pointIndex.clamp(0, points.length - 1)] = safe;
      final next = _working.copyWith(
        routes: <String, List<Offset>>{..._working.routes, _routeId: points},
      );
      if (recordUndo) {
        _mutate(next);
      } else {
        setState(() => _working = next);
      }
    }
  }

  void _beginDrag(int index) {
    setState(() {
      _pointIndex = index;
      _undo.add(_clone(_working));
    });
  }

  List<Offset> get _selectedPoints =>
      _section == _BaseCampEditorSection.buildings
      ? _working.facilityOutlines[_facilityId]!
      : _working.routes[_routeId]!;

  void _selectPoint(int index) => setState(() => _pointIndex = index);

  void _addPoint() {
    final points = List<Offset>.of(_selectedPoints);
    final current = points[_pointIndex.clamp(0, points.length - 1)];
    final next = _pointIndex + 1 < points.length
        ? Offset.lerp(current, points[_pointIndex + 1], .5)!
        : current;
    points.insert(_pointIndex + 1, next);
    _replaceSelectedPoints(points, _pointIndex + 1);
  }

  void _removePoint() {
    final minimum = _section == _BaseCampEditorSection.buildings ? 3 : 2;
    if (_selectedPoints.length <= minimum) return;
    final points = List<Offset>.of(_selectedPoints)..removeAt(_pointIndex);
    _replaceSelectedPoints(
      points,
      (_pointIndex - 1).clamp(0, points.length - 1),
    );
  }

  void _replaceSelectedPoints(List<Offset> points, int selected) {
    setState(() {
      _undo.add(_clone(_working));
      _working = _section == _BaseCampEditorSection.buildings
          ? _working.copyWith(
              facilityOutlines: <String, List<Offset>>{
                ..._working.facilityOutlines,
                _facilityId: points,
              },
            )
          : _working.copyWith(
              routes: <String, List<Offset>>{
                ..._working.routes,
                _routeId: points,
              },
            );
      _pointIndex = selected;
    });
  }

  Future<void> _editCoordinates() async {
    final point =
        _selectedPoints[_pointIndex.clamp(0, _selectedPoints.length - 1)];
    final x = TextEditingController(text: point.dx.toStringAsFixed(3));
    final y = TextEditingController(text: point.dy.toStringAsFixed(3));
    final result = await showDialog<Offset>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('EDIT COORDINATE'),
        content: Row(
          children: [
            Expanded(
              child: TextField(
                controller: x,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: 'X'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: y,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: 'Y'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            onPressed: () {
              final dx = double.tryParse(x.text);
              final dy = double.tryParse(y.text);
              if (dx != null && dy != null && dx.isFinite && dy.isFinite) {
                Navigator.pop(context, Offset(dx, dy));
              }
            },
            child: const Text('APPLY'),
          ),
        ],
      ),
    );
    x.dispose();
    y.dispose();
    if (result != null) _updatePoint(result);
  }

  Future<void> _save() async {
    await baseCampMapConfigurationController.save(_working);
    if (mounted) setState(() => _undo.clear());
  }

  void _undoLast() {
    if (_undo.isEmpty) return;
    setState(() => _working = _undo.removeLast());
  }

  Future<void> _resetToDefaults() async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('RESET TO DEFAULT'),
        content: const Text(
          'Restore all routes, facility outlines and soldier size?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('RESET'),
          ),
        ],
      ),
    );
    if (approved != true) return;
    await baseCampMapConfigurationController.resetToDefaults();
    if (mounted) {
      setState(() {
        _working = _clone(baseCampMapConfigurationController.value);
        _undo.clear();
        _pointIndex = 0;
      });
    }
  }

  Future<bool> _confirmExit() async {
    if (!_dirty) return true;
    final choice = await showDialog<_ExitChoice>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('UNSAVED BASE CAMP MAP'),
        content: const Text('Save changes before leaving the editor?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, _ExitChoice.cancel),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, _ExitChoice.discard),
            child: const Text('DISCARD'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, _ExitChoice.save),
            child: const Text('SAVE'),
          ),
        ],
      ),
    );
    if (choice == _ExitChoice.save) {
      await _save();
    }
    return choice == _ExitChoice.save || choice == _ExitChoice.discard;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        final canExit = !didPop && await _confirmExit();
        if (canExit && mounted) {
          Navigator.of(this.context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('BASE CAMP MAP EDITOR'),
          leading: IconButton(
            tooltip: 'Close editor',
            onPressed: () async {
              if (await _confirmExit() && mounted) {
                Navigator.of(this.context).pop();
              }
            },
            icon: const Icon(Icons.close),
          ),
          actions: [
            IconButton(
              key: const ValueKey('base-camp-editor-undo'),
              onPressed: _undo.isEmpty ? null : _undoLast,
              icon: const Icon(Icons.undo),
            ),
            IconButton(
              key: const ValueKey('base-camp-editor-copy-json'),
              onPressed: () => Clipboard.setData(
                ClipboardData(
                  text: const JsonEncoder.withIndent(
                    '  ',
                  ).convert(_working.toJson()),
                ),
              ),
              icon: const Icon(Icons.content_copy),
            ),
            IconButton(
              key: const ValueKey('base-camp-editor-export-json'),
              onPressed: () => exportBaseCampMapJson(
                const JsonEncoder.withIndent('  ').convert(_working.toJson()),
              ),
              icon: const Icon(Icons.download),
            ),
            IconButton(
              key: const ValueKey('base-camp-editor-save'),
              onPressed: _save,
              icon: const Icon(Icons.save),
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: SegmentedButton<_BaseCampEditorSection>(
                  segments: const [
                    ButtonSegment(
                      value: _BaseCampEditorSection.routes,
                      label: Text('ROUTE EDITOR'),
                    ),
                    ButtonSegment(
                      value: _BaseCampEditorSection.buildings,
                      label: Text('BUILDING EDITOR'),
                    ),
                    ButtonSegment(
                      value: _BaseCampEditorSection.soldierSize,
                      label: Text('SOLDIER SIZE'),
                    ),
                  ],
                  selected: <_BaseCampEditorSection>{_section},
                  onSelectionChanged: (value) => setState(() {
                    _section = value.first;
                    _pointIndex = 0;
                  }),
                ),
              ),
              Expanded(
                child: _BaseCampEditorCanvas(
                  configuration: _working,
                  section: _section,
                  selectedRouteId: _routeId,
                  selectedFacilityId: _facilityId,
                  selectedPoint: _pointIndex,
                  onPointSelected: _selectPoint,
                  onDragStarted: _beginDrag,
                  onPointDragged: (point) =>
                      _updatePoint(point, recordUndo: false),
                ),
              ),
              _editorControls(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _editorControls() {
    if (_section == _BaseCampEditorSection.soldierSize) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (final item in const [
                  (label: '2/3', value: 2 / 3),
                  (label: '1/1', value: 1.0),
                  (label: '2/1', value: 2.0),
                ])
                  FilledButton.tonal(
                    key: ValueKey('base-camp-soldier-size-${item.label}'),
                    onPressed: () =>
                        _mutate(_working.copyWith(soldierScale: item.value)),
                    child: Text(item.label),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              key: const ValueKey('base-camp-editor-reset'),
              onPressed: _resetToDefaults,
              icon: const Icon(Icons.restart_alt),
              label: const Text('RESET TO DEFAULT'),
            ),
          ],
        ),
      );
    }
    final points = _selectedPoints;
    final point = points[_pointIndex.clamp(0, points.length - 1)];
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _section == _BaseCampEditorSection.routes
                      ? _routeId
                      : _facilityId,
                  items:
                      (_section == _BaseCampEditorSection.routes
                              ? const <String>['route-a', 'route-b', 'route-c']
                              : baseCampFacilities
                                    .map((facility) => facility.id)
                                    .toList())
                          .map(
                            (id) => DropdownMenuItem(
                              value: id,
                              child: Text(id.toUpperCase()),
                            ),
                          )
                          .toList(),
                  onChanged: (value) => setState(() {
                    if (_section == _BaseCampEditorSection.routes) {
                      _routeId = value!;
                    } else {
                      _facilityId = value!;
                    }
                    _pointIndex = 0;
                  }),
                ),
              ),
              IconButton(
                onPressed: _addPoint,
                icon: const Icon(Icons.add_circle_outline),
              ),
              IconButton(
                onPressed: _removePoint,
                icon: const Icon(Icons.remove_circle_outline),
              ),
            ],
          ),
          Row(
            children: [
              IconButton(
                onPressed: _pointIndex == 0
                    ? null
                    : () => _selectPoint(_pointIndex - 1),
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Text(
                  'POINT ${_pointIndex + 1}/${points.length}  X ${point.dx.toStringAsFixed(3)}  Y ${point.dy.toStringAsFixed(3)}',
                  textAlign: TextAlign.center,
                ),
              ),
              IconButton(
                onPressed: _pointIndex >= points.length - 1
                    ? null
                    : () => _selectPoint(_pointIndex + 1),
                icon: const Icon(Icons.chevron_right),
              ),
              IconButton(
                tooltip: 'Edit coordinate',
                onPressed: _editCoordinates,
                icon: const Icon(Icons.edit_location_alt),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: () => _updatePoint(
                  Offset(
                    point.dx,
                    point.dy -
                        (_section == _BaseCampEditorSection.routes
                            ? 1
                            : 1 / baseCampMapSourceSize.height),
                  ),
                ),
                icon: const Icon(Icons.keyboard_arrow_up),
              ),
              IconButton(
                onPressed: () => _updatePoint(
                  Offset(
                    point.dx -
                        (_section == _BaseCampEditorSection.routes
                            ? 1
                            : 1 / baseCampMapSourceSize.width),
                    point.dy,
                  ),
                ),
                icon: const Icon(Icons.keyboard_arrow_left),
              ),
              IconButton(
                onPressed: () => _updatePoint(
                  Offset(
                    point.dx +
                        (_section == _BaseCampEditorSection.routes
                            ? 1
                            : 1 / baseCampMapSourceSize.width),
                    point.dy,
                  ),
                ),
                icon: const Icon(Icons.keyboard_arrow_right),
              ),
              IconButton(
                onPressed: () => _updatePoint(
                  Offset(
                    point.dx,
                    point.dy +
                        (_section == _BaseCampEditorSection.routes
                            ? 1
                            : 1 / baseCampMapSourceSize.height),
                  ),
                ),
                icon: const Icon(Icons.keyboard_arrow_down),
              ),
            ],
          ),
          OutlinedButton.icon(
            key: const ValueKey('base-camp-editor-reset'),
            onPressed: _resetToDefaults,
            icon: const Icon(Icons.restart_alt),
            label: const Text('RESET TO DEFAULT'),
          ),
        ],
      ),
    );
  }
}

enum _ExitChoice { save, discard, cancel }

class _BaseCampEditorCanvas extends StatelessWidget {
  const _BaseCampEditorCanvas({
    required this.configuration,
    required this.section,
    required this.selectedRouteId,
    required this.selectedFacilityId,
    required this.selectedPoint,
    required this.onPointSelected,
    required this.onDragStarted,
    required this.onPointDragged,
  });
  final BaseCampMapConfiguration configuration;
  final _BaseCampEditorSection section;
  final String selectedRouteId, selectedFacilityId;
  final int selectedPoint;
  final ValueChanged<int> onPointSelected;
  final ValueChanged<int> onDragStarted;
  final ValueChanged<Offset> onPointDragged;

  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: 16 / 9,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final points = section == _BaseCampEditorSection.buildings
            ? configuration.facilityOutlines[selectedFacilityId]!
            : configuration.routes[selectedRouteId]!;
        Offset displayPoint(Offset point) =>
            section == _BaseCampEditorSection.buildings
            ? Offset(point.dx * size.width, point.dy * size.height)
            : Offset(
                point.dx / baseCampMapSourceSize.width * size.width,
                point.dy / baseCampMapSourceSize.height * size.height,
              );
        Offset sourcePoint(Offset point) =>
            section == _BaseCampEditorSection.buildings
            ? Offset(point.dx / size.width, point.dy / size.height)
            : Offset(
                point.dx / size.width * baseCampMapSourceSize.width,
                point.dy / size.height * baseCampMapSourceSize.height,
              );
        return ClipRect(
          child: Stack(
            fit: StackFit.expand,
            children: [
              const Image(
                image: AssetImage(baseCampMapAsset),
                fit: BoxFit.cover,
              ),
              IgnorePointer(
                child: BaseCampWalkerPreviewLayer(
                  elapsed: const Duration(seconds: 2),
                  reducedMotion: false,
                  configuration: configuration,
                ),
              ),
              CustomPaint(
                painter: _BaseCampEditorGuidePainter(
                  configuration: configuration,
                  section: section,
                  selectedId: section == _BaseCampEditorSection.buildings
                      ? selectedFacilityId
                      : selectedRouteId,
                ),
              ),
              if (section != _BaseCampEditorSection.soldierSize)
                for (var i = 0; i < points.length; i++)
                  Positioned(
                    left: displayPoint(points[i]).dx - 14,
                    top: displayPoint(points[i]).dy - 14,
                    width: 28,
                    height: 28,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onPointSelected(i),
                      onPanStart: (_) => onDragStarted(i),
                      onPanUpdate: (details) => onPointDragged(
                        sourcePoint(displayPoint(points[i]) + details.delta),
                      ),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i == selectedPoint
                              ? const Color(0xFF68E8F2)
                              : const Color(0xCC101A1D),
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                      ),
                    ),
                  ),
            ],
          ),
        );
      },
    ),
  );
}

class _BaseCampEditorGuidePainter extends CustomPainter {
  const _BaseCampEditorGuidePainter({
    required this.configuration,
    required this.section,
    required this.selectedId,
  });
  final BaseCampMapConfiguration configuration;
  final _BaseCampEditorSection section;
  final String selectedId;
  @override
  void paint(Canvas canvas, Size size) {
    if (section == _BaseCampEditorSection.soldierSize) return;
    final normalized = section == _BaseCampEditorSection.buildings;
    final points = normalized
        ? configuration.facilityOutlines[selectedId]!
        : configuration.routes[selectedId]!;
    final path = Path();
    for (var index = 0; index < points.length; index++) {
      final point = normalized
          ? Offset(
              points[index].dx * size.width,
              points[index].dy * size.height,
            )
          : Offset(
              points[index].dx / baseCampMapSourceSize.width * size.width,
              points[index].dy / baseCampMapSourceSize.height * size.height,
            );
      if (index == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    if (normalized) path.close();
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF68E8F2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_BaseCampEditorGuidePainter old) =>
      old.configuration != configuration ||
      old.section != section ||
      old.selectedId != selectedId;
}
