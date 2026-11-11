import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/startup_diagnostic.dart';
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
    this.foodSmokeOrigin = const Offset(.29, .26),
    this.smokeFx = const BaseCampSmokeFx(),
    required this.labels,
    required this.waterFx,
    this.compatibilityWaterFxV7 = const <String, BaseCampWaterFx>{},
    this.staticSoldiers = const <BaseCampStaticSoldier>[],
  });

  static const schemaVersion = 8;
  static const mapId = 'base-camp-map-v2';

  final Map<String, List<Offset>> routes;
  final Map<String, List<Offset>> facilityOutlines;
  final Map<String, BaseCampMapObject> objects;
  final double soldierScale;

  /// Normalized within the transformed FOOD object bounds. The initial value
  /// follows the supplied acceptance reference and remains editor-adjustable.
  final Offset foodSmokeOrigin;
  final BaseCampSmokeFx smokeFx;
  final Map<String, BaseCampFacilityLabel> labels;
  final Map<String, BaseCampWaterFx> waterFx;
  final Map<String, BaseCampWaterFx> compatibilityWaterFxV7;
  final List<BaseCampStaticSoldier> staticSoldiers;

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
    labels: <String, BaseCampFacilityLabel>{
      for (final facility in baseCampFacilities)
        facility.id: BaseCampFacilityLabel.defaultsFor(facility.id),
    },
    waterFx: BaseCampWaterFx.defaults(),
  );

  BaseCampMapConfiguration copyWith({
    Map<String, List<Offset>>? routes,
    Map<String, List<Offset>>? facilityOutlines,
    Map<String, BaseCampMapObject>? objects,
    double? soldierScale,
    Offset? foodSmokeOrigin,
    BaseCampSmokeFx? smokeFx,
    Map<String, BaseCampFacilityLabel>? labels,
    Map<String, BaseCampWaterFx>? waterFx,
    Map<String, BaseCampWaterFx>? compatibilityWaterFxV7,
    List<BaseCampStaticSoldier>? staticSoldiers,
  }) => BaseCampMapConfiguration(
    routes: routes ?? this.routes,
    facilityOutlines: facilityOutlines ?? this.facilityOutlines,
    objects: objects ?? this.objects,
    soldierScale: soldierScale ?? this.soldierScale,
    foodSmokeOrigin: foodSmokeOrigin ?? this.foodSmokeOrigin,
    smokeFx: smokeFx ?? this.smokeFx,
    labels: labels ?? this.labels,
    waterFx: waterFx ?? this.waterFx,
    compatibilityWaterFxV7:
        compatibilityWaterFxV7 ?? this.compatibilityWaterFxV7,
    staticSoldiers: staticSoldiers ?? this.staticSoldiers,
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
    'foodSmokeOrigin': <String, double>{
      'x': foodSmokeOrigin.dx,
      'y': foodSmokeOrigin.dy,
    },
    'smokeFx': smokeFx.toJson(),
    'labels': labels.map((id, label) => MapEntry(id, label.toJson())),
    'waterFx': waterFx.map((id, effect) => MapEntry(id, effect.toJson())),
    if (compatibilityWaterFxV7.isNotEmpty)
      'compatibilityWaterFxV7': compatibilityWaterFxV7.map(
        (id, effect) => MapEntry(id, effect.toJson()),
      ),
    'staticSoldiers': staticSoldiers.map((item) => item.toJson()).toList(),
  };

  String encode() => jsonEncode(toJson());

  static BaseCampMapConfiguration? tryParse(Object? raw) {
    if (raw is! Map) return null;
    if (raw['schemaVersion'] == 1 && raw['mapId'] == 'base-camp-map-v1') {
      return _migrateV1(raw);
    }
    if (raw['schemaVersion'] == 2 && raw['mapId'] == mapId) {
      return _migrateV2(raw);
    }
    if (raw['schemaVersion'] == 3 && raw['mapId'] == mapId) {
      return _migrateV3(raw);
    }
    if (raw['schemaVersion'] == 4 && raw['mapId'] == mapId) {
      return _migrateV4(raw);
    }
    if (raw['schemaVersion'] == 5 && raw['mapId'] == mapId) {
      return _migrateV5(raw);
    }
    if (raw['schemaVersion'] == 6 && raw['mapId'] == mapId) {
      return _migrateV6(raw);
    }
    if (raw['schemaVersion'] == 7 && raw['mapId'] == mapId) {
      return _migrateV7(raw);
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
    final smokeOrigin = _decodeNormalizedPoint(raw['foodSmokeOrigin']);
    final objects = BaseCampMapObject.decodeAll(raw['objects']);
    final smokeFx = BaseCampSmokeFx.tryParse(raw['smokeFx']);
    final labels = BaseCampFacilityLabel.decodeAll(raw['labels']);
    final waterFx = BaseCampWaterFx.decodeAll(raw['waterFx']);
    final compatibilityWaterFxV7 = raw['compatibilityWaterFxV7'] == null
        ? const <String, BaseCampWaterFx>{}
        : BaseCampWaterFx.decodeLegacy(raw['compatibilityWaterFxV7']);
    final staticSoldiers = BaseCampStaticSoldier.decodeAll(
      raw['staticSoldiers'],
    );
    if (routes == null ||
        outlines == null ||
        objects == null ||
        scale == null ||
        smokeOrigin == null ||
        smokeFx == null ||
        labels == null ||
        waterFx == null ||
        compatibilityWaterFxV7 == null ||
        staticSoldiers == null ||
        scale <= 0) {
      return null;
    }
    final safeWaterFx = _replaceUntouchedLegacyV8Areas(
      waterFx,
      compatibilityWaterFxV7,
    );
    return BaseCampMapConfiguration(
      routes: routes,
      facilityOutlines: outlines,
      objects: objects,
      // V1 exposed the accidental 2/1 control. Keep every valid route and
      // building edit, but migrate only that obsolete multiplier to 1/1.
      soldierScale: _normaliseSoldierScale(scale),
      foodSmokeOrigin: smokeOrigin,
      smokeFx: smokeFx,
      labels: labels,
      waterFx: safeWaterFx,
      compatibilityWaterFxV7: compatibilityWaterFxV7,
      staticSoldiers: staticSoldiers,
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
      labels: <String, BaseCampFacilityLabel>{
        for (final facility in baseCampFacilities)
          facility.id: BaseCampFacilityLabel.defaultsFor(facility.id),
      },
      waterFx: BaseCampWaterFx.defaults(),
    );
  }

  /// Corrects the historical FOOD/COMMAND CENTER identity registration once.
  /// The object transforms and image asset IDs remain exactly where users put
  /// them; only the facility identity bound to those placements is exchanged.
  static BaseCampMapConfiguration? _migrateV2(Map raw) {
    final v3 = Map<String, Object?>.from(raw)..['schemaVersion'] = 3;
    final objects = raw['objects'];
    final outlines = raw['facilityOutlines'];
    if (objects is! Map || outlines is! Map) return null;
    final correctedObjects = Map<Object?, Object?>.from(objects);
    final food = correctedObjects['food'];
    final commandCenter = correctedObjects['command-center'];
    if (food is! Map || commandCenter is! Map) return null;
    correctedObjects['food'] = <Object?, Object?>{
      ...Map<Object?, Object?>.from(commandCenter),
      'id': 'food',
    };
    correctedObjects['command-center'] = <Object?, Object?>{
      ...Map<Object?, Object?>.from(food),
      'id': 'command-center',
    };
    final status = correctedObjects['status'];
    if (status is! Map) return null;
    // The approved transparent STATUS animation supersedes only the bundled
    // STATUS reference.  Its calibrated transform remains untouched, and no
    // other imported asset reference is changed.
    correctedObjects['status'] = <Object?, Object?>{
      ...Map<Object?, Object?>.from(status),
      'id': 'status',
      'assetId': 'status',
    };
    final correctedOutlines = Map<Object?, Object?>.from(outlines);
    correctedOutlines['food'] = outlines['command-center'];
    correctedOutlines['command-center'] = outlines['food'];
    v3['objects'] = correctedObjects;
    v3['facilityOutlines'] = correctedOutlines;
    return tryParse(v3);
  }

  static BaseCampMapConfiguration? _migrateV3(Map raw) {
    final v4 = Map<String, Object?>.from(raw)
      ..['schemaVersion'] = schemaVersion
      ..['foodSmokeOrigin'] = const <String, double>{'x': .29, 'y': .26};
    return tryParse(v4);
  }

  static BaseCampMapConfiguration? _migrateV4(Map raw) {
    final defaults = BaseCampMapConfiguration.defaults();
    final v5 = Map<String, Object?>.from(raw)
      ..['schemaVersion'] = schemaVersion
      ..['smokeFx'] = defaults.smokeFx.toJson()
      ..['labels'] = defaults.labels.map(
        (id, label) => MapEntry(id, label.toJson()),
      )
      ..['waterFx'] = defaults.waterFx.map(
        (id, effect) => MapEntry(id, effect.toJson()),
      )
      ..['staticSoldiers'] = const <Object?>[];
    return tryParse(v5);
  }

  /// V5 water points were in the 1280×720 legacy scene. The artwork became
  /// square, so only water calibration moves to artwork coordinates; routes,
  /// facilities and objects retain their durable source coordinates.
  static BaseCampMapConfiguration? _migrateV5(Map raw) {
    final water = raw['waterFx'];
    if (water is! Map) return null;
    Offset convert(Offset point) => Offset(
      point.dx / 1280 * baseCampMapArtworkSize.width,
      point.dy / 720 * baseCampMapArtworkSize.height,
    );
    final converted = <Object?, Object?>{};
    for (final entry in water.entries) {
      if (entry.key is! String || entry.value is! Map) return null;
      final item = Map<Object?, Object?>.from(entry.value as Map);
      List<Object?>? transformPoints(Object? value) {
        if (value is! List) return null;
        final result = <Object?>[];
        for (final rawPoint in value) {
          if (rawPoint is! Map ||
              rawPoint['x'] is! num ||
              rawPoint['y'] is! num) {
            return null;
          }
          final x = (rawPoint['x'] as num).toDouble();
          final y = (rawPoint['y'] as num).toDouble();
          if (!x.isFinite ||
              !y.isFinite ||
              x < 0 ||
              x > 1280 ||
              y < 0 ||
              y > 720) {
            return null;
          }
          final point = Offset(x, y);
          final next = convert(point);
          result.add(<String, double>{'x': next.dx, 'y': next.dy});
        }
        return result;
      }

      final shoreline = transformPoints(item['shoreline']);
      final mask = transformPoints(item['mask']);
      if (shoreline == null || mask == null) return null;
      final exclusions = item['exclusionMasks'];
      if (exclusions is! List) return null;
      final nextExclusions = <Object?>[];
      for (final polygon in exclusions) {
        final next = transformPoints(polygon);
        if (next == null) return null;
        nextExclusions.add(next);
      }
      item['shoreline'] = shoreline;
      item['mask'] = mask;
      item['exclusionMasks'] = nextExclusions;
      converted[entry.key] = item;
    }
    final v6 = Map<String, Object?>.from(raw)
      ..['schemaVersion'] = 6
      ..['waterFx'] = converted;
    return tryParse(v6);
  }

  /// V7 adds optional independent water areas. V6's single area remains the
  /// first effective area, so this migration never reconstructs or discards
  /// a user-drawn polygon.
  static BaseCampMapConfiguration? _migrateV6(Map raw) {
    final v7 = Map<String, Object?>.from(raw)..['schemaVersion'] = 7;
    return tryParse(v7);
  }

  /// V8 replaces the two map-era effect slots with one common WATER MASK.
  /// Legacy FX polygons are retained only as compatibility data: they were
  /// authored for the previous map and must never become editable water.
  static BaseCampMapConfiguration? _migrateV7(Map raw) {
    final legacy = BaseCampWaterFx.decodeLegacy(raw['waterFx']);
    if (legacy == null) return null;
    final areas = BaseCampWaterFx.defaults()['water']!.effectiveAreas;
    final parameters = legacy['rock-foam'] ?? legacy.values.first;
    final unified = parameters.copyWith(
      areas: areas,
      mask: areas.first.mask,
      shoreline: areas.first.shoreline,
      exclusionMasks: areas.first.exclusionMasks,
    );
    final v8 = Map<String, Object?>.from(raw)
      ..['schemaVersion'] = schemaVersion
      ..['waterFx'] = <String, Object?>{'water': unified.toJson()}
      ..['compatibilityWaterFxV7'] = legacy.map(
        (id, effect) => MapEntry(id, effect.toJson()),
      );
    return tryParse(v8);
  }

  /// Repairs only the exact V8 payload generated by the first V7 migration.
  /// Any vertex-level user edit makes the geometry differ and is therefore
  /// preserved. This gives existing devices the approved four regions without
  /// guessing about, deleting, or overwriting user-authored V8 areas.
  static Map<String, BaseCampWaterFx> _replaceUntouchedLegacyV8Areas(
    Map<String, BaseCampWaterFx> waterFx,
    Map<String, BaseCampWaterFx> compatibility,
  ) {
    if (compatibility.isEmpty) return waterFx;
    final effect = waterFx['water'];
    if (effect == null) return waterFx;
    final legacyAreas = <BaseCampWaterArea>[
      for (final legacy in compatibility.values) ...legacy.effectiveAreas,
    ];
    if (!_sameWaterAreas(effect.effectiveAreas, legacyAreas)) return waterFx;
    final approved = BaseCampWaterFx.defaults()['water']!.effectiveAreas;
    return <String, BaseCampWaterFx>{
      'water': effect.copyWith(
        areas: approved,
        mask: approved.first.mask,
        shoreline: approved.first.shoreline,
        exclusionMasks: approved.first.exclusionMasks,
      ),
    };
  }

  static bool _sameWaterAreas(
    List<BaseCampWaterArea> left,
    List<BaseCampWaterArea> right,
  ) {
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index++) {
      final a = left[index], b = right[index];
      if (!_samePoints(a.mask, b.mask) ||
          !_samePoints(a.shoreline, b.shoreline) ||
          a.exclusionMasks.length != b.exclusionMasks.length) {
        return false;
      }
      for (var mask = 0; mask < a.exclusionMasks.length; mask++) {
        if (!_samePoints(a.exclusionMasks[mask], b.exclusionMasks[mask])) {
          return false;
        }
      }
    }
    return true;
  }

  static bool _samePoints(List<Offset> left, List<Offset> right) {
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index++) {
      if (left[index] != right[index]) return false;
    }
    return true;
  }

  static Offset? _decodeNormalizedPoint(Object? raw) {
    if (raw is! Map) return null;
    final x = _finite(raw['x']);
    final y = _finite(raw['y']);
    if (x == null || y == null || x < 0 || x > 1 || y < 0 || y > 1) {
      return null;
    }
    return Offset(x, y);
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
class BaseCampSmokeFx {
  const BaseCampSmokeFx({
    this.density = 3,
    this.opacity = .52,
    this.particleSize = 1,
    this.spread = 1,
    this.riseHeight = 1,
    this.lifetime = 1,
    this.drift = 1,
    this.softness = 1,
    this.turbulence = 1,
    this.contrast = 1,
    this.expansion = 1,
    this.visible = true,
  });
  final double density, opacity, particleSize, spread, riseHeight, lifetime;
  final double drift, softness, turbulence, contrast, expansion;
  final bool visible;
  BaseCampSmokeFx copyWith({
    double? density,
    double? opacity,
    double? particleSize,
    double? spread,
    double? riseHeight,
    double? lifetime,
    double? drift,
    double? softness,
    double? turbulence,
    double? contrast,
    double? expansion,
    bool? visible,
  }) => BaseCampSmokeFx(
    density: density ?? this.density,
    opacity: opacity ?? this.opacity,
    particleSize: particleSize ?? this.particleSize,
    spread: spread ?? this.spread,
    riseHeight: riseHeight ?? this.riseHeight,
    lifetime: lifetime ?? this.lifetime,
    drift: drift ?? this.drift,
    softness: softness ?? this.softness,
    turbulence: turbulence ?? this.turbulence,
    contrast: contrast ?? this.contrast,
    expansion: expansion ?? this.expansion,
    visible: visible ?? this.visible,
  );
  Map<String, Object?> toJson() => <String, Object?>{
    'density': density,
    'opacity': opacity,
    'particleSize': particleSize,
    'spread': spread,
    'riseHeight': riseHeight,
    'lifetime': lifetime,
    'drift': drift,
    'softness': softness,
    'turbulence': turbulence,
    'contrast': contrast,
    'expansion': expansion,
    'visible': visible,
  };
  static BaseCampSmokeFx? tryParse(Object? raw) {
    if (raw is! Map) return null;
    double? value(String key) => raw[key] is num && (raw[key] as num).isFinite
        ? (raw[key] as num).toDouble()
        : null;
    final values = <double?>[
      for (final key in const [
        'density',
        'opacity',
        'particleSize',
        'spread',
        'riseHeight',
        'lifetime',
        'drift',
        'softness',
        'turbulence',
        'contrast',
        'expansion',
      ])
        value(key),
    ];
    if (values.any((item) => item == null || item < 0 || item > 4) ||
        raw['visible'] is! bool) {
      return null;
    }
    return BaseCampSmokeFx(
      density: values[0]!,
      opacity: values[1]!,
      particleSize: values[2]!,
      spread: values[3]!,
      riseHeight: values[4]!,
      lifetime: values[5]!,
      drift: values[6]!,
      softness: values[7]!,
      turbulence: values[8]!,
      contrast: values[9]!,
      expansion: values[10]!,
      visible: raw['visible'] as bool,
    );
  }
}

@immutable
class BaseCampFacilityLabel {
  const BaseCampFacilityLabel({
    required this.position,
    Offset? connectorStart,
    required this.connectorEnd,
    this.scale = 1,
    this.visible = true,
    this.elbow = .5,
  }) : connectorStart = connectorStart ?? position;
  final Offset position, connectorStart, connectorEnd;
  final double scale, elbow;
  final bool visible;
  static BaseCampFacilityLabel defaultsFor(String id) => switch (id) {
    'status' => const BaseCampFacilityLabel(
      position: Offset(150, 190),
      connectorStart: Offset(214, 190),
      connectorEnd: Offset(295, 310),
    ),
    'food' => const BaseCampFacilityLabel(
      position: Offset(500, 155),
      connectorStart: Offset(565, 155),
      connectorEnd: Offset(624, 231),
    ),
    'training' => const BaseCampFacilityLabel(
      position: Offset(1015, 135),
      connectorStart: Offset(1015, 155),
      connectorEnd: Offset(1010, 260),
    ),
    'activity' => const BaseCampFacilityLabel(
      position: Offset(190, 400),
      connectorStart: Offset(255, 400),
      connectorEnd: Offset(360, 510),
    ),
    _ => const BaseCampFacilityLabel(
      position: Offset(760, 415),
      connectorStart: Offset(825, 415),
      connectorEnd: Offset(900, 530),
    ),
  };
  BaseCampFacilityLabel copyWith({
    Offset? position,
    Offset? connectorStart,
    Offset? connectorEnd,
    double? scale,
    bool? visible,
    double? elbow,
  }) => BaseCampFacilityLabel(
    position: position ?? this.position,
    connectorStart: connectorStart ?? this.connectorStart,
    connectorEnd: connectorEnd ?? this.connectorEnd,
    scale: scale ?? this.scale,
    visible: visible ?? this.visible,
    elbow: elbow ?? this.elbow,
  );
  Map<String, Object?> toJson() => {
    'x': position.dx,
    'y': position.dy,
    'startX': connectorStart.dx,
    'startY': connectorStart.dy,
    'endX': connectorEnd.dx,
    'endY': connectorEnd.dy,
    'scale': scale,
    'visible': visible,
    'elbow': elbow,
  };
  static Map<String, BaseCampFacilityLabel>? decodeAll(Object? raw) {
    if (raw is! Map || raw.length != baseCampFacilities.length) return null;
    final result = <String, BaseCampFacilityLabel>{};
    for (final facility in baseCampFacilities) {
      final item = raw[facility.id];
      if (item is! Map || item['visible'] is! bool) {
        return null;
      }
      double? n(String k) => item[k] is num && (item[k] as num).isFinite
          ? (item[k] as num).toDouble()
          : null;
      final x = n('x'),
          y = n('y'),
          sx = n('startX') ?? n('x'),
          sy = n('startY') ?? n('y'),
          ex = n('endX'),
          ey = n('endY'),
          s = n('scale'),
          e = n('elbow');
      if ([x, y, sx, sy, ex, ey, s, e].any((v) => v == null) ||
          x! < 0 ||
          x > 1280 ||
          y! < 0 ||
          y > 720 ||
          sx! < 0 ||
          sx > 1280 ||
          sy! < 0 ||
          sy > 720 ||
          ex! < 0 ||
          ex > 1280 ||
          ey! < 0 ||
          ey > 720 ||
          s! <= 0 ||
          s > 3 ||
          e! < 0 ||
          e > 1) {
        return null;
      }
      result[facility.id] = BaseCampFacilityLabel(
        position: Offset(x, y),
        connectorStart: Offset(sx, sy),
        connectorEnd: Offset(ex, ey),
        scale: s,
        visible: item['visible'] as bool,
        elbow: e,
      );
    }
    return result;
  }
}

@immutable
class BaseCampWaterArea {
  const BaseCampWaterArea({
    required this.mask,
    required this.shoreline,
    this.exclusionMasks = const <List<Offset>>[],
  });
  final List<Offset> mask, shoreline;
  final List<List<Offset>> exclusionMasks;
  Map<String, Object?> toJson() => <String, Object?>{
    'mask': _pointsJson(mask),
    'shoreline': _pointsJson(shoreline),
    'exclusionMasks': exclusionMasks.map(_pointsJson).toList(growable: false),
  };
  static BaseCampWaterArea? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final mask = _points(raw['mask'], 3);
    final shoreline = _points(raw['shoreline'], 2);
    final exclusions = _decodeExclusionMasks(raw['exclusionMasks']);
    if (mask == null || shoreline == null || exclusions == null) return null;
    return BaseCampWaterArea(
      mask: mask,
      shoreline: shoreline,
      exclusionMasks: exclusions,
    );
  }
}

