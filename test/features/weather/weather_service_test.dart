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

  test('persists active multi-location authority without GPS data', () async {
    final service = WeatherService(store: WeatherStore());

    await service.addLocation(location);

    final reloaded = await service.loadActiveLocation();
    expect(reloaded?.displayName, location.displayName);
    expect(reloaded?.latitude, location.latitude);
    expect(reloaded?.longitude, location.longitude);
    expect(reloaded?.timezone, 'Asia/Tokyo');
  });

  test(
    'uses bounded Japanese suffix normalization without Latin aliases',
    () async {
      final client = _SequenceClient([
        _geocodingResponse('市原', featureCode: 'PPL', admin1: '熊本県'),
        _geocodingResponse('市原市', featureCode: 'PPLA2', admin1: '千葉県'),
      ]);
      final results = await WeatherService(
        store: WeatherStore(),
        client: client,
      ).searchLocations('市原');

      expect(results.single.displayName, contains('市原市'));
      expect(client.urls, hasLength(2));
      expect(client.urls.first, contains('name=%E5%B8%82%E5%8E%9F'));
      expect(client.urls.last, contains('name=%E5%B8%82%E5%8E%9F%E5%B8%82'));
      expect(client.urls.every((url) => url.contains('language=ja')), isTrue);
      expect(
        client.urls.every((url) => url.contains('countryCode=JP')),
        isTrue,
      );
    },
  );

  test(
    'keeps successful native Japanese geocoding as the provider query',
    () async {
      final client = _FakeClient(response: _geocodingResponse('市原市'));
      final results = await WeatherService(
        store: WeatherStore(),
        client: client,
      ).searchLocations('市原');

      expect(results.single.displayName, contains('市原市'));
      expect(client.urls, hasLength(1));
      expect(client.urls.single, contains('name=%E5%B8%82%E5%8E%9F'));
    },
  );

  test('supports generalized Japanese municipality queries', () async {
    const cityQueries = ['千葉', '市原', '札幌', '大阪', '静岡', '横浜', '名古屋', '京都', '福岡'];
    for (final query in cityQueries) {
      final client = _SequenceClient([
        jsonEncode({}),
        _geocodingResponse('$query市', featureCode: 'PPLA'),
      ]);

      final results = await WeatherService(
        store: WeatherStore(),
        client: client,
      ).searchLocations(query);

      expect(results, hasLength(1));
      expect(client.urls, hasLength(2));
      expect(client.urls.last, contains('language=ja'));
      expect(client.urls.last, isNot(contains('name=Chiba')));
    }
  });

  test(
    'uses the bounded administrative variant when a city variant is absent',
    () async {
      final client = _SequenceClient([
        jsonEncode({}),
        jsonEncode({}),
        _geocodingResponse('東京都', featureCode: 'PPLC', admin1: '東京都'),
      ]);
      final results = await WeatherService(
        store: WeatherStore(),
        client: client,
      ).searchLocations('東京');

      expect(results.single.displayName, contains('東京都'));
      expect(client.urls, hasLength(3));
      expect(client.urls.last, contains('name=%E6%9D%B1%E4%BA%AC%E9%83%BD'));
    },
  );

  test(
    'ranks a matching Japanese municipality above unrelated provider results',
    () async {
      final client = _SequenceClient([
        jsonEncode({
          'results': [
            _result('Chibana', 26.3, 127.8, featureCode: 'PPL'),
            _result('千葉ニュータウン', 35.8, 140.1, featureCode: 'PPL'),
          ],
        }),
        jsonEncode({
          'results': [_result('千葉市', 35.6, 140.1, featureCode: 'PPLA')],
        }),
      ]);
      final results = await WeatherService(
        store: WeatherStore(),
        client: client,
      ).searchLocations('千葉');

      expect(results.first.displayName, startsWith('千葉市'));
      expect(
        results.any((result) => result.displayName.startsWith('Chibana')),
        isFalse,
      );
    },
  );

  test('keeps English geocoding as a single provider query', () async {
    for (final query in ['chiba', 'ichihara', 'sapporo', 'tokyo', 'shizuoka']) {
      final client = _FakeClient(response: _geocodingResponse('Tokyo'));
      final results = await WeatherService(
        store: WeatherStore(),
        client: client,
      ).searchLocations(query);

      expect(results, hasLength(1));
      expect(client.urls, hasLength(1));
      expect(client.urls.single, contains('name=$query'));
    }
  });

  test(
    'limits saved locations to three and persists an explicit active location',
    () async {
      final service = WeatherService(store: WeatherStore());
      final tokyo = _location('Tokyo', 35.6762, 139.6503);
      final osaka = _location('Osaka', 34.6937, 135.5023);

      await service.addLocation(location);
      await service.addLocation(tokyo);
      await service.addLocation(osaka);
      await service.setActiveLocation(tokyo.stableId);

      final saved = await service.loadLocations();
      expect(saved.locations, hasLength(3));
      expect(saved.activeLocation?.stableId, tokyo.stableId);
      await expectLater(
        service.addLocation(_location('Chiba', 35.6074, 140.1065)),
        throwsA(isA<StateError>()),
      );
      await expectLater(service.addLocation(tokyo), throwsA(isA<StateError>()));
    },
  );

  test(
    'migrates the V1 location into the first active V1.1 location',
    () async {
      SharedPreferences.setMockInitialValues({
        'weather.location.v1': jsonEncode(location.toJson()),
      });

      final preferences = await WeatherStore().loadLocations();

      expect(preferences.locations, hasLength(1));
      expect(preferences.activeLocation?.stableId, location.stableId);
    },
  );

  test(
    'removing the active location selects the first remaining location',
    () async {
      final service = WeatherService(store: WeatherStore());
      final tokyo = _location('Tokyo', 35.6762, 139.6503);
      await service.addLocation(location);
      await service.addLocation(tokyo);
      await service.setActiveLocation(tokyo.stableId);

      await service.removeLocation(tokyo.stableId);

      expect(
        (await service.loadLocations()).activeLocation?.stableId,
        location.stableId,
      );
    },
  );

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
      expect(result.snapshot?.daily.first.uvIndexMax, 3);
      expect(result.snapshot?.hourly.first.dewPoint, 11);
      expect(result.snapshot?.hourly.first.windDirection, 25);
      expect(result.snapshot?.hourly.first.surfacePressure, 1012);
      expect(result.snapshot?.hourly.first.visibility, 24000);
      expect(result.snapshot?.hourly.first.uvIndex, 1);
      expect(client.urls.single, contains('timezone=Asia%2FTokyo'));
      expect(client.urls.single, contains('dew_point_2m'));
      expect(client.urls.single, contains('uv_index_max'));
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

