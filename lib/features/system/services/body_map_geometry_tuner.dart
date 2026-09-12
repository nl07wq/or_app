import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum BodyMapGeometryShape {
  current,
  circle,
  ellipse,
  capsule,
  roundedRect,
  rect,
  diamond,
  heart,
}

class BodyMapGeometryComponent {
  const BodyMapGeometryComponent({
    required this.componentId,
    required this.shape,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.scaleX = 1,
    this.scaleY = 1,
    this.rotationDeg = 0,
    this.cornerRadius = 0,
  });

  final String componentId;
  final BodyMapGeometryShape shape;
  final double x, y, width, height, scaleX, scaleY, rotationDeg, cornerRadius;

  BodyMapGeometryComponent copyWith({
    BodyMapGeometryShape? shape,
    double? x,
    double? y,
    double? width,
    double? height,
    double? scaleX,
    double? scaleY,
    double? rotationDeg,
    double? cornerRadius,
  }) => BodyMapGeometryComponent(
    componentId: componentId,
    shape: shape ?? this.shape,
    x: x ?? this.x,
    y: y ?? this.y,
    width: width ?? this.width,
    height: height ?? this.height,
    scaleX: scaleX ?? this.scaleX,
    scaleY: scaleY ?? this.scaleY,
    rotationDeg: rotationDeg ?? this.rotationDeg,
    cornerRadius: cornerRadius ?? this.cornerRadius,
  );

  Map<String, Object> toJson() => {
    'componentId': componentId,
    'shape': shape.name,
    'x': x,
    'y': y,
    'width': width,
    'height': height,
    'scaleX': scaleX,
    'scaleY': scaleY,
    'rotationDeg': rotationDeg,
    'cornerRadius': cornerRadius,
  };

  factory BodyMapGeometryComponent.fromJson(Map<String, dynamic> json) =>
      BodyMapGeometryComponent(
        componentId: json['componentId'] as String,
        shape: BodyMapGeometryShape.values.firstWhere(
          (shape) => shape.name == json['shape'],
          orElse: () => BodyMapGeometryShape.current,
        ),
        x: (json['x'] as num).toDouble(),
        y: (json['y'] as num).toDouble(),
        width: (json['width'] as num).toDouble(),
        height: (json['height'] as num).toDouble(),
        scaleX: (json['scaleX'] as num?)?.toDouble() ?? 1,
        scaleY: (json['scaleY'] as num?)?.toDouble() ?? 1,
        rotationDeg: (json['rotationDeg'] as num?)?.toDouble() ?? 0,
        cornerRadius: (json['cornerRadius'] as num?)?.toDouble() ?? 0,
      );
}

extension BodyMapGeometryShapeLabel on BodyMapGeometryShape {
  String get label => switch (this) {
    BodyMapGeometryShape.current => 'CURRENT',
    BodyMapGeometryShape.circle => 'CIRCLE',
    BodyMapGeometryShape.ellipse => 'ELLIPSE',
    BodyMapGeometryShape.capsule => 'CAPSULE',
    BodyMapGeometryShape.roundedRect => 'ROUNDED_RECT',
    BodyMapGeometryShape.rect => 'RECT',
    BodyMapGeometryShape.diamond => 'DIAMOND',
    BodyMapGeometryShape.heart => 'HEART',
  };
}

class BodyMapGeometryDraft {
  const BodyMapGeometryDraft({
    required this.side,
    required this.regionId,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.shape = BodyMapGeometryShape.current,
    this.scaleX = 1,
    this.scaleY = 1,
    this.rotationDeg = 0,
    this.cornerRadius = 0,
    this.mirrorLinked = true,
    this.locked = false,
    this.components = const [],
  });

  final String side;
  final String regionId;
  final BodyMapGeometryShape shape;
  final double x;
  final double y;
  final double width;
  final double height;
  final double scaleX;
  final double scaleY;
  final double rotationDeg;
  final double cornerRadius;
  final bool mirrorLinked;
  final bool locked;
  final List<BodyMapGeometryComponent> components;
  List<BodyMapGeometryComponent> get effectiveComponents => components.isEmpty
      ? [
          BodyMapGeometryComponent(
            componentId: 'component-0',
            shape: shape,
            x: x,
            y: y,
            width: width,
            height: height,
            scaleX: scaleX,
            scaleY: scaleY,
            rotationDeg: rotationDeg,
            cornerRadius: cornerRadius,
          ),
        ]
      : components;