@immutable
class BaseCampWaterFx {
  const BaseCampWaterFx({
    required this.shoreline,
    required this.mask,
    this.exclusionMasks = const <List<Offset>>[],
    this.areas = const <BaseCampWaterArea>[],
    this.intensity = 1,
    this.speed = 1,
    this.foam = 1,
    this.opacity = .38,
    this.spread = 1,
    this.frequency = 1,
    this.shimmerDensity = 1,
    this.shimmerBrightness = 1,
    this.shimmerSpeed = 1,
    this.flowDistortion = 1,
    this.foamIntensity = 1,
    this.foamLifetime = 1,
    this.shimmerEnabled = true,
    this.rippleEnabled = true,
    this.foamEnabled = true,
    this.visible = true,
  });
  final List<Offset> shoreline, mask;
  final List<List<Offset>> exclusionMasks;

  /// Empty preserves the V6 primary area. Non-empty is the complete set of
  /// independent editable water regions.
  final List<BaseCampWaterArea> areas;
  List<BaseCampWaterArea> get effectiveAreas => areas.isEmpty
      ? <BaseCampWaterArea>[
          BaseCampWaterArea(
            mask: mask,
            shoreline: shoreline,
            exclusionMasks: exclusionMasks,
          ),
        ]
      : areas;
  final double intensity, speed, foam, opacity, spread, frequency;
  final double shimmerDensity, shimmerBrightness, shimmerSpeed;
  final double flowDistortion, foamIntensity, foamLifetime;
  final bool shimmerEnabled, rippleEnabled, foamEnabled, visible;
  static Map<String, BaseCampWaterFx> defaults() => <String, BaseCampWaterFx>{
    'water': const BaseCampWaterFx(
      // The primary fields mirror area zero for compatibility with the V7
      // shape contract. `areas` is authoritative in schema V8.
      mask: <Offset>[
        Offset(0, 0),
        Offset(27, 6),
        Offset(46, 15),
        Offset(299, 15),
        Offset(356, 39),
        Offset(458, 41),
        Offset(486, 95),
        Offset(451, 104),
        Offset(393, 104),
        Offset(328, 121),
        Offset(277, 144),
        Offset(221, 175),
        Offset(171, 215),
        Offset(130, 263),
        Offset(86, 310),
        Offset(44, 362),
        Offset(5, 427),
        Offset(0, 492),
      ],
      shoreline: <Offset>[
        Offset(27, 6),
        Offset(46, 15),
        Offset(299, 15),
        Offset(356, 39),
        Offset(458, 41),
        Offset(486, 95),
        Offset(451, 104),
        Offset(393, 104),
        Offset(328, 121),
        Offset(277, 144),
        Offset(221, 175),
        Offset(171, 215),
        Offset(130, 263),
        Offset(86, 310),
        Offset(44, 362),
        Offset(5, 427),
        Offset(0, 492),
      ],
      exclusionMasks: <List<Offset>>[
        <Offset>[
          Offset(24, 8),
          Offset(310, 8),
          Offset(365, 34),
          Offset(458, 38),
          Offset(486, 96),
          Offset(451, 108),
          Offset(305, 108),
          Offset(24, 92),
        ],
        <Offset>[
          Offset(48, 246),
          Offset(126, 244),
          Offset(151, 332),
          Offset(89, 388),
          Offset(38, 344),
        ],
      ],
      areas: <BaseCampWaterArea>[
        BaseCampWaterArea(
          mask: <Offset>[
            Offset(0, 0),
            Offset(27, 6),
            Offset(46, 15),
            Offset(299, 15),
            Offset(356, 39),
            Offset(458, 41),
            Offset(486, 95),
            Offset(451, 104),
            Offset(393, 104),
            Offset(328, 121),
            Offset(277, 144),
            Offset(221, 175),
            Offset(171, 215),
            Offset(130, 263),
            Offset(86, 310),
            Offset(44, 362),
            Offset(5, 427),
            Offset(0, 492),
          ],
          shoreline: <Offset>[
            Offset(27, 6),
            Offset(46, 15),
            Offset(299, 15),
            Offset(356, 39),
            Offset(458, 41),
            Offset(486, 95),
            Offset(451, 104),
            Offset(393, 104),
            Offset(328, 121),
            Offset(277, 144),
            Offset(221, 175),
            Offset(171, 215),
            Offset(130, 263),
            Offset(86, 310),
            Offset(44, 362),
            Offset(5, 427),
            Offset(0, 492),
          ],
          exclusionMasks: <List<Offset>>[
            <Offset>[
              Offset(24, 8),
              Offset(310, 8),
              Offset(365, 34),
              Offset(458, 38),
              Offset(486, 96),
              Offset(451, 108),
              Offset(305, 108),
              Offset(24, 92),
            ],
            <Offset>[
              Offset(48, 246),
              Offset(126, 244),
              Offset(151, 332),
              Offset(89, 388),
              Offset(38, 344),
            ],
          ],
        ),
        BaseCampWaterArea(
          mask: <Offset>[
            Offset(876, 0),
            Offset(1254, 0),
            Offset(1254, 170),
            Offset(1205, 161),
            Offset(1174, 143),
            Offset(1129, 125),
            Offset(1084, 106),
            Offset(1036, 86),
            Offset(992, 69),
            Offset(949, 50),
            Offset(906, 33),
            Offset(876, 18),
          ],
          shoreline: <Offset>[
            Offset(876, 18),
            Offset(906, 33),
            Offset(949, 50),
            Offset(992, 69),
            Offset(1036, 86),
            Offset(1084, 106),
            Offset(1129, 125),
            Offset(1174, 143),
            Offset(1205, 161),
            Offset(1254, 170),
          ],
        ),
        BaseCampWaterArea(
          mask: <Offset>[
            Offset(0, 748),
            Offset(11, 748),
            Offset(5, 770),
            Offset(22, 791),
            Offset(46, 814),
            Offset(76, 842),
            Offset(109, 871),
            Offset(144, 903),
            Offset(176, 930),
            Offset(198, 960),
            Offset(195, 987),
            Offset(167, 1014),
            Offset(136, 1040),
            Offset(105, 1067),
            Offset(71, 1094),
            Offset(38, 1115),
            Offset(9, 1134),
            Offset(0, 1134),
          ],
          shoreline: <Offset>[
            Offset(11, 748),
            Offset(5, 770),
            Offset(22, 791),
            Offset(46, 814),
            Offset(76, 842),
            Offset(109, 871),
            Offset(144, 903),
            Offset(176, 930),
            Offset(198, 960),
            Offset(195, 987),
            Offset(167, 1014),
            Offset(136, 1040),
            Offset(105, 1067),
            Offset(71, 1094),
            Offset(38, 1115),
            Offset(9, 1134),
          ],
        ),
        BaseCampWaterArea(
          mask: <Offset>[
            Offset(203, 1214),
            Offset(219, 1160),
            Offset(271, 1122),
            Offset(316, 1119),
            Offset(582, 1119),
            Offset(626, 1130),
            Offset(702, 1132),
            Offset(758, 1140),
            Offset(812, 1154),
            Offset(870, 1159),
            Offset(929, 1163),
            Offset(996, 1167),
            Offset(1051, 1154),
            Offset(1094, 1107),
            Offset(1132, 1065),
            Offset(1170, 1031),
            Offset(1199, 1012),
            Offset(1222, 1014),
            Offset(1254, 1044),
            Offset(1254, 1254),
            Offset(203, 1254),
          ],
          shoreline: <Offset>[
            Offset(203, 1214),
            Offset(219, 1160),
            Offset(271, 1122),
            Offset(316, 1119),
            Offset(582, 1119),
            Offset(626, 1130),
            Offset(702, 1132),
            Offset(758, 1140),
            Offset(812, 1154),
            Offset(870, 1159),
            Offset(929, 1163),
            Offset(996, 1167),
            Offset(1051, 1154),
            Offset(1094, 1107),
            Offset(1132, 1065),
            Offset(1170, 1031),
            Offset(1199, 1012),
            Offset(1222, 1014),
            Offset(1254, 1044),
          ],
          exclusionMasks: <List<Offset>>[
            <Offset>[
              Offset(430, 1140),
              Offset(525, 1128),
              Offset(568, 1198),
              Offset(530, 1254),
              Offset(420, 1254),
            ],
            <Offset>[
              Offset(665, 1094),
              Offset(758, 1080),
              Offset(812, 1145),
              Offset(785, 1215),
              Offset(690, 1218),
            ],
            <Offset>[
              Offset(830, 1150),
              Offset(928, 1138),
              Offset(980, 1202),
              Offset(946, 1254),
              Offset(842, 1254),
            ],
          ],
        ),
      ],
    ),
  };
  BaseCampWaterFx copyWith({
    List<Offset>? shoreline,
    List<Offset>? mask,
    List<List<Offset>>? exclusionMasks,
    List<BaseCampWaterArea>? areas,
    double? intensity,
    double? speed,
    double? foam,
    double? opacity,
    double? spread,
    double? frequency,
    double? shimmerDensity,
    double? shimmerBrightness,
    double? shimmerSpeed,
    double? flowDistortion,
    double? foamIntensity,
    double? foamLifetime,
    bool? shimmerEnabled,
    bool? rippleEnabled,
    bool? foamEnabled,
    bool? visible,
  }) => BaseCampWaterFx(
    shoreline: shoreline ?? this.shoreline,
    mask: mask ?? this.mask,
    exclusionMasks: exclusionMasks ?? this.exclusionMasks,
    areas: areas ?? this.areas,
    intensity: intensity ?? this.intensity,
    speed: speed ?? this.speed,
    foam: foam ?? this.foam,
    opacity: opacity ?? this.opacity,
    spread: spread ?? this.spread,
    frequency: frequency ?? this.frequency,
    shimmerDensity: shimmerDensity ?? this.shimmerDensity,
    shimmerBrightness: shimmerBrightness ?? this.shimmerBrightness,
    shimmerSpeed: shimmerSpeed ?? this.shimmerSpeed,
    flowDistortion: flowDistortion ?? this.flowDistortion,
    foamIntensity: foamIntensity ?? this.foamIntensity,
    foamLifetime: foamLifetime ?? this.foamLifetime,
    shimmerEnabled: shimmerEnabled ?? this.shimmerEnabled,
    rippleEnabled: rippleEnabled ?? this.rippleEnabled,
    foamEnabled: foamEnabled ?? this.foamEnabled,
    visible: visible ?? this.visible,
  );
  Map<String, Object?> toJson() => {
    'shoreline': _pointsJson(shoreline),
    'mask': _pointsJson(mask),
    'exclusionMasks': exclusionMasks.map(_pointsJson).toList(growable: false),
    if (areas.isNotEmpty) 'areas': areas.map((area) => area.toJson()).toList(),
    'intensity': intensity,
    'speed': speed,
    'foam': foam,
    'opacity': opacity,
    'spread': spread,
    'frequency': frequency,
    'shimmerDensity': shimmerDensity,
    'shimmerBrightness': shimmerBrightness,
    'shimmerSpeed': shimmerSpeed,
    'flowDistortion': flowDistortion,
    'foamIntensity': foamIntensity,
    'foamLifetime': foamLifetime,
    'shimmerEnabled': shimmerEnabled,
    'rippleEnabled': rippleEnabled,
    'foamEnabled': foamEnabled,
    'visible': visible,
  };
  static Map<String, BaseCampWaterFx>? decodeAll(Object? raw) =>
      _decode(raw, const <String>['water'], defaults());

