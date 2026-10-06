import 'dart:js_interop';

abstract class WeatherHttpClient {
  Future<String> get(String url);
}

class PlatformWeatherHttpClient implements WeatherHttpClient {
  @override
  Future<String> get(String url) async {
    final response = await _fetch(url.toJS).toDart;
    if (!response.ok.toDart) {
      throw StateError(
        'Weather request failed: HTTP ${response.status.toDartInt}',
      );
    }
    return (await response.text().toDart).toDart;
  }
}

@JS('fetch')
external JSPromise<_WebResponse> _fetch(JSString url);

extension type _WebResponse._(JSObject _) implements JSObject {
  external JSBoolean get ok;
  external JSNumber get status;
  external JSPromise<JSString> text();
}
