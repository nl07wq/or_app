import 'dart:convert';

class WeatherLocation {
  const WeatherLocation({
    required this.displayName,
    required this.latitude,
    required this.longitude,
    required this.timezone,
    this.id,
  });
  final String? id;
  final String displayName;
  final double latitude;
  final double longitude;
  final String timezone;
  String get stableId =>
      id ??
      'weather_${latitude.toStringAsFixed(5)}_${longitude.toStringAsFixed(5)}_$timezone';
  Map<String, Object> toJson() => {
    'id': stableId,
    'displayName': displayName,
    'latitude': latitude,
    'longitude': longitude,
    'timezone': timezone,
  };
  factory WeatherLocation.fromJson(Map<String, Object?> json) =>
      WeatherLocation(
        id: json['id'] as String?,
        displayName: json['displayName'] as String,
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        timezone: json['timezone'] as String,
      );
}

class WeatherLocationPreferences {
  const WeatherLocationPreferences({
    required this.locations,
    required this.activeLocationId,
  });

  static const maximumLocations = 3;
  final List<WeatherLocation> locations;
  final String? activeLocationId;
  WeatherLocation? get activeLocation {
    for (final location in locations) {
      if (location.stableId == activeLocationId) return location;
    }
    return null;
  }

  Map<String, Object?> toJson() => {
    'locations': locations.map((location) => location.toJson()).toList(),
    'activeLocationId': activeLocationId,
  };
  factory WeatherLocationPreferences.fromJson(Map<String, Object?> json) {
    final locations = (json['locations'] as List)
        .map(
          (value) =>
              WeatherLocation.fromJson(Map<String, Object?>.from(value as Map)),
        )
        .toList(growable: false);
    final active = json['activeLocationId'] as String?;
    return WeatherLocationPreferences(
      locations: locations,
      activeLocationId: locations.any((location) => location.stableId == active)
          ? active
          : (locations.isEmpty ? null : locations.first.stableId),
    );
  }
}

enum WeatherCondition {
  clear,
  mainlyClear,
  partlyCloudy,
  cloudy,
  fog,
  drizzle,
  rain,
  showers,
  snow,
  thunder,
  unknown,
}

WeatherCondition weatherConditionForCode(int code) => switch (code) {
  0 => WeatherCondition.clear,
  1 => WeatherCondition.mainlyClear,
  2 => WeatherCondition.partlyCloudy,
  3 => WeatherCondition.cloudy,
  45 || 48 => WeatherCondition.fog,
  51 || 53 || 55 || 56 || 57 => WeatherCondition.drizzle,
  61 || 63 || 65 || 66 || 67 => WeatherCondition.rain,
  80 || 81 || 82 => WeatherCondition.showers,
  71 || 73 || 75 || 77 || 85 || 86 => WeatherCondition.snow,
  95 || 96 || 99 => WeatherCondition.thunder,
  _ => WeatherCondition.unknown,
};
String weatherConditionLabel(WeatherCondition value) => switch (value) {
  WeatherCondition.clear => 'CLEAR',
  WeatherCondition.mainlyClear => 'MAINLY CLEAR',
  WeatherCondition.partlyCloudy => 'PARTLY CLOUDY',
  WeatherCondition.cloudy => 'CLOUDY',
  WeatherCondition.fog => 'FOG',
  WeatherCondition.drizzle => 'DRIZZLE',
  WeatherCondition.rain => 'RAIN',
  WeatherCondition.showers => 'SHOWERS',
  WeatherCondition.snow => 'SNOW',
  WeatherCondition.thunder => 'THUNDER',
  WeatherCondition.unknown => 'UNKNOWN',
};

class WeatherDaily {
  const WeatherDaily({
    required this.date,
    required this.code,
    required this.high,
    required this.low,
    required this.precipitationProbability,
    required this.precipitation,
    required this.sunrise,
    required this.sunset,
    this.uvIndexMax,
    this.windSpeedMax,
  });
  final String date;
  final int code;
  final double high;
  final double low;
  final int precipitationProbability;
  final double precipitation;
  final String sunrise;
  final String sunset;
  final double? uvIndexMax;
  final double? windSpeedMax;
  Map<String, Object> toJson() {
    final optional = <String, Object>{};
    if (uvIndexMax != null) optional['uvIndexMax'] = uvIndexMax!;
    if (windSpeedMax != null) optional['windSpeedMax'] = windSpeedMax!;
    return {
      'date': date,
      'code': code,
      'high': high,
      'low': low,
      'precipitationProbability': precipitationProbability,
      'precipitation': precipitation,
      'sunrise': sunrise,
      'sunset': sunset,
      ...optional,
    };
  }

