import 'dart:convert';
import 'dart:math' as math;

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
  labels,
  waterFx,
  waterMask,
  shoreline,
  exclusionMask,
  staticSoldiers,
  soldierSize,
}

enum _BaseCampWaterLayer { shimmer, ripple, foam }

int _nearestPolygonSegment(
  List<Offset> points,
  Offset point, {
  required bool closed,
}) {
  final count = closed ? points.length : points.length - 1;
  var best = 0;
  var bestDistance = double.infinity;
  for (var index = 0; index < count; index++) {
    final a = points[index];
    final b = points[(index + 1) % points.length];
    final delta = b - a;
    final length2 = delta.dx * delta.dx + delta.dy * delta.dy;
    final t = length2 == 0
        ? 0.0
        : (((point - a).dx * delta.dx + (point - a).dy * delta.dy) / length2)
              .clamp(0.0, 1.0);
    final nearest = a + delta * t;
    final distance = (point - nearest).distanceSquared;
    if (distance < bestDistance) {
      best = index;
      bestDistance = distance;
    }
  }
  return best;
}

bool _selfIntersects(List<Offset> points) {
  bool intersects(Offset a, Offset b, Offset c, Offset d) {
    double cross(Offset p, Offset q, Offset r) =>
        (q.dx - p.dx) * (r.dy - p.dy) - (q.dy - p.dy) * (r.dx - p.dx);
    final abC = cross(a, b, c), abD = cross(a, b, d);
    final cdA = cross(c, d, a), cdB = cross(c, d, b);
    return (abC > 0) != (abD > 0) && (cdA > 0) != (cdB > 0);
  }

  for (var i = 0; i < points.length; i++) {
    final a = points[i], b = points[(i + 1) % points.length];
    for (var j = i + 1; j < points.length; j++) {
      if (j == i ||
          (j + 1) % points.length == i ||
          (i + 1) % points.length == j) {
        continue;
      }
      if (intersects(a, b, points[j], points[(j + 1) % points.length])) {
        return true;
      }
    }
  }
  return false;
}

