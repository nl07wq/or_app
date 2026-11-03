import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'base_camp_map_configuration.dart';
import 'base_camp_asset_import.dart';
import 'base_camp_asset_store.dart';
import 'base_camp_map_export.dart';
import 'widgets/base_camp_map.dart';

enum _BaseCampEditorSection {
  routes,
  buildings,
  objects,
  smokeOrigin,
  soldierSize,
}

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
  final GlobalKey<_BaseCampEditorCanvasState> _canvasKey =
      GlobalKey<_BaseCampEditorCanvasState>();
  _BaseCampEditorSection _section = _BaseCampEditorSection.routes;
  String _routeId = 'route-a';
  String _facilityId = 'status';
  String _objectId = 'status';
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
        objects: Map<String, BaseCampMapObject>.of(source.objects),
        soldierScale: source.soldierScale,
        foodSmokeOrigin: source.foodSmokeOrigin,
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

  void _beginSmokeOriginDrag() {
    setState(() => _undo.add(_clone(_working)));
  }

  void _updateSmokeOrigin(Offset sourcePoint, {bool recordUndo = true}) {
    final food = _working.objects['food'];
    if (food == null) return;
    final local = baseCampSourceToObjectLocal(food, sourcePoint);
    final safe = Offset(
      local.dx.clamp(0.0, 1.0).toDouble(),
      local.dy.clamp(0.0, 1.0).toDouble(),
    );
    final next = _working.copyWith(foodSmokeOrigin: safe);
    if (recordUndo) {
      _mutate(next);
    } else {
      setState(() => _working = next);
    }
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
            IconButton(
              key: const ValueKey('base-camp-editor-reset-view'),
              tooltip: 'FIT MAP',
              onPressed: () => _canvasKey.currentState?.resetView(),
              icon: const Icon(Icons.fit_screen),
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
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
                        value: _BaseCampEditorSection.objects,
                        label: Text('OBJECT EDITOR'),
                      ),
                      ButtonSegment(
                        value: _BaseCampEditorSection.smokeOrigin,
                        label: Text('SMOKE ORIGIN'),
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
              ),
              Expanded(
                child: _BaseCampEditorCanvas(
                  key: _canvasKey,
                  configuration: _working,
                  section: _section,
                  selectedRouteId: _routeId,
                  selectedFacilityId: _facilityId,
                  selectedObjectId: _objectId,
                  selectedPoint: _pointIndex,
                  onPointSelected: _selectPoint,
                  onDragStarted: _beginDrag,
                  onPointDragged: (point) =>
                      _updatePoint(point, recordUndo: false),
                  onSmokeOriginDragStarted: _beginSmokeOriginDrag,
                  onSmokeOriginDragged: (point) =>
                      _updateSmokeOrigin(point, recordUndo: false),
                  onObjectDragStarted: () {
                    setState(() => _undo.add(_clone(_working)));
                  },
                  onObjectDragged: (point) {
                    final object = _working.objects[_objectId]!;
                    _replaceObject(
                      object.copyWith(position: point),
                      recordUndo: false,
                    );
                  },
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
    if (_section == _BaseCampEditorSection.objects) {
      final object = _working.objects[_objectId]!;
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _objectId,
              items: _working.objects.keys
                  .map(
                    (id) => DropdownMenuItem(
                      value: id,
                      child: Text(id.toUpperCase()),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _objectId = value!),
            ),
            Row(
              children: [
                const Text('SCALE'),
                Expanded(
                  child: Slider(
                    value: object.scale,
                    min: .1,
                    max: 2,
                    onChanged: (value) =>
                        _replaceObject(object.copyWith(scale: value)),
                  ),
                ),
                Text(object.scale.toStringAsFixed(2)),
              ],
            ),
            Row(
              children: [
                const Text('ROTATION'),
                Expanded(
                  child: Slider(
                    value: object.rotation.clamp(-3.14159, 3.14159),
                    min: -3.14159,
                    max: 3.14159,
                    onChanged: (value) =>
                        _replaceObject(object.copyWith(rotation: value)),
                  ),
                ),
                IconButton(
                  tooltip: object.visible ? 'HIDE' : 'SHOW',
                  onPressed: () =>
                      _replaceObject(object.copyWith(visible: !object.visible)),
                  icon: Icon(
                    object.visible ? Icons.visibility : Icons.visibility_off,
                  ),
                ),
                IconButton(
                  tooltip: 'MOVE LAYER UP',
                  onPressed: () => _replaceObject(
                    object.copyWith(zIndex: object.zIndex + 1),
                  ),
                  icon: const Icon(Icons.layers),
                ),
                IconButton(
                  tooltip: 'MOVE LAYER DOWN',
                  onPressed: () => _replaceObject(
                    object.copyWith(zIndex: object.zIndex - 1),
                  ),
                  icon: const Icon(Icons.layers_clear),
                ),
              ],
            ),
            Row(
              children: [
                const Text('ANCHOR'),
                const SizedBox(width: 8),
                for (final item in const [
                  (label: 'TOP', value: Offset(.5, 0)),
                  (label: 'CENTER', value: Offset(.5, .5)),
                  (label: 'FEET', value: Offset(.5, 1)),
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: OutlinedButton(
                      onPressed: () =>
                          _replaceObject(object.copyWith(anchor: item.value)),
                      child: Text(item.label),
                    ),
                  ),
              ],
            ),
            Row(
              children: [
                OutlinedButton.icon(
                  key: const ValueKey('base-camp-editor-import-object'),
                  onPressed: _importObjectAsset,
                  icon: const Icon(Icons.upload_file),
                  label: const Text('IMPORT'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  key: const ValueKey('base-camp-editor-delete-object'),
                  onPressed: _deleteSelectedObjectAsset,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('DELETE'),
                ),
              ],
            ),
            const Text(
              'Drag the selected object on the map. JSON includes asset references only; imported image bytes remain device-local.',
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
                  (label: '1/1', value: 1.0),
                  (label: '2/3', value: 2 / 3),
                  (label: '1/2', value: .5),
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
    if (_section == _BaseCampEditorSection.smokeOrigin) {
      final origin = _working.foodSmokeOrigin;
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Drag the marker to the FOOD chimney tip. The point is stored in FOOD-local coordinates and follows object transforms.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'LOCAL: ${origin.dx.toStringAsFixed(3)}, ${origin.dy.toStringAsFixed(3)}',
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              key: const ValueKey('base-camp-editor-smoke-reset'),
              onPressed: () => _mutate(
                _working.copyWith(
                  foodSmokeOrigin:
                      BaseCampMapConfiguration.defaults().foodSmokeOrigin,
                ),
              ),
              icon: const Icon(Icons.restart_alt),
              label: const Text('RESET SMOKE ORIGIN'),
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

  void _replaceObject(BaseCampMapObject object, {bool recordUndo = true}) {
    final next = _working.copyWith(
      objects: <String, BaseCampMapObject>{
        ..._working.objects,
        object.id: object,
      },
    );
    if (recordUndo) {
      _mutate(next);
    } else {
      setState(() => _working = next);
    }
  }

  Future<void> _importObjectAsset() async {
    try {
      final imported = await pickBaseCampAssetFile();
      if (imported == null) return;
      final assetId =
          'base-camp-asset-${DateTime.now().microsecondsSinceEpoch}';
      await BaseCampAssetStore().save(
        BaseCampStoredAsset(
          id: assetId,
          mimeType: imported.mimeType,
          bytes: imported.bytes,
        ),
      );
      if (!mounted) return;
      final object = _working.objects[_objectId]!;
      _replaceObject(object.copyWith(assetId: assetId, visible: true));
    } on BaseCampAssetStorageException catch (error) {
      if (!mounted) return;
      final message = switch (error.code) {
        'invalid_asset' => 'Use a PNG, GIF, or JPEG image under 8 MB.',
        _ => 'Image storage failed. Check available browser storage.',
      };
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } on UnsupportedError {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Image import is available in the web app.'),
          ),
        );
      }
    }
  }

  Future<void> _deleteSelectedObjectAsset() async {
    final object = _working.objects[_objectId]!;
    final bundled = baseCampObjectAssets.containsKey(object.assetId);
    if (!bundled) {
      try {
        await BaseCampAssetStore().delete(object.assetId);
      } on BaseCampAssetStorageException {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Image storage could not be updated.'),
            ),
          );
        }
        return;
      }
    }
    if (!mounted) return;
    _replaceObject(object.copyWith(visible: false));
  }
}

enum _ExitChoice { save, discard, cancel }

class _BaseCampEditorCanvas extends StatefulWidget {
  const _BaseCampEditorCanvas({
    super.key,
    required this.configuration,
    required this.section,
    required this.selectedRouteId,
    required this.selectedFacilityId,
    required this.selectedObjectId,
    required this.selectedPoint,
    required this.onPointSelected,
    required this.onDragStarted,
    required this.onPointDragged,
    required this.onSmokeOriginDragStarted,
    required this.onSmokeOriginDragged,
    required this.onObjectDragStarted,
    required this.onObjectDragged,
  });
  final BaseCampMapConfiguration configuration;
  final _BaseCampEditorSection section;
  final String selectedRouteId, selectedFacilityId, selectedObjectId;
  final int selectedPoint;
  final ValueChanged<int> onPointSelected;
  final ValueChanged<int> onDragStarted;
  final ValueChanged<Offset> onPointDragged;
  final VoidCallback onSmokeOriginDragStarted;
  final ValueChanged<Offset> onSmokeOriginDragged;
  final VoidCallback onObjectDragStarted;
  final ValueChanged<Offset> onObjectDragged;

  @override
  State<_BaseCampEditorCanvas> createState() => _BaseCampEditorCanvasState();
}

class _BaseCampEditorCanvasState extends State<_BaseCampEditorCanvas> {
  final TransformationController _transform = TransformationController();
  final GlobalKey _sourceKey = GlobalKey();
  Size? _viewport;

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  /// Fits the whole 1280×719 image; it is intentionally independent from
  /// route data, so RESET VIEW can never alter durable source coordinates.
  void resetView() {
    final viewport = _viewport;
    if (viewport == null || viewport.isEmpty) return;
    final geometry = BaseCampMapGeometry.contain(viewport);
    _transform.value = Matrix4.identity()
      ..translateByDouble(geometry.imageRect.left, geometry.imageRect.top, 0, 1)
      ..scaleByDouble(geometry.scale, geometry.scale, 1, 1);
  }

  void _setInitialFit(Size viewport) {
    if (_viewport == viewport) return;
    _viewport = viewport;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) resetView();
    });
  }

  void _dragPointAtGlobalPosition(Offset globalPosition) {
    final renderBox =
        _sourceKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final sourcePoint = renderBox.globalToLocal(globalPosition);
    final modelPoint = widget.section == _BaseCampEditorSection.buildings
        ? Offset(
            sourcePoint.dx / baseCampMapSourceSize.width,
            sourcePoint.dy / baseCampMapSourceSize.height,
          )
        : sourcePoint;
    if (widget.section == _BaseCampEditorSection.smokeOrigin) {
      widget.onSmokeOriginDragged(sourcePoint);
    } else {
      widget.onPointDragged(modelPoint);
    }
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final viewport = constraints.biggest;
      _setInitialFit(viewport);
      return ClipRect(
        child: InteractiveViewer(
          key: const ValueKey('base-camp-editor-map'),
          transformationController: _transform,
          constrained: false,
          minScale: .2,
          maxScale: 3.2,
          boundaryMargin: const EdgeInsets.all(160),
          child: SizedBox(
            width: baseCampMapSourceSize.width,
            height: baseCampMapSourceSize.height,
            child: _BaseCampEditorSourceMap(
              key: _sourceKey,
              configuration: widget.configuration,
              section: widget.section,
              selectedRouteId: widget.selectedRouteId,
              selectedFacilityId: widget.selectedFacilityId,
              selectedObjectId: widget.selectedObjectId,
              selectedPoint: widget.selectedPoint,
              onPointSelected: widget.onPointSelected,
              onDragStarted: widget.onDragStarted,
              onSmokeOriginDragStarted: widget.onSmokeOriginDragStarted,
              onPointGlobalDragged: _dragPointAtGlobalPosition,
              onObjectDragStarted: widget.onObjectDragStarted,
              onObjectGlobalDragged: (globalPosition) {
                final renderBox =
                    _sourceKey.currentContext?.findRenderObject() as RenderBox?;
                if (renderBox != null) {
                  widget.onObjectDragged(
                    renderBox.globalToLocal(globalPosition),
                  );
                }
              },
            ),
          ),
        ),
      );
    },
  );
}