  static Map<String, BaseCampWaterFx>? decodeLegacy(Object? raw) => _decode(
    raw,
    const <String>['rock-foam', 'coast-ripple'],
    _legacyDefaults,
  );

  static Map<String, BaseCampWaterFx>? _decode(
    Object? raw,
    List<String> ids,
    Map<String, BaseCampWaterFx> defaults,
  ) {
    if (raw is! Map || raw.length != ids.length) return null;
    final result = <String, BaseCampWaterFx>{};
    for (final id in ids) {
      final i = raw[id];
      if (i is! Map || i['visible'] is! bool) return null;
      final shore = _points(i['shoreline'], 2), mask = _points(i['mask'], 3);
      double? n(String k) => i[k] is num && (i[k] as num).isFinite
          ? (i[k] as num).toDouble()
          : null;
      final a = n('intensity'),
          b = n('speed'),
          c = n('foam'),
          d = n('opacity'),
          e = n('spread'),
          f = n('frequency');
      final defaultEffect = defaults[id]!;
      final exclusions = _decodeExclusionMasks(i['exclusionMasks']);
      final rawAreas = i['areas'];
      final areas = rawAreas == null
          ? const <BaseCampWaterArea>[]
          : rawAreas is List
          ? rawAreas
                .map(BaseCampWaterArea.tryParse)
                .whereType<BaseCampWaterArea>()
                .toList()
          : null;
      final shimmerDensity =
          n('shimmerDensity') ?? defaultEffect.shimmerDensity;
      final shimmerBrightness =
          n('shimmerBrightness') ?? defaultEffect.shimmerBrightness;
      final shimmerSpeed = n('shimmerSpeed') ?? defaultEffect.shimmerSpeed;
      final flowDistortion =
          n('flowDistortion') ?? defaultEffect.flowDistortion;
      final foamIntensity = n('foamIntensity') ?? defaultEffect.foamIntensity;
      final foamLifetime = n('foamLifetime') ?? defaultEffect.foamLifetime;
      if (shore == null ||
          mask == null ||
          exclusions == null ||
          areas == null ||
          (rawAreas is List && areas.length != rawAreas.length) ||
          [
            a,
            b,
            c,
            d,
            e,
            f,
            shimmerDensity,
            shimmerBrightness,
            shimmerSpeed,
            flowDistortion,
            foamIntensity,
            foamLifetime,
          ].any((v) => v == null || v < 0 || v > 4)) {
        return null;
      }
      result[id] = BaseCampWaterFx(
        shoreline: shore,
        mask: mask,
        exclusionMasks: exclusions,
        areas: areas,
        intensity: a!,
        speed: b!,
        foam: c!,
        opacity: d!,
        spread: e!,
        frequency: f!,
        shimmerDensity: shimmerDensity,
        shimmerBrightness: shimmerBrightness,
        shimmerSpeed: shimmerSpeed,
        flowDistortion: flowDistortion,
        foamIntensity: foamIntensity,
        foamLifetime: foamLifetime,
        shimmerEnabled: i['shimmerEnabled'] is bool
            ? i['shimmerEnabled'] as bool
            : defaultEffect.shimmerEnabled,
        rippleEnabled: i['rippleEnabled'] is bool
            ? i['rippleEnabled'] as bool
            : defaultEffect.rippleEnabled,
        foamEnabled: i['foamEnabled'] is bool
            ? i['foamEnabled'] as bool
            : defaultEffect.foamEnabled,
        visible: i['visible'] as bool,
      );
    }
    return result;
  }

