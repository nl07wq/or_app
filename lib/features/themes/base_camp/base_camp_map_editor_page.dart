import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'base_camp_map_configuration.dart';
import 'base_camp_asset_import.dart';
import 'base_camp_asset_store.dart';
import 'base_camp_map_export.dart';
import 'base_camp_helicopter_configuration.dart';
import 'widgets/base_camp_map.dart';
import 'widgets/base_camp_helicopter.dart';

enum _BaseCampEditorSection {
  routes,
  buildings,
  objects,
  smokeOrigin,
  labels,
  waterMask,
  shoreline,
  exclusionMask,
  staticSoldiers,
  soldierSize,
  helicopter,
}

enum _HelicopterPart { body, mainRotor, tailRotor }

enum _HelicopterInteraction { partEdit, mapNav }

enum _HelicopterPreview { stationary, flight }

const double _sectionTabsHeight = 52;
const double _workspaceHandleHeight = 24;
const double _preferredMinimumMapHeight = 120;
const double _preferredMinimumControlsHeight = 180;
const double _defaultMapWorkspaceFraction = .35;

class _BaseCampEditorWorkspaceMetrics {
  const _BaseCampEditorWorkspaceMetrics({
    required this.mapHeight,
    required this.handleHeight,
    required this.panelHeight,
    required this.minimumMapHeight,
    required this.maximumMapHeight,
  });

  factory _BaseCampEditorWorkspaceMetrics.fromHeight(
    double availableHeight,
    double requestedMapFraction,
  ) {
    final safeHeight = math.max(0.0, availableHeight);
    final handleHeight = math.min(_workspaceHandleHeight, safeHeight);
    final panelHeight = math.max(0.0, safeHeight - handleHeight);
    if (panelHeight == 0) {
      return _BaseCampEditorWorkspaceMetrics(
        mapHeight: 0,
        handleHeight: handleHeight,
        panelHeight: 0,
        minimumMapHeight: 0,
        maximumMapHeight: 0,
      );
    }

    final preferredTotal =
        _preferredMinimumMapHeight + _preferredMinimumControlsHeight;
    final reduction = math.min(1.0, panelHeight / preferredTotal);
    final minimumMapHeight = _preferredMinimumMapHeight * reduction;
    final minimumControlsHeight = _preferredMinimumControlsHeight * reduction;
    final maximumMapHeight = math.max(
      minimumMapHeight,
      panelHeight - minimumControlsHeight,
    );
    final requestedMapHeight = panelHeight * requestedMapFraction;
    return _BaseCampEditorWorkspaceMetrics(
      mapHeight: requestedMapHeight
          .clamp(minimumMapHeight, maximumMapHeight)
          .toDouble(),
      handleHeight: handleHeight,
      panelHeight: panelHeight,
      minimumMapHeight: minimumMapHeight,
      maximumMapHeight: maximumMapHeight,
    );
  }

  final double mapHeight;
  final double handleHeight;
  final double panelHeight;
  final double minimumMapHeight;
  final double maximumMapHeight;
}

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

@immutable
class BaseCampWaterGeometryImport {
  const BaseCampWaterGeometryImport._(this.areas);

  static const expectedExclusionCounts = <int>[3, 0, 2, 2];
  final List<BaseCampWaterArea> areas;

  int get exclusionCount =>
      areas.fold<int>(0, (count, area) => count + area.exclusionMasks.length);

  factory BaseCampWaterGeometryImport.parse(String source) {
    final Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException {
      throw const FormatException('JSON syntax is invalid.');
    }
    if (decoded is! Map) {
      throw const FormatException('The import root must be a JSON object.');
    }
    if (decoded['schemaVersion'] != BaseCampMapConfiguration.schemaVersion) {
      throw FormatException(
        'Unsupported schemaVersion. Expected '
        '${BaseCampMapConfiguration.schemaVersion}.',
      );
    }
    if (decoded['mapId'] != BaseCampMapConfiguration.mapId) {
      throw const FormatException('The JSON is not a BASE CAMP MAP export.');
    }
    final waterFx = decoded['waterFx'];
    final rawWater = waterFx is Map ? waterFx['water'] : null;
    final rawAreas = rawWater is Map ? rawWater['areas'] : null;
    if (rawAreas is! List || rawAreas.length != 4) {
      throw const FormatException(
        'The approved import must contain exactly four WATER areas.',
      );
    }
    final areas = <BaseCampWaterArea>[];
    for (var index = 0; index < rawAreas.length; index++) {
      final area = BaseCampWaterArea.tryParse(rawAreas[index]);
      if (area == null ||
          !_validImportPolygon(area.mask) ||
          area.shoreline.length < 2 ||
          area.exclusionMasks.any((polygon) => !_validImportPolygon(polygon))) {
        throw FormatException(
          'WATER area ${index + 1} contains invalid or missing coordinates.',
        );
      }
      final expected = expectedExclusionCounts[index];
      if (area.exclusionMasks.length != expected) {
        throw FormatException(
          'WATER area ${index + 1} must contain $expected EXCLUSION masks.',
        );
      }
      areas.add(area);
    }

    final compatibilityArea = BaseCampWaterArea.tryParse(rawWater);
    if (compatibilityArea == null ||
        !_samePoints(compatibilityArea.mask, areas.first.mask) ||
        !_samePoints(compatibilityArea.shoreline, areas.first.shoreline) ||
        !_samePolygons(
          compatibilityArea.exclusionMasks,
          areas.first.exclusionMasks,
        )) {
      throw const FormatException(
        'Area 1 and the compatibility WATER fields are not synchronized.',
      );
    }
    return BaseCampWaterGeometryImport._(
      List<BaseCampWaterArea>.unmodifiable(areas),
    );
  }

  BaseCampWaterFx applyTo(BaseCampWaterFx current) {
    final primary = areas.first;
    return current.copyWith(
      areas: List<BaseCampWaterArea>.of(areas),
      mask: List<Offset>.of(primary.mask),
      shoreline: List<Offset>.of(primary.shoreline),
      exclusionMasks: primary.exclusionMasks
          .map((polygon) => List<Offset>.of(polygon))
          .toList(growable: false),
    );
  }
}

bool _validImportPolygon(List<Offset> points) {
  if (points.length < 3 || _selfIntersects(points)) return false;
  var twiceArea = 0.0;
  for (var index = 0; index < points.length; index++) {
    final current = points[index];
    final next = points[(index + 1) % points.length];
    if (current == next) return false;
    twiceArea += current.dx * next.dy - next.dx * current.dy;
  }
  return twiceArea.abs() > .001;
}

bool _samePoints(List<Offset> left, List<Offset> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}

bool _samePolygons(List<List<Offset>> left, List<List<Offset>> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (!_samePoints(left[index], right[index])) return false;
  }
  return true;
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
  const BaseCampMapEditorPage({
    super.key,
    this.configurationController,
    this.waterDraftStore,
    this.waterJsonPicker,
  });

  final BaseCampMapConfigurationController? configurationController;
  final BaseCampWaterDraftStore? waterDraftStore;
  final Future<BaseCampImportedFile?> Function()? waterJsonPicker;

  @override
  State<BaseCampMapEditorPage> createState() => _BaseCampMapEditorPageState();
}

class _BaseCampMapEditorPageState extends State<BaseCampMapEditorPage> {
  late final BaseCampMapConfigurationController _configurationController;
  late final BaseCampWaterDraftStore _waterDraftStore;
  late BaseCampMapConfiguration _working;
  final List<BaseCampMapConfiguration> _undo = <BaseCampMapConfiguration>[];
  final GlobalKey<_BaseCampEditorCanvasState> _canvasKey =
      GlobalKey<_BaseCampEditorCanvasState>();
  final ScrollController _sectionTabsController = ScrollController();
  final ScrollController _controlsScrollController = ScrollController();
  final GlobalKey _sectionTabsViewportKey = GlobalKey();
  final Map<_BaseCampEditorSection, GlobalKey> _sectionTabKeys =
      <_BaseCampEditorSection, GlobalKey>{
        for (final section in _BaseCampEditorSection.values)
          section: GlobalKey(),
      };
  _BaseCampEditorSection _section = _BaseCampEditorSection.routes;
  double _mapWorkspaceFraction = _defaultMapWorkspaceFraction;
  String _routeId = 'route-a';
  String _facilityId = 'status';
  String _objectId = 'status';
  static const _waterFxId = 'water';
  int _exclusionMaskIndex = 0;
  int _waterPointIndex = 0;
  bool _waterMaskSelected = false;
  int _waterAreaIndex = 0;
  int _activeWaterDragAreaIndex = -1;
  bool _awaitingNewWaterArea = false;
  bool _awaitingWaterPoint = false;
  bool _awaitingExclusionPoint = false;
  String? _staticSoldierId;
  int _pointIndex = 0;
  bool _loading = true;
  Timer? _waterDraftDebounce;
  BaseCampMapConfiguration? _pendingWaterDraft;
  Future<void>? _waterDraftDrain;
  String? _waterDraftError;
  _HelicopterPart _helicopterPart = _HelicopterPart.body;
  _HelicopterInteraction _helicopterInteraction =
      _HelicopterInteraction.partEdit;
  _HelicopterPreview _helicopterPreview = _HelicopterPreview.stationary;
  bool _helicopterRotorsOn = false;
  bool _helicopterMainVisible = true;
  bool _helicopterTailVisible = true;
  int _helicopterMainFrame = 0;
  int _helicopterTailFrame = 0;
  Offset _helicopterTestPosition = const Offset(350, 120);
  BaseCampHelicopterDirection _helicopterDirection =
      BaseCampHelicopterDirection.leftToRight;
  int? _helicopterFlightRunId;
  int _nextHelicopterFlightRunId = 0;
  BaseCampMapConfiguration? _helicopterGestureStart;
  BaseCampMapConfiguration? _helicopterSliderStart;
  Offset _helicopterGesturePosition = Offset.zero;

  @override
  void initState() {
    super.initState();
    _configurationController =
        widget.configurationController ?? baseCampMapConfigurationController;
    _waterDraftStore = widget.waterDraftStore ?? BaseCampWaterDraftStore();
    _load();
  }

  @override
  void dispose() {
    baseCampHelicopterEditorActive.value = false;
    _waterDraftDebounce?.cancel();
    _sectionTabsController.dispose();
    _controlsScrollController.dispose();
    if (_pendingWaterDraft != null) {
      unawaited(_drainWaterDraftWrites().catchError((_) {}));
    }
    super.dispose();
  }