  BodyMapGeometryDraft copyWith({
    BodyMapGeometryShape? shape,
    double? x,
    double? y,
    double? width,
    double? height,
    double? scaleX,
    double? scaleY,
    double? rotationDeg,
    double? cornerRadius,
    bool? mirrorLinked,
    bool? locked,
    List<BodyMapGeometryComponent>? components,
  }) => BodyMapGeometryDraft(
    side: side,
    regionId: regionId,
    shape: shape ?? this.shape,
    x: x ?? this.x,
    y: y ?? this.y,
    width: width ?? this.width,
    height: height ?? this.height,
    scaleX: scaleX ?? this.scaleX,
    scaleY: scaleY ?? this.scaleY,
    rotationDeg: rotationDeg ?? this.rotationDeg,
    cornerRadius: cornerRadius ?? this.cornerRadius,
    mirrorLinked: mirrorLinked ?? this.mirrorLinked,
    locked: locked ?? this.locked,
    components: components ?? this.components,
  );

  Map<String, Object> toJson() => {
    'side': side,
    'regionId': regionId,
    'shape': shape.name,
    'x': x,
    'y': y,
    'width': width,
    'height': height,
    'scaleX': scaleX,
    'scaleY': scaleY,
    'rotationDeg': rotationDeg,
    'cornerRadius': cornerRadius,
    'mirrorLinked': mirrorLinked,
    'locked': locked,
    if (components.isNotEmpty)
      'components': components.map((item) => item.toJson()).toList(),
  };

  factory BodyMapGeometryDraft.fromJson(Map<String, dynamic> json) {
    final shapeName = json['shape'] as String? ?? 'current';
    return BodyMapGeometryDraft(
      side: json['side'] as String,
      regionId: json['regionId'] as String,
      shape: BodyMapGeometryShape.values.firstWhere(
        (shape) => shape.name == shapeName,
        orElse: () => BodyMapGeometryShape.current,
      ),
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      width: (json['width'] as num).toDouble(),
      height: (json['height'] as num).toDouble(),
      scaleX: (json['scaleX'] as num?)?.toDouble() ?? 1,
      scaleY: (json['scaleY'] as num?)?.toDouble() ?? 1,
      rotationDeg: (json['rotationDeg'] as num?)?.toDouble() ?? 0,
      cornerRadius: (json['cornerRadius'] as num?)?.toDouble() ?? 0,
      mirrorLinked: json['mirrorLinked'] as bool? ?? true,
      locked: json['locked'] as bool? ?? false,
      components: (json['components'] as List<dynamic>? ?? const [])
          .map(
            (item) =>
                BodyMapGeometryComponent.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
    );
  }
}

/// Development-only, locally persisted geometry draft state for the SVG preview.
class BodyMapGeometryTunerController extends ChangeNotifier {
  static const maxComponents = 4;
  BodyMapGeometryTunerController({
    required this.baselineCommit,
    Future<SharedPreferences> Function()? preferencesLoader,
  }) : _preferencesLoader = preferencesLoader ?? SharedPreferences.getInstance;

  static const _storageKey = 'or_app.body_map_geometry_tuner.v1';

  final String baselineCommit;
  final Future<SharedPreferences> Function() _preferencesLoader;
  final Map<String, BodyMapGeometryDraft> _drafts = {};
  Map<String, BodyMapGeometryDraft> _restoredDrafts = {};
  Map<String, BodyMapGeometryDraft> _staleDrafts = {};
  Map<String, dynamic>? _staleSerialized;
  String? _staleBaselineCommit;

  static String keyFor(String side, String regionId) => '$side:$regionId';

