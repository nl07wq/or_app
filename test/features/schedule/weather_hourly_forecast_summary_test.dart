import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/schedule/weather_forecast_summary.dart';
import 'package:or_app/features/weather/weather_models.dart';

void main() {
  test('keeps a stable clear hour concise and deterministic', () {
    final hours = _hours();
    final first = WeatherHourlyForecastSummaryEngine.summarize(
      hourly: hours,
      index: 1,
    );
    final second = WeatherHourlyForecastSummaryEngine.summarize(
      hourly: hours,
      index: 1,
    );

    expect(first.primary, '晴れが続き、降水の可能性は低い予報です。');
    expect(second.primary, first.primary);
    expect(second.supporting, first.supporting);
  });

  test('distinguishes rain starting, continuing, and ending', () {
    final starting = WeatherHourlyForecastSummaryEngine.summarize(
      hourly: _hours(codes: [3, 61, 61]),
      index: 1,
    );
    final continuing = WeatherHourlyForecastSummaryEngine.summarize(
      hourly: _hours(codes: [61, 61, 61]),
      index: 1,
    );
    final ending = WeatherHourlyForecastSummaryEngine.summarize(
      hourly: _hours(codes: [61, 61, 3]),
      index: 1,
    );

    expect(starting.primary, contains('この時間から雨'));
    expect(continuing.primary, contains('雨が続く'));
    expect(ending.primary, contains('その後は弱まる'));
  });

  test('adds wind and temperature trends only when meaningful', () {
    final wind = WeatherHourlyForecastSummaryEngine.summarize(
      hourly: _hours(winds: [5, 12, 12], gusts: [9, 20, 20]),
      index: 0,
    );
    final rising = WeatherHourlyForecastSummaryEngine.summarize(
      hourly: _hours(temperatures: [18, 21, 22]),
      index: 0,
    );
    final falling = WeatherHourlyForecastSummaryEngine.summarize(
      hourly: _hours(temperatures: [22, 19, 18]),
      index: 0,
    );

    expect(wind.supporting.join(' '), contains('風が強まる'));
    expect(rising.supporting.join(' '), contains('気温が上がる'));
    expect(falling.supporting.join(' '), contains('気温が下がる'));
  });

  test(
    'does not assert rain from probability alone and handles missing data',
    () {
      final probabilityOnly = WeatherHourlyForecastSummaryEngine.summarize(
        hourly: _hours(probabilities: [85, 85, 85]),
        index: 1,
      );
      final missing = WeatherHourlyForecastSummaryEngine.summarize(
        hourly: const [],
        index: 0,
      );

      expect(probabilityOnly.primary, isNot(contains('雨')));
      expect(missing.primary, 'この時間の詳細な予報は確認できません。');
    },
  );
}

List<WeatherHourly> _hours({
  List<int> codes = const [0, 0, 0],
  List<double> temperatures = const [20, 20, 20],
  List<double> winds = const [5, 5, 5],
  List<double> gusts = const [9, 9, 9],
  List<int> probabilities = const [20, 20, 20],
}) => [
  for (var index = 0; index < codes.length; index++)
    WeatherHourly(
      time: '2026-10-02T${(12 + index).toString().padLeft(2, '0')}:00',
      temperature: temperatures[index],
      apparentTemperature: temperatures[index],
      humidity: 60,
      precipitationProbability: probabilities[index],
      precipitation: 0,
      code: codes[index],
      cloudCover: 30,
      windSpeed: winds[index],
      windGust: gusts[index],
    ),
];