  static const Map<String, BaseCampWaterFx> _legacyDefaults = {
    'rock-foam': BaseCampWaterFx(
      shoreline: [
        Offset(9.8, 932),
        Offset(47, 982),
        Offset(76, 1071),
        Offset(65, 1187),
      ],
      mask: [
        Offset(0, 868),
        Offset(43, 911),
        Offset(84, 1033),
        Offset(75, 1201),
        Offset(0, 1254),
      ],
      intensity: 1.25,
      foam: 1.3,
    ),
    'coast-ripple': BaseCampWaterFx(
      shoreline: [
        Offset(5, 143),
        Offset(57, 185),
        Offset(59, 293),
        Offset(41, 414),
      ],
      mask: [
        Offset(0, 101),
        Offset(61, 150),
        Offset(67, 287),
        Offset(45, 432),
        Offset(0, 484),
      ],
      intensity: .55,
      foam: .3,
      opacity: .24,
    ),
  };
}

@immutable
class BaseCampStaticSoldier {
  const BaseCampStaticSoldier({
    required this.id,
    required this.position,
    this.direction = 'front',
    this.scale = 1,
    this.breathing = true,
    this.breathingIntensity = 1,
    this.breathingPeriod = 3.2,
    this.visible = true,
  });
  final String id, direction;
  final Offset position;
  final double scale, breathingIntensity, breathingPeriod;
  final bool breathing, visible;
  BaseCampStaticSoldier copyWith({
    Offset? position,
    String? direction,
    double? scale,
    bool? breathing,
    double? breathingIntensity,
    double? breathingPeriod,
    bool? visible,
  }) => BaseCampStaticSoldier(
    id: id,
    position: position ?? this.position,
    direction: direction ?? this.direction,
    scale: scale ?? this.scale,
    breathing: breathing ?? this.breathing,
    breathingIntensity: breathingIntensity ?? this.breathingIntensity,
    breathingPeriod: breathingPeriod ?? this.breathingPeriod,
    visible: visible ?? this.visible,
  );
  Map<String, Object?> toJson() => {
    'id': id,
    'x': position.dx,
    'y': position.dy,
    'direction': direction,
    'scale': scale,
    'breathing': breathing,
    'breathingIntensity': breathingIntensity,
    'breathingPeriod': breathingPeriod,
    'visible': visible,
  };
  static List<BaseCampStaticSoldier>? decodeAll(Object? raw) {
    if (raw is! List) return null;
    final ids = <String>{};
    final result = <BaseCampStaticSoldier>[];
    for (final i in raw) {
      if (i is! Map ||
          i['id'] is! String ||
          !ids.add(i['id'] as String) ||
          i['direction'] is! String ||
          i['breathing'] is! bool ||
          i['visible'] is! bool) {
        return null;
      }
      double? n(String k) => i[k] is num && (i[k] as num).isFinite
          ? (i[k] as num).toDouble()
          : null;
      final x = n('x'),
          y = n('y'),
          s = n('scale'),
          bi = n('breathingIntensity'),
          bp = n('breathingPeriod');
      if ([x, y, s, bi, bp].any((v) => v == null) ||
          x! < 0 ||
          x > 1280 ||
          y! < 0 ||
          y > 720 ||
          s! <= 0 ||
          s > 3 ||
          bi! < 0 ||
          bi > 2 ||
          bp! < 1 ||
          bp > 10 ||
          !const ['front', 'back', 'right', 'left'].contains(i['direction'])) {
        return null;
      }
      result.add(
        BaseCampStaticSoldier(
          id: i['id'] as String,
          position: Offset(x, y),
          direction: i['direction'] as String,
          scale: s,
          breathing: i['breathing'] as bool,
          breathingIntensity: bi,
          breathingPeriod: bp,
          visible: i['visible'] as bool,
        ),
      );
    }
    return result;
  }
}