  Iterable<BodyMapGeometryDraft> get drafts => _drafts.values;
  bool get hasStaleDraft => _staleSerialized != null;
  String? get staleBaselineCommit => _staleBaselineCommit;
  Iterable<BodyMapGeometryDraft> get staleDrafts => _staleDrafts.values;

  Future<void> load() async {
    try {
      final prefs = await _preferencesLoader();
      final raw = prefs.getString(_storageKey);
      if (raw == null) return;
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      _restoreStaleDraft(decoded['staleDraft'] as Map<String, dynamic>?);
      if (decoded['baselineCommit'] != baselineCommit) {
        _staleSerialized = decoded;
        _staleBaselineCommit = decoded['baselineCommit'] as String?;
        _staleDrafts = _decodeDrafts(decoded);
        notifyListeners();
        return;
      }
      _restoredDrafts = _decodeDrafts(decoded);
      notifyListeners();
    } catch (_) {
      // Debug data is intentionally disposable if an old version is malformed.
    }
  }

  BodyMapGeometryDraft ensureRegion({
    required String side,
    required String regionId,
    required Rect baseBounds,
    bool mirrorLinked = true,
    bool locked = false,
  }) {
    final key = keyFor(side, regionId);
    return _drafts.putIfAbsent(key, () {
      final restored = _restoredDrafts.remove(key);
      return restored ??
          BodyMapGeometryDraft(
            side: side,
            regionId: regionId,
            x: baseBounds.center.dx,
            y: baseBounds.center.dy,
            width: baseBounds.width,
            height: baseBounds.height,
            mirrorLinked: mirrorLinked,
            locked: locked,
          );
    });
  }

  BodyMapGeometryDraft? draftFor(String side, String regionId) =>
      _drafts[keyFor(side, regionId)] ??
      _restoredDrafts[keyFor(side, regionId)];

  Path pathFor({
    required String side,
    required String regionId,
    required Path basePath,
    bool mirrorLinked = true,
    bool locked = false,
  }) {
    final draft = ensureRegion(
      side: side,
      regionId: regionId,
      baseBounds: basePath.getBounds(),
      mirrorLinked: mirrorLinked,
      locked: locked,
    );
    final components = draft.effectiveComponents;
    var composite = _pathForComponent(basePath, components.first);
    for (final component in components.skip(1)) {
      final next = _pathForComponent(basePath, component);
      try {
        composite = Path.combine(PathOperation.union, composite, next);
      } catch (_) {
        composite.addPath(next, Offset.zero);
      }
    }
    return composite;
  }

  bool addComponent(String side, String regionId, BodyMapGeometryShape shape) {
    final draft = _drafts[keyFor(side, regionId)];
    if (draft == null ||
        draft.locked ||
        draft.effectiveComponents.length >= maxComponents) {
      return false;
    }
    final components = [...draft.effectiveComponents];
    final base = components.first;
    components.add(
      BodyMapGeometryComponent(
        componentId: 'component-${components.length}',
        shape: shape,
        x: base.x,
        y: base.y - 8,
        width: math.max(8, base.width * .6),
        height: math.max(8, base.height * .3),
        rotationDeg: base.rotationDeg,
      ),
    );
    update(draft.copyWith(components: components), mirror: true);
    return true;
  }

  bool duplicateComponent(String side, String regionId, int index) {
    final draft = _drafts[keyFor(side, regionId)];
    if (draft == null ||
        draft.locked ||
        draft.effectiveComponents.length >= maxComponents) {
      return false;
    }
    final components = [...draft.effectiveComponents];
    final source = components[index];
    components.add(source);
    components[components.length - 1] = BodyMapGeometryComponent(
      componentId: 'component-${components.length - 1}',
      shape: source.shape,
      x: source.x + 3,
      y: source.y - 3,
      width: source.width,
      height: source.height,
      scaleX: source.scaleX,
      scaleY: source.scaleY,
      rotationDeg: source.rotationDeg,
      cornerRadius: source.cornerRadius,
    );
    update(draft.copyWith(components: components), mirror: true);
    return true;
  }

