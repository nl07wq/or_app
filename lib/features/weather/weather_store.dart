import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'weather_models.dart';

class WeatherStore {
  static const _locationKey = 'weather.location.v1';
  static const _cacheKey = 'weather.cache.v1';
  Future<WeatherLocation?> loadLocation() async {
    final value = (await SharedPreferences.getInstance()).getString(
      _locationKey,
    );
    return value == null
        ? null
        : WeatherLocation.fromJson(
            Map<String, Object?>.from(jsonDecode(value) as Map),
          );
  }

  Future<void> saveLocation(WeatherLocation location) async =>
      (await SharedPreferences.getInstance()).setString(
        _locationKey,
        jsonEncode(location.toJson()),
      );
  Future<void> removeLocation() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_locationKey);
    await prefs.remove(_cacheKey);
  }

  Future<WeatherSnapshot?> loadCache() async {
    final value = (await SharedPreferences.getInstance()).getString(_cacheKey);
    if (value == null) return null;
    try {
      return WeatherSnapshot.decode(value);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveCache(WeatherSnapshot snapshot) async =>
      (await SharedPreferences.getInstance()).setString(
        _cacheKey,
        snapshot.encode(),
      );
}