class _BaseCampEditorSourceMap extends StatelessWidget {
  const _BaseCampEditorSourceMap({
    super.key,
    required this.configuration,
    required this.section,
    required this.selectedRouteId,
    required this.selectedFacilityId,
    required this.selectedObjectId,
    required this.selectedPoint,
    required this.onPointSelected,
    required this.onDragStarted,
    required this.onSmokeOriginDragStarted,
    required this.onPointGlobalDragged,
    required this.onObjectDragStarted,
    required this.onObjectGlobalDragged,
  });
  final BaseCampMapConfiguration configuration;
  final _BaseCampEditorSection section;
  final String selectedRouteId, selectedFacilityId, selectedObjectId;
  final int selectedPoint;
  final ValueChanged<int> onPointSelected;
  final ValueChanged<int> onDragStarted;
  final VoidCallback onSmokeOriginDragStarted;
  final ValueChanged<Offset> onPointGlobalDragged;
  final VoidCallback onObjectDragStarted;
  final ValueChanged<Offset> onObjectGlobalDragged;

  @override
  Widget build(BuildContext context) {
    final points = section == _BaseCampEditorSection.buildings
        ? configuration.facilityOutlines[selectedFacilityId]!
        : section == _BaseCampEditorSection.routes
        ? configuration.routes[selectedRouteId]!
        : const <Offset>[];
    Offset sourcePoint(Offset point) =>
        section == _BaseCampEditorSection.buildings
        ? Offset(
            point.dx * baseCampMapSourceSize.width,
            point.dy * baseCampMapSourceSize.height,
          )
        : point;
    final food = configuration.objects['food'];
    final smokeSource = food == null
        ? Offset.zero
        : baseCampObjectLocalToSource(food, configuration.foodSmokeOrigin);
    return Stack(
      fit: StackFit.expand,
      children: [
        const Image(image: AssetImage(baseCampMapAsset), fit: BoxFit.fill),
        IgnorePointer(
          child: BaseCampObjectLayer(
            configuration: configuration,
            geometry: BaseCampMapGeometry.contain(baseCampMapSourceSize),
          ),
        ),
        IgnorePointer(
          child: BaseCampFoodSmokeLayer(
            configuration: configuration,
            geometry: BaseCampMapGeometry.contain(baseCampMapSourceSize),
            elapsed: const Duration(seconds: 2),
          ),
        ),
        IgnorePointer(
          child: BaseCampWalkerPreviewLayer(
            elapsed: const Duration(seconds: 2),
            reducedMotion: false,
            configuration: configuration,
            geometry: BaseCampMapGeometry.contain(baseCampMapSourceSize),
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
        if (section == _BaseCampEditorSection.routes ||
            section == _BaseCampEditorSection.buildings)
          for (var i = 0; i < points.length; i++)
            Positioned(
              left: sourcePoint(points[i]).dx - 24,
              top: sourcePoint(points[i]).dy - 24,
              width: 48,
              height: 48,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onPointSelected(i),
                onPanStart: (_) => onDragStarted(i),
                onPanUpdate: (details) =>
                    onPointGlobalDragged(details.globalPosition),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i == selectedPoint
                        ? const Color(0xFF68E8F2)
                        : const Color(0xCC101A1D),
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
            ),
        if (section == _BaseCampEditorSection.smokeOrigin && food != null)
          Positioned(
            left: smokeSource.dx - 24,
            top: smokeSource.dy - 24,
            width: 48,
            height: 48,
            child: GestureDetector(
              key: const ValueKey('base-camp-editor-smoke-origin'),
              behavior: HitTestBehavior.opaque,
              onPanStart: (_) => onSmokeOriginDragStarted(),
              onPanUpdate: (details) =>
                  onPointGlobalDragged(details.globalPosition),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xCC101A1D),
                  border: Border.all(color: const Color(0xFFD7D9D6), width: 2),
                ),
                child: const Icon(Icons.cloud_outlined, color: Colors.white),
              ),
            ),
          ),
        if (section == _BaseCampEditorSection.objects)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onPanStart: (_) => onObjectDragStarted(),
              onPanUpdate: (details) =>
                  onObjectGlobalDragged(details.globalPosition),
              child: const SizedBox.expand(),
            ),
          ),
      ],
    );
  }
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
    if (section == _BaseCampEditorSection.soldierSize ||
        section == _BaseCampEditorSection.objects ||
        section == _BaseCampEditorSection.smokeOrigin) {
      return;
    }
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