  bool deleteComponent(String side, String regionId, int index) {
    final draft = _drafts[keyFor(side, regionId)];
    if (draft == null ||
        draft.locked ||
        draft.effectiveComponents.length <= 1) {
      return false;
    }
    final components = [...draft.effectiveComponents]..removeAt(index);
    update(draft.copyWith(components: _renumber(components)), mirror: true);
    return true;
  }

  void updateComponent(
    String side,
    String regionId,
    int index,
    BodyMapGeometryComponent component,
  ) {
    final draft = _drafts[keyFor(side, regionId)];
    if (draft == null || draft.locked) return;
    final components = [...draft.effectiveComponents];
    components[index] = component;
    update(draft.copyWith(components: components), mirror: true);
  }

  void update(BodyMapGeometryDraft draft, {bool mirror = true}) {
    _drafts[keyFor(draft.side, draft.regionId)] = draft;
    if (mirror && draft.mirrorLinked) {
      final oppositeId = _oppositeRegionId(draft.regionId);
      if (oppositeId != null) {
        final opposite = _drafts[keyFor(draft.side, oppositeId)];
        if (opposite != null && !opposite.locked) {
          _drafts[keyFor(draft.side, oppositeId)] = opposite.copyWith(
            shape: draft.shape,
            x: _mirrorX(draft.x),
            y: draft.y,
            width: draft.width,
            height: draft.height,
            scaleX: draft.scaleX,
            scaleY: draft.scaleY,
            rotationDeg: -draft.rotationDeg,
            cornerRadius: draft.cornerRadius,
            mirrorLinked: true,
            components: draft.effectiveComponents
                .map(
                  (component) => BodyMapGeometryComponent(
                    componentId: component.componentId,
                    shape: component.shape,
                    x: _mirrorX(component.x),
                    y: component.y,
                    width: component.width,
                    height: component.height,
                    scaleX: component.scaleX,
                    scaleY: component.scaleY,
                    rotationDeg: -component.rotationDeg,
                    cornerRadius: component.cornerRadius,
                  ),
                )
                .toList(),
          );
        }
      }
    }
    _save();
    notifyListeners();
  }

  void resetRegion(String side, String regionId) {
    _drafts.remove(keyFor(side, regionId));
    final opposite = _oppositeRegionId(regionId);
    if (opposite != null) _drafts.remove(keyFor(side, opposite));
    _save();
    notifyListeners();
  }

  void resetAll() {
    _drafts.clear();
    _restoredDrafts.clear();
    _staleDrafts = {};
    _staleSerialized = null;
    _staleBaselineCommit = null;
    _save();
    notifyListeners();
  }

  bool isChanged(BodyMapGeometryDraft draft, Rect baseBounds) {
    const epsilon = 0.0001;
    return draft.shape != BodyMapGeometryShape.current ||
        (draft.x - baseBounds.center.dx).abs() > epsilon ||
        (draft.y - baseBounds.center.dy).abs() > epsilon ||
        (draft.width - baseBounds.width).abs() > epsilon ||
        (draft.height - baseBounds.height).abs() > epsilon ||
        (draft.scaleX - 1).abs() > epsilon ||
        (draft.scaleY - 1).abs() > epsilon ||
        draft.rotationDeg.abs() > epsilon ||
        draft.cornerRadius.abs() > epsilon ||
        draft.locked;
  }