List<Map<String, double>> _pointsJson(List<Offset> points) =>
    points.map((p) => {'x': p.dx, 'y': p.dy}).toList();
List<Offset>? _points(Object? raw, int min) {
  if (raw is! List || raw.length < min) {
    return null;
  }
  final r = <Offset>[];
  for (final p in raw) {
    if (p is! Map || p['x'] is! num || p['y'] is! num) {
      return null;
    }
    final x = (p['x'] as num).toDouble(), y = (p['y'] as num).toDouble();
    if (!x.isFinite ||
        !y.isFinite ||
        x < 0 ||
        x > baseCampMapArtworkSize.width ||
        y < 0 ||
        y > baseCampMapArtworkSize.height) {
      return null;
    }
    r.add(Offset(x, y));
  }
  return r;
}

List<List<Offset>>? _decodeExclusionMasks(Object? raw) {
  if (raw == null) return const <List<Offset>>[];
  if (raw is! List || raw.length > 8) return null;
  final masks = <List<Offset>>[];
  for (final item in raw) {
    final points = _points(item, 3);
    if (points == null) return null;
    masks.add(points);
  }
  return masks;
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
    position: Offset(293.9966913479477, 397.1475629664179),
    scale: 1.3947747332466733,
    rotation: -0.016356174941200674,
    zIndex: 1,
    animationRate: .5,
  ),
  BaseCampMapObject(
    id: 'food',
    // Preserve the image reference that was already placed in this slot.
    assetId: 'command-center',
    position: Offset(673.9635319496268, 280.3980099502487),
    scale: 1.5335217986344545,
    zIndex: 2,
  ),
  BaseCampMapObject(
    id: 'training',
    assetId: 'training',
    position: Offset(1094.2619908271142, 450.21562111318417),
    scale: 1.8612519490597221,
    zIndex: 3,
  ),
  BaseCampMapObject(
    id: 'activity',
    assetId: 'activity',
    position: Offset(395.8872386116293, 631.7081584266168),
    scale: 1.5574437857572583,
    zIndex: 4,
  ),
  BaseCampMapObject(
    id: 'command-center',
    // Preserve the image reference that was already placed in this slot.
    assetId: 'food',
    position: Offset(938.2420903296019, 640.1990049751244),
    scale: 1.7464267612889284,
    rotation: 0.049093242219480526,
    zIndex: 5,
  ),
  BaseCampMapObject(
    id: 'flag',
    assetId: 'flag',
    position: Offset(1195.0912430037313, 563.7810945273632),
    scale: .8397862526839035,
    zIndex: 6,
  ),
];

