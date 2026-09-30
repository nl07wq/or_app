import 'dart:convert';

import 'weather_client.dart';
import 'weather_models.dart';
import 'weather_store.dart';

class WeatherLoadResult {
  const WeatherLoadResult({
    this.snapshot,
    required this.isCached,
    required this.isStale,
    this.error,
  });

  final WeatherSnapshot? snapshot;
  final bool isCached;
  final bool isStale;
  final Object? error;
}

class WeatherService {
  WeatherService({
    WeatherStore? store,
    WeatherHttpClient? client,
    DateTime Function()? now,
  }) : _store = store ?? WeatherStore(),
       _client = client ?? PlatformWeatherHttpClient(),
       _now = now ?? DateTime.now;

  static const cacheTtl = Duration(minutes: 30);

  final WeatherStore _store;
  final WeatherHttpClient _client;
  final DateTime Function() _now;

  Future<WeatherLocationPreferences> loadLocations() => _store.loadLocations();

  Future<WeatherLocation?> loadActiveLocation() async =>
      (await _store.loadLocations()).activeLocation;

  Future<void> addLocation(WeatherLocation value) async {
    final preferences = await _store.loadLocations();
    if (preferences.locations.any(
      (location) => location.stableId == value.stableId,
    )) {
      throw StateError('LOCATION ALREADY SAVED');
    }
    if (preferences.locations.length >=
        WeatherLocationPreferences.maximumLocations) {
      throw StateError('LOCATION LIMIT REACHED');
    }
    final locations = [...preferences.locations, value];
    await _store.saveLocations(
      WeatherLocationPreferences(
        locations: locations,
        activeLocationId: preferences.activeLocationId ?? value.stableId,
      ),
    );
  }

  Future<void> setActiveLocation(String locationId) async {
    final preferences = await _store.loadLocations();
    if (!preferences.locations.any(
      (location) => location.stableId == locationId,
    )) {
      throw StateError('LOCATION NOT SAVED');
    }
    await _store.saveLocations(
      WeatherLocationPreferences(
        locations: preferences.locations,
        activeLocationId: locationId,
      ),
    );
  }

  Future<void> removeLocation(String locationId) async {
    final preferences = await _store.loadLocations();
    final removed = preferences.locations
        .where((location) => location.stableId == locationId)
        .toList(growable: false);
    final locations = preferences.locations
        .where((location) => location.stableId != locationId)
        .toList(growable: false);
    await _store.saveLocations(
      WeatherLocationPreferences(
        locations: locations,
        activeLocationId: preferences.activeLocationId == locationId
            ? (locations.isEmpty ? null : locations.first.stableId)
            : preferences.activeLocationId,
      ),
    );
    for (final location in removed) {
      await _store.removeCache(location);
    }
  }

  Future<WeatherLoadResult> load(
    WeatherLocation location, {
    bool forceRefresh = false,
  }) async {
    final matchingCache = await _store.loadCache(location);
    final isFresh =
        matchingCache != null &&
        _now().toUtc().difference(matchingCache.fetchedAt).abs() < cacheTtl;
    if (!forceRefresh && isFresh) {
      return WeatherLoadResult(
        snapshot: matchingCache,
        isCached: true,
        isStale: false,
      );
    }

    try {
      final snapshot = await _fetchForecast(location);
      await _store.saveCache(snapshot);
      return WeatherLoadResult(
        snapshot: snapshot,
        isCached: false,
        isStale: false,
      );
    } catch (error) {
      if (matchingCache != null) {
        return WeatherLoadResult(
          snapshot: matchingCache,
          isCached: true,
          isStale: true,
          error: error,
        );
      }
      return WeatherLoadResult(isCached: false, isStale: false, error: error);
    }
  }

