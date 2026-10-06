import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/schedule/weather_forecast_summary.dart';
import 'package:or_app/features/weather/weather_models.dart';

void main() {
  test('summarizes all-day rain without inventing a transition', () {
    final summary = WeatherForecastSummaryEngine.summarize(
      day: _day(precipitation: 8),
      hourly: _hours(codeForHour: (_) => 61, precipitation: 1),
    );

    expect(summary.primary, '一日を通して雨が続く予報です。');
  });

  test('summarizes a cloudy-to-rain afternoon transition', () {
    final summary = WeatherForecastSummaryEngine.summarize(
      day: _day(precipitation: 4),
      hourly: _hours(codeForHour: (hour) => hour < 12 ? 3 : 61),
    );

    expect(summary.primary, contains('午前は曇り中心で、午後から雨'));
  });

  test(
    'reports late and intermittent rain at the correct daypart granularity',
    () {
      final late = WeatherForecastSummaryEngine.summarize(
        day: _day(precipitation: 3),
        hourly: _hours(codeForHour: (hour) => hour < 17 ? 3 : 61),
      );
      final intermittent = WeatherForecastSummaryEngine.summarize(
        day: _day(precipitation: .2),
        hourly: _hours(codeForHour: (hour) => hour == 17 ? 61 : 3),
      );

      expect(late.primary, contains('夕方頃から雨'));
      expect(intermittent.primary, contains('夕方に一時雨'));
    },
  );

  test('does not assert rain from probability alone', () {
    final summary = WeatherForecastSummaryEngine.summarize(
      day: _day(precipitation: 0, probability: 85),
      hourly: _hours(codeForHour: (_) => 3, precipitationProbability: 85),
    );

    expect(summary.primary, isNot(contains('雨')));
    expect(summary.primary, contains('曇り'));
  });

  test('adds a wind trend only when the hourly data supports it', () {
    final windy = WeatherForecastSummaryEngine.summarize(
      day: _day(),
      hourly: _hours(
        codeForHour: (_) => 0,
        windForHour: (hour) => hour >= 12 && hour < 17 ? 18 : 5,
        gustForHour: (hour) => hour >= 12 && hour < 17 ? 42 : 9,
      ),
    );
    final calm = WeatherForecastSummaryEngine.summarize(
      day: _day(),
      hourly: _hours(codeForHour: (_) => 0),
    );

    expect(windy.supporting.join(' '), contains('午後は風が強まり'));
    expect(calm.supporting.join(' '), isNot(contains('風が強まり')));
  });

  test('uses a deterministic missing-data fallback', () {
    final first = WeatherForecastSummaryEngine.summarize(
      day: _day(),
      hourly: const [],
    );
    final second = WeatherForecastSummaryEngine.summarize(
      day: _day(),
      hourly: const [],
    );

    expect(first.primary, 'この日の詳細な時間変化は確認できません。');
    expect(second.primary, first.primary);
  });

  test('keeps a stable clear forecast concise and deterministic', () {
    final hourly = _hours(codeForHour: (_) => 0);
    final first = WeatherForecastSummaryEngine.summarize(
      day: _day(),
      hourly: hourly,
    );
    final second = WeatherForecastSummaryEngine.summarize(
      day: _day(),
      hourly: hourly,
    );

    expect(first.primary, '一日を通して晴れ中心の予報です。');
    expect(second.primary, first.primary);
    expect(second.supporting, first.supporting);
  });
}

WeatherDaily _day({double precipitation = 0, int probability = 20}) =>
    WeatherDaily(
      date: '2026-10-02',
      code: 3,
      high: 24,
      low: 16,
      precipitationProbability: probability,
      precipitation: precipitation,
      sunrise: '2026-10-02T05:30',
      sunset: '2026-10-02T17:20',
    );

List<WeatherHourly> _hours({
  required int Function(int hour) codeForHour,
  double precipitation = 0,
  int precipitationProbability = 20,
  double Function(int hour)? windForHour,
  double Function(int hour)? gustForHour,
}) => [
  for (var hour = 0; hour < 24; hour++)
    WeatherHourly(
      time: '2026-10-02T${hour.toString().padLeft(2, '0')}:00',
      temperature: 20,
      apparentTemperature: 20,
      humidity: 60,
      precipitationProbability: precipitationProbability,
      precipitation: precipitation,
      code: codeForHour(hour),
      cloudCover: 50,
      windSpeed: windForHour?.call(hour) ?? 5,
      windGust: gustForHour?.call(hour) ?? 9,
    ),
];
