import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'widgets/base_camp_map.dart';

/// The single persisted source for BASE CAMP map calibration.  Normal map
/// rendering and the developer editor deliberately share this model so a
/// saved edit cannot diverge from hit testing or walker placement.
@immutable
class BaseCampMapConfiguration {
  const BaseCampMapConfiguration({
    required this.routes,
    required this.facilityOutlines,
    required this.objects,
    this.soldierScale = 1,
  });

  static const schemaVersion = 2;
  static const mapId = 'base-camp-map-v2';

  final Map<String, List<Offset>> routes;
  final Map<String, List<Offset>> facilityOutlines;
  final Map<String, BaseCampMapObject> objects;
  final double soldierScale;

  static const soldierScaleFull = 1.0;
  static const soldierScaleTwoThirds = 2 / 3;
  static const soldierScaleHalf = .5;

  factory BaseCampMapConfiguration.defaults() => BaseCampMapConfiguration(
    routes: <String, List<Offset>>{
      'route-a': const <Offset>[
        Offset(247, 348),
        Offset(316, 319),
        Offset(397, 289),
        Offset(462, 255),
        Offset(514, 229),
      ],
      for (final route in baseCampWalkerRoutes)
        route.id: List<Offset>.of(route.sourcePoints),
    },
    facilityOutlines: <String, List<Offset>>{
      for (final facility in baseCampFacilities)
        facility.id: List<Offset>.of(facility.outline()),
    },
    objects: <String, BaseCampMapObject>{
      for (final object in baseCampDefaultObjects) object.id: object,
    },
  );

  BaseCampMapConfiguration copyWith({
    Map<String, List<Offset>>? routes,
    Map<String, List<Offset>>? facilityOutlines,
    Map<String, BaseCampMapObject>? objects,
    double? soldierScale,
  }) => BaseCampMapConfiguration(
    routes: routes ?? this.routes,
    facilityOutlines: facilityOutlines ?? this.facilityOutlines,
    objects: objects ?? this.objects,
    soldierScale: soldierScale ?? this.soldierScale,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'schemaVersion': schemaVersion,
    'mapId': mapId,
    'imageWidth': baseCampMapSourceSize.width,
    'imageHeight': baseCampMapSourceSize.height,
    'routes': _encodePointGroups(routes),
    'facilityOutlines': _encodePointGroups(facilityOutlines),
    'objects': objects.map((id, object) => MapEntry(id, object.toJson())),
    'soldierScale': soldierScale,
  };

  String encode() => jsonEncode(toJson());

  static BaseCampMapConfiguration? tryParse(Object? raw) {
    if (raw is! Map) return null;
    if (raw['schemaVersion'] == 1 && raw['mapId'] == 'base-camp-map-v1') {
      return _migrateV1(raw);
    }
    if (raw['schemaVersion'] != schemaVersion || raw['mapId'] != mapId) {
      return null;
    }
    final width = _finite(raw['imageWidth']);
    final height = _finite(raw['imageHeight']);
    if (width != baseCampMapSourceSize.width ||
        height != baseCampMapSourceSize.height) {
      return null;
    }
    final routes = _decodePointGroups(
      raw['routes'],
      const <String>['route-a', 'route-b', 'route-c'],
      normalized: false,
      minimumPoints: 2,
    );
    final outlines = _decodePointGroups(
      raw['facilityOutlines'],
      baseCampFacilities.map((facility) => facility.id).toList(growable: false),
      normalized: true,
      minimumPoints: 3,
    );
    final scale = _finite(raw['soldierScale']);
    final objects = BaseCampMapObject.decodeAll(raw['objects']);
    if (routes == null ||
        outlines == null ||
        objects == null ||
        scale == null ||
        scale <= 0) {
      return null;
    }
    return BaseCampMapConfiguration(
      routes: routes,
      facilityOutlines: outlines,
      objects: objects,
      // V1 exposed the accidental 2/1 control. Keep every valid route and
      // building edit, but migrate only that obsolete multiplier to 1/1.
      soldierScale: _normaliseSoldierScale(scale),
    );
  }