  Future<List<WeatherGeocodingResult>> searchLocations(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];
    final source = await _geocodingRequest(trimmed);
    var result = _geocodingResults(source);
    final fallbackQuery = _japaneseQueryAliases[trimmed];
    if (result.isEmpty && fallbackQuery != null) {
      result = _geocodingResults(await _geocodingRequest(fallbackQuery));
    }
    return result;
  }

  Future<String> _geocodingRequest(String query) {
    final uri = Uri.https('geocoding-api.open-meteo.com', '/v1/search', {
      'name': query,
      'count': '8',
      'language': 'ja',
      'format': 'json',
      'countryCode': 'JP',
    });
    return _client.get(uri.toString());
  }

  List<WeatherGeocodingResult> _geocodingResults(String source) {
    final response = Map<String, Object?>.from(jsonDecode(source) as Map);
    final results = response['results'];
    if (results is! List) return const [];
    return results
        .map((value) {
          final item = Map<String, Object?>.from(value as Map);
          final segments = <String>[
            item['name'] as String,
            if (item['admin1'] is String) item['admin1'] as String,
            if (item['country'] is String) item['country'] as String,
          ];
          return WeatherGeocodingResult(
            displayName: segments.join(' / '),
            latitude: (item['latitude'] as num).toDouble(),
            longitude: (item['longitude'] as num).toDouble(),
            timezone: item['timezone'] as String,
          );
        })
        .toList(growable: false);
  }

  Future<WeatherSnapshot> _fetchForecast(WeatherLocation location) async {
    final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': location.latitude.toString(),
      'longitude': location.longitude.toString(),
      'timezone': location.timezone,
      'forecast_days': '7',
      'daily': [
        'weather_code',
        'temperature_2m_max',
        'temperature_2m_min',
        'precipitation_probability_max',
        'precipitation_sum',
        'sunrise',
        'sunset',
      ].join(','),
      'hourly': [
        'temperature_2m',
        'apparent_temperature',
        'relative_humidity_2m',
        'precipitation_probability',
        'precipitation',
        'weather_code',
        'cloud_cover',
        'wind_speed_10m',
        'wind_gusts_10m',
      ].join(','),
    });
    final source = await _client.get(uri.toString());
    final response = Map<String, Object?>.from(jsonDecode(source) as Map);
    return WeatherSnapshot(
      location: location,
      fetchedAt: _now().toUtc(),
      daily: _daily(Map<String, Object?>.from(response['daily'] as Map)),
      hourly: _hourly(Map<String, Object?>.from(response['hourly'] as Map)),
    );
  }

  List<WeatherDaily> _daily(Map<String, Object?> data) {
    final dates = _values<String>(data, 'time');
    return List.generate(
      dates.length,
      (index) => WeatherDaily(
        date: dates[index],
        code: _values<num>(data, 'weather_code')[index].toInt(),
        high: _values<num>(data, 'temperature_2m_max')[index].toDouble(),
        low: _values<num>(data, 'temperature_2m_min')[index].toDouble(),
        precipitationProbability: _values<num>(
          data,
          'precipitation_probability_max',
        )[index].toInt(),
        precipitation: _values<num>(
          data,
          'precipitation_sum',
        )[index].toDouble(),
        sunrise: _values<String>(data, 'sunrise')[index],
        sunset: _values<String>(data, 'sunset')[index],
      ),
      growable: false,
    );
  }

  List<WeatherHourly> _hourly(Map<String, Object?> data) {
    final times = _values<String>(data, 'time');
    return List.generate(
      times.length,
      (index) => WeatherHourly(
        time: times[index],
        temperature: _values<num>(data, 'temperature_2m')[index].toDouble(),
        apparentTemperature: _values<num>(
          data,
          'apparent_temperature',
        )[index].toDouble(),
        humidity: _values<num>(data, 'relative_humidity_2m')[index].toInt(),
        precipitationProbability: _values<num>(
          data,
          'precipitation_probability',
        )[index].toInt(),
        precipitation: _values<num>(data, 'precipitation')[index].toDouble(),
        code: _values<num>(data, 'weather_code')[index].toInt(),
        cloudCover: _values<num>(data, 'cloud_cover')[index].toInt(),
        windSpeed: _values<num>(data, 'wind_speed_10m')[index].toDouble(),
        windGust: _values<num>(data, 'wind_gusts_10m')[index].toDouble(),
      ),
      growable: false,
    );
  }

  List<T> _values<T>(Map<String, Object?> data, String key) =>
      (data[key] as List).cast<T>();

  static const _japaneseQueryAliases = <String, String>{
    '千葉': 'Chiba',
    '千葉県': 'Chiba',
    '市原': 'Ichihara',
    '市原市': 'Ichihara',
    '札幌': 'Sapporo',
    '札幌市': 'Sapporo',
    '東京': 'Tokyo',
    '東京都': 'Tokyo',
    '大阪': 'Osaka',
    '大阪市': 'Osaka',
  };
}