/// Computes a temporary editor-only transform that centres a selected water
/// mask. It never changes source coordinates or durable map framing.
Matrix4 baseCampWaterFocusTransform({
  required BaseCampWaterFx effect,
  required Size viewport,
}) {
  final sourceBounds = Rect.fromPoints(
    effect.mask.reduce(
      (a, b) => Offset(math.min(a.dx, b.dx), math.min(a.dy, b.dy)),
    ),
    effect.mask.reduce(
      (a, b) => Offset(math.max(a.dx, b.dx), math.max(a.dy, b.dy)),
    ),
  );
  final artworkGeometry = BaseCampMapGeometry.contain(baseCampMapArtworkSize);
  final bounds = Rect.fromPoints(
    artworkGeometry.artworkToViewport(sourceBounds.topLeft),
    artworkGeometry.artworkToViewport(sourceBounds.bottomRight),
  );
  final scale = math
      .min(
        viewport.width * .78 / math.max(1, bounds.width),
        viewport.height * .70 / math.max(1, bounds.height),
      )
      .clamp(.2, 3.2)
      .toDouble();
  final translation =
      Offset(viewport.width / 2, viewport.height / 2) - bounds.center * scale;
  return Matrix4.identity()
    ..translateByDouble(translation.dx, translation.dy, 0, 1)
    ..scaleByDouble(scale, scale, 1, 1);
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
  String _waterFxId = 'rock-foam';
  int _exclusionMaskIndex = 0;
  _BaseCampWaterLayer _waterLayer = _BaseCampWaterLayer.shimmer;
  int _waterPointIndex = 0;
  bool _waterMaskSelected = false;
  bool _awaitingWaterPoint = false;
  bool _awaitingExclusionPoint = false;
  String? _staticSoldierId;
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
        smokeFx: source.smokeFx,
        labels: Map<String, BaseCampFacilityLabel>.of(source.labels),
        waterFx: Map<String, BaseCampWaterFx>.of(source.waterFx),
        staticSoldiers: List<BaseCampStaticSoldier>.of(source.staticSoldiers),
      );

  bool get _dirty =>
      _working.encode() != baseCampMapConfigurationController.value.encode();

  BaseCampStaticSoldier? get _selectedStaticSoldier {
    final id = _staticSoldierId;
    if (id == null) return null;
    for (final soldier in _working.staticSoldiers) {
      if (soldier.id == id) return soldier;
    }
    return null;
  }

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

  void _updateSmokeFx(String field, double value) {
    final fx = _working.smokeFx;
    final next = switch (field) {
      'DENSITY' => fx.copyWith(density: value),
      'OPACITY' => fx.copyWith(opacity: value),
      'PARTICLE SIZE' => fx.copyWith(particleSize: value),
      'SPREAD' => fx.copyWith(spread: value),
      'RISE HEIGHT' => fx.copyWith(riseHeight: value),
      'LIFETIME' => fx.copyWith(lifetime: value),
      'DRIFT' => fx.copyWith(drift: value),
      'SOFTNESS' => fx.copyWith(softness: value),
      'TURBULENCE' => fx.copyWith(turbulence: value),
      'CONTRAST' => fx.copyWith(contrast: value),
      _ => fx.copyWith(expansion: value),
    };
    _mutate(_working.copyWith(smokeFx: next));
  }

  void _replaceLabel(String id, BaseCampFacilityLabel label) => _mutate(
    _working.copyWith(
      labels: <String, BaseCampFacilityLabel>{..._working.labels, id: label},
    ),
  );

  void _updateLabelPosition(String id, Offset position, {required int part}) {
    final label = _working.labels[id]!;
    final safe = Offset(
      position.dx.clamp(0, baseCampMapSourceSize.width).toDouble(),
      position.dy.clamp(0, baseCampMapSourceSize.height).toDouble(),
    );
    setState(() {
      _working = _working.copyWith(
        labels: <String, BaseCampFacilityLabel>{
          ..._working.labels,
          id: switch (part) {
            1 => label.copyWith(connectorStart: safe),
            2 => label.copyWith(connectorEnd: safe),
            _ => label.copyWith(position: safe),
          },
        },
      );
    });
  }

  void _replaceWaterFx(String id, BaseCampWaterFx effect) => _mutate(
    _working.copyWith(
      waterFx: <String, BaseCampWaterFx>{..._working.waterFx, id: effect},
    ),
  );

  void _updateWaterPoint(
    String id,
    int index,
    Offset point, {
    required bool mask,
  }) {
    final effect = _working.waterFx[id]!;
    final values = List<Offset>.of(mask ? effect.mask : effect.shoreline);
    values[index] = Offset(
      point.dx.clamp(0, baseCampMapArtworkSize.width).toDouble(),
      point.dy.clamp(0, baseCampMapArtworkSize.height).toDouble(),
    );
    setState(() {
      _working = _working.copyWith(
        waterFx: <String, BaseCampWaterFx>{
          ..._working.waterFx,
          id: mask
              ? effect.copyWith(mask: values)
              : effect.copyWith(shoreline: values),
        },
      );
    });
  }

  void _insertWaterPointAt(Offset point, {required bool mask}) {
    final effect = _working.waterFx[_waterFxId]!;
    final points = List<Offset>.of(mask ? effect.mask : effect.shoreline);
    final safe = Offset(
      point.dx.clamp(0, baseCampMapArtworkSize.width).toDouble(),
      point.dy.clamp(0, baseCampMapArtworkSize.height).toDouble(),
    );
    final segment = _nearestPolygonSegment(points, safe, closed: mask);
    points.insert(segment + 1, safe);
    if (mask && _selfIntersects(points)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('SELF-INTERSECTING WATER MASK REJECTED')),
      );
      return;
    }
    _mutate(
      _working.copyWith(
        waterFx: <String, BaseCampWaterFx>{
          ..._working.waterFx,
          _waterFxId: mask
              ? effect.copyWith(mask: points)
              : effect.copyWith(shoreline: points),
        },
      ),
    );
    setState(() {
      _waterPointIndex = segment + 1;
      _waterMaskSelected = mask;
      _awaitingWaterPoint = false;
    });
  }

  void _deleteWaterPoint({required bool mask}) {
    final effect = _working.waterFx[_waterFxId]!;
    final points = List<Offset>.of(mask ? effect.mask : effect.shoreline);
    final minimum = mask ? 3 : 2;
    if (points.length <= minimum) return;
    points.removeAt(_waterPointIndex.clamp(0, points.length - 1));
    _mutate(
      _working.copyWith(
        waterFx: <String, BaseCampWaterFx>{
          ..._working.waterFx,
          _waterFxId: mask
              ? effect.copyWith(mask: points)
              : effect.copyWith(shoreline: points),
        },
      ),
    );
    setState(() => _waterPointIndex = 0);
  }

  void _addExclusionMask() {
    final effect = _working.waterFx[_waterFxId]!;
    final center =
        effect.mask.reduce((a, b) => a + b) / effect.mask.length.toDouble();
    final polygon = <Offset>[
      center + const Offset(-12, -10),
      center + const Offset(15, -8),
      center + const Offset(14, 14),
      center + const Offset(-10, 16),
    ];
    _mutate(
      _working.copyWith(
        waterFx: <String, BaseCampWaterFx>{
          ..._working.waterFx,
          _waterFxId: effect.copyWith(
            exclusionMasks: <List<Offset>>[...effect.exclusionMasks, polygon],
          ),
        },
      ),
    );
    setState(() {
      _exclusionMaskIndex = effect.exclusionMasks.length;
      _waterPointIndex = 0;
    });
  }

  void _deleteExclusionMask() {
    final effect = _working.waterFx[_waterFxId]!;
    if (effect.exclusionMasks.isEmpty) return;
    final masks = List<List<Offset>>.of(
      effect.exclusionMasks,
    )..removeAt(_exclusionMaskIndex.clamp(0, effect.exclusionMasks.length - 1));
    _mutate(
      _working.copyWith(
        waterFx: <String, BaseCampWaterFx>{
          ..._working.waterFx,
          _waterFxId: effect.copyWith(exclusionMasks: masks),
        },
      ),
    );
    setState(() => _exclusionMaskIndex = 0);
  }

  void _insertExclusionPointAt(Offset point) {
    final effect = _working.waterFx[_waterFxId]!;
    if (effect.exclusionMasks.isEmpty) return;
    final polygonIndex = _exclusionMaskIndex.clamp(
      0,
      effect.exclusionMasks.length - 1,
    );
    final masks = effect.exclusionMasks
        .map((item) => List<Offset>.of(item))
        .toList(growable: false);
    final polygon = masks[polygonIndex];
    final safe = Offset(
      point.dx.clamp(0, baseCampMapArtworkSize.width).toDouble(),
      point.dy.clamp(0, baseCampMapArtworkSize.height).toDouble(),
    );
    final segment = _nearestPolygonSegment(polygon, safe, closed: true);
    polygon.insert(segment + 1, safe);
    if (_selfIntersects(polygon)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('SELF-INTERSECTING EXCLUSION REJECTED')),
      );
      return;
    }
    _mutate(
      _working.copyWith(
        waterFx: <String, BaseCampWaterFx>{
          ..._working.waterFx,
          _waterFxId: effect.copyWith(exclusionMasks: masks),
        },
      ),
    );
    setState(() {
      _waterPointIndex = segment + 1;
      _awaitingExclusionPoint = false;
    });
  }

  void _deleteExclusionPoint() {
    final effect = _working.waterFx[_waterFxId]!;
    if (effect.exclusionMasks.isEmpty) return;
    final polygonIndex = _exclusionMaskIndex.clamp(
      0,
      effect.exclusionMasks.length - 1,
    );
    final masks = effect.exclusionMasks
        .map((item) => List<Offset>.of(item))
        .toList(growable: false);
    final polygon = masks[polygonIndex];
    if (polygon.length <= 3) return;
    polygon.removeAt(_waterPointIndex.clamp(0, polygon.length - 1));
    _mutate(
      _working.copyWith(
        waterFx: <String, BaseCampWaterFx>{
          ..._working.waterFx,
          _waterFxId: effect.copyWith(exclusionMasks: masks),
        },
      ),
    );
    setState(() => _waterPointIndex = 0);
  }

  void _replaceStaticSoldier(BaseCampStaticSoldier soldier) => _mutate(
    _working.copyWith(
      staticSoldiers: _working.staticSoldiers
          .map((item) => item.id == soldier.id ? soldier : item)
          .toList(growable: false),
    ),
  );

  void _updateStaticSoldierPosition(String id, Offset position) {
    final soldier = _working.staticSoldiers.firstWhere((item) => item.id == id);
    setState(() {
      _working = _working.copyWith(
        staticSoldiers: _working.staticSoldiers
            .map(
              (item) => item.id == id
                  ? soldier.copyWith(
                      position: Offset(
                        position.dx
                            .clamp(0, baseCampMapSourceSize.width)
                            .toDouble(),
                        position.dy
                            .clamp(0, baseCampMapSourceSize.height)
                            .toDouble(),
                      ),
                    )
                  : item,
            )
            .toList(growable: false),
      );
    });
  }

  void _addStaticSoldier() {
    final id = 'static-${DateTime.now().microsecondsSinceEpoch}';
    _mutate(
      _working.copyWith(
        staticSoldiers: <BaseCampStaticSoldier>[
          ..._working.staticSoldiers,
          BaseCampStaticSoldier(id: id, position: const Offset(640, 430)),
        ],
      ),
    );
    setState(() => _staticSoldierId = id);
  }

  void _deleteStaticSoldier() {
    final id = _staticSoldierId;
    if (id == null) return;
    _mutate(
      _working.copyWith(
        staticSoldiers: _working.staticSoldiers
            .where((item) => item.id != id)
            .toList(growable: false),
      ),
    );
    setState(() => _staticSoldierId = null);
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
              tooltip: 'Cancel unsaved changes',
              onPressed: () => setState(() {
                _working = _clone(baseCampMapConfigurationController.value);
                _undo.clear();
              }),
              icon: const Icon(Icons.cancel_outlined),
            ),
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
              tooltip: 'RESET VIEW',
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
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final item in const <(_BaseCampEditorSection, String)>[
                      (_BaseCampEditorSection.routes, 'ROUTE EDITOR'),
                      (_BaseCampEditorSection.buildings, 'BUILDING EDITOR'),
                      (_BaseCampEditorSection.objects, 'OBJECT EDITOR'),
                      (_BaseCampEditorSection.smokeOrigin, 'SMOKE ORIGIN'),
                      (_BaseCampEditorSection.labels, 'FACILITY LABEL'),
                      (_BaseCampEditorSection.waterFx, 'FX PARAMETERS'),
                      (_BaseCampEditorSection.waterMask, 'WATER MASK'),
                      (_BaseCampEditorSection.shoreline, 'SHORELINE'),
                      (_BaseCampEditorSection.exclusionMask, 'EXCLUSION MASK'),
                      (_BaseCampEditorSection.staticSoldiers, 'STATIC SOLDIER'),
                      (_BaseCampEditorSection.soldierSize, 'SOLDIER SIZE'),
                    ])
                      ChoiceChip(
                        label: Text(item.$2),
                        selected: _section == item.$1,
                        onSelected: (_) => setState(() {
                          _section = item.$1;
                          _pointIndex = 0;
                          if (item.$1 == _BaseCampEditorSection.waterFx ||
                              item.$1 == _BaseCampEditorSection.waterMask ||
                              item.$1 == _BaseCampEditorSection.shoreline ||
                              item.$1 == _BaseCampEditorSection.exclusionMask) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              _canvasKey.currentState?.focusWaterFx(_waterFxId);
                            });
                          }
                        }),
                      ),
                  ],
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
                  onLabelDragStarted: () =>
                      setState(() => _undo.add(_clone(_working))),
                  onLabelDragged: (position, part) =>
                      _updateLabelPosition(_facilityId, position, part: part),
                  selectedWaterFxId: _waterFxId,
                  selectedWaterPoint: _waterPointIndex,
                  selectedWaterMask: _waterMaskSelected,
                  selectedExclusionMask: _exclusionMaskIndex,
                  awaitingWaterPoint: _awaitingWaterPoint,
                  onWaterCanvasTap: (position, mask) =>
                      _insertWaterPointAt(position, mask: mask),
                  awaitingExclusionPoint: _awaitingExclusionPoint,
                  onExclusionCanvasTap: _insertExclusionPointAt,
                  onWaterPointSelected: (index, mask) => setState(() {
                    _waterPointIndex = index;
                    _waterMaskSelected = mask;
                  }),
                  onExclusionSelected: (polygon, point) => setState(() {
                    _exclusionMaskIndex = polygon;
                    _waterPointIndex = point;
                    _waterMaskSelected = false;
                  }),
                  onWaterDragStarted: () =>
                      setState(() => _undo.add(_clone(_working))),
                  onWaterPointDragged: (index, position, mask) =>
                      _updateWaterPoint(
                        _waterFxId,
                        index,
                        position,
                        mask: mask,
                      ),
                  onExclusionPointDragged: (polygon, index, position) {
                    final effect = _working.waterFx[_waterFxId]!;
                    if (polygon < 0 ||
                        polygon >= effect.exclusionMasks.length) {
                      return;
                    }
                    final masks = effect.exclusionMasks
                        .map((item) => List<Offset>.of(item))
                        .toList(growable: false);
                    masks[polygon][index] = Offset(
                      position.dx
                          .clamp(0, baseCampMapArtworkSize.width)
                          .toDouble(),
                      position.dy
                          .clamp(0, baseCampMapArtworkSize.height)
                          .toDouble(),
                    );
                    setState(
                      () => _working = _working.copyWith(
                        waterFx: <String, BaseCampWaterFx>{
                          ..._working.waterFx,
                          _waterFxId: effect.copyWith(exclusionMasks: masks),
                        },
                      ),
                    );
                  },
                  selectedStaticSoldierId: _staticSoldierId,
                  onStaticSoldierDragStarted: () =>
                      setState(() => _undo.add(_clone(_working))),
                  onStaticSoldierDragged: (id, position) {
                    _staticSoldierId = id;
                    _updateStaticSoldierPosition(id, position);
                  },
                ),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 170),
                child: SingleChildScrollView(child: _editorControls()),
              ),
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
    if (_section == _BaseCampEditorSection.labels) {
      final label = _working.labels[_facilityId]!;
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _facilityId,
              items: baseCampFacilities
                  .map(
                    (facility) => DropdownMenuItem(
                      value: facility.id,
                      child: Text(facility.label),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _facilityId = value!),
            ),
            _editorSlider(
              'SCALE',
              label.scale,
              0.4,
              2.5,
              (value) =>
                  _replaceLabel(_facilityId, label.copyWith(scale: value)),
            ),
            _editorSlider(
              'CONNECTOR ROUTING',
              label.elbow,
              0,
              1,
              (value) =>
                  _replaceLabel(_facilityId, label.copyWith(elbow: value)),
            ),
            SwitchListTile(
              title: const Text('VISIBLE'),
              value: label.visible,
              onChanged: (value) =>
                  _replaceLabel(_facilityId, label.copyWith(visible: value)),
            ),
            const Text(
              'Drag the cyan plate handle, beige connector start, and terminal dot on the map.',
            ),
            OutlinedButton.icon(
              onPressed: () => _replaceLabel(
                _facilityId,
                BaseCampFacilityLabel.defaultsFor(_facilityId),
              ),
              icon: const Icon(Icons.restart_alt),
              label: const Text('PRESET RESET'),
            ),
          ],
        ),
      );
    }
    if (_section == _BaseCampEditorSection.waterFx) {
      final effect = _working.waterFx[_waterFxId]!;
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _waterFxId,
              items: const [
                DropdownMenuItem(value: 'rock-foam', child: Text('ROCK FOAM')),
                DropdownMenuItem(
                  value: 'coast-ripple',
                  child: Text('COAST RIPPLE'),
                ),
              ],
              onChanged: (value) => setState(() {
                _waterFxId = value!;
                _waterPointIndex = 0;
                _waterMaskSelected = false;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _canvasKey.currentState?.focusWaterFx(_waterFxId);
                });
              }),
            ),
            const Text('FX PARAMETERS: 水面の光・うねり・泡を個別に調整します。'),
            Wrap(
              spacing: 6,
              children: [
                for (final layer in _BaseCampWaterLayer.values)
                  ChoiceChip(
                    label: Text(layer.name.toUpperCase()),
                    selected: _waterLayer == layer,
                    onSelected: (_) => setState(() => _waterLayer = layer),
                  ),
              ],
            ),
            SwitchListTile(
              title: Text('${_waterLayer.name.toUpperCase()} ON'),
              value: switch (_waterLayer) {
                _BaseCampWaterLayer.shimmer => effect.shimmerEnabled,
                _BaseCampWaterLayer.ripple => effect.rippleEnabled,
                _BaseCampWaterLayer.foam => effect.foamEnabled,
              },
              onChanged: (value) =>
                  _replaceWaterFx(_waterFxId, switch (_waterLayer) {
                    _BaseCampWaterLayer.shimmer => effect.copyWith(
                      shimmerEnabled: value,
                    ),
                    _BaseCampWaterLayer.ripple => effect.copyWith(
                      rippleEnabled: value,
                    ),
                    _BaseCampWaterLayer.foam => effect.copyWith(
                      foamEnabled: value,
                    ),
                  }),
            ),
            for (final entry in switch (_waterLayer) {
              _BaseCampWaterLayer.shimmer => <(String, double)>[
                ('DENSITY', effect.shimmerDensity),
                ('BRIGHTNESS', effect.shimmerBrightness),
                ('CHANGE SPEED', effect.shimmerSpeed),
              ],
              _BaseCampWaterLayer.ripple => <(String, double)>[
                ('STRENGTH', effect.intensity),
                ('FLOW SPEED', effect.speed),
                ('SPREAD', effect.flowDistortion),
              ],
              _BaseCampWaterLayer.foam => <(String, double)>[
                ('AMOUNT', effect.foamIntensity),
                ('SPREAD', effect.spread),
                ('LIFETIME', effect.foamLifetime),
              ],
            })
              _editorSlider(entry.$1, entry.$2, 0, 4, (value) {
                final next = switch (entry.$1) {
                  'DENSITY' => effect.copyWith(shimmerDensity: value),
                  'BRIGHTNESS' => effect.copyWith(shimmerBrightness: value),
                  'CHANGE SPEED' => effect.copyWith(shimmerSpeed: value),
                  'STRENGTH' => effect.copyWith(intensity: value),
                  'FLOW SPEED' => effect.copyWith(speed: value),
                  'AMOUNT' => effect.copyWith(foamIntensity: value),
                  'LIFETIME' => effect.copyWith(foamLifetime: value),
                  _ =>
                    _waterLayer == _BaseCampWaterLayer.ripple
                        ? effect.copyWith(flowDistortion: value)
                        : effect.copyWith(spread: value),
                };
                _replaceWaterFx(_waterFxId, next);
              }),
            SwitchListTile(
              title: const Text('VISIBLE'),
              value: effect.visible,
              onChanged: (value) =>
                  _replaceWaterFx(_waterFxId, effect.copyWith(visible: value)),
            ),
            const Text('上部のMAPは実際のBASE CAMP背景と同じLIVE PREVIEWです。'),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () =>
                      _canvasKey.currentState?.focusWaterFx(_waterFxId),
                  icon: const Icon(Icons.center_focus_strong),
                  label: const Text('FOCUS AREA'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _canvasKey.currentState?.exitWaterFocus(),
                  icon: const Icon(Icons.fullscreen_exit),
                  label: const Text('EXIT FOCUS'),
                ),
              ],
            ),
            OutlinedButton.icon(
              onPressed: () => _replaceWaterFx(
                _waterFxId,
                BaseCampWaterFx.defaults()[_waterFxId]!,
              ),
              icon: const Icon(Icons.restart_alt),
              label: const Text('PRESET RESET'),
            ),
          ],
        ),
      );
    }
    if (_section == _BaseCampEditorSection.waterMask ||
        _section == _BaseCampEditorSection.shoreline) {
      final isMask = _section == _BaseCampEditorSection.waterMask;
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('水域を選択してから、頂点をドラッグして形状を調整します。'),
            Text(
              isMask
                  ? 'WATER MASK: FXを描画してよい水面範囲です。'
                  : 'SHORELINE: FOAMが発生する水際の基準線です。',
            ),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => setState(() => _awaitingWaterPoint = true),
                  icon: const Icon(Icons.add),
                  label: const Text('ADD POINT ON MAP'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _deleteWaterPoint(mask: isMask),
                  icon: const Icon(Icons.remove),
                  label: const Text('DELETE POINT'),
                ),
                OutlinedButton.icon(
                  onPressed: () =>
                      _canvasKey.currentState?.focusWaterFx(_waterFxId),
                  icon: const Icon(Icons.center_focus_strong),
                  label: const Text('FOCUS AREA'),
                ),
              ],
            ),
          ],
        ),
      );
    }
    if (_section == _BaseCampEditorSection.exclusionMask) {
      final effect = _working.waterFx[_waterFxId]!;
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('EXCLUSION MASK: 見張り台・岩・陸地を水面FXから除外します。'),
            Text(
              '選択中: ${effect.exclusionMasks.isEmpty ? 'なし' : _exclusionMaskIndex + 1}',
            ),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _addExclusionMask,
                  icon: const Icon(Icons.add),
                  label: const Text('ADD AREA'),
                ),
                OutlinedButton.icon(
                  onPressed: _deleteExclusionMask,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('DELETE AREA'),
                ),
                OutlinedButton.icon(
                  onPressed: effect.exclusionMasks.isEmpty
                      ? null
                      : () => setState(() => _awaitingExclusionPoint = true),
                  icon: const Icon(Icons.add_location_alt_outlined),
                  label: const Text('ADD POINT ON MAP'),
                ),
                OutlinedButton.icon(
                  onPressed: _deleteExclusionPoint,
                  icon: const Icon(Icons.remove_circle_outline),
                  label: const Text('DELETE POINT'),
                ),
                OutlinedButton.icon(
                  onPressed: () =>
                      _canvasKey.currentState?.focusWaterFx(_waterFxId),
                  icon: const Icon(Icons.center_focus_strong),
                  label: const Text('FOCUS AREA'),
                ),
              ],
            ),
          ],
        ),
      );
    }
    if (_section == _BaseCampEditorSection.staticSoldiers) {
      final soldier = _selectedStaticSoldier;
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                FilledButton.icon(
                  onPressed: _addStaticSoldier,
                  icon: const Icon(Icons.add),
                  label: const Text('ADD'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: soldier == null ? null : _deleteStaticSoldier,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('DELETE'),
                ),
              ],
            ),
            if (soldier != null) ...[
              DropdownButtonFormField<String>(
                initialValue: soldier.direction,
                items: const ['front', 'back', 'right', 'left']
                    .map(
                      (value) => DropdownMenuItem(
                        value: value,
                        child: Text(value.toUpperCase()),
                      ),
                    )
                    .toList(),
                onChanged: (value) =>
                    _replaceStaticSoldier(soldier.copyWith(direction: value)),
              ),
              _editorSlider(
                'SCALE',
                soldier.scale,
                .3,
                2,
                (value) =>
                    _replaceStaticSoldier(soldier.copyWith(scale: value)),
              ),
              _editorSlider(
                'BREATHING INTENSITY',
                soldier.breathingIntensity,
                0,
                2,
                (value) => _replaceStaticSoldier(
                  soldier.copyWith(breathingIntensity: value),
                ),
              ),
              _editorSlider(
                'BREATHING PERIOD',
                soldier.breathingPeriod,
                1,
                8,
                (value) => _replaceStaticSoldier(
                  soldier.copyWith(breathingPeriod: value),
                ),
              ),
              SwitchListTile(
                title: const Text('BREATHING'),
                value: soldier.breathing,
                onChanged: (value) =>
                    _replaceStaticSoldier(soldier.copyWith(breathing: value)),
              ),
              SwitchListTile(
                title: const Text('VISIBLE'),
                value: soldier.visible,
                onChanged: (value) =>
                    _replaceStaticSoldier(soldier.copyWith(visible: value)),
              ),
            ],
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
            for (final entry in <(String, double)>[
              ('DENSITY', _working.smokeFx.density),
              ('OPACITY', _working.smokeFx.opacity),
              ('PARTICLE SIZE', _working.smokeFx.particleSize),
              ('SPREAD', _working.smokeFx.spread),
              ('RISE HEIGHT', _working.smokeFx.riseHeight),
              ('LIFETIME', _working.smokeFx.lifetime),
              ('DRIFT', _working.smokeFx.drift),
              ('SOFTNESS', _working.smokeFx.softness),
              ('TURBULENCE', _working.smokeFx.turbulence),
              ('CONTRAST', _working.smokeFx.contrast),
              ('EXPANSION', _working.smokeFx.expansion),
            ])
              Row(
                children: [
                  SizedBox(
                    width: 104,
                    child: Text(entry.$1, style: const TextStyle(fontSize: 10)),
                  ),
                  Expanded(
                    child: Slider(
                      value: entry.$2,
                      min: 0,
                      max: 4,
                      onChanged: (value) => _updateSmokeFx(entry.$1, value),
                    ),
                  ),
                  Text(entry.$2.toStringAsFixed(1)),
                ],
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
            OutlinedButton.icon(
              key: const ValueKey('base-camp-editor-smoke-preset-reset'),
              onPressed: () =>
                  _mutate(_working.copyWith(smokeFx: const BaseCampSmokeFx())),
              icon: const Icon(Icons.water_drop_outlined),
              label: const Text('ORIGINAL SMOKE'),
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

  Widget _editorSlider(
    String title,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged,
  ) => Row(
    children: [
      SizedBox(
        width: 118,
        child: Text(title, style: const TextStyle(fontSize: 10)),
      ),
      Expanded(
        child: Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          onChanged: onChanged,
        ),
      ),
      SizedBox(width: 32, child: Text(value.toStringAsFixed(1))),
    ],
  );

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
    required this.onLabelDragStarted,
    required this.onLabelDragged,
    required this.selectedWaterFxId,
    required this.selectedWaterPoint,
    required this.selectedWaterMask,
    required this.selectedExclusionMask,
    required this.awaitingWaterPoint,
    required this.onWaterCanvasTap,
    required this.awaitingExclusionPoint,
    required this.onExclusionCanvasTap,
    required this.onWaterPointSelected,
    required this.onExclusionSelected,
    required this.onWaterDragStarted,
    required this.onWaterPointDragged,
    required this.onExclusionPointDragged,
    required this.selectedStaticSoldierId,
    required this.onStaticSoldierDragStarted,
    required this.onStaticSoldierDragged,
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
  final VoidCallback onLabelDragStarted;
  final void Function(Offset position, int part) onLabelDragged;
  final String selectedWaterFxId;
  final int selectedWaterPoint;
  final bool selectedWaterMask;
  final int selectedExclusionMask;
  final bool awaitingWaterPoint;
  final void Function(Offset position, bool mask) onWaterCanvasTap;
  final bool awaitingExclusionPoint;
  final ValueChanged<Offset> onExclusionCanvasTap;
  final void Function(int index, bool mask) onWaterPointSelected;
  final void Function(int polygon, int point) onExclusionSelected;
  final VoidCallback onWaterDragStarted;
  final void Function(int index, Offset position, bool mask)
  onWaterPointDragged;
  final void Function(int polygon, int index, Offset position)
  onExclusionPointDragged;
  final String? selectedStaticSoldierId;
  final VoidCallback onStaticSoldierDragStarted;
  final void Function(String id, Offset position) onStaticSoldierDragged;

  @override
  State<_BaseCampEditorCanvas> createState() => _BaseCampEditorCanvasState();
}

