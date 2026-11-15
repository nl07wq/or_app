import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/schedule/pages/calendar_page.dart';
import 'package:or_app/features/weather/weather_models.dart';

void main() {
  test('Calendar integrates generation gating without dropping reloads', () {
    final source = File(
      'lib/features/schedule/pages/calendar_page.dart',
    ).readAsStringSync();

    expect(source, contains('_weatherLoadGeneration.begin()'));
    expect(source, contains('_weatherLoadGeneration.owns(generation)'));
    expect(source, isNot(contains('if (_weatherLoading) return;')));
    expect(source, contains('_weatherPreferences = preferences'));
    expect(source, contains("'FORECAST SYNC UNAVAILABLE'"));
    expect(source, contains("'WEATHER LOCATION UNAVAILABLE'"));
  });

  test('new weather requests supersede every older generation', () {
    final generations = WeatherLoadGeneration();

    final first = generations.begin();
    final second = generations.begin();

    expect(generations.owns(first), isFalse);
    expect(generations.owns(second), isTrue);
  });

  test('saved locations recover a missing or invalid active identity', () {
    const location = WeatherLocation(
      displayName: 'Tokyo / Japan',
      latitude: 35.6762,
      longitude: 139.6503,
      timezone: 'Asia/Tokyo',
    );

    final preferences = WeatherLocationPreferences.fromJson({
      'locations': [location.toJson()],
      'activeLocationId': 'missing-location',
    });

    expect(preferences.activeLocation?.stableId, location.stableId);
  });
}