@immutable
class BaseCampWaterDraft {
  const BaseCampWaterDraft({
    required this.waterFx,
    required this.compatibilityWaterFxV7,
  });

  static const schemaVersion = 1;
  final Map<String, BaseCampWaterFx> waterFx;
  final Map<String, BaseCampWaterFx> compatibilityWaterFxV7;

  factory BaseCampWaterDraft.fromConfiguration(
    BaseCampMapConfiguration configuration,
  ) => BaseCampWaterDraft(
    waterFx: Map<String, BaseCampWaterFx>.of(configuration.waterFx),
    compatibilityWaterFxV7: Map<String, BaseCampWaterFx>.of(
      configuration.compatibilityWaterFxV7,
    ),
  );

  BaseCampMapConfiguration applyTo(BaseCampMapConfiguration configuration) =>
      configuration.copyWith(
        waterFx: Map<String, BaseCampWaterFx>.of(waterFx),
        compatibilityWaterFxV7: Map<String, BaseCampWaterFx>.of(
          compatibilityWaterFxV7,
        ),
      );

  Map<String, Object?> toJson() => <String, Object?>{
    'draftSchemaVersion': schemaVersion,
    'mapSchemaVersion': BaseCampMapConfiguration.schemaVersion,
    'mapId': BaseCampMapConfiguration.mapId,
    'waterFx': waterFx.map((id, effect) => MapEntry(id, effect.toJson())),
    if (compatibilityWaterFxV7.isNotEmpty)
      'compatibilityWaterFxV7': compatibilityWaterFxV7.map(
        (id, effect) => MapEntry(id, effect.toJson()),
      ),
  };