  String copyRegion(BodyMapGeometryDraft draft) {
    if (draft.effectiveComponents.length > 1) {
      final buffer = StringBuffer()
        ..writeln('BODY MAP GEOMETRY FEEDBACK')
        ..writeln()
        ..writeln('baselineCommit: $baselineCommit')
        ..writeln('side: ${draft.side.toUpperCase()}')
        ..writeln('region: ${regionNameFor(draft.regionId)}')
        ..writeln('regionId: ${draft.regionId}')
        ..writeln('shape: COMPOSITE')
        ..writeln('components:');
      for (final component in draft.effectiveComponents) {
        buffer
          ..writeln('- componentId: ${component.componentId}')
          ..writeln('  shape: ${component.shape.label}')
          ..write(_componentLines(component, indent: '  '));
      }
      return '${buffer.toString().trimRight()}\nlocked: ${draft.locked}';
    }
    final buffer = StringBuffer()
      ..writeln('BODY MAP GEOMETRY FEEDBACK')
      ..writeln()
      ..writeln('baselineCommit: $baselineCommit')
      ..writeln('side: ${draft.side.toUpperCase()}')
      ..writeln('region: ${regionNameFor(draft.regionId)}')
      ..writeln('regionId: ${draft.regionId}')
      ..writeln()
      ..writeln('shape: ${draft.shape.label}')
      ..writeln('mirrorLinked: ${draft.mirrorLinked}')
      ..writeln()
      ..writeln('parameters:')
      ..write(_parameterLines(draft, indent: '  '))
      ..writeln('locked: ${draft.locked}');
    final opposite = _oppositeRegionId(draft.regionId);
    if (opposite != null && draft.mirrorLinked) {
      buffer
        ..writeln()
        ..writeln('opposite:')
        ..writeln('  regionId: $opposite')
        ..writeln('  mirrorOf: ${draft.regionId}');
    }
    return buffer.toString().trimRight();
  }

  String copyAllChanges(Map<String, Rect> baseBoundsByKey) {
    final changed = _drafts.values.where((draft) {
      final bounds = baseBoundsByKey[keyFor(draft.side, draft.regionId)];
      return bounds != null && isChanged(draft, bounds);
    }).toList()..sort(_compareDrafts);
    final buffer = StringBuffer()
      ..writeln('BODY MAP GEOMETRY FEEDBACK')
      ..writeln()
      ..writeln('baselineCommit: $baselineCommit')
      ..writeln()
      ..writeln('changedRegions:');
    if (changed.isEmpty) {
      buffer.writeln('  []');
    } else {
      for (final draft in changed) {
        buffer
          ..writeln('- side: ${draft.side.toUpperCase()}')
          ..writeln('  region: ${regionNameFor(draft.regionId)}')
          ..writeln('  regionId: ${draft.regionId}')
          ..writeln('  shape: ${draft.shape.label}')
          ..writeln('  mirrorLinked: ${draft.mirrorLinked}')
          ..write(_parameterLines(draft, indent: '  '))
          ..writeln('  locked: ${draft.locked}');
      }
    }
    return buffer.toString().trimRight();
  }

  String copyStaleDraft() {
    final baseline = _staleBaselineCommit ?? 'UNKNOWN';
    final buffer = StringBuffer()
      ..writeln('BODY MAP GEOMETRY FEEDBACK — STALE DRAFT')
      ..writeln()
      ..writeln('draftBaselineCommit: $baseline')
      ..writeln('currentBaselineCommit: $baselineCommit')
      ..writeln()
      ..writeln('changedRegions:');
    final stale = _staleDrafts.values.toList()..sort(_compareDrafts);
    for (final draft in stale) {
      buffer
        ..writeln('- side: ${draft.side.toUpperCase()}')
        ..writeln('  region: ${regionNameFor(draft.regionId)}')
        ..writeln('  regionId: ${draft.regionId}')
        ..writeln('  shape: ${draft.shape.label}')
        ..write(_parameterLines(draft, indent: '  '));
    }
    return buffer.toString().trimRight();
  }

  static Path _pathForComponent(
    Path basePath,
    BodyMapGeometryComponent component,
  ) {
    if (component.shape != BodyMapGeometryShape.current) {
      return _primitivePath(component);
    }
    final base = basePath.getBounds();
    final scaleX = (component.width / base.width) * component.scaleX;
    final scaleY = (component.height / base.height) * component.scaleY;
    final radians = component.rotationDeg * math.pi / 180;
    final cos = math.cos(radians);
    final sin = math.sin(radians);
    final cx = base.center.dx;
    final cy = base.center.dy;
    final matrix = Float64List.fromList(<double>[
      scaleX * cos,
      scaleX * sin,
      0,
      0,
      -scaleY * sin,
      scaleY * cos,
      0,
      0,
      0,
      0,
      1,
      0,
      component.x - scaleX * cos * cx + scaleY * sin * cy,
      component.y - scaleX * sin * cx - scaleY * cos * cy,
      0,
      1,
    ]);
    return basePath.transform(matrix);
  }

