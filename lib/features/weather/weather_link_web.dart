import 'dart:js_interop';

Future<void> openWeatherProviderSite() async {
  _open('https://open-meteo.com/'.toJS, 'open-meteo'.toJS);
}

@JS('open')
external JSAny? _open(JSString url, JSString target);
