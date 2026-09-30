abstract class WeatherHttpClient {
  Future<String> get(String url);
}

class PlatformWeatherHttpClient implements WeatherHttpClient {
  @override
  Future<String> get(String url) => Future.error(
    UnsupportedError('Weather is available in the web application.'),
  );
}
