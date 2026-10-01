import '../weather/weather_models.dart';

enum WeatherDaypart { preDawn, morning, lateMorning, afternoon, evening, night }

extension on WeatherDaypart {
  String get label => switch (this) {
    WeatherDaypart.preDawn => '未明',
    WeatherDaypart.morning => '朝',
    WeatherDaypart.lateMorning => '午前',
    WeatherDaypart.afternoon => '午後',
    WeatherDaypart.evening => '夕方',
    WeatherDaypart.night => '夜',
  };
}

class WeatherForecastSummary {
  const WeatherForecastSummary({
    required this.primary,
    required this.supporting,
    required this.strongestWindDaypart,
  });

  final String primary;
  final List<String> supporting;
  final WeatherDaypart? strongestWindDaypart;
}

/// Presentation-only, deterministic forecast interpretation. It deliberately
/// consumes the existing forecast payload and never makes a network request.
abstract final class WeatherForecastSummaryEngine {
  static WeatherForecastSummary summarize({
    required WeatherDaily day,
    required List<WeatherHourly> hourly,
  }) {
    if (hourly.isEmpty) {
      return const WeatherForecastSummary(
        primary: 'この日の詳細な時間変化は確認できません。',
        supporting: [],
        strongestWindDaypart: null,
      );
    }

    final grouped = <WeatherDaypart, List<WeatherHourly>>{};
    for (final value in hourly) {
      (grouped[_daypartFor(value.time)] ??= []).add(value);
    }
    final dayparts =
        grouped.entries
            .map(
              (entry) => _DaypartForecast(
                daypart: entry.key,
                values: entry.value,
                condition: _dominantCondition(entry.value),
                rainy: _isRainy(entry.value),
              ),
            )
            .toList()
          ..sort((a, b) => a.daypart.index.compareTo(b.daypart.index));

    final rainyParts = dayparts.where((part) => part.rainy).toList();
    final main = _conditionSummary(dayparts, rainyParts);
    final supporting = <String>[];
    final peakProbability = hourly
        .map((value) => value.precipitationProbability)
        .reduce((a, b) => a > b ? a : b);
    if (day.precipitation > 0 || peakProbability > 0) {
      final peak = dayparts.reduce(
        (a, b) => a.maxPrecipitationProbability >= b.maxPrecipitationProbability
            ? a
            : b,
      );
      supporting.add(
        '降水 ${day.precipitation.toStringAsFixed(1)}mm · 最大降水確率 $peakProbability%（${peak.daypart.label}）',
      );
    }

    final strongestWind = dayparts.reduce(
      (a, b) => a.maxWindGust >= b.maxWindGust ? a : b,
    );
    final calmReference =
        hourly.map((value) => value.windSpeed).reduce((a, b) => a + b) /
        hourly.length;
    if (strongestWind.maxWindGust >= 30 ||
        strongestWind.maxWindSpeed >= calmReference + 8) {
      supporting.add(
        '${strongestWind.daypart.label}は風が強まり、最大突風 ${strongestWind.maxWindGust.round()}km/h の予報です。',
      );
    } else if (day.high - day.low >= 9) {
      supporting.add('日中と朝晩の気温差は約 ${(day.high - day.low).round()}° の予報です。');
    }

    return WeatherForecastSummary(
      primary: main,
      supporting: supporting,
      strongestWindDaypart: strongestWind.daypart,
    );
  }

