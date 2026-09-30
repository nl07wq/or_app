import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/weather/weather_client_stub.dart';
import 'package:or_app/features/weather/weather_models.dart';
import 'package:or_app/features/weather/weather_service.dart';
import 'package:or_app/features/weather/weather_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const location = WeatherLocation(
    displayName: 'Sapporo / Hokkaido / Japan',
    latitude: 43.0618,
    longitude: 141.3545,
    timezone: 'Asia/Tokyo',
  );

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('maps Open-Meteo weather codes to stable presentation semantics', () {
    expect(weatherConditionForCode(0), WeatherCondition.clear);
    expect(weatherConditionForCode(80), WeatherCondition.showers);
    expect(weatherConditionForCode(95), WeatherCondition.thunder);
    expect(weatherConditionForCode(999), WeatherCondition.unknown);
  });

  test('persists the explicit location authority without GPS data', () async {
    final service = WeatherService(store: WeatherStore());

    await service.saveLocation(location);

    final reloaded = await service.loadLocation();
    expect(reloaded?.displayName, location.displayName);
    expect(reloaded?.latitude, location.latitude);
    expect(reloaded?.longitude, location.longitude);
    expect(reloaded?.timezone, 'Asia/Tokyo');
  });

  test('returns explicit geocoding candidates instead of selecting one', () async {
    final service = WeatherService(
      store: WeatherStore(),
      client: _FakeClient(
        response: jsonEncode({
          'results': [
            {
              'name': '札幌市',
              'admin1': 'Hokkaido',
              'country': 'Japan',
              'latitude': 43.0618,
              'longitude': 141.3545,
              'timezone': 'Asia/Tokyo',
            },
          ],
        }),
      ),
    );

    final results = await service.searchLocations('札幌');

    expect(results, hasLength(1));
    expect(results.single.displayName, contains('札幌市'));
    expect(results.single.timezone, 'Asia/Tokyo');
  });

  test('uses a fresh matching cache without a network request', () async {
    final store = WeatherStore();
    final now = DateTime.utc(2026, 9, 30, 1);
    await store.saveCache(_snapshot(location, now));
    final service = WeatherService(
      store: store,
      client: _FakeClient(),
      now: () => now.add(const Duration(minutes: 29)),
    );

    final result = await service.load(location);

    expect(result.isCached, isTrue);
    expect(result.isStale, isFalse);
    expect(result.snapshot?.daily, hasLength(7));
  });

  test('uses stale matching cache after a forecast failure', () async {
    final store = WeatherStore();
    final now = DateTime.utc(2026, 9, 30, 1);
    await store.saveCache(_snapshot(location, now));
    final service = WeatherService(
      store: store,
      client: _FakeClient(error: StateError('network unavailable')),
      now: () => now.add(const Duration(minutes: 31)),
    );

    final result = await service.load(location);

    expect(result.snapshot, isNotNull);
    expect(result.isCached, isTrue);
    expect(result.isStale, isTrue);
  });

  test(
    'fetches seven daily and hourly values in the saved location timezone',
    () async {
      final client = _FakeClient(response: _forecastResponse());
      final service = WeatherService(
        store: WeatherStore(),
        client: client,
        now: () => DateTime.utc(2026, 9, 30, 1),
      );

      final result = await service.load(location);

      expect(result.snapshot?.daily, hasLength(7));
      expect(result.snapshot?.hourly.first.time, '2026-09-30T00:00');
      expect(client.urls.single, contains('timezone=Asia%2FTokyo'));
    },
  );

  test('does not reuse cache for a different weather location', () async {
    final store = WeatherStore();
    await store.saveCache(_snapshot(location, DateTime.utc(2026, 9, 30, 1)));
    final service = WeatherService(
      store: store,
      client: _FakeClient(error: StateError('offline')),
      now: () => DateTime.utc(2026, 9, 30, 1, 5),
    );
    const other = WeatherLocation(
      displayName: 'Tokyo / Japan',
      latitude: 35.6762,
      longitude: 139.6503,
      timezone: 'Asia/Tokyo',
    );

    final result = await service.load(other);

    expect(result.snapshot, isNull);
    expect(result.error, isNotNull);
  });
}

class _FakeClient implements WeatherHttpClient {
  _FakeClient({this.response, this.error});

  final String? response;
  final Object? error;
  final urls = <String>[];

  @override
  Future<String> get(String url) {
    urls.add(url);
    if (error != null) return Future<String>.error(error!);
    return Future<String>.value(response!);
  }
}

WeatherSnapshot _snapshot(WeatherLocation location, DateTime fetchedAt) =>
    WeatherSnapshot(
      location: location,
      fetchedAt: fetchedAt,
      daily: List.generate(
        7,
        (index) => WeatherDaily(
          date: '2026-10-${(index + 1).toString().padLeft(2, '0')}',
          code: 0,
          high: 20,
          low: 10,
          precipitationProbability: 0,
          precipitation: 0,
          sunrise: '2026-10-01T05:30',
          sunset: '2026-10-01T17:00',
        ),
      ),
      hourly: const [],
    );

String _forecastResponse() => jsonEncode({
  'daily': {
    'time': [
      '2026-09-30',
      '2026-10-01',
      '2026-10-02',
      '2026-10-03',
      '2026-10-04',
      '2026-10-05',
      '2026-10-06',
    ],
    'weather_code': List.filled(7, 0),
    'temperature_2m_max': List.filled(7, 20),
    'temperature_2m_min': List.filled(7, 10),
    'precipitation_probability_max': List.filled(7, 10),
    'precipitation_sum': List.filled(7, 0),
    'sunrise': List.filled(7, '2026-09-30T05:30'),
    'sunset': List.filled(7, '2026-09-30T17:00'),
  },
  'hourly': {
    'time': ['2026-09-30T00:00'],
    'temperature_2m': [16],
    'apparent_temperature': [15],
    'relative_humidity_2m': [75],
    'precipitation_probability': [10],
    'precipitation': [0],
    'weather_code': [0],
    'cloud_cover': [15],
    'wind_speed_10m': [8],
    'wind_gusts_10m': [13],
  },
});