  String encode() => jsonEncode(toJson());

  static BaseCampWaterDraft? tryParse(Object? raw) {
    if (raw is! Map ||
        raw['draftSchemaVersion'] != schemaVersion ||
        raw['mapSchemaVersion'] != BaseCampMapConfiguration.schemaVersion ||
        raw['mapId'] != BaseCampMapConfiguration.mapId) {
      return null;
    }
    final waterFx = BaseCampWaterFx.decodeAll(raw['waterFx']);
    final compatibility = raw['compatibilityWaterFxV7'] == null
        ? const <String, BaseCampWaterFx>{}
        : BaseCampWaterFx.decodeLegacy(raw['compatibilityWaterFxV7']);
    if (waterFx == null || compatibility == null) return null;
    return BaseCampWaterDraft(
      waterFx: waterFx,
      compatibilityWaterFxV7: compatibility,
    );
  }
}

enum BaseCampWaterDraftState { missing, ready, corrupt, unavailable }

@immutable
class BaseCampWaterDraftLoadResult {
  const BaseCampWaterDraftLoadResult(this.state, {this.draft});
  final BaseCampWaterDraftState state;
  final BaseCampWaterDraft? draft;
}

class BaseCampWaterDraftStore {
  BaseCampWaterDraftStore({
    Future<SharedPreferences> Function()? preferencesLoader,
  }) : _preferencesLoader = preferencesLoader ?? SharedPreferences.getInstance;