  static String _conditionSummary(
    List<_DaypartForecast> parts,
    List<_DaypartForecast> rainyParts,
  ) {
    final rainyHours = rainyParts.fold<int>(
      0,
      (sum, part) => sum + part.values.length,
    );
    // A scattered single rainy hour in several dayparts is intermittent, not
    // an all-day rain forecast. Require broad duration as well as spread.
    if (rainyHours >= 16 || (rainyParts.length >= 5 && rainyHours >= 12)) {
      return '一日を通して雨が続く予報です。';
    }
    if (rainyParts.isNotEmpty) {
      final firstRain = rainyParts.first;
      if (rainyHours <= 3) return '${firstRain.daypart.label}に一時雨の可能性があります。';
      if (firstRain.daypart == WeatherDaypart.evening ||
          firstRain.daypart == WeatherDaypart.night) {
        return '${firstRain.daypart.label}頃から雨が降りやすくなる予報です。';
      }
      final before = parts
          .where((part) => part.daypart.index < firstRain.daypart.index)
          .toList();
      final beforeCondition = before.isEmpty ? null : before.last.condition;
      if (beforeCondition != null) {
        return '${before.last.daypart.label}は${_conditionName(beforeCondition)}中心で、${firstRain.daypart.label}から雨の予報です。';
      }
      return '${firstRain.daypart.label}から雨の予報です。';
    }

    final dominant = _dominantPartCondition(parts);
    final changes = parts.where((part) => part.condition != dominant).toList();
    if (changes.isEmpty) return '一日を通して${_conditionName(dominant)}中心の予報です。';
    final firstChange = changes.first;
    final before = parts
        .where((part) => part.daypart.index < firstChange.daypart.index)
        .toList();
    if (before.isNotEmpty) {
      return '${before.last.daypart.label}は${_conditionName(before.last.condition)}で、${firstChange.daypart.label}は${_conditionName(firstChange.condition)}中心の予報です。';
    }
    return '${firstChange.daypart.label}は${_conditionName(firstChange.condition)}中心の予報です。';
  }

  static WeatherDaypart _daypartFor(String time) {
    final hour = DateTime.tryParse(time)?.hour ?? 0;
    if (hour < 6) return WeatherDaypart.preDawn;
    if (hour < 9) return WeatherDaypart.morning;
    if (hour < 12) return WeatherDaypart.lateMorning;
    if (hour < 17) return WeatherDaypart.afternoon;
    if (hour < 20) return WeatherDaypart.evening;
    return WeatherDaypart.night;
  }

  static WeatherCondition _dominantCondition(List<WeatherHourly> values) {
    final counts = <WeatherCondition, int>{};
    for (final value in values) {
      final condition = weatherConditionForCode(value.code);
      counts[condition] = (counts[condition] ?? 0) + 1;
    }
    return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  static WeatherCondition _dominantPartCondition(List<_DaypartForecast> parts) {
    final counts = <WeatherCondition, int>{};
    for (final part in parts) {
      counts[part.condition] = (counts[part.condition] ?? 0) + 1;
    }
    return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  static bool _isRainy(List<WeatherHourly> values) => values.any(
    (value) => switch (weatherConditionForCode(value.code)) {
      WeatherCondition.drizzle ||
      WeatherCondition.rain ||
      WeatherCondition.showers ||
      WeatherCondition.thunder => true,
      _ => value.precipitation >= .2,
    },
  );

  static String _conditionName(WeatherCondition condition) =>
      switch (condition) {
        WeatherCondition.clear || WeatherCondition.mainlyClear => '晴れ',
        WeatherCondition.partlyCloudy => '晴れ時々曇り',
        WeatherCondition.cloudy => '曇り',
        WeatherCondition.fog => '霧',
        WeatherCondition.drizzle => '霧雨',
        WeatherCondition.rain || WeatherCondition.showers => '雨',
        WeatherCondition.snow => '雪',
        WeatherCondition.thunder => '雷雨',
        WeatherCondition.unknown => '変わりやすい天気',
      };
}

class _DaypartForecast {
  const _DaypartForecast({
    required this.daypart,
    required this.values,
    required this.condition,
    required this.rainy,
  });

  final WeatherDaypart daypart;
  final List<WeatherHourly> values;
  final WeatherCondition condition;
  final bool rainy;

  int get maxPrecipitationProbability => values
      .map((value) => value.precipitationProbability)
      .reduce((a, b) => a > b ? a : b);
  double get maxWindSpeed =>
      values.map((value) => value.windSpeed).reduce((a, b) => a > b ? a : b);
  double get maxWindGust =>
      values.map((value) => value.windGust).reduce((a, b) => a > b ? a : b);
}