  static Path _primitivePath(BodyMapGeometryComponent draft) {
    final width = math.max(0.1, draft.width * draft.scaleX);
    final height = math.max(0.1, draft.height * draft.scaleY);
    final rect = Rect.fromCenter(
      center: Offset(draft.x, draft.y),
      width: width,
      height: height,
    );
    final path = Path();
    switch (draft.shape) {
      case BodyMapGeometryShape.current:
        throw StateError('CURRENT requires a base SVG path.');
      case BodyMapGeometryShape.circle:
        final size = math.min(width, height);
        path.addOval(
          Rect.fromCenter(center: rect.center, width: size, height: size),
        );
      case BodyMapGeometryShape.ellipse:
        path.addOval(rect);
      case BodyMapGeometryShape.capsule:
        path.addRRect(
          RRect.fromRectAndRadius(
            rect,
            Radius.circular(math.min(width, height) / 2),
          ),
        );
      case BodyMapGeometryShape.roundedRect:
        path.addRRect(
          RRect.fromRectAndRadius(
            rect,
            Radius.circular(
              draft.cornerRadius > 0
                  ? math.min(draft.cornerRadius, math.min(width, height) / 2)
                  : math.min(width, height) * .2,
            ),
          ),
        );
      case BodyMapGeometryShape.rect:
        path.addRect(rect);
      case BodyMapGeometryShape.diamond:
        path
          ..moveTo(rect.center.dx, rect.top)
          ..lineTo(rect.right, rect.center.dy)
          ..lineTo(rect.center.dx, rect.bottom)
          ..lineTo(rect.left, rect.center.dy)
          ..close();
      case BodyMapGeometryShape.heart:
        final cx = rect.center.dx;
        final cy = rect.center.dy;
        path
          ..moveTo(cx, rect.bottom)
          ..cubicTo(
            rect.left,
            cy + height * .12,
            rect.left,
            rect.top + height * .28,
            cx - width * .25,
            rect.top + height * .22,
          )
          ..cubicTo(
            cx - width * .08,
            rect.top - height * .02,
            cx,
            rect.top + height * .15,
            cx,
            rect.top + height * .28,
          )
          ..cubicTo(
            cx,
            rect.top + height * .15,
            cx + width * .08,
            rect.top - height * .02,
            cx + width * .25,
            rect.top + height * .22,
          )
          ..cubicTo(
            rect.right,
            rect.top + height * .28,
            rect.right,
            cy + height * .12,
            cx,
            rect.bottom,
          )
          ..close();
    }
    if (draft.rotationDeg == 0) return path;
    final radians = draft.rotationDeg * math.pi / 180;
    final cos = math.cos(radians);
    final sin = math.sin(radians);
    return path.transform(
      Float64List.fromList(<double>[
        cos,
        sin,
        0,
        0,
        -sin,
        cos,
        0,
        0,
        0,
        0,
        1,
        0,
        rect.center.dx - cos * rect.center.dx + sin * rect.center.dy,
        rect.center.dy - sin * rect.center.dx - cos * rect.center.dy,
        0,
        1,
      ]),
    );
  }

  static List<BodyMapGeometryComponent> _renumber(
    List<BodyMapGeometryComponent> items,
  ) => [
    for (var i = 0; i < items.length; i++)
      BodyMapGeometryComponent(
        componentId: 'component-$i',
        shape: items[i].shape,
        x: items[i].x,
        y: items[i].y,
        width: items[i].width,
        height: items[i].height,
        scaleX: items[i].scaleX,
        scaleY: items[i].scaleY,
        rotationDeg: items[i].rotationDeg,
        cornerRadius: items[i].cornerRadius,
      ),
  ];

  Future<void> _save() async {
    try {
      final prefs = await _preferencesLoader();
      await prefs.setString(
        _storageKey,
        jsonEncode({
          'baselineCommit': baselineCommit,
          'drafts': _drafts.values.map((draft) => draft.toJson()).toList(),
          if (_staleSerialized != null) 'staleDraft': _staleSerialized,
        }),
      );
    } catch (_) {
      // Preview tests and unsupported platforms retain an in-memory draft.
    }
  }

