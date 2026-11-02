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
    this.soldierScale = 1,
  });

  static const schemaVersion = 1;
  static const mapId = 'base-camp-map-v1';

  final Map<String, List<Offset>> routes;
  final Map<String, List<Offset>> facilityOutlines;
  final double soldierScale;

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
  );

  BaseCampMapConfiguration copyWith({
    Map<String, List<Offset>>? routes,
    Map<String, List<Offset>>? facilityOutlines,
    double? soldierScale,
  }) => BaseCampMapConfiguration(
    routes: routes ?? this.routes,
    facilityOutlines: facilityOutlines ?? this.facilityOutlines,
    soldierScale: soldierScale ?? this.soldierScale,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'schemaVersion': schemaVersion,
    'mapId': mapId,
    'imageWidth': baseCampMapSourceSize.width,
    'imageHeight': baseCampMapSourceSize.height,
    'routes': _encodePointGroups(routes),
    'facilityOutlines': _encodePointGroups(facilityOutlines),
    'soldierScale': soldierScale,
  };

  String encode() => jsonEncode(toJson());

  static BaseCampMapConfiguration? tryParse(Object? raw) {
    if (raw is! Map) return null;
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
    if (routes == null ||
        outlines == null ||
        scale == null ||
        scale < .4 ||
        scale > 3) {
      return null;
    }
    return BaseCampMapConfiguration(
      routes: routes,
      facilityOutlines: outlines,
      soldierScale: scale,
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

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    final raw = (await _preferencesLoader()).getString(storageKey);
    if (raw == null) return;
    try {
      final restored = BaseCampMapConfiguration.tryParse(jsonDecode(raw));
      if (restored != null) value = restored;
    } on FormatException {
      // Invalid local calibration intentionally falls back to the audited defaults.
    }
  }

  Future<void> save(BaseCampMapConfiguration configuration) async {
    if (BaseCampMapConfiguration.tryParse(configuration.toJson()) == null) {
      throw ArgumentError.value(
        configuration,
        'configuration',
        'Invalid Base Camp map configuration',
      );
    }
    value = configuration;
    await (await _preferencesLoader()).setString(
      storageKey,
      configuration.encode(),
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