  factory WeatherDaily.fromJson(Map<String, Object?> json) => WeatherDaily(
    date: json['date'] as String,
    code: json['code'] as int,
    high: (json['high'] as num).toDouble(),
    low: (json['low'] as num).toDouble(),
    precipitationProbability: json['precipitationProbability'] as int,
    precipitation: (json['precipitation'] as num).toDouble(),
    sunrise: json['sunrise'] as String,
    sunset: json['sunset'] as String,
    uvIndexMax: (json['uvIndexMax'] as num?)?.toDouble(),
    windSpeedMax: (json['windSpeedMax'] as num?)?.toDouble(),
  );
}

class WeatherHourly {
  const WeatherHourly({
    required this.time,
    required this.temperature,
    required this.apparentTemperature,
    required this.humidity,
    required this.precipitationProbability,
    required this.precipitation,
    required this.code,
    required this.cloudCover,
    required this.windSpeed,
    required this.windGust,
    this.dewPoint,
    this.windDirection,
    this.surfacePressure,
    this.visibility,
    this.uvIndex,
  });
  final String time;
  final double temperature;
  final double apparentTemperature;
  final int humidity;
  final int precipitationProbability;
  final double precipitation;
  final int code;
  final int cloudCover;
  final double windSpeed;
  final double windGust;
  final double? dewPoint;
  final double? windDirection;
  final double? surfacePressure;
  final double? visibility;
  final double? uvIndex;
  Map<String, Object> toJson() {
    final optional = <String, Object>{};
    if (dewPoint != null) optional['dewPoint'] = dewPoint!;
    if (windDirection != null) optional['windDirection'] = windDirection!;
    if (surfacePressure != null) {
      optional['surfacePressure'] = surfacePressure!;
    }
    if (visibility != null) optional['visibility'] = visibility!;
    if (uvIndex != null) optional['uvIndex'] = uvIndex!;
    return {
      'time': time,
      'temperature': temperature,
      'apparentTemperature': apparentTemperature,
      'humidity': humidity,
      'precipitationProbability': precipitationProbability,
      'precipitation': precipitation,
      'code': code,
      'cloudCover': cloudCover,
      'windSpeed': windSpeed,
      'windGust': windGust,
      ...optional,
    };
  }

  factory WeatherHourly.fromJson(Map<String, Object?> json) => WeatherHourly(
    time: json['time'] as String,
    temperature: (json['temperature'] as num).toDouble(),
    apparentTemperature: (json['apparentTemperature'] as num).toDouble(),
    humidity: json['humidity'] as int,
    precipitationProbability: json['precipitationProbability'] as int,
    precipitation: (json['precipitation'] as num).toDouble(),
    code: json['code'] as int,
    cloudCover: json['cloudCover'] as int,
    windSpeed: (json['windSpeed'] as num).toDouble(),
    windGust: (json['windGust'] as num).toDouble(),
    dewPoint: (json['dewPoint'] as num?)?.toDouble(),
    windDirection: (json['windDirection'] as num?)?.toDouble(),
    surfacePressure: (json['surfacePressure'] as num?)?.toDouble(),
    visibility: (json['visibility'] as num?)?.toDouble(),
    uvIndex: (json['uvIndex'] as num?)?.toDouble(),
  );
}

class WeatherSnapshot {
  const WeatherSnapshot({
    required this.location,
    required this.fetchedAt,
    required this.daily,
    required this.hourly,
  });
  final WeatherLocation location;
  final DateTime fetchedAt;
  final List<WeatherDaily> daily;
  final List<WeatherHourly> hourly;
  String encode() => jsonEncode({
    'provider': 'open-meteo',
    'cacheVersion': 5,
    'location': location.toJson(),
    'fetchedAt': fetchedAt.toUtc().toIso8601String(),
    'daily': daily.map((v) => v.toJson()).toList(),
    'hourly': hourly.map((v) => v.toJson()).toList(),
  });
  factory WeatherSnapshot.decode(String source) {
    final json = Map<String, Object?>.from(jsonDecode(source) as Map);
    return WeatherSnapshot(
      location: WeatherLocation.fromJson(
        Map<String, Object?>.from(json['location'] as Map),
      ),
      fetchedAt: DateTime.parse(json['fetchedAt'] as String).toUtc(),
      daily: (json['daily'] as List)
          .map(
            (v) => WeatherDaily.fromJson(Map<String, Object?>.from(v as Map)),
          )
          .toList(),
      hourly: (json['hourly'] as List)
          .map(
            (v) => WeatherHourly.fromJson(Map<String, Object?>.from(v as Map)),
          )
          .toList(),
    );
  }
}

class WeatherGeocodingResult {
  const WeatherGeocodingResult({
    required this.displayName,
    required this.latitude,
    required this.longitude,
    required this.timezone,
  });
  final String displayName;
  final double latitude;
  final double longitude;
  final String timezone;
  WeatherLocation toLocation() => WeatherLocation(
    displayName: displayName,
    latitude: latitude,
    longitude: longitude,
    timezone: timezone,
  );
}
