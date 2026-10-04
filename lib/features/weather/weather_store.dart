import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'weather_models.dart';

class WeatherStore {
  static const _legacyLocationKey = 'weather.location.v1';
  static const _locationsKey = 'weather.locations.v2';
  // Past weather is now retained for 31 days. A new namespace prevents a
  // shorter v4 snapshot from being treated as a complete recent-past record.
  static const _cachePrefix = 'weather.cache.v5.';

  Future<WeatherLocationPreferences> loadLocations() async {
    final prefs = await SharedPreferences.getInstance();
    final source = prefs.getString(_locationsKey);
    if (source != null) {
      try {
        return WeatherLocationPreferences.fromJson(
          Map<String, Object?>.from(jsonDecode(source) as Map),
        );
      } catch (_) {
        // Context data cannot block Calendar when a legacy preference exists.
      }
    }
    final legacy = prefs.getString(_legacyLocationKey);
    if (legacy == null) return _empty;
    try {
      final location = WeatherLocation.fromJson(
        Map<String, Object?>.from(jsonDecode(legacy) as Map),
      );
      final migrated = WeatherLocationPreferences(
        locations: [location],
        activeLocationId: location.stableId,
      );
      await saveLocations(migrated);
      return migrated;
    } catch (_) {
      return _empty;
    }
  }

  Future<void> saveLocations(WeatherLocationPreferences preferences) async {
    await (await SharedPreferences.getInstance()).setString(
      _locationsKey,
      jsonEncode(preferences.toJson()),
    );
  }

  Future<WeatherSnapshot?> loadCache(WeatherLocation location) async {
    final value = (await SharedPreferences.getInstance()).getString(
      _cacheKey(location),
    );
    if (value == null) return null;
    try {
      final snapshot = WeatherSnapshot.decode(value);
      return snapshot.location.stableId == location.stableId ? snapshot : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> saveCache(WeatherSnapshot snapshot) async =>
      (await SharedPreferences.getInstance()).setString(
        _cacheKey(snapshot.location),
        snapshot.encode(),
      );

  Future<void> removeCache(WeatherLocation location) async =>
      (await SharedPreferences.getInstance()).remove(_cacheKey(location));

  String _cacheKey(WeatherLocation location) =>
      '$_cachePrefix${Uri.encodeComponent(location.stableId)}';

  static const _empty = WeatherLocationPreferences(
    locations: [],
    activeLocationId: null,
  );
}