  static BaseCampMapConfiguration? _migrateV1(Map raw) {
    final legacyRoutes = _decodePointGroups(
      raw['routes'],
      const <String>['route-a', 'route-b', 'route-c'],
      normalized: false,
      minimumPoints: 2,
    );
    final outlines = _decodePointGroups(
      raw['facilityOutlines'],
      baseCampFacilities.map((facility) => facility.id).toList(growable: false),
      normalized: true,
      minimumPoints: 3,
    );
    final scale = _finite(raw['soldierScale']);
    if (legacyRoutes == null ||
        outlines == null ||
        scale == null ||
        scale <= 0) {
      return null;
    }
    // Preserve every editable source point rather than discarding calibration.
    // The one-pixel source-height difference is converted through normalized Y.
    final routes = legacyRoutes.map(
      (id, points) => MapEntry(
        id,
        points.map((point) => Offset(point.dx, point.dy / 719 * 720)).toList(),
      ),
    );
    return BaseCampMapConfiguration(
      routes: routes,
      facilityOutlines: outlines,
      objects: <String, BaseCampMapObject>{
        for (final object in baseCampDefaultObjects) object.id: object,
      },
      soldierScale: _normaliseSoldierScale(scale),
    );
  }

  static Map<String, Object?> _encodePointGroups(
    Map<String, List<Offset>> groups,
  ) => groups.map(
    (key, points) => MapEntry(
      key,
      points
          .map((point) => <String, double>{'x': point.dx, 'y': point.dy})
          .toList(growable: false),
    ),
  );

  static Map<String, List<Offset>>? _decodePointGroups(
    Object? raw,
    List<String> expectedIds, {
    required bool normalized,
    required int minimumPoints,
  }) {
    if (raw is! Map || raw.length != expectedIds.length) return null;
    final result = <String, List<Offset>>{};
    for (final id in expectedIds) {
      final values = raw[id];
      if (values is! List || values.length < minimumPoints) return null;
      final points = <Offset>[];
      for (final value in values) {
        if (value is! Map) return null;
        final x = _finite(value['x']);
        final y = _finite(value['y']);
        if (x == null || y == null) return null;
        if (normalized) {
          if (x < 0 || x > 1 || y < 0 || y > 1) return null;
        } else if (x < 0 ||
            x > baseCampMapSourceSize.width ||
            y < 0 ||
            y > baseCampMapSourceSize.height) {
          return null;
        }
        points.add(Offset(x, y));
      }
      result[id] = points;
    }
    return result;
  }

  static double? _finite(Object? value) =>
      value is num && value.isFinite ? value.toDouble() : null;

  static double _normaliseSoldierScale(double value) {
    if ((value - 2).abs() < .0001) return soldierScaleFull;
    if ((value - soldierScaleHalf).abs() < .0001) return soldierScaleHalf;
    if ((value - soldierScaleTwoThirds).abs() < .0001) {
      return soldierScaleTwoThirds;
    }
    return soldierScaleFull;
  }
}

@immutable
class BaseCampMapObject {
  const BaseCampMapObject({
    required this.id,
    required this.assetId,
    required this.position,
    this.scale = 1,
    this.rotation = 0,
    this.anchor = const Offset(.5, 1),
    this.zIndex = 0,
    this.visible = true,
    this.animationRate = 1,
  });

  final String id, assetId;
  final Offset position, anchor;
  final double scale, rotation, animationRate;
  final int zIndex;
  final bool visible;

  BaseCampMapObject copyWith({
    String? assetId,
    Offset? position,
    double? scale,
    double? rotation,
    Offset? anchor,
    int? zIndex,
    bool? visible,
    double? animationRate,
  }) => BaseCampMapObject(
    id: id,
    assetId: assetId ?? this.assetId,
    position: position ?? this.position,
    scale: scale ?? this.scale,
    rotation: rotation ?? this.rotation,
    anchor: anchor ?? this.anchor,
    zIndex: zIndex ?? this.zIndex,
    visible: visible ?? this.visible,
    animationRate: animationRate ?? this.animationRate,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'assetId': assetId,
    'x': position.dx,
    'y': position.dy,
    'scale': scale,
    'rotation': rotation,
    'anchorX': anchor.dx,
    'anchorY': anchor.dy,
    'zIndex': zIndex,
    'visible': visible,
    'animationRate': animationRate,
  };