class _BaseCampEditorCanvasState extends State<_BaseCampEditorCanvas>
    with TickerProviderStateMixin {
  final TransformationController _transform = TransformationController();
  final GlobalKey _sourceKey = GlobalKey();
  Size? _viewport;
  Matrix4? _transformBeforeWaterFocus;
  String? _focusedWaterFxId;
  late final AnimationController _previewTimeline;

  @override
  void initState() {
    super.initState();
    _previewTimeline = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    )..repeat();
  }

  @override
  void dispose() {
    _previewTimeline.dispose();
    _transform.dispose();
    super.dispose();
  }

  /// Fits the whole square artwork; it is intentionally independent from
  /// route data, so RESET VIEW can never alter durable source coordinates.
  void resetView() {
    final focusedId = _focusedWaterFxId;
    if (focusedId != null) {
      _applyWaterFocus(focusedId);
      return;
    }
    final viewport = _viewport;
    if (viewport == null || viewport.isEmpty) return;
    final geometry = BaseCampMapGeometry.contain(viewport);
    _transform.value = Matrix4.identity()
      ..translateByDouble(geometry.imageRect.left, geometry.imageRect.top, 0, 1)
      ..scaleByDouble(geometry.artworkScale, geometry.artworkScale, 1, 1);
  }

  void focusWaterFx(String id) {
    _transformBeforeWaterFocus ??= Matrix4.copy(_transform.value);
    _focusedWaterFxId = id;
    _applyWaterFocus(id);
  }

  void exitWaterFocus() {
    final previous = _transformBeforeWaterFocus;
    _focusedWaterFxId = null;
    _transformBeforeWaterFocus = null;
    if (previous != null) _transform.value = previous;
  }

  void _applyWaterFocus(String id) {
    final viewport = _viewport;
    final effect = widget.configuration.waterFx[id];
    if (viewport == null || viewport.isEmpty || effect == null) return;
    _transform.value = baseCampWaterFocusTransform(
      effect: effect,
      viewport: viewport,
    );
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
    final sourcePoint = BaseCampMapGeometry.contain(
      baseCampMapArtworkSize,
    ).artworkToSource(renderBox.globalToLocal(globalPosition));
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
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _previewTimeline,
    builder: (context, _) => LayoutBuilder(
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
              width: baseCampMapArtworkSize.width,
              height: baseCampMapArtworkSize.height,
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
                      _sourceKey.currentContext?.findRenderObject()
                          as RenderBox?;
                  if (renderBox != null) {
                    widget.onObjectDragged(
                      BaseCampMapGeometry.contain(
                        baseCampMapArtworkSize,
                      ).artworkToSource(
                        renderBox.globalToLocal(globalPosition),
                      ),
                    );
                  }
                },
                onLabelDragStarted: widget.onLabelDragStarted,
                onLabelGlobalDragged: (globalPosition, part) {
                  final renderBox =
                      _sourceKey.currentContext?.findRenderObject()
                          as RenderBox?;
                  if (renderBox != null) {
                    widget.onLabelDragged(
                      BaseCampMapGeometry.contain(
                        baseCampMapArtworkSize,
                      ).artworkToSource(
                        renderBox.globalToLocal(globalPosition),
                      ),
                      part,
                    );
                  }
                },
                selectedWaterFxId: widget.selectedWaterFxId,
                elapsed: Duration(
                  milliseconds: (_previewTimeline.value * 30000).round(),
                ),
                selectedWaterPoint: widget.selectedWaterPoint,
                selectedWaterMask: widget.selectedWaterMask,
                selectedExclusionMask: widget.selectedExclusionMask,
                awaitingWaterPoint: widget.awaitingWaterPoint,
                onWaterCanvasTap: widget.onWaterCanvasTap,
                awaitingExclusionPoint: widget.awaitingExclusionPoint,
                onExclusionCanvasTap: widget.onExclusionCanvasTap,
                onWaterPointSelected: widget.onWaterPointSelected,
                onExclusionSelected: widget.onExclusionSelected,
                onWaterDragStarted: widget.onWaterDragStarted,
                onWaterGlobalDragged: (index, globalPosition, mask) {
                  final renderBox =
                      _sourceKey.currentContext?.findRenderObject()
                          as RenderBox?;
                  if (renderBox != null) {
                    widget.onWaterPointDragged(
                      index,
                      BaseCampMapGeometry.contain(
                        baseCampMapArtworkSize,
                      ).viewportToArtwork(
                        renderBox.globalToLocal(globalPosition),
                      ),
                      mask,
                    );
                  }
                },
                onExclusionGlobalDragged: (polygon, index, globalPosition) {
                  final renderBox =
                      _sourceKey.currentContext?.findRenderObject()
                          as RenderBox?;
                  if (renderBox != null) {
                    widget.onExclusionPointDragged(
                      polygon,
                      index,
                      BaseCampMapGeometry.contain(
                        baseCampMapArtworkSize,
                      ).viewportToArtwork(
                        renderBox.globalToLocal(globalPosition),
                      ),
                    );
                  }
                },
                selectedStaticSoldierId: widget.selectedStaticSoldierId,
                onStaticSoldierDragStarted: widget.onStaticSoldierDragStarted,
                onStaticSoldierGlobalDragged: (id, globalPosition) {
                  final renderBox =
                      _sourceKey.currentContext?.findRenderObject()
                          as RenderBox?;
                  if (renderBox != null) {
                    widget.onStaticSoldierDragged(
                      id,
                      BaseCampMapGeometry.contain(
                        baseCampMapArtworkSize,
                      ).artworkToSource(
                        renderBox.globalToLocal(globalPosition),
                      ),
                    );
                  }
                },
              ),
            ),
          ),
        );
      },
    ),
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
    required this.onLabelDragStarted,
    required this.onLabelGlobalDragged,
    required this.selectedWaterFxId,
    required this.elapsed,
    required this.selectedWaterPoint,
    required this.selectedWaterMask,
    required this.selectedExclusionMask,
    required this.awaitingWaterPoint,
    required this.onWaterCanvasTap,
    required this.awaitingExclusionPoint,
    required this.onExclusionCanvasTap,
    required this.onWaterPointSelected,
    required this.onExclusionSelected,
    required this.onWaterDragStarted,
    required this.onWaterGlobalDragged,
    required this.onExclusionGlobalDragged,
    required this.selectedStaticSoldierId,
    required this.onStaticSoldierDragStarted,
    required this.onStaticSoldierGlobalDragged,
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
  final VoidCallback onLabelDragStarted;
  final void Function(Offset position, int part) onLabelGlobalDragged;
  final String selectedWaterFxId;
  final Duration elapsed;
  final int selectedWaterPoint;
  final bool selectedWaterMask;
  final int selectedExclusionMask;
  final bool awaitingWaterPoint;
  final void Function(Offset position, bool mask) onWaterCanvasTap;
  final bool awaitingExclusionPoint;
  final ValueChanged<Offset> onExclusionCanvasTap;
  final void Function(int index, bool mask) onWaterPointSelected;
  final void Function(int polygon, int point) onExclusionSelected;
  final VoidCallback onWaterDragStarted;
  final void Function(int index, Offset position, bool mask)
  onWaterGlobalDragged;
  final void Function(int polygon, int index, Offset position)
  onExclusionGlobalDragged;
  final String? selectedStaticSoldierId;
  final VoidCallback onStaticSoldierDragStarted;
  final void Function(String id, Offset position) onStaticSoldierGlobalDragged;

  @override
  Widget build(BuildContext context) {
    final geometry = BaseCampMapGeometry.contain(baseCampMapArtworkSize);
    final points = section == _BaseCampEditorSection.buildings
        ? configuration.facilityOutlines[selectedFacilityId]!
        : section == _BaseCampEditorSection.routes
        ? configuration.routes[selectedRouteId]!
        : const <Offset>[];
    Offset sourcePoint(Offset point) => geometry.sourceToViewport(
      section == _BaseCampEditorSection.buildings
          ? Offset(
              point.dx * baseCampMapSourceSize.width,
              point.dy * baseCampMapSourceSize.height,
            )
          : point,
    );
    final food = configuration.objects['food'];
    final smokeSource = food == null
        ? Offset.zero
        : geometry.sourceToViewport(
            baseCampObjectLocalToSource(food, configuration.foodSmokeOrigin),
          );
    final label = configuration.labels[selectedFacilityId];
    final water = configuration.waterFx[selectedWaterFxId];
    return Stack(
      fit: StackFit.expand,
      children: [
        const Image(image: AssetImage(baseCampMapAsset), fit: BoxFit.contain),
        IgnorePointer(
          child: BaseCampWaterFxLayer(
            configuration: configuration,
            geometry: geometry,
            elapsed: elapsed,
          ),
        ),
        IgnorePointer(
          child: BaseCampObjectLayer(
            configuration: configuration,
            geometry: geometry,
          ),
        ),
        IgnorePointer(
          child: BaseCampFoodSmokeLayer(
            configuration: configuration,
            geometry: geometry,
            elapsed: elapsed,
          ),
        ),
        IgnorePointer(
          child: BaseCampWalkerPreviewLayer(
            elapsed: elapsed,
            reducedMotion: false,
            configuration: configuration,
            geometry: geometry,
          ),
        ),
        // Keep the editor preview's paint order identical to the normal map:
        // labels must remain readable above facilities, smoke and patrols.
        IgnorePointer(
          child: BaseCampFacilityLabelLayer(
            configuration: configuration,
            geometry: geometry,
          ),
        ),
        if ((section == _BaseCampEditorSection.waterMask ||
                section == _BaseCampEditorSection.shoreline ||
                section == _BaseCampEditorSection.exclusionMask) &&
            water != null)
          IgnorePointer(
            child: CustomPaint(
              painter: _BaseCampWaterEditOverlayPainter(
                water,
                section,
                geometry,
              ),
            ),
          ),
        CustomPaint(
          painter: _BaseCampEditorGuidePainter(
            configuration: configuration,
            section: section,
            geometry: geometry,
            selectedId: section == _BaseCampEditorSection.buildings
                ? selectedFacilityId
                : selectedRouteId,
          ),
        ),
        if (awaitingWaterPoint &&
            (section == _BaseCampEditorSection.waterMask ||
                section == _BaseCampEditorSection.shoreline))
          Positioned.fill(
            child: GestureDetector(
              key: const ValueKey('base-camp-editor-water-add-point-canvas'),
              behavior: HitTestBehavior.translucent,
              onTapUp: (details) => onWaterCanvasTap(
                details.localPosition,
                section == _BaseCampEditorSection.waterMask,
              ),
              child: const SizedBox.expand(),
            ),
          ),
        if (awaitingExclusionPoint &&
            section == _BaseCampEditorSection.exclusionMask)
          Positioned.fill(
            child: GestureDetector(
              key: const ValueKey(
                'base-camp-editor-exclusion-add-point-canvas',
              ),
              behavior: HitTestBehavior.translucent,
              onTapUp: (details) => onExclusionCanvasTap(details.localPosition),
              child: const SizedBox.expand(),
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
        if (section == _BaseCampEditorSection.labels && label != null) ...[
          _EditorDragHandle(
            point: geometry.sourceToViewport(label.position),
            icon: Icons.label_outline,
            color: const Color(0xFF68E8F2),
            onStart: onLabelDragStarted,
            onUpdate: (details) =>
                onLabelGlobalDragged(details.globalPosition, 0),
          ),
          _EditorDragHandle(
            point: geometry.sourceToViewport(label.connectorStart),
            icon: Icons.call_made,
            color: const Color(0xFFE5DFCF),
            onStart: onLabelDragStarted,
            onUpdate: (details) =>
                onLabelGlobalDragged(details.globalPosition, 1),
          ),
          _EditorDragHandle(
            point: geometry.sourceToViewport(label.connectorEnd),
            icon: Icons.radio_button_checked,
            color: const Color(0xFFE5DFCF),
            onStart: onLabelDragStarted,
            onUpdate: (details) =>
                onLabelGlobalDragged(details.globalPosition, 2),
          ),
        ],
        if (section == _BaseCampEditorSection.shoreline && water != null) ...[
          for (var i = 0; i < water.shoreline.length; i++)
            _EditorDragHandle(
              point: geometry.artworkToViewport(water.shoreline[i]),
              icon: Icons.waves,
              color: selectedWaterPoint == i && !selectedWaterMask
                  ? const Color(0xFF68E8F2)
                  : const Color(0xFFEAF1EA),
              selected: selectedWaterPoint == i && !selectedWaterMask,
              onTap: () => onWaterPointSelected(i, false),
              onStart: () {
                onWaterPointSelected(i, false);
                onWaterDragStarted();
              },
              onUpdate: (details) =>
                  onWaterGlobalDragged(i, details.globalPosition, false),
            ),
        ],
        if (section == _BaseCampEditorSection.waterMask && water != null) ...[
          for (var i = 0; i < water.mask.length; i++)
            _EditorDragHandle(
              point: geometry.artworkToViewport(water.mask[i]),
              icon: Icons.crop_square,
              color: selectedWaterPoint == i && selectedWaterMask
                  ? const Color(0xFFF0E8D4)
                  : const Color(0xFF68E8F2),
              selected: selectedWaterPoint == i && selectedWaterMask,
              onTap: () => onWaterPointSelected(i, true),
              onStart: () {
                onWaterPointSelected(i, true);
                onWaterDragStarted();
              },
              onUpdate: (details) =>
                  onWaterGlobalDragged(i, details.globalPosition, true),
            ),
        ],
        if (section == _BaseCampEditorSection.exclusionMask && water != null)
          for (
            var polygon = 0;
            polygon < water.exclusionMasks.length;
            polygon++
          )
            for (
              var point = 0;
              point < water.exclusionMasks[polygon].length;
              point++
            )
              _EditorDragHandle(
                point: geometry.artworkToViewport(
                  water.exclusionMasks[polygon][point],
                ),
                icon: Icons.block,
                color: polygon == selectedExclusionMask
                    ? const Color(0xFFFF9C7A)
                    : const Color(0xFF85564A),
                selected:
                    polygon == selectedExclusionMask &&
                    point == selectedWaterPoint,
                onTap: () => onExclusionSelected(polygon, point),
                onStart: () {
                  onExclusionSelected(polygon, point);
                  onWaterDragStarted();
                },
                onUpdate: (details) => onExclusionGlobalDragged(
                  polygon,
                  point,
                  details.globalPosition,
                ),
              ),
        if (section == _BaseCampEditorSection.staticSoldiers)
          for (final soldier in configuration.staticSoldiers)
            _EditorDragHandle(
              point: geometry.sourceToViewport(soldier.position),
              icon: Icons.person_pin_circle,
              color: soldier.id == selectedStaticSoldierId
                  ? const Color(0xFF68E8F2)
                  : const Color(0xFFD7D9D6),
              onStart: onStaticSoldierDragStarted,
              onUpdate: (details) => onStaticSoldierGlobalDragged(
                soldier.id,
                details.globalPosition,
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

class _BaseCampWaterEditOverlayPainter extends CustomPainter {
  const _BaseCampWaterEditOverlayPainter(
    this.effect,
    this.section,
    this.geometry,
  );

  final BaseCampWaterFx effect;
  final _BaseCampEditorSection section;
  final BaseCampMapGeometry geometry;

  @override
  void paint(Canvas canvas, Size size) {
    Path pathFor(List<Offset> points, {bool close = true}) =>
        Path()
          ..addPolygon(points.map(geometry.artworkToViewport).toList(), close);
    final water = pathFor(effect.mask);
    canvas.drawPath(
      water,
      Paint()
        ..color = const Color(0x3347C9E8)
        ..style = PaintingStyle.fill,
    );
    if (section == _BaseCampEditorSection.waterMask) {
      canvas.drawPath(
        water,
        Paint()
          ..color = const Color(0xFF68E8F2)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
    if (section == _BaseCampEditorSection.shoreline) {
      canvas.drawPath(
        pathFor(effect.shoreline, close: false),
        Paint()
          ..color = const Color(0xFFEAF1EA)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
    }
    if (section == _BaseCampEditorSection.exclusionMask) {
      for (final exclusion in effect.exclusionMasks) {
        final path = pathFor(exclusion);
        canvas.drawPath(
          path,
          Paint()
            ..color = const Color(0x55FF9C7A)
            ..style = PaintingStyle.fill,
        );
        canvas.drawPath(
          path,
          Paint()
            ..color = const Color(0xFFFF9C7A)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_BaseCampWaterEditOverlayPainter oldDelegate) =>
      oldDelegate.effect != effect ||
      oldDelegate.section != section ||
      oldDelegate.geometry != geometry;
}

class _EditorDragHandle extends StatelessWidget {
  const _EditorDragHandle({
    required this.point,
    required this.icon,
    required this.color,
    this.selected = false,
    this.onTap,
    required this.onStart,
    required this.onUpdate,
  });
  final Offset point;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback? onTap;
  final VoidCallback onStart;
  final GestureDragUpdateCallback onUpdate;

  @override
  Widget build(BuildContext context) => Positioned(
    left: point.dx - 24,
    top: point.dy - 24,
    width: 48,
    height: 48,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onPanStart: (_) => onStart(),
      onPanUpdate: onUpdate,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xCC101A1D),
          shape: BoxShape.circle,
          border: Border.all(color: color, width: selected ? 4 : 2),
          boxShadow: selected
              ? <BoxShadow>[
                  BoxShadow(color: color.withValues(alpha: .7), blurRadius: 10),
                ]
              : null,
        ),
        child: Icon(icon, color: color, size: 20),
      ),
    ),
  );
}

class _BaseCampEditorGuidePainter extends CustomPainter {
  const _BaseCampEditorGuidePainter({
    required this.configuration,
    required this.section,
    required this.geometry,
    required this.selectedId,
  });
  final BaseCampMapConfiguration configuration;
  final _BaseCampEditorSection section;
  final BaseCampMapGeometry geometry;
  final String selectedId;
  @override
  void paint(Canvas canvas, Size size) {
    if (section == _BaseCampEditorSection.soldierSize ||
        section == _BaseCampEditorSection.objects ||
        section == _BaseCampEditorSection.smokeOrigin ||
        section == _BaseCampEditorSection.labels ||
        section == _BaseCampEditorSection.waterFx ||
        section == _BaseCampEditorSection.waterMask ||
        section == _BaseCampEditorSection.shoreline ||
        section == _BaseCampEditorSection.exclusionMask ||
        section == _BaseCampEditorSection.staticSoldiers) {
      return;
    }
    final normalized = section == _BaseCampEditorSection.buildings;
    final points = normalized
        ? configuration.facilityOutlines[selectedId]!
        : configuration.routes[selectedId]!;
    final path = Path();
    for (var index = 0; index < points.length; index++) {
      final source = normalized
          ? Offset(
              points[index].dx * baseCampMapSourceSize.width,
              points[index].dy * baseCampMapSourceSize.height,
            )
          : points[index];
      final point = geometry.sourceToViewport(source);
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
      old.geometry != geometry ||
      old.selectedId != selectedId;
}