  Future<void> _load() async {
    await _configurationController.load();
    final draftResult = await _waterDraftStore.load();
    if (!mounted) return;
    setState(() {
      _working = _clone(_configurationController.value);
      _loading = false;
    });
    if (draftResult.state != BaseCampWaterDraftState.missing && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_resolveWaterDraft(draftResult));
      });
    }
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
        compatibilityWaterFxV7: Map<String, BaseCampWaterFx>.of(
          source.compatibilityWaterFxV7,
        ),
        staticSoldiers: List<BaseCampStaticSoldier>.of(source.staticSoldiers),
        helicopterAssembly: source.helicopterAssembly,
      );

  void _selectSection(_BaseCampEditorSection section) {
    final helicopter = section == _BaseCampEditorSection.helicopter;
    baseCampHelicopterEditorActive.value = helicopter;
    if (!helicopter) _stopHelicopterFlight();
    setState(() {
      _section = section;
      _pointIndex = 0;
      _awaitingNewWaterArea = false;
      _awaitingWaterPoint = false;
      _awaitingExclusionPoint = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_sectionTabsController.hasClients) return;
      final tabContext = _sectionTabKeys[section]?.currentContext;
      final tabBox = tabContext?.findRenderObject() as RenderBox?;
      final viewportBox =
          _sectionTabsViewportKey.currentContext?.findRenderObject()
              as RenderBox?;
      if (tabBox == null || viewportBox == null) return;
      final viewportCenterX = viewportBox
          .localToGlobal(viewportBox.size.center(Offset.zero))
          .dx;
      final tabCenterX = tabBox
          .localToGlobal(tabBox.size.center(Offset.zero))
          .dx;
      final target =
          (_sectionTabsController.offset + tabCenterX - viewportCenterX)
              .clamp(
                _sectionTabsController.position.minScrollExtent,
                _sectionTabsController.position.maxScrollExtent,
              )
              .toDouble();
      _sectionTabsController.jumpTo(target);
    });
  }

  void _resizeWorkspace(
    DragUpdateDetails details,
    _BaseCampEditorWorkspaceMetrics metrics,
  ) {
    if (metrics.panelHeight <= 0) return;
    final nextMapHeight = (metrics.mapHeight + details.delta.dy)
        .clamp(metrics.minimumMapHeight, metrics.maximumMapHeight)
        .toDouble();
    setState(() {
      _mapWorkspaceFraction = nextMapHeight / metrics.panelHeight;
    });
  }

  void _beginHelicopterGesture() {
    _helicopterGestureStart = _clone(_working);
    _helicopterGesturePosition = _helicopterTestPosition;
    setState(() => _undo.add(_clone(_working)));
  }

  void _updateHelicopterGesture(
    Offset mapDelta,
    Offset bodyDelta,
    double gestureScale,
  ) {
    final start = _helicopterGestureStart;
    if (start == null) return;
    final assembly = start.helicopterAssembly;
    BaseCampHelicopterAssembly next = assembly;
    switch (_helicopterPart) {
      case _HelicopterPart.body:
        _helicopterTestPosition = _helicopterGesturePosition + mapDelta;
        next = assembly.copyWith(
          globalScale: (assembly.globalScale * gestureScale)
              .clamp(
                BaseCampHelicopterAssembly.minimumScale,
                BaseCampHelicopterAssembly.maximumScale,
              )
              .toDouble(),
        );
        break;
      case _HelicopterPart.mainRotor:
        next = assembly.copyWith(
          mainHub: _safeHelicopterHub(assembly.mainHub + bodyDelta),
          mainScale: (assembly.mainScale * gestureScale)
              .clamp(
                BaseCampHelicopterAssembly.minimumScale,
                BaseCampHelicopterAssembly.maximumScale,
              )
              .toDouble(),
        );
        break;
      case _HelicopterPart.tailRotor:
        next = assembly.copyWith(
          tailHub: _safeHelicopterHub(assembly.tailHub + bodyDelta),
          tailScale: (assembly.tailScale * gestureScale)
              .clamp(
                BaseCampHelicopterAssembly.minimumScale,
                BaseCampHelicopterAssembly.maximumScale,
              )
              .toDouble(),
        );
        break;
    }
    setState(() => _working = _working.copyWith(helicopterAssembly: next));
  }

  static Offset _safeHelicopterHub(Offset value) => Offset(
    value.dx.clamp(0.0, BaseCampHelicopterAssembly.sourceSize.width).toDouble(),
    value.dy
        .clamp(0.0, BaseCampHelicopterAssembly.sourceSize.height)
        .toDouble(),
  );

  void _setHelicopterValue({double? x, double? y, double? scale}) {
    final assembly = _working.helicopterAssembly;
    if (_helicopterPart == _HelicopterPart.body) {
      if (x != null || y != null) {
        setState(
          () => _helicopterTestPosition = Offset(
            x ?? _helicopterTestPosition.dx,
            y ?? _helicopterTestPosition.dy,
          ),
        );
      }
      if (scale != null) {
        _mutate(
          _working.copyWith(
            helicopterAssembly: assembly.copyWith(globalScale: scale),
          ),
        );
      }
      return;
    }
    final hub = _helicopterPart == _HelicopterPart.mainRotor
        ? assembly.mainHub
        : assembly.tailHub;
    final nextHub = _safeHelicopterHub(Offset(x ?? hub.dx, y ?? hub.dy));
    final next = _helicopterPart == _HelicopterPart.mainRotor
        ? assembly.copyWith(mainHub: nextHub, mainScale: scale)
        : assembly.copyWith(tailHub: nextHub, tailScale: scale);
    _mutate(_working.copyWith(helicopterAssembly: next));
  }

  void _runHelicopterFlight() {
    setState(() {
      _helicopterPreview = _HelicopterPreview.flight;
      _helicopterFlightRunId = ++_nextHelicopterFlightRunId;
    });
  }

  void _stopHelicopterFlight() {
    if (mounted && _helicopterFlightRunId != null) {
      setState(() => _helicopterFlightRunId = null);
    } else {
      _helicopterFlightRunId = null;
    }
  }

  void _beginHelicopterSlider() {
    _helicopterSliderStart ??= _clone(_working);
  }

  void _updateHelicopterAssembly(BaseCampHelicopterAssembly assembly) {
    setState(() => _working = _working.copyWith(helicopterAssembly: assembly));
  }

  void _endHelicopterSlider() {
    final start = _helicopterSliderStart;
    _helicopterSliderStart = null;
    if (start == null || start.encode() == _working.encode()) return;
    setState(() => _undo.add(start));
  }

  Future<void> _copyHelicopterJson() async {
    final source = const JsonEncoder.withIndent('  ').convert(<String, Object?>{
      'helicopterAssembly': _working.helicopterAssembly.toJson(),
    });
    try {
      await Clipboard.setData(ClipboardData(text: source));
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('HELICOPTER JSON COPIED')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('HELICOPTER JSON COPY FAILED')),
      );
    }
  }

  bool get _dirty =>
      _working.encode() != _configurationController.value.encode();

  String get _workingJson =>
      const JsonEncoder.withIndent('  ').convert(_working.toJson());

  bool get _waterDirty =>
      jsonEncode(_working.waterFx.map((id, fx) => MapEntry(id, fx.toJson()))) !=
          jsonEncode(
            _configurationController.value.waterFx.map(
              (id, fx) => MapEntry(id, fx.toJson()),
            ),
          ) ||
      jsonEncode(
            _working.compatibilityWaterFxV7.map(
              (id, fx) => MapEntry(id, fx.toJson()),
            ),
          ) !=
          jsonEncode(
            _configurationController.value.compatibilityWaterFxV7.map(
              (id, fx) => MapEntry(id, fx.toJson()),
            ),
          );

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

  void _scheduleWaterDraftSave() {
    if (!_waterDirty) return;
    _pendingWaterDraft = _clone(_working);
    if (_waterDraftDebounce?.isActive == true) return;
    _waterDraftDebounce = Timer(const Duration(milliseconds: 180), () {
      _waterDraftDebounce = null;
      unawaited(_drainWaterDraftWrites());
    });
  }

  Future<void> _drainWaterDraftWrites() async {
    final active = _waterDraftDrain;
    if (active != null) return active;
    final operation = _runWaterDraftDrain();
    _waterDraftDrain = operation;
    try {
      await operation;
    } finally {
      if (identical(_waterDraftDrain, operation)) _waterDraftDrain = null;
    }
  }

  Future<void> _runWaterDraftDrain() async {
    while (_pendingWaterDraft != null) {
      final pending = _pendingWaterDraft!;
      _pendingWaterDraft = null;
      try {
        await _waterDraftStore.save(pending);
        if (mounted && _waterDraftError != null) {
          setState(() => _waterDraftError = null);
        } else {
          _waterDraftError = null;
        }
      } catch (_) {
        if (mounted) {
          setState(() => _waterDraftError = 'WATER DRAFT AUTO-SAVE FAILED');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('WATER DRAFT AUTO-SAVE FAILED')),
          );
        } else {
          _waterDraftError = 'WATER DRAFT AUTO-SAVE FAILED';
        }
      }
    }
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

  void _replaceWaterFx(String id, BaseCampWaterFx effect) {
    _mutate(
      _working.copyWith(
        waterFx: <String, BaseCampWaterFx>{..._working.waterFx, id: effect},
      ),
    );
    _scheduleWaterDraftSave();
  }

  Future<void> _importWaterJson() async {
    try {
      final file =
          await (widget.waterJsonPicker?.call() ?? pickBaseCampWaterJsonFile());
      if (file == null || !mounted) return;
      if (file.bytes.lengthInBytes > 2 * 1024 * 1024) {
        throw const FormatException('The WATER JSON exceeds the 2 MB limit.');
      }
      final imported = BaseCampWaterGeometryImport.parse(
        utf8.decode(file.bytes, allowMalformed: false),
      );
      final current = _working.waterFx[_waterFxId];
      if (current == null) {
        throw const FormatException(
          'The current WATER configuration is missing.',
        );
      }
      final oldAreas = current.effectiveAreas.length;
      final oldExclusions = current.effectiveAreas.fold<int>(
        0,
        (count, area) => count + area.exclusionMasks.length,
      );
      final approved = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('IMPORT WATER JSON?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('WATER AREAS  $oldAreas → ${imported.areas.length}'),
              const SizedBox(height: 8),
              Text(
                'EXCLUSION MASKS  $oldExclusions → '
                '${imported.exclusionCount}',
              ),
              const SizedBox(height: 12),
              const Text(
                'Only WATER MASK, SHORELINE, and EXCLUSION geometry will be '
                'replaced in the editor working copy. Press SAVE to persist.',
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('CANCEL'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('REPLACE WATER'),
            ),
          ],
        ),
      );
      if (approved != true || !mounted) return;
      _replaceWaterFx(_waterFxId, imported.applyTo(current));
      setState(() {
        _waterAreaIndex = 0;
        _exclusionMaskIndex = 0;
        _waterPointIndex = 0;
        _activeWaterDragAreaIndex = -1;
        _awaitingNewWaterArea = false;
        _awaitingWaterPoint = false;
        _awaitingExclusionPoint = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('WATER IMPORT READY — PRESS SAVE TO PERSIST'),
        ),
      );
    } on FormatException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('WATER IMPORT REJECTED — ${error.message}')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('WATER IMPORT FAILED — DATA UNCHANGED')),
      );
    }
  }

  List<BaseCampWaterArea> _areas(BaseCampWaterFx effect) =>
      List<BaseCampWaterArea>.of(effect.effectiveAreas);

  BaseCampWaterFx _withAreas(
    BaseCampWaterFx effect,
    List<BaseCampWaterArea> areas,
  ) => effect.copyWith(
    areas: areas,
    // Keep v6-compatible primary fields in sync with area zero for old JSON
    // consumers; the V7 `areas` collection remains authoritative.
    mask: areas.first.mask,
    shoreline: areas.first.shoreline,
    exclusionMasks: areas.first.exclusionMasks,
  );

  int _safeAreaIndex(BaseCampWaterFx effect) =>
      _waterAreaIndex.clamp(0, _areas(effect).length - 1);

  void _addWaterAreaAt(Offset center) {
    final effect = _working.waterFx[_waterFxId]!;
    final areas = _areas(effect);
    final safe = Offset(
      center.dx.clamp(0, baseCampMapArtworkSize.width).toDouble(),
      center.dy.clamp(0, baseCampMapArtworkSize.height).toDouble(),
    );
    Offset point(double x, double y) => Offset(
      (safe.dx + x).clamp(0, baseCampMapArtworkSize.width).toDouble(),
      (safe.dy + y).clamp(0, baseCampMapArtworkSize.height).toDouble(),
    );
    areas.add(
      BaseCampWaterArea(
        mask: <Offset>[
          point(-60, -60),
          point(60, -60),
          point(60, 60),
          point(-60, 60),
        ],
        shoreline: <Offset>[point(-60, 0), point(60, 0)],
      ),
    );
    _replaceWaterFx(_waterFxId, _withAreas(effect, areas));
    setState(() {
      _waterAreaIndex = areas.length - 1;
      _activeWaterDragAreaIndex = -1;
      _awaitingNewWaterArea = false;
    });
  }

  void _deleteWaterArea() {
    final effect = _working.waterFx[_waterFxId]!;
    final areas = _areas(effect);
    if (areas.length <= 1) return;
    areas.removeAt(_safeAreaIndex(effect));
    _replaceWaterFx(_waterFxId, _withAreas(effect, areas));
    setState(() {
      _waterAreaIndex = 0;
      _activeWaterDragAreaIndex = -1;
    });
  }

  void _updateWaterPoint(
    String id,
    int index,
    Offset point, {
    required bool mask,
  }) {
    final effect = _working.waterFx[id];
    if (effect == null) return;
    final areas = _areas(effect);
    if (areas.isEmpty) return;
    final areaIndex = _safeAreaIndex(effect);
    final area = areas[areaIndex];
    final values = List<Offset>.of(mask ? area.mask : area.shoreline);
    // A final WebKit pointer event may arrive after AREA selection changed.
    // Ignore that stale event instead of indexing the newly selected polygon.
    if (index < 0 || index >= values.length) return;
    values[index] = Offset(
      point.dx.clamp(0, baseCampMapArtworkSize.width).toDouble(),
      point.dy.clamp(0, baseCampMapArtworkSize.height).toDouble(),
    );
    setState(() {
      _working = _working.copyWith(
        waterFx: <String, BaseCampWaterFx>{
          ..._working.waterFx,
          id: _withAreas(
            effect,
            areas
              ..[areaIndex] = mask
                  ? BaseCampWaterArea(
                      mask: values,
                      shoreline: area.shoreline,
                      exclusionMasks: area.exclusionMasks,
                    )
                  : BaseCampWaterArea(
                      mask: area.mask,
                      shoreline: values,
                      exclusionMasks: area.exclusionMasks,
                    ),
          ),
        },
      );
    });
    _scheduleWaterDraftSave();
  }

  void _insertWaterPointAt(Offset point, {required bool mask}) {
    final effect = _working.waterFx[_waterFxId]!;
    final areas = _areas(effect);
    final areaIndex = _safeAreaIndex(effect);
    final area = areas[areaIndex];
    final points = List<Offset>.of(mask ? area.mask : area.shoreline);
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
          _waterFxId: _withAreas(
            effect,
            areas
              ..[areaIndex] = mask
                  ? BaseCampWaterArea(
                      mask: points,
                      shoreline: area.shoreline,
                      exclusionMasks: area.exclusionMasks,
                    )
                  : BaseCampWaterArea(
                      mask: area.mask,
                      shoreline: points,
                      exclusionMasks: area.exclusionMasks,
                    ),
          ),
        },
      ),
    );
    setState(() {
      _waterPointIndex = segment + 1;
      _waterMaskSelected = mask;
      _awaitingWaterPoint = false;
    });
    _scheduleWaterDraftSave();
  }

  void _deleteWaterPoint({required bool mask}) {
    final effect = _working.waterFx[_waterFxId]!;
    final areas = _areas(effect);
    final areaIndex = _safeAreaIndex(effect);
    final area = areas[areaIndex];
    final points = List<Offset>.of(mask ? area.mask : area.shoreline);
    final minimum = mask ? 3 : 2;
    if (points.length <= minimum) return;
    points.removeAt(_waterPointIndex.clamp(0, points.length - 1));
    _mutate(
      _working.copyWith(
        waterFx: <String, BaseCampWaterFx>{
          ..._working.waterFx,
          _waterFxId: _withAreas(
            effect,
            areas
              ..[areaIndex] = mask
                  ? BaseCampWaterArea(
                      mask: points,
                      shoreline: area.shoreline,
                      exclusionMasks: area.exclusionMasks,
                    )
                  : BaseCampWaterArea(
                      mask: area.mask,
                      shoreline: points,
                      exclusionMasks: area.exclusionMasks,
                    ),
          ),
        },
      ),
    );
    setState(() => _waterPointIndex = 0);
    _scheduleWaterDraftSave();
  }

  void _addExclusionMask() {
    final effect = _working.waterFx[_waterFxId]!;
    final areas = _areas(effect);
    final areaIndex = _safeAreaIndex(effect);
    final area = areas[areaIndex];
    final center =
        area.mask.reduce((a, b) => a + b) / area.mask.length.toDouble();
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
          _waterFxId: _withAreas(
            effect,
            areas
              ..[areaIndex] = BaseCampWaterArea(
                mask: area.mask,
                shoreline: area.shoreline,
                exclusionMasks: <List<Offset>>[...area.exclusionMasks, polygon],
              ),
          ),
        },
      ),
    );
    setState(() {
      _exclusionMaskIndex = area.exclusionMasks.length;
      _waterPointIndex = 0;
    });
    _scheduleWaterDraftSave();
  }

  void _deleteExclusionMask() {
    final effect = _working.waterFx[_waterFxId]!;
    final areas = _areas(effect);
    final areaIndex = _safeAreaIndex(effect);
    final area = areas[areaIndex];
    if (area.exclusionMasks.isEmpty) return;
    final masks = List<List<Offset>>.of(area.exclusionMasks)
      ..removeAt(_exclusionMaskIndex.clamp(0, area.exclusionMasks.length - 1));
    _mutate(
      _working.copyWith(
        waterFx: <String, BaseCampWaterFx>{
          ..._working.waterFx,
          _waterFxId: _withAreas(
            effect,
            areas
              ..[areaIndex] = BaseCampWaterArea(
                mask: area.mask,
                shoreline: area.shoreline,
                exclusionMasks: masks,
              ),
          ),
        },
      ),
    );
    setState(() => _exclusionMaskIndex = 0);
    _scheduleWaterDraftSave();
  }

  void _insertExclusionPointAt(Offset point) {
    final effect = _working.waterFx[_waterFxId]!;
    final areas = _areas(effect);
    final areaIndex = _safeAreaIndex(effect);
    final area = areas[areaIndex];
    if (area.exclusionMasks.isEmpty) return;
    final polygonIndex = _exclusionMaskIndex.clamp(
      0,
      area.exclusionMasks.length - 1,
    );
    final masks = area.exclusionMasks
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
          _waterFxId: _withAreas(
            effect,
            areas
              ..[areaIndex] = BaseCampWaterArea(
                mask: area.mask,
                shoreline: area.shoreline,
                exclusionMasks: masks,
              ),
          ),
        },
      ),
    );
    setState(() {
      _waterPointIndex = segment + 1;
      _awaitingExclusionPoint = false;
    });
    _scheduleWaterDraftSave();
  }

  void _deleteExclusionPoint() {
    final effect = _working.waterFx[_waterFxId]!;
    final areas = _areas(effect);
    final areaIndex = _safeAreaIndex(effect);
    final area = areas[areaIndex];
    if (area.exclusionMasks.isEmpty) return;
    final polygonIndex = _exclusionMaskIndex.clamp(
      0,
      area.exclusionMasks.length - 1,
    );
    final masks = area.exclusionMasks
        .map((item) => List<Offset>.of(item))
        .toList(growable: false);
    final polygon = masks[polygonIndex];
    if (polygon.length <= 3) return;
    polygon.removeAt(_waterPointIndex.clamp(0, polygon.length - 1));
    _mutate(
      _working.copyWith(
        waterFx: <String, BaseCampWaterFx>{
          ..._working.waterFx,
          _waterFxId: _withAreas(
            effect,
            areas
              ..[areaIndex] = BaseCampWaterArea(
                mask: area.mask,
                shoreline: area.shoreline,
                exclusionMasks: masks,
              ),
          ),
        },
      ),
    );
    setState(() => _waterPointIndex = 0);
    _scheduleWaterDraftSave();
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

  Future<bool> _save() async {
    _waterDraftDebounce?.cancel();
    _waterDraftDebounce = null;
    if (_waterDirty) {
      _pendingWaterDraft = _clone(_working);
      await _drainWaterDraftWrites();
    }
    try {
      await _configurationController.save(_working);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('SAVE FAILED — EDITS AND WATER DRAFT RETAINED'),
          ),
        );
      }
      return false;
    }
    try {
      await _waterDraftStore.discard();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('MAP SAVED — OLD WATER DRAFT COULD NOT BE CLEARED'),
          ),
        );
      }
    }
    if (mounted) {
      setState(() {
        _undo.clear();
        _waterDraftError = null;
      });
    }
    return true;
  }

  void _undoLast() {
    if (_undo.isEmpty) return;
    setState(() => _working = _undo.removeLast());
    _scheduleWaterDraftSave();
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
    await _configurationController.resetToDefaults();
    try {
      await _waterDraftStore.discard();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('MAP RESET — OLD WATER DRAFT COULD NOT BE CLEARED'),
          ),
        );
      }
    }
    if (mounted) {
      setState(() {
        _working = _clone(_configurationController.value);
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
      return _save();
    }
    if (choice == _ExitChoice.discard) {
      try {
        await _waterDraftStore.discard();
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('WATER DRAFT DISCARD FAILED')),
          );
        }
        return false;
      }
    }
    return choice == _ExitChoice.discard;
  }

  Future<void> _cancelUnsavedChanges() async {
    if (!_dirty) return;
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('DISCARD UNSAVED EDITS?'),
        content: const Text(
          'This also discards the recoverable BASE CAMP WATER draft.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('KEEP EDITING'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('DISCARD'),
          ),
        ],
      ),
    );
    if (discard != true) return;
    try {
      await _waterDraftStore.discard();
      if (mounted) {
        setState(() {
          _working = _clone(_configurationController.value);
          _undo.clear();
          _waterDraftError = null;
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('WATER DRAFT DISCARD FAILED')),
        );
      }
    }
  }

  Future<void> _resolveWaterDraft(BaseCampWaterDraftLoadResult result) async {
    if (result.state == BaseCampWaterDraftState.unavailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('WATER DRAFT STORAGE UNAVAILABLE')),
      );
      return;
    }
    if (result.state == BaseCampWaterDraftState.corrupt) {
      final discard = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('WATER DRAFT NEEDS RECOVERY'),
          content: const Text(
            'The draft is damaged or belongs to another schema. Keep it for recovery or discard it.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('KEEP'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('DISCARD'),
            ),
          ],
        ),
      );
      if (discard == true) {
        try {
          await _waterDraftStore.discard();
        } catch (_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('WATER DRAFT DISCARD FAILED')),
            );
          }
        }
      }
      return;
    }
    final draft = result.draft;
    if (draft == null) return;
    final restore = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('RECOVER WATER EDITS?'),
        content: const Text(
          'An unsaved BASE CAMP WATER draft was found. RESTORE keeps it isolated from Dashboard until SAVE.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('DISCARD'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('RESTORE'),
          ),
        ],
      ),
    );
    if (restore == true) {
      if (mounted) {
        setState(() {
          _working = _clone(draft.applyTo(_configurationController.value));
          _undo.clear();
        });
      }
    } else {
      try {
        await _waterDraftStore.discard();
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('WATER DRAFT DISCARD FAILED')),
          );
        }
      }
    }
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
              onPressed: _cancelUnsavedChanges,
              icon: const Icon(Icons.cancel_outlined),
            ),
            IconButton(
              key: const ValueKey('base-camp-editor-undo'),
              onPressed: _undo.isEmpty ? null : _undoLast,
              icon: const Icon(Icons.undo),
            ),
            IconButton(
              key: const ValueKey('base-camp-editor-copy-json'),
              onPressed: () =>
                  Clipboard.setData(ClipboardData(text: _workingJson)),
              icon: const Icon(Icons.content_copy),
            ),
            IconButton(
              key: const ValueKey('base-camp-editor-export-json'),
              onPressed: () => exportBaseCampMapJson(_workingJson),
              icon: const Icon(Icons.download),
            ),
            SizedBox(
              width: 32,
              child: IconButton(
                key: const ValueKey('base-camp-editor-import-water-json'),
                tooltip: 'IMPORT WATER JSON',
                onPressed: () => unawaited(_importWaterJson()),
                constraints: const BoxConstraints.tightFor(
                  width: 32,
                  height: 48,
                ),
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.upload_file),
              ),
            ),
            IconButton(
              key: const ValueKey('base-camp-editor-save'),
              onPressed: () => unawaited(_save()),
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
              SizedBox(
                key: _sectionTabsViewportKey,
                height: _sectionTabsHeight,
                width: double.infinity,
                child: SizedBox(
                  key: const ValueKey('base-camp-editor-section-tabs'),
                  child: SingleChildScrollView(
                    key: const ValueKey('base-camp-editor-section-tabs-scroll'),
                    controller: _sectionTabsController,
                    scrollDirection: Axis.horizontal,
                    padding: EdgeInsets.only(
                      left: 12,
                      right: MediaQuery.sizeOf(context).width / 2,
                    ),
                    child: Row(
                      children: [
                        for (final item
                            in const <(_BaseCampEditorSection, String)>[
                              (_BaseCampEditorSection.routes, 'ROUTE EDITOR'),
                              (
                                _BaseCampEditorSection.buildings,
                                'BUILDING EDITOR',
                              ),
                              (_BaseCampEditorSection.objects, 'OBJECT EDITOR'),
                              (
                                _BaseCampEditorSection.smokeOrigin,
                                'SMOKE ORIGIN',
                              ),
                              (_BaseCampEditorSection.labels, 'FACILITY LABEL'),
                              (_BaseCampEditorSection.waterMask, 'WATER MASK'),
                              (_BaseCampEditorSection.shoreline, 'SHORELINE'),
                              (
                                _BaseCampEditorSection.exclusionMask,
                                'EXCLUSION MASK',
                              ),
                              (
                                _BaseCampEditorSection.staticSoldiers,
                                'STATIC SOLDIER',
                              ),
                              (
                                _BaseCampEditorSection.soldierSize,
                                'SOLDIER SIZE',
                              ),
                              (_BaseCampEditorSection.helicopter, 'HELICOPTER'),
                            ]) ...[
                          SizedBox(
                            key: _sectionTabKeys[item.$1],
                            child: ChoiceChip(
                              label: Text(item.$2),
                              selected: _section == item.$1,
                              onSelected: (_) => _selectSection(item.$1),
                            ),
                          ),
                          if (item.$1 != _BaseCampEditorSection.helicopter)
                            const SizedBox(width: 6),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final metrics = _BaseCampEditorWorkspaceMetrics.fromHeight(
                      constraints.maxHeight,
                      _mapWorkspaceFraction,
                    );
                    return Column(
                      children: [
                        SizedBox(
                          key: const ValueKey('base-camp-editor-map-pane'),
                          height: metrics.mapHeight,
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
                                _updateLabelPosition(
                                  _facilityId,
                                  position,
                                  part: part,
                                ),
                            selectedWaterFxId: _waterFxId,
                            selectedWaterArea: _waterAreaIndex,
                            selectedWaterPoint: _waterPointIndex,
                            selectedWaterMask: _waterMaskSelected,
                            selectedExclusionMask: _exclusionMaskIndex,
                            awaitingWaterPoint: _awaitingWaterPoint,
                            onWaterCanvasTap: (position, mask) =>
                                _insertWaterPointAt(position, mask: mask),
                            awaitingNewWaterArea: _awaitingNewWaterArea,
                            onNewWaterAreaCanvasTap: _addWaterAreaAt,
                            awaitingExclusionPoint: _awaitingExclusionPoint,
                            onExclusionCanvasTap: _insertExclusionPointAt,
                            onWaterPointSelected: (index, mask) => setState(() {
                              _waterPointIndex = index;
                              _waterMaskSelected = mask;
                            }),
                            onExclusionSelected: (polygon, point) =>
                                setState(() {
                                  _exclusionMaskIndex = polygon;
                                  _waterPointIndex = point;
                                  _waterMaskSelected = false;
                                }),
                            onWaterDragStarted: () => setState(() {
                              _activeWaterDragAreaIndex = _waterAreaIndex;
                              _undo.add(_clone(_working));
                            }),
                            onWaterPointDragged: (index, position, mask) {
                              if (_activeWaterDragAreaIndex !=
                                  _waterAreaIndex) {
                                return;
                              }
                              _updateWaterPoint(
                                _waterFxId,
                                index,
                                position,
                                mask: mask,
                              );
                            },
                            onExclusionPointDragged:
                                (polygon, index, position) {
                                  if (_activeWaterDragAreaIndex !=
                                      _waterAreaIndex) {
                                    return;
                                  }
                                  final effect = _working.waterFx[_waterFxId]!;
                                  final areas = _areas(effect);
                                  final areaIndex = _safeAreaIndex(effect);
                                  final area = areas[areaIndex];
                                  if (polygon < 0 ||
                                      polygon >= area.exclusionMasks.length) {
                                    return;
                                  }
                                  final masks = area.exclusionMasks
                                      .map((item) => List<Offset>.of(item))
                                      .toList(growable: false);
                                  if (index < 0 ||
                                      index >= masks[polygon].length) {
                                    return;
                                  }
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
                                        _waterFxId: _withAreas(
                                          effect,
                                          areas
                                            ..[areaIndex] = BaseCampWaterArea(
                                              mask: area.mask,
                                              shoreline: area.shoreline,
                                              exclusionMasks: masks,
                                            ),
                                        ),
                                      },
                                    ),
                                  );
                                  _scheduleWaterDraftSave();
                                },
                            selectedStaticSoldierId: _staticSoldierId,
                            onStaticSoldierSelected: (id) =>
                                setState(() => _staticSoldierId = id),
                            onStaticSoldierDragStarted: (id) => setState(() {
                              _staticSoldierId = id;
                              _undo.add(_clone(_working));
                            }),
                            onStaticSoldierDragged: (id, position) {
                              _updateStaticSoldierPosition(id, position);
                            },
                            helicopterPart: _helicopterPart,
                            helicopterInteraction: _helicopterInteraction,
                            helicopterPreview: _helicopterPreview,
                            helicopterRotorsOn: _helicopterRotorsOn,
                            helicopterMainVisible: _helicopterMainVisible,
                            helicopterTailVisible: _helicopterTailVisible,
                            helicopterMainFrame: _helicopterMainFrame,
                            helicopterTailFrame: _helicopterTailFrame,
                            helicopterTestPosition: _helicopterTestPosition,
                            helicopterDirection: _helicopterDirection,
                            helicopterFlightRunId: _helicopterFlightRunId,
                            onHelicopterFlightComplete: _stopHelicopterFlight,
                            onHelicopterGestureStart: _beginHelicopterGesture,
                            onHelicopterGestureUpdate: _updateHelicopterGesture,
                          ),
                        ),
                        GestureDetector(
                          key: const ValueKey('base-camp-editor-resize-handle'),
                          behavior: HitTestBehavior.opaque,
                          onVerticalDragUpdate: (details) =>
                              _resizeWorkspace(details, metrics),
                          child: SizedBox(
                            height: metrics.handleHeight,
                            child: Center(
                              child: Container(
                                width: 44,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.outlineVariant,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          key: const ValueKey('base-camp-editor-controls-pane'),
                          child: Scrollbar(
                            controller: _controlsScrollController,
                            child: SingleChildScrollView(
                              key: const ValueKey(
                                'base-camp-editor-controls-scroll',
                              ),
                              controller: _controlsScrollController,
                              keyboardDismissBehavior:
                                  ScrollViewKeyboardDismissBehavior.onDrag,
                              child: _editorControls(),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _editorControls() {
    if (_section == _BaseCampEditorSection.helicopter) {
      return _helicopterControls();
    }
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
                if (_waterDraftError != null)
                  Text(
                    _waterDraftError!,
                    key: const ValueKey('base-camp-water-draft-error'),
                    style: const TextStyle(color: Colors.redAccent),
                  ),
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
                if (isMask)
                  OutlinedButton.icon(
                    key: const ValueKey('base-camp-editor-water-new-area'),
                    onPressed: () => setState(() {
                      _awaitingNewWaterArea = true;
                      _awaitingWaterPoint = false;
                    }),
                    icon: const Icon(Icons.add_box_outlined),
                    label: const Text('NEW AREA'),
                  ),
                OutlinedButton.icon(
                  onPressed: () => setState(() => _awaitingWaterPoint = true),
                  icon: const Icon(Icons.add),
                  label: const Text('ADD POINT'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _deleteWaterPoint(mask: isMask),
                  icon: const Icon(Icons.remove),
                  label: const Text('DELETE POINT'),
                ),
                if (isMask)
                  OutlinedButton.icon(
                    onPressed: _deleteWaterArea,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('DELETE AREA'),
                  ),
                OutlinedButton.icon(
                  onPressed: () =>
                      _canvasKey.currentState?.focusWaterFx(_waterFxId),
                  icon: const Icon(Icons.center_focus_strong),
                  label: const Text('FOCUS AREA'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _canvasKey.currentState?.exitWaterFocus(),
                  icon: const Icon(Icons.fullscreen_exit),
                  label: const Text('FULL MAP'),
                ),
              ],
            ),
            if (isMask)
              DropdownButton<int>(
                key: const ValueKey('base-camp-editor-water-select-area'),
                value: _safeAreaIndex(_working.waterFx[_waterFxId]!),
                items: [
                  for (
                    var index = 0;
                    index < _areas(_working.waterFx[_waterFxId]!).length;
                    index++
                  )
                    DropdownMenuItem(
                      value: index,
                      child: Text('SELECT AREA ${index + 1}'),
                    ),
                ],
                onChanged: (value) => setState(() {
                  _waterAreaIndex = value!;
                  _activeWaterDragAreaIndex = -1;
                  _waterPointIndex = 0;
                  _waterMaskSelected = true;
                }),
              ),
            const Text('MOVE POINT: drag a selected vertex on the map.'),
            if (isMask && _awaitingNewWaterArea)
              const Text(
                'PLACEMENT READY — TAP MAP TO CREATE WATER AREA',
                key: ValueKey('base-camp-editor-water-placement-ready'),
              ),
          ],
        ),
      );
    }
    if (_section == _BaseCampEditorSection.exclusionMask) {
      final effect = _working.waterFx[_waterFxId]!;
      final area = _areas(effect)[_safeAreaIndex(effect)];
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('EXCLUSION MASK: 見張り台・岩・陸地を水面FXから除外します。'),
            Text(
              '選択中: ${area.exclusionMasks.isEmpty ? 'なし' : _exclusionMaskIndex + 1}',
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
                  onPressed: area.exclusionMasks.isEmpty
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
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'SELECTED: ${soldier.id}',
                  key: const ValueKey('base-camp-static-soldier-selection'),
                ),
              ),
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

  Widget _helicopterControls() {
    final assembly = _working.helicopterAssembly;
    final (x, y, scale) = switch (_helicopterPart) {
      _HelicopterPart.body => (
        _helicopterTestPosition.dx,
        _helicopterTestPosition.dy,
        assembly.globalScale,
      ),
      _HelicopterPart.mainRotor => (
        assembly.mainHub.dx,
        assembly.mainHub.dy,
        assembly.mainScale,
      ),
      _HelicopterPart.tailRotor => (
        assembly.tailHub.dx,
        assembly.tailHub.dy,
        assembly.tailScale,
      ),
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final part in _HelicopterPart.values)
                ChoiceChip(
                  key: ValueKey('helicopter-part-${part.name}'),
                  label: Text(switch (part) {
                    _HelicopterPart.body => 'BODY',
                    _HelicopterPart.mainRotor => 'MAIN ROTOR',
                    _HelicopterPart.tailRotor => 'TAIL ROTOR',
                  }),
                  selected: _helicopterPart == part,
                  onSelected: (_) => setState(() => _helicopterPart = part),
                ),
              ChoiceChip(
                key: const ValueKey('helicopter-part-edit'),
                label: const Text('PART EDIT'),
                selected:
                    _helicopterInteraction == _HelicopterInteraction.partEdit,
                onSelected: (_) => setState(
                  () =>
                      _helicopterInteraction = _HelicopterInteraction.partEdit,
                ),
              ),
              ChoiceChip(
                key: const ValueKey('helicopter-map-nav'),
                label: const Text('MAP NAV'),
                selected:
                    _helicopterInteraction == _HelicopterInteraction.mapNav,
                onSelected: (_) => setState(
                  () => _helicopterInteraction = _HelicopterInteraction.mapNav,
                ),
              ),
              ChoiceChip(
                label: const Text('STATIONARY'),
                selected: _helicopterPreview == _HelicopterPreview.stationary,
                onSelected: (_) {
                  _stopHelicopterFlight();
                  setState(
                    () => _helicopterPreview = _HelicopterPreview.stationary,
                  );
                },
              ),
              ChoiceChip(
                label: const Text('FLIGHT'),
                selected: _helicopterPreview == _HelicopterPreview.flight,
                onSelected: (_) => setState(
                  () => _helicopterPreview = _HelicopterPreview.flight,
                ),
              ),
              FilterChip(
                key: const ValueKey('helicopter-rotors-on'),
                label: Text(_helicopterRotorsOn ? 'ROTORS ON' : 'ROTORS OFF'),
                selected: _helicopterRotorsOn,
                onSelected: (value) =>
                    setState(() => _helicopterRotorsOn = value),
              ),
              FilterChip(
                label: const Text('MAIN VISIBLE'),
                selected: _helicopterMainVisible,
                onSelected: (value) =>
                    setState(() => _helicopterMainVisible = value),
              ),
              FilterChip(
                label: const Text('TAIL VISIBLE'),
                selected: _helicopterTailVisible,
                onSelected: (value) =>
                    setState(() => _helicopterTailVisible = value),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _helicopterSlider(
            label: 'GLOBAL HELICOPTER SCALE',
            valueLabel: '${assembly.globalScale.toStringAsFixed(2)}×',
            keyName: 'helicopter-global-scale',
            value: assembly.globalScale,
            minimum: BaseCampHelicopterAssembly.minimumScale,
            maximum: BaseCampHelicopterAssembly.maximumScale,
            divisions: 58,
            onChanged: (value) => _updateHelicopterAssembly(
              assembly.copyWith(globalScale: (value * 20).roundToDouble() / 20),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              key: const ValueKey('helicopter-reset-global-scale'),
              onPressed: assembly.globalScale == 1
                  ? null
                  : () => _mutate(
                      _working.copyWith(
                        helicopterAssembly: assembly.copyWith(globalScale: 1),
                      ),
                    ),
              icon: const Icon(Icons.restart_alt),
              label: const Text('RESET SCALE'),
            ),
          ),
          _helicopterSlider(
            label: 'MAIN ROTOR SPEED',
            valueLabel:
                '${assembly.mainFrameMs}ms/frame · ${assembly.mainFrameMs * baseCampHelicopterMainRotorAssets.length}ms loop',
            keyName: 'helicopter-main-speed',
            value: assembly.mainFrameMs.toDouble(),
            minimum: BaseCampHelicopterAssembly.minimumMainFrameMs.toDouble(),
            maximum: BaseCampHelicopterAssembly.maximumMainFrameMs.toDouble(),
            divisions:
                (BaseCampHelicopterAssembly.maximumMainFrameMs -
                    BaseCampHelicopterAssembly.minimumMainFrameMs) ~/
                BaseCampHelicopterAssembly.frameMsStep,
            onChanged: (value) => _updateHelicopterAssembly(
              assembly.copyWith(
                mainFrameMs:
                    (value / BaseCampHelicopterAssembly.frameMsStep).round() *
                    BaseCampHelicopterAssembly.frameMsStep,
              ),
            ),
          ),
          _helicopterSlider(
            label: 'TAIL ROTOR SPEED',
            valueLabel:
                '${assembly.tailFrameMs}ms/frame · ${assembly.tailFrameMs * baseCampHelicopterTailRotorAssets.length}ms loop',
            keyName: 'helicopter-tail-speed',
            value: assembly.tailFrameMs.toDouble(),
            minimum: BaseCampHelicopterAssembly.minimumTailFrameMs.toDouble(),
            maximum: BaseCampHelicopterAssembly.maximumTailFrameMs.toDouble(),
            divisions:
                (BaseCampHelicopterAssembly.maximumTailFrameMs -
                    BaseCampHelicopterAssembly.minimumTailFrameMs) ~/
                BaseCampHelicopterAssembly.frameMsStep,
            onChanged: (value) => _updateHelicopterAssembly(
              assembly.copyWith(
                tailFrameMs:
                    (value / BaseCampHelicopterAssembly.frameMsStep).round() *
                    BaseCampHelicopterAssembly.frameMsStep,
              ),
            ),
          ),
          _helicopterSlider(
            label: 'FLIGHT SPEED',
            valueLabel: '${assembly.flightSpeed} MAP px/s',
            keyName: 'helicopter-flight-speed',
            value: assembly.flightSpeed.toDouble(),
            minimum: BaseCampHelicopterAssembly.minimumFlightSpeed.toDouble(),
            maximum: BaseCampHelicopterAssembly.maximumFlightSpeed.toDouble(),
            divisions:
                (BaseCampHelicopterAssembly.maximumFlightSpeed -
                    BaseCampHelicopterAssembly.minimumFlightSpeed) ~/
                BaseCampHelicopterAssembly.flightSpeedStep,
            onChanged: (value) => _updateHelicopterAssembly(
              assembly.copyWith(
                flightSpeed:
                    (value / BaseCampHelicopterAssembly.flightSpeedStep)
                        .round() *
                    BaseCampHelicopterAssembly.flightSpeedStep,
              ),
            ),
          ),
          _helicopterSlider(
            label: 'FORWARD PITCH',
            valueLabel: '${assembly.forwardPitchDegrees}°',
            keyName: 'helicopter-forward-pitch',
            value: assembly.forwardPitchDegrees.toDouble(),
            minimum: BaseCampHelicopterAssembly.minimumForwardPitchDegrees
                .toDouble(),
            maximum: BaseCampHelicopterAssembly.maximumForwardPitchDegrees
                .toDouble(),
            divisions:
                (BaseCampHelicopterAssembly.maximumForwardPitchDegrees -
                    BaseCampHelicopterAssembly.minimumForwardPitchDegrees) ~/
                BaseCampHelicopterAssembly.forwardPitchDegreesStep,
            onChanged: (value) => _updateHelicopterAssembly(
              assembly.copyWith(
                forwardPitchDegrees:
                    (value / BaseCampHelicopterAssembly.forwardPitchDegreesStep)
                        .round() *
                    BaseCampHelicopterAssembly.forwardPitchDegreesStep,
              ),
            ),
          ),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 6,
            runSpacing: 6,
            children: [
              TextButton.icon(
                key: const ValueKey('helicopter-reset-speed'),
                onPressed:
                    assembly.mainFrameMs ==
                            BaseCampHelicopterAssembly.defaultMainFrameMs &&
                        assembly.tailFrameMs ==
                            BaseCampHelicopterAssembly.defaultTailFrameMs
                    ? null
                    : () => _mutate(
                        _working.copyWith(
                          helicopterAssembly: assembly.copyWith(
                            mainFrameMs:
                                BaseCampHelicopterAssembly.defaultMainFrameMs,
                            tailFrameMs:
                                BaseCampHelicopterAssembly.defaultTailFrameMs,
                          ),
                        ),
                      ),
                icon: const Icon(Icons.restart_alt),
                label: const Text('RESET SPEED'),
              ),
              TextButton.icon(
                key: const ValueKey('helicopter-reset-flight-settings'),
                onPressed:
                    assembly.flightSpeed ==
                            BaseCampHelicopterAssembly.defaultFlightSpeed &&
                        assembly.forwardPitchDegrees ==
                            BaseCampHelicopterAssembly
                                .defaultForwardPitchDegrees
                    ? null
                    : () => _mutate(
                        _working.copyWith(
                          helicopterAssembly: assembly.copyWith(
                            flightSpeed:
                                BaseCampHelicopterAssembly.defaultFlightSpeed,
                            forwardPitchDegrees: BaseCampHelicopterAssembly
                                .defaultForwardPitchDegrees,
                          ),
                        ),
                      ),
                icon: const Icon(Icons.restart_alt),
                label: const Text('RESET FLIGHT SETTINGS'),
              ),
              OutlinedButton.icon(
                key: const ValueKey('helicopter-copy-json'),
                onPressed: _copyHelicopterJson,
                icon: const Icon(Icons.copy),
                label: const Text('COPY HELICOPTER JSON'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(child: _helicopterNumberField('X', x)),
              const SizedBox(width: 6),
              Expanded(child: _helicopterNumberField('Y', y)),
              const SizedBox(width: 6),
              Expanded(child: _helicopterNumberField('SCALE', scale)),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              DropdownButton<int>(
                value: _helicopterMainFrame,
                items: List<DropdownMenuItem<int>>.generate(
                  baseCampHelicopterMainRotorAssets.length,
                  (index) => DropdownMenuItem(
                    value: index,
                    child: Text('MAIN F${index + 1}'),
                  ),
                ),
                onChanged: (value) =>
                    setState(() => _helicopterMainFrame = value ?? 0),
              ),
              DropdownButton<int>(
                value: _helicopterTailFrame,
                items: List<DropdownMenuItem<int>>.generate(
                  baseCampHelicopterTailRotorAssets.length,
                  (index) => DropdownMenuItem(
                    value: index,
                    child: Text('TAIL F${index + 1}'),
                  ),
                ),
                onChanged: (value) =>
                    setState(() => _helicopterTailFrame = value ?? 0),
              ),
              ChoiceChip(
                key: const ValueKey('helicopter-direction-left-to-right'),
                label: const Text('LEFT → RIGHT'),
                selected:
                    _helicopterDirection ==
                    BaseCampHelicopterDirection.leftToRight,
                onSelected: (_) => setState(
                  () => _helicopterDirection =
                      BaseCampHelicopterDirection.leftToRight,
                ),
              ),
              ChoiceChip(
                key: const ValueKey('helicopter-direction-right-to-left'),
                label: const Text('RIGHT → LEFT'),
                selected:
                    _helicopterDirection ==
                    BaseCampHelicopterDirection.rightToLeft,
                onSelected: (_) => setState(
                  () => _helicopterDirection =
                      BaseCampHelicopterDirection.rightToLeft,
                ),
              ),
              FilledButton.icon(
                key: const ValueKey('helicopter-run-flight'),
                onPressed: _runHelicopterFlight,
                icon: const Icon(Icons.play_arrow),
                label: const Text('RUN FLIGHT'),
              ),
              OutlinedButton.icon(
                key: const ValueKey('helicopter-stop-flight'),
                onPressed: _stopHelicopterFlight,
                icon: const Icon(Icons.stop),
                label: const Text('STOP'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _helicopterSlider({
    required String label,
    required String valueLabel,
    required String keyName,
    required double value,
    required double minimum,
    required double maximum,
    required int divisions,
    required ValueChanged<double> onChanged,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.labelMedium),
          ),
          Text(valueLabel, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
      Slider(
        key: ValueKey(keyName),
        value: value.clamp(minimum, maximum).toDouble(),
        min: minimum,
        max: maximum,
        divisions: divisions,
        onChangeStart: (_) => _beginHelicopterSlider(),
        onChanged: onChanged,
        onChangeEnd: (_) => _endHelicopterSlider(),
      ),
    ],
  );

  Widget _helicopterNumberField(String label, double value) => TextFormField(
    key: ValueKey(
      'helicopter-${_helicopterPart.name}-$label-${value.toStringAsFixed(3)}',
    ),
    initialValue: value.toStringAsFixed(label == 'SCALE' ? 3 : 1),
    keyboardType: const TextInputType.numberWithOptions(
      decimal: true,
      signed: true,
    ),
    decoration: InputDecoration(labelText: label, isDense: true),
    onFieldSubmitted: (raw) {
      final parsed = double.tryParse(raw);
      final scaleValid =
          label != 'SCALE' ||
          (parsed != null &&
              parsed >= BaseCampHelicopterAssembly.minimumScale &&
              parsed <= BaseCampHelicopterAssembly.maximumScale);
      if (parsed == null || !parsed.isFinite || !scaleValid) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('INVALID HELICOPTER VALUE')),
        );
        return;
      }
      _setHelicopterValue(
        x: label == 'X' ? parsed : null,
        y: label == 'Y' ? parsed : null,
        scale: label == 'SCALE' ? parsed : null,
      );
    },
  );

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
    required this.selectedWaterArea,
    required this.selectedWaterPoint,
    required this.selectedWaterMask,
    required this.selectedExclusionMask,
    required this.awaitingWaterPoint,
    required this.onWaterCanvasTap,
    required this.awaitingNewWaterArea,
    required this.onNewWaterAreaCanvasTap,
    required this.awaitingExclusionPoint,
    required this.onExclusionCanvasTap,
    required this.onWaterPointSelected,
    required this.onExclusionSelected,
    required this.onWaterDragStarted,
    required this.onWaterPointDragged,
    required this.onExclusionPointDragged,
    required this.selectedStaticSoldierId,
    required this.onStaticSoldierSelected,
    required this.onStaticSoldierDragStarted,
    required this.onStaticSoldierDragged,
    required this.helicopterPart,
    required this.helicopterInteraction,
    required this.helicopterPreview,
    required this.helicopterRotorsOn,
    required this.helicopterMainVisible,
    required this.helicopterTailVisible,
    required this.helicopterMainFrame,
    required this.helicopterTailFrame,
    required this.helicopterTestPosition,
    required this.helicopterDirection,
    required this.helicopterFlightRunId,
    required this.onHelicopterFlightComplete,
    required this.onHelicopterGestureStart,
    required this.onHelicopterGestureUpdate,
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
  final int selectedWaterArea;
  final int selectedWaterPoint;
  final bool selectedWaterMask;
  final int selectedExclusionMask;
  final bool awaitingWaterPoint;
  final void Function(Offset position, bool mask) onWaterCanvasTap;
  final bool awaitingNewWaterArea;
  final ValueChanged<Offset> onNewWaterAreaCanvasTap;
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
  final ValueChanged<String> onStaticSoldierSelected;
  final ValueChanged<String> onStaticSoldierDragStarted;
  final void Function(String id, Offset position) onStaticSoldierDragged;
  final _HelicopterPart helicopterPart;
  final _HelicopterInteraction helicopterInteraction;
  final _HelicopterPreview helicopterPreview;
  final bool helicopterRotorsOn;
  final bool helicopterMainVisible;
  final bool helicopterTailVisible;
  final int helicopterMainFrame;
  final int helicopterTailFrame;
  final Offset helicopterTestPosition;
  final BaseCampHelicopterDirection helicopterDirection;
  final int? helicopterFlightRunId;
  final VoidCallback onHelicopterFlightComplete;
  final VoidCallback onHelicopterGestureStart;
  final void Function(Offset mapDelta, Offset bodyDelta, double scale)
  onHelicopterGestureUpdate;

  @override
  State<_BaseCampEditorCanvas> createState() => _BaseCampEditorCanvasState();
}

class _BaseCampEditorCanvasState extends State<_BaseCampEditorCanvas> {
  final TransformationController _transform = TransformationController();
  final GlobalKey _sourceKey = GlobalKey();
  Size? _viewport;
  Offset? _pendingViewportAnchorScene;
  int _viewportAdjustmentGeneration = 0;
  Matrix4? _transformBeforeWaterFocus;
  String? _focusedWaterFxId;
  final ValueNotifier<Duration> _previewElapsed = ValueNotifier<Duration>(
    Duration.zero,
  );
  final Stopwatch _previewWatch = Stopwatch();
  Timer? _previewTimer;
  Offset _helicopterMapDelta = Offset.zero;
  double _helicopterBodyUnitsPerSourcePixel = 1;
  int _helicopterPointers = 0;

  Duration get previewElapsed => _previewElapsed.value;

  @override
  void initState() {
    super.initState();
    _previewWatch.start();
    // iPhone Safari cannot sustain rebuilding a 1254px editor stack at the
    // display refresh rate. Ten preview frames per second keep motion clear
    // while bounding canvas allocation and raster work.
    _previewTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      _previewElapsed.value = _previewWatch.elapsed;
    });
  }

  @override
  void dispose() {
    _previewTimer?.cancel();
    _previewWatch.stop();
    _previewElapsed.dispose();
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

  void _updateViewport(Size viewport) {
    if (_viewport == viewport) return;
    final previous = _viewport;
    if (previous == null) {
      _viewport = viewport;
      final generation = ++_viewportAdjustmentGeneration;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && generation == _viewportAdjustmentGeneration) {
          resetView();
        }
      });
      return;
    }

    _pendingViewportAnchorScene ??= _transform.toScene(
      previous.center(Offset.zero),
    );
    _viewport = viewport;
    final generation = ++_viewportAdjustmentGeneration;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || generation != _viewportAdjustmentGeneration) return;
      final focusedId = _focusedWaterFxId;
      if (focusedId != null) {
        _pendingViewportAnchorScene = null;
        _applyWaterFocus(focusedId);
        return;
      }
      final anchorScene = _pendingViewportAnchorScene;
      _pendingViewportAnchorScene = null;
      if (anchorScene == null) return;
      final matrix = Matrix4.copy(_transform.value);
      final mappedAnchor = MatrixUtils.transformPoint(matrix, anchorScene);
      final viewportCenter = viewport.center(Offset.zero);
      final delta = viewportCenter - mappedAnchor;
      final translation = matrix.getTranslation();
      matrix.setTranslationRaw(
        translation.x + delta.dx,
        translation.y + delta.dy,
        translation.z,
      );
      _transform.value = matrix;
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
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final viewport = constraints.biggest;
      _updateViewport(viewport);
      final viewer = InteractiveViewer(
        key: const ValueKey('base-camp-editor-map'),
        transformationController: _transform,
        constrained: false,
        minScale: .2,
        maxScale: 3.2,
        boundaryMargin: const EdgeInsets.all(160),
        panEnabled:
            widget.section != _BaseCampEditorSection.helicopter ||
            widget.helicopterInteraction == _HelicopterInteraction.mapNav,
        scaleEnabled:
            widget.section != _BaseCampEditorSection.helicopter ||
            widget.helicopterInteraction == _HelicopterInteraction.mapNav,
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
                  _sourceKey.currentContext?.findRenderObject() as RenderBox?;
              if (renderBox != null) {
                widget.onObjectDragged(
                  BaseCampMapGeometry.contain(
                    baseCampMapArtworkSize,
                  ).artworkToSource(renderBox.globalToLocal(globalPosition)),
                );
              }
            },
            onLabelDragStarted: widget.onLabelDragStarted,
            onLabelGlobalDragged: (globalPosition, part) {
              final renderBox =
                  _sourceKey.currentContext?.findRenderObject() as RenderBox?;
              if (renderBox != null) {
                widget.onLabelDragged(
                  BaseCampMapGeometry.contain(
                    baseCampMapArtworkSize,
                  ).artworkToSource(renderBox.globalToLocal(globalPosition)),
                  part,
                );
              }
            },
            selectedWaterFxId: widget.selectedWaterFxId,
            selectedWaterArea: widget.selectedWaterArea,
            previewElapsed: _previewElapsed,
            selectedWaterPoint: widget.selectedWaterPoint,
            selectedWaterMask: widget.selectedWaterMask,
            selectedExclusionMask: widget.selectedExclusionMask,
            awaitingWaterPoint: widget.awaitingWaterPoint,
            onWaterCanvasTap: widget.onWaterCanvasTap,
            awaitingNewWaterArea: widget.awaitingNewWaterArea,
            onNewWaterAreaCanvasTap: widget.onNewWaterAreaCanvasTap,
            awaitingExclusionPoint: widget.awaitingExclusionPoint,
            onExclusionCanvasTap: widget.onExclusionCanvasTap,
            onWaterPointSelected: widget.onWaterPointSelected,
            onExclusionSelected: widget.onExclusionSelected,
            onWaterDragStarted: widget.onWaterDragStarted,
            onWaterGlobalDragged: (index, globalPosition, mask) {
              final renderBox =
                  _sourceKey.currentContext?.findRenderObject() as RenderBox?;
              if (renderBox != null) {
                widget.onWaterPointDragged(
                  index,
                  BaseCampMapGeometry.contain(
                    baseCampMapArtworkSize,
                  ).viewportToArtwork(renderBox.globalToLocal(globalPosition)),
                  mask,
                );
              }
            },
            onExclusionGlobalDragged: (polygon, index, globalPosition) {
              final renderBox =
                  _sourceKey.currentContext?.findRenderObject() as RenderBox?;
              if (renderBox != null) {
                widget.onExclusionPointDragged(
                  polygon,
                  index,
                  BaseCampMapGeometry.contain(
                    baseCampMapArtworkSize,
                  ).viewportToArtwork(renderBox.globalToLocal(globalPosition)),
                );
              }
            },
            selectedStaticSoldierId: widget.selectedStaticSoldierId,
            onStaticSoldierSelected: widget.onStaticSoldierSelected,
            onStaticSoldierDragStarted: widget.onStaticSoldierDragStarted,
            onStaticSoldierGlobalDragged: (id, globalPosition) {
              final renderBox =
                  _sourceKey.currentContext?.findRenderObject() as RenderBox?;
              if (renderBox != null) {
                widget.onStaticSoldierDragged(
                  id,
                  BaseCampMapGeometry.contain(
                    baseCampMapArtworkSize,
                  ).artworkToSource(renderBox.globalToLocal(globalPosition)),
                );
              }
            },
            helicopterPart: widget.helicopterPart,
            helicopterInteraction: widget.helicopterInteraction,
            helicopterPreview: widget.helicopterPreview,
            helicopterRotorsOn: widget.helicopterRotorsOn,
            helicopterMainVisible: widget.helicopterMainVisible,
            helicopterTailVisible: widget.helicopterTailVisible,
            helicopterMainFrame: widget.helicopterMainFrame,
            helicopterTailFrame: widget.helicopterTailFrame,
            helicopterTestPosition: widget.helicopterTestPosition,
            helicopterDirection: widget.helicopterDirection,
            helicopterFlightRunId: widget.helicopterFlightRunId,
            onHelicopterFlightComplete: widget.onHelicopterFlightComplete,
            onHelicopterGestureStart: widget.onHelicopterGestureStart,
            onHelicopterGestureUpdate: widget.onHelicopterGestureUpdate,
          ),
        ),
      );
      final partEdit =
          widget.section == _BaseCampEditorSection.helicopter &&
          widget.helicopterInteraction == _HelicopterInteraction.partEdit &&
          widget.helicopterPreview == _HelicopterPreview.stationary;
      return ClipRect(
        child: partEdit
            ? Listener(
                onPointerDown: (_) {
                  if (_helicopterPointers++ != 0) return;
                  _helicopterMapDelta = Offset.zero;
                  _helicopterBodyUnitsPerSourcePixel =
                      BaseCampHelicopterSprite.sourceSize.width /
                      (baseCampMapArtworkSize.width *
                          .42 *
                          widget.configuration.helicopterAssembly.globalScale);
                  widget.onHelicopterGestureStart();
                },
                onPointerUp: (_) =>
                    _helicopterPointers = math.max(0, _helicopterPointers - 1),
                onPointerCancel: (_) =>
                    _helicopterPointers = math.max(0, _helicopterPointers - 1),
                child: GestureDetector(
                  key: const ValueKey('base-camp-helicopter-part-gesture'),
                  behavior: HitTestBehavior.opaque,
                  onScaleUpdate: (details) {
                    final transformScale = _transform.value
                        .getMaxScaleOnAxis()
                        .clamp(.0001, double.infinity)
                        .toDouble();
                    _helicopterMapDelta +=
                        details.focalPointDelta / transformScale;
                    widget.onHelicopterGestureUpdate(
                      _helicopterMapDelta,
                      _helicopterMapDelta * _helicopterBodyUnitsPerSourcePixel,
                      details.scale,
                    );
                  },
                  child: IgnorePointer(child: viewer),
                ),
              )
            : viewer,
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
    required this.onLabelDragStarted,
    required this.onLabelGlobalDragged,
    required this.selectedWaterFxId,
    required this.selectedWaterArea,
    required this.previewElapsed,
    required this.selectedWaterPoint,
    required this.selectedWaterMask,
    required this.selectedExclusionMask,
    required this.awaitingWaterPoint,
    required this.onWaterCanvasTap,
    required this.awaitingNewWaterArea,
    required this.onNewWaterAreaCanvasTap,
    required this.awaitingExclusionPoint,
    required this.onExclusionCanvasTap,
    required this.onWaterPointSelected,
    required this.onExclusionSelected,
    required this.onWaterDragStarted,
    required this.onWaterGlobalDragged,
    required this.onExclusionGlobalDragged,
    required this.selectedStaticSoldierId,
    required this.onStaticSoldierSelected,
    required this.onStaticSoldierDragStarted,
    required this.onStaticSoldierGlobalDragged,
    required this.helicopterPart,
    required this.helicopterInteraction,
    required this.helicopterPreview,
    required this.helicopterRotorsOn,
    required this.helicopterMainVisible,
    required this.helicopterTailVisible,
    required this.helicopterMainFrame,
    required this.helicopterTailFrame,
    required this.helicopterTestPosition,
    required this.helicopterDirection,
    required this.helicopterFlightRunId,
    required this.onHelicopterFlightComplete,
    required this.onHelicopterGestureStart,
    required this.onHelicopterGestureUpdate,
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
  final int selectedWaterArea;
  final ValueListenable<Duration> previewElapsed;
  final int selectedWaterPoint;
  final bool selectedWaterMask;
  final int selectedExclusionMask;
  final bool awaitingWaterPoint;
  final void Function(Offset position, bool mask) onWaterCanvasTap;
  final bool awaitingNewWaterArea;
  final ValueChanged<Offset> onNewWaterAreaCanvasTap;
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
  final ValueChanged<String> onStaticSoldierSelected;
  final ValueChanged<String> onStaticSoldierDragStarted;
  final void Function(String id, Offset position) onStaticSoldierGlobalDragged;
  final _HelicopterPart helicopterPart;
  final _HelicopterInteraction helicopterInteraction;
  final _HelicopterPreview helicopterPreview;
  final bool helicopterRotorsOn;
  final bool helicopterMainVisible;
  final bool helicopterTailVisible;
  final int helicopterMainFrame;
  final int helicopterTailFrame;
  final Offset helicopterTestPosition;
  final BaseCampHelicopterDirection helicopterDirection;
  final int? helicopterFlightRunId;
  final VoidCallback onHelicopterFlightComplete;
  final VoidCallback onHelicopterGestureStart;
  final void Function(Offset mapDelta, Offset bodyDelta, double scale)
  onHelicopterGestureUpdate;

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
    final effect = configuration.waterFx[selectedWaterFxId];
    final areas = effect?.effectiveAreas ?? const <BaseCampWaterArea>[];
    final water = areas.isEmpty
        ? null
        : areas[selectedWaterArea.clamp(0, areas.length - 1)];
    return Stack(
      fit: StackFit.expand,
      children: [
        const Image(image: AssetImage(baseCampMapAsset), fit: BoxFit.contain),
        IgnorePointer(
          child: BaseCampObjectLayer(
            configuration: configuration,
            geometry: geometry,
          ),
        ),
        RepaintBoundary(
          key: const ValueKey('base-camp-editor-ambient-preview-boundary'),
          child: ValueListenableBuilder<Duration>(
            valueListenable: previewElapsed,
            builder: (context, elapsed, _) => IgnorePointer(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  BaseCampFoodSmokeLayer(
                    configuration: configuration,
                    geometry: geometry,
                    elapsed: elapsed,
                  ),
                  BaseCampWalkerPreviewLayer(
                    elapsed: elapsed,
                    reducedMotion: false,
                    configuration: configuration,
                    geometry: geometry,
                  ),
                ],
              ),
            ),
          ),
        ),
        // Facility plates stay above terrain/facilities, while the aircraft
        // crosses above them exactly as it does on the production MAP.
        IgnorePointer(
          child: BaseCampFacilityLabelLayer(
            configuration: configuration,
            geometry: geometry,
          ),
        ),
        if (section == _BaseCampEditorSection.helicopter)
          _HelicopterEditorOverlay(
            assembly: configuration.helicopterAssembly,
            part: helicopterPart,
            interaction: helicopterInteraction,
            preview: helicopterPreview,
            rotorsOn: helicopterRotorsOn,
            mainVisible: helicopterMainVisible,
            tailVisible: helicopterTailVisible,
            selectedMainFrame: helicopterMainFrame,
            selectedTailFrame: helicopterTailFrame,
            testPosition: helicopterTestPosition,
            direction: helicopterDirection,
            flightRunId: helicopterFlightRunId,
            onFlightComplete: onHelicopterFlightComplete,
            onGestureStart: onHelicopterGestureStart,
            onGestureUpdate: onHelicopterGestureUpdate,
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
        if (awaitingNewWaterArea && section == _BaseCampEditorSection.waterMask)
          Positioned.fill(
            child: GestureDetector(
              key: const ValueKey('base-camp-editor-water-new-area-canvas'),
              behavior: HitTestBehavior.translucent,
              onTapUp: (details) =>
                  onNewWaterAreaCanvasTap(details.localPosition),
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
              key: ValueKey('base-camp-water-shoreline-point-$i'),
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
              key: ValueKey('base-camp-water-mask-point-$i'),
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
                key: ValueKey(
                  'base-camp-water-exclusion-$polygon-point-$point',
                ),
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
              key: ValueKey('base-camp-static-soldier-handle-${soldier.id}'),
              point: geometry.sourceToViewport(soldier.position),
              icon: Icons.person_pin_circle,
              color: soldier.id == selectedStaticSoldierId
                  ? const Color(0xFF68E8F2)
                  : const Color(0xFFD7D9D6),
              selected: soldier.id == selectedStaticSoldierId,
              onTap: () => onStaticSoldierSelected(soldier.id),
              onStart: () => onStaticSoldierDragStarted(soldier.id),
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

class _HelicopterEditorOverlay extends StatefulWidget {
  const _HelicopterEditorOverlay({
    required this.assembly,
    required this.part,
    required this.interaction,
    required this.preview,
    required this.rotorsOn,
    required this.mainVisible,
    required this.tailVisible,
    required this.selectedMainFrame,
    required this.selectedTailFrame,
    required this.testPosition,
    required this.direction,
    required this.flightRunId,
    required this.onFlightComplete,
    required this.onGestureStart,
    required this.onGestureUpdate,
  });

  final BaseCampHelicopterAssembly assembly;
  final _HelicopterPart part;
  final _HelicopterInteraction interaction;
  final _HelicopterPreview preview;
  final bool rotorsOn, mainVisible, tailVisible;
  final int selectedMainFrame, selectedTailFrame;
  final Offset testPosition;
  final BaseCampHelicopterDirection direction;
  final int? flightRunId;
  final VoidCallback onFlightComplete;
  final VoidCallback onGestureStart;
  final void Function(Offset mapDelta, Offset bodyDelta, double scale)
  onGestureUpdate;

  @override
  State<_HelicopterEditorOverlay> createState() =>
      _HelicopterEditorOverlayState();
}

class _HelicopterEditorOverlayState extends State<_HelicopterEditorOverlay>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _elapsed = Duration.zero;
  Duration _tickerBase = Duration.zero;
  Duration? _flightStartedAt;
  bool _completionSent = false;

  bool get _needsTicker => widget.rotorsOn || widget.flightRunId != null;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((sinceStart) {
      if (!mounted) return;
      final elapsed = _tickerBase + sinceStart;
      setState(() => _elapsed = elapsed);
      final flightStartedAt = _flightStartedAt;
      if (flightStartedAt != null && !_completionSent) {
        final path = baseCampHelicopterFlightPath(
          assembly: widget.assembly,
          direction: widget.direction,
        );
        if (elapsed - flightStartedAt >= path.duration) {
          _completionSent = true;
          scheduleMicrotask(widget.onFlightComplete);
        }
      }
    });
    if (widget.flightRunId != null) _flightStartedAt = Duration.zero;
    if (_needsTicker) _ticker.start();
  }

  @override
  void didUpdateWidget(covariant _HelicopterEditorOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.flightRunId != oldWidget.flightRunId) {
      _flightStartedAt = widget.flightRunId == null ? null : _elapsed;
      _completionSent = false;
    }
    if (_needsTicker && !_ticker.isActive) {
      _tickerBase = _elapsed;
      _ticker.start();
    } else if (!_needsTicker && _ticker.isActive) {
      _ticker.stop();
      _tickerBase = _elapsed;
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const mapSize = baseCampMapArtworkSize;
    final width = mapSize.width * .42 * widget.assembly.globalScale;
    final height =
        width *
        BaseCampHelicopterSprite.sourceSize.height /
        BaseCampHelicopterSprite.sourceSize.width;
    final flight = widget.preview == _HelicopterPreview.flight;
    final flightStart = _flightStartedAt;
    final path = baseCampHelicopterFlightPath(
      assembly: widget.assembly,
      direction: widget.direction,
    );
    final flightElapsed = flightStart == null
        ? Duration.zero
        : _elapsed - flightStart;
    final progress = flightStart == null
        ? 0.0
        : (flightElapsed.inMicroseconds / path.duration.inMicroseconds).clamp(
            0.0,
            1.0,
          );
    final left = flight ? path.leftAt(progress) : widget.testPosition.dx;
    final top = flight
        ? math.max(mapSize.height * .1, -path.visualBounds.top)
        : widget.testPosition.dy;
    final animateRotors = widget.flightRunId != null || widget.rotorsOn;
    final elapsed = _elapsed;
    final mainFrame = animateRotors
        ? baseCampHelicopterFrameIndex(
            elapsed: elapsed,
            frameDurationMs: widget.assembly.mainFrameMs,
            frameCount: baseCampHelicopterMainRotorAssets.length,
          )
        : widget.selectedMainFrame;
    final tailFrame = animateRotors
        ? baseCampHelicopterFrameIndex(
            elapsed: elapsed,
            frameDurationMs: widget.assembly.tailFrameMs,
            frameCount: baseCampHelicopterTailRotorAssets.length,
          )
        : widget.selectedTailFrame;
    final sprite = DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(
          color: widget.interaction == _HelicopterInteraction.partEdit
              ? const Color(0xAA68E8F2)
              : Colors.transparent,
        ),
      ),
      child: BaseCampHelicopterSprite(
        direction: widget.direction,
        mainRotorFrame: mainFrame,
        tailRotorFrame: tailFrame,
        assembly: widget.assembly,
        showMainRotor: widget.mainVisible,
        showTailRotor: widget.tailVisible,
        pitchRadians: flight
            ? baseCampHelicopterSignedPitchRadians(
                direction: widget.direction,
                forwardPitchDegrees: widget.assembly.forwardPitchDegrees,
                elapsed: flightElapsed,
              )
            : 0,
      ),
    );
    return Positioned(
      key: const ValueKey('base-camp-helicopter-editor-preview'),
      left: left,
      top: top,
      width: width,
      height: height,
      child: IgnorePointer(child: sprite),
    );
  }
}

class _BaseCampWaterEditOverlayPainter extends CustomPainter {
  const _BaseCampWaterEditOverlayPainter(
    this.area,
    this.section,
    this.geometry,
  );

  final BaseCampWaterArea area;
  final _BaseCampEditorSection section;
  final BaseCampMapGeometry geometry;

  @override
  void paint(Canvas canvas, Size size) {
    Path pathFor(List<Offset> points, {bool close = true}) =>
        Path()
          ..addPolygon(points.map(geometry.artworkToViewport).toList(), close);
    final water = pathFor(area.mask);
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
        pathFor(area.shoreline, close: false),
        Paint()
          ..color = const Color(0xFFEAF1EA)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
    }
    if (section == _BaseCampEditorSection.exclusionMask) {
      for (final exclusion in area.exclusionMasks) {
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
      oldDelegate.area != area ||
      oldDelegate.section != section ||
      oldDelegate.geometry != geometry;
}

class _EditorDragHandle extends StatelessWidget {
  const _EditorDragHandle({
    super.key,
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
