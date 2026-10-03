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
    final candidates = [...await _geocodingCandidates(trimmed)];
    if (_isJapaneseQuery(trimmed) &&
        !_hasPreferredJapaneseCandidate(candidates, trimmed)) {
      for (final variant in _japaneseSearchVariants(trimmed)) {
        candidates.addAll(await _geocodingCandidates(variant));
        if (_hasPreferredJapaneseCandidate(candidates, trimmed)) break;
      }
    }
    return _rankCandidates(candidates, trimmed);
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

  Future<List<_GeocodingCandidate>> _geocodingCandidates(String query) async =>
      _parseGeocodingCandidates(await _geocodingRequest(query));

  List<_GeocodingCandidate> _parseGeocodingCandidates(String source) {
    final response = Map<String, Object?>.from(jsonDecode(source) as Map);
    final results = response['results'];
    if (results is! List) return const [];
    return results
        .map((value) {
          final item = Map<String, Object?>.from(value as Map);
          return _GeocodingCandidate(
            name: item['name'] as String,
            admin1: item['admin1'] as String?,
            country: item['country'] as String?,
            countryCode: item['country_code'] as String?,
            featureCode: item['feature_code'] as String?,
            latitude: (item['latitude'] as num).toDouble(),
            longitude: (item['longitude'] as num).toDouble(),
            timezone: item['timezone'] as String,
          );
        })
        .toList(growable: false);
  }

  List<WeatherGeocodingResult> _rankCandidates(
    List<_GeocodingCandidate> candidates,
    String query,
  ) {
    final japanese = _isJapaneseQuery(query);
    final hasPreferredJapaneseResult =
        japanese && _hasPreferredJapaneseCandidate(candidates, query);
    final ranked =
        candidates
            .where(
              (candidate) =>
                  candidate.countryCode == null ||
                  candidate.countryCode == 'JP',
            )
            .where(
              (candidate) =>
                  !hasPreferredJapaneseResult ||
                  (_isMunicipalityFeature(candidate.featureCode) &&
                      _japaneseStem(candidate.name) == _japaneseStem(query)),
            )
            .map(
              (candidate) => (
                candidate: candidate,
                score: japanese ? _japaneseCandidateScore(candidate, query) : 0,
              ),
            )
            .where((value) => !japanese || value.score > 0)
            .toList()
          ..sort((a, b) => b.score.compareTo(a.score));

    final seen = <String>{};
    final values = <WeatherGeocodingResult>[];
    for (final value in ranked) {
      final candidate = value.candidate;
      final identity =
          '${candidate.latitude.toStringAsFixed(5)}:${candidate.longitude.toStringAsFixed(5)}:${candidate.timezone}';
      if (!seen.add(identity)) continue;
      values.add(candidate.toResult());
      if (values.length == 5) break;
    }
    return values;
  }

  bool _hasPreferredJapaneseCandidate(
    List<_GeocodingCandidate> candidates,
    String query,
  ) => candidates.any(
    (candidate) =>
        (candidate.countryCode == null || candidate.countryCode == 'JP') &&
        _isMunicipalityFeature(candidate.featureCode) &&
        _japaneseStem(candidate.name) == _japaneseStem(query),
  );

  int _japaneseCandidateScore(_GeocodingCandidate candidate, String query) {
    final stem = _japaneseStem(query);
    final name = _normalizeJapanese(candidate.name);
    if (stem.isEmpty || !name.contains(stem)) return -10000;

    var score = 200;
    if (name == _normalizeJapanese(query)) score += 1000;
    if (name == '$stem市') score += 1100;
    if (_japaneseStem(name) == stem) score += 800;
    if (_japaneseStem(candidate.admin1 ?? '') == stem) score += 140;
    if (_isMunicipalityFeature(candidate.featureCode)) score += 260;
    return score;
  }

  bool _isMunicipalityFeature(String? featureCode) =>
      featureCode == 'PPLA' ||
      featureCode == 'PPLA2' ||
      featureCode == 'PPLA3' ||
      featureCode == 'PPLC';

  bool _isJapaneseQuery(String value) =>
      RegExp(r'[\u3040-\u30ff\u3400-\u9fff\uff66-\uff9f]').hasMatch(value);

  String _normalizeJapanese(String value) =>
      value.replaceAll(RegExp(r'\s+'), '').trim();

  String _japaneseStem(String value) {
    final normalized = _normalizeJapanese(value);
    if (normalized.isEmpty) return normalized;
    const suffixes = ['市', '区', '町', '村', '都', '道', '府', '県'];
    for (final suffix in suffixes) {
      if (normalized.endsWith(suffix) &&
          normalized.length - suffix.length >= 2) {
        return normalized.substring(0, normalized.length - suffix.length);
      }
    }
    return normalized;
  }

  List<String> _japaneseSearchVariants(String query) {
    final stem = _japaneseStem(query);
    if (stem.isEmpty) return const [];
    return <String>{
      '$stem市',
      '$stem都',
      '$stem道',
      '$stem府',
      '$stem県',
    }.where((variant) => variant != query).toList(growable: false);
  }

  Future<WeatherSnapshot> _fetchForecast(WeatherLocation location) async {
    final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': location.latitude.toString(),
      'longitude': location.longitude.toString(),
      'timezone': location.timezone,
      'forecast_days': '7',
      'past_days': '1',
      'daily': [
        'weather_code',
        'temperature_2m_max',
        'temperature_2m_min',
        'precipitation_probability_max',
        'precipitation_sum',
        'sunrise',
        'sunset',
        'uv_index_max',
        'wind_speed_10m_max',
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
        'dew_point_2m',
        'wind_direction_10m',
        'surface_pressure',
        'visibility',
        'uv_index',
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
    final dailyWindSpeedMax = _optionalValues<num>(data, 'wind_speed_10m_max');
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
        uvIndexMax: _values<num>(data, 'uv_index_max')[index].toDouble(),
        windSpeedMax:
            dailyWindSpeedMax != null && index < dailyWindSpeedMax.length
            ? dailyWindSpeedMax[index].toDouble()
            : null,
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
        dewPoint: _values<num>(data, 'dew_point_2m')[index].toDouble(),
        windDirection: _values<num>(
          data,
          'wind_direction_10m',
        )[index].toDouble(),
        surfacePressure: _values<num>(
          data,
          'surface_pressure',
        )[index].toDouble(),
        visibility: _values<num>(data, 'visibility')[index].toDouble(),
        uvIndex: _values<num>(data, 'uv_index')[index].toDouble(),
      ),
      growable: false,
    );
  }

  List<T> _values<T>(Map<String, Object?> data, String key) =>
      (data[key] as List).cast<T>();

  List<T>? _optionalValues<T>(Map<String, Object?> data, String key) {
    final value = data[key];
    return value is List ? value.cast<T>() : null;
  }
}

class _GeocodingCandidate {
  const _GeocodingCandidate({
    required this.name,
    required this.admin1,
    required this.country,
    required this.countryCode,
    required this.featureCode,
    required this.latitude,
    required this.longitude,
    required this.timezone,
  });

  final String name;
  final String? admin1;
  final String? country;
  final String? countryCode;
  final String? featureCode;
  final double latitude;
  final double longitude;
  final String timezone;

  WeatherGeocodingResult toResult() {
    final segments = <String>[name, ?admin1, ?country];
    return WeatherGeocodingResult(
      displayName: segments.join(' / '),
      latitude: latitude,
      longitude: longitude,
      timezone: timezone,
    );
  }
}