  static const storageKey = 'base_camp_water_editor_draft_v1';
  final Future<SharedPreferences> Function() _preferencesLoader;

  Future<BaseCampWaterDraftLoadResult> load() async {
    try {
      final raw = (await _preferencesLoader()).getString(storageKey);
      if (raw == null) {
        return const BaseCampWaterDraftLoadResult(
          BaseCampWaterDraftState.missing,
        );
      }
      final draft = BaseCampWaterDraft.tryParse(jsonDecode(raw));
      return draft == null
          ? const BaseCampWaterDraftLoadResult(BaseCampWaterDraftState.corrupt)
          : BaseCampWaterDraftLoadResult(
              BaseCampWaterDraftState.ready,
              draft: draft,
            );
    } on FormatException {
      return const BaseCampWaterDraftLoadResult(
        BaseCampWaterDraftState.corrupt,
      );
    } catch (_) {
      return const BaseCampWaterDraftLoadResult(
        BaseCampWaterDraftState.unavailable,
      );
    }
  }

  Future<void> save(BaseCampMapConfiguration configuration) async {
    final draft = BaseCampWaterDraft.fromConfiguration(configuration);
    final normalised = BaseCampWaterDraft.tryParse(draft.toJson());
    if (normalised == null) {
      throw ArgumentError.value(
        configuration,
        'configuration',
        'Invalid water draft',
      );
    }
    final saved = await (await _preferencesLoader()).setString(
      storageKey,
      normalised.encode(),
    );
    if (!saved) throw StateError('Water draft write was rejected');
  }

  Future<void> discard() async {
    final removed = await (await _preferencesLoader()).remove(storageKey);
    if (!removed) throw StateError('Water draft removal was rejected');
  }
}

class BaseCampMapConfigurationController
    extends ValueNotifier<BaseCampMapConfiguration> {
  BaseCampMapConfigurationController({
    Future<SharedPreferences> Function()? preferencesLoader,
  }) : _preferencesLoader = preferencesLoader ?? SharedPreferences.getInstance,
       super(BaseCampMapConfiguration.defaults());

  static const storageKey = 'base_camp_map_editor_v1';
  final Future<SharedPreferences> Function() _preferencesLoader;
  bool _loaded = false;
  String? _lastLoadFailureStage;

  /// A safe, value-free classification of the last optional calibration
  /// restore failure.  The map deliberately stays on its audited defaults
  /// when this is non-null; it never clears or rewrites the saved payload.
  String? get lastLoadFailureStage => _lastLoadFailureStage;

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final preferences = await _preferencesLoader();
      final raw = preferences.getString(storageKey);
      if (raw == null) return;
      final restored = BaseCampMapConfiguration.tryParse(jsonDecode(raw));
      if (restored != null) {
        value = restored;
        // Persist compatible schema and obsolete 2/1 multiplier migrations
        // immediately, without changing any route or facility-outline payload.
        if (restored.encode() != raw) {
          await preferences.setString(storageKey, restored.encode());
        }
      }
    } on FormatException {
      _recordLoadFailure('configuration_format');
    } catch (error) {
      // Local map calibration is optional presentation data.  A Safari
      // storage/security failure must not escape an unawaited map load and
      // prevent the dashboard from rendering.  Keep the original payload
      // untouched for later recovery and record only its error category.
      _recordLoadFailure('storage_or_restore_${error.runtimeType}');
    }
  }

  void _recordLoadFailure(String stage) {
    _lastLoadFailureStage = stage;
    StartupDiagnostic.instance.record(
      'BASE_CAMP',
      'MAP_CONFIGURATION_RESTORE_FAILED',
      fields: <String, Object?>{'stage': stage},
    );
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
    final saved = await (await _preferencesLoader()).setString(
      storageKey,
      normalised.encode(),
    );
    if (!saved) throw StateError('Base Camp map save was rejected');
    // Dashboard listeners must see the new configuration only after durable
    // storage succeeds. A failed SAVE therefore leaves production untouched.
    value = normalised;
  }

  Future<void> resetToDefaults() => save(BaseCampMapConfiguration.defaults());

  @visibleForTesting
  void resetForTesting(BaseCampMapConfiguration configuration) {
    _loaded = true;
    _lastLoadFailureStage = null;
    value = configuration;
  }
}

final baseCampMapConfigurationController = BaseCampMapConfigurationController();