  Map<String, BodyMapGeometryDraft> _decodeDrafts(Map<String, dynamic> json) {
    final items = json['drafts'] as List<dynamic>? ?? const [];
    return Map.fromEntries(
      items.map((item) {
        final draft = BodyMapGeometryDraft.fromJson(
          item as Map<String, dynamic>,
        );
        return MapEntry(keyFor(draft.side, draft.regionId), draft);
      }),
    );
  }

  void _restoreStaleDraft(Map<String, dynamic>? stale) {
    if (stale == null) return;
    _staleSerialized = stale;
    _staleBaselineCommit = stale['baselineCommit'] as String?;
    _staleDrafts = _decodeDrafts(stale);
  }

  static String? _oppositeRegionId(String regionId) {
    if (regionId.endsWith('-left')) {
      return '${regionId.substring(0, regionId.length - 5)}-right';
    }
    if (regionId.endsWith('-right')) {
      return '${regionId.substring(0, regionId.length - 6)}-left';
    }
    return null;
  }

  static double _mirrorX(double x) => 200 - x;

  static int _compareDrafts(BodyMapGeometryDraft a, BodyMapGeometryDraft b) {
    const order = <String>[
      'front-shoulder',
      'front-chest',
      'front-core',
      'front-biceps',
      'front-forearm',
      'front-quadriceps',
      'back-shoulder',
      'back-trapezius',
      'back-lats',
      'back-triceps',
      'back-forearm',
      'back-glutes',
      'back-hamstrings',
      'back-calves',
    ];
    int index(BodyMapGeometryDraft draft) {
      final stem = draft.regionId.replaceAll(RegExp(r'-(left|right)$'), '');
      return order.indexOf(stem);
    }

    final compare = index(a).compareTo(index(b));
    return compare != 0 ? compare : a.regionId.compareTo(b.regionId);
  }

  static String regionNameFor(String regionId) {
    if (regionId.contains('shoulder')) return 'DELTOID';
    if (regionId.contains('chest')) return 'CHEST';
    if (regionId.contains('core')) return 'CORE';
    if (regionId.contains('biceps')) return 'BICEPS';
    if (regionId.contains('triceps')) return 'TRICEPS';
    if (regionId.contains('forearm')) return 'FOREARM';
    if (regionId.contains('quadriceps')) return 'QUADRICEPS';
    if (regionId.contains('trapezius')) return 'TRAPEZIUS';
    if (regionId.contains('lats')) return 'LATS';
    if (regionId.contains('glute')) return 'GLUTES';
    if (regionId.contains('hamstring')) return 'HAMSTRINGS';
    if (regionId.contains('calf')) return 'CALVES';
    return regionId.toUpperCase();
  }

  static String _parameterLines(
    BodyMapGeometryDraft draft, {
    required String indent,
  }) {
    String value(double number) => number.toStringAsFixed(2);
    return '${indent}x: ${value(draft.x)}\n'
        '${indent}y: ${value(draft.y)}\n'
        '${indent}width: ${value(draft.width)}\n'
        '${indent}height: ${value(draft.height)}\n'
        '${indent}scaleX: ${value(draft.scaleX)}\n'
        '${indent}scaleY: ${value(draft.scaleY)}\n'
        '${indent}rotationDeg: ${value(draft.rotationDeg)}\n'
        '${indent}cornerRadius: ${value(draft.cornerRadius)}\n';
  }

  static String _componentLines(
    BodyMapGeometryComponent component, {
    required String indent,
  }) {
    String value(double number) => number.toStringAsFixed(2);
    return '${indent}x: ${value(component.x)}\n${indent}y: ${value(component.y)}\n'
        '${indent}width: ${value(component.width)}\n${indent}height: ${value(component.height)}\n'
        '${indent}scaleX: ${value(component.scaleX)}\n${indent}scaleY: ${value(component.scaleY)}\n'
        '${indent}rotationDeg: ${value(component.rotationDeg)}\n${indent}cornerRadius: ${value(component.cornerRadius)}\n';
  }
}