class _SequenceClient implements WeatherHttpClient {
  _SequenceClient(this.responses);

  final List<String> responses;
  final urls = <String>[];

  @override
  Future<String> get(String url) {
    urls.add(url);
    if (responses.isEmpty) {
      return Future<String>.error(StateError('Unexpected request'));
    }
    return Future<String>.value(responses.removeAt(0));
  }
}

WeatherLocation _location(String name, double latitude, double longitude) =>
    WeatherLocation(
      displayName: '$name / Japan',
      latitude: latitude,
      longitude: longitude,
      timezone: 'Asia/Tokyo',
    );

String _geocodingResponse(
  String name, {
  String admin1 = '千葉県',
  String featureCode = 'PPLA',
}) => jsonEncode({
  'results': [
    _result(name, 35.4973, 140.1158, admin1: admin1, featureCode: featureCode),
  ],
});

Map<String, Object> _result(
  String name,
  double latitude,
  double longitude, {
  String admin1 = '千葉県',
  String featureCode = 'PPLA',
}) => {
  'name': name,
  'admin1': admin1,
  'country': '日本',
  'country_code': 'JP',
  'feature_code': featureCode,
  'latitude': latitude,
  'longitude': longitude,
  'timezone': 'Asia/Tokyo',
};

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
    'uv_index_max': List.filled(7, 3),
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
    'dew_point_2m': [11],
    'wind_direction_10m': [25],
    'surface_pressure': [1012],
    'visibility': [24000],
    'uv_index': [1],
  },
});