  static Map<String, BaseCampMapObject>? decodeAll(Object? raw) {
    if (raw is! Map || raw.length != baseCampDefaultObjects.length) return null;
    final result = <String, BaseCampMapObject>{};
    for (final fallback in baseCampDefaultObjects) {
      final json = raw[fallback.id];
      if (json is! Map ||
          json['id'] != fallback.id ||
          json['assetId'] is! String) {
        return null;
      }
      double? finite(String key) =>
          json[key] is num && (json[key] as num).isFinite
          ? (json[key] as num).toDouble()
          : null;
      final x = finite('x');
      final y = finite('y');
      final scale = finite('scale');
      final rotation = finite('rotation');
      final ax = finite('anchorX');
      final ay = finite('anchorY');
      final rate = finite('animationRate');
      final z = json['zIndex'];
      final visible = json['visible'];
      if (x == null ||
          y == null ||
          scale == null ||
          rotation == null ||
          ax == null ||
          ay == null ||
          rate == null ||
          z is! int ||
          visible is! bool ||
          x < 0 ||
          x > 1280 ||
          y < 0 ||
          y > 720 ||
          scale < .1 ||
          scale > 4 ||
          ax < 0 ||
          ax > 1 ||
          ay < 0 ||
          ay > 1 ||
          rate <= 0 ||
          rate > 2) {
        return null;
      }
      result[fallback.id] = BaseCampMapObject(
        id: fallback.id,
        assetId: json['assetId'] as String,
        position: Offset(x, y),
        scale: scale,
        rotation: rotation,
        anchor: Offset(ax, ay),
        zIndex: z,
        visible: visible,
        animationRate: rate,
      );
    }
    return result;
  }
}

const baseCampDefaultObjects = <BaseCampMapObject>[
  BaseCampMapObject(
    id: 'status',
    assetId: 'status',
    position: Offset(300, 300),
    scale: .75,
    zIndex: 1,
    animationRate: .5,
  ),
  BaseCampMapObject(
    id: 'food',
    assetId: 'food',
    position: Offset(625, 280),
    scale: .35,
    zIndex: 2,
  ),
  BaseCampMapObject(
    id: 'training',
    assetId: 'training',
    position: Offset(1030, 305),
    scale: .75,
    zIndex: 3,
  ),
  BaseCampMapObject(
    id: 'activity',
    assetId: 'activity',
    position: Offset(300, 560),
    scale: .8,
    zIndex: 4,
  ),
  BaseCampMapObject(
    id: 'command-center',
    assetId: 'command-center',
    position: Offset(930, 585),
    scale: .35,
    zIndex: 5,
  ),
  BaseCampMapObject(
    id: 'flag',
    assetId: 'flag',
    position: Offset(1170, 600),
    scale: .22,
    zIndex: 6,
  ),
];

class BaseCampMapConfigurationController
    extends ValueNotifier<BaseCampMapConfiguration> {
  BaseCampMapConfigurationController({
    Future<SharedPreferences> Function()? preferencesLoader,
  }) : _preferencesLoader = preferencesLoader ?? SharedPreferences.getInstance,
       super(BaseCampMapConfiguration.defaults());

  static const storageKey = 'base_camp_map_editor_v1';
  final Future<SharedPreferences> Function() _preferencesLoader;
  bool _loaded = false;

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    final raw = (await _preferencesLoader()).getString(storageKey);
    if (raw == null) return;
    try {
      final restored = BaseCampMapConfiguration.tryParse(jsonDecode(raw));
      if (restored != null) {
        value = restored;
        // Persist the V1 2/1 -> 1/1 migration immediately, without changing
        // any route or facility-outline payload.
        if (restored.encode() != raw) {
          await (await _preferencesLoader()).setString(
            storageKey,
            restored.encode(),
          );
        }
      }
    } on FormatException {
      // Invalid local calibration intentionally falls back to the audited defaults.
    }
  }

  Future<void> save(BaseCampMapConfiguration configuration) async {
    final normalised = BaseCampMapConfiguration.tryParse(
      configuration.toJson(),
    );
    if (normalised == null) {
      throw ArgumentError.value(
        configuration,
        'configuration',
        'Invalid Base Camp map configuration',
      );
    }
    value = normalised;
    await (await _preferencesLoader()).setString(
      storageKey,
      normalised.encode(),
    );
  }

  Future<void> resetToDefaults() => save(BaseCampMapConfiguration.defaults());

  @visibleForTesting
  void resetForTesting(BaseCampMapConfiguration configuration) {
    _loaded = true;
    value = configuration;
  }
}

final baseCampMapConfigurationController = BaseCampMapConfigurationController();
