@JS()
library;

import 'dart:js_interop';

@JS('orAppPush.permission')
external JSString _permission();
@JS('orAppPush.timeZone')
external JSString _timeZone();
@JS('orAppPush.randomToken')
external JSString _randomToken(JSNumber bytes);
@JS('orAppPush.subscribe')
external JSPromise<JSString> _subscribe(JSString vapidPublicKey);
@JS('orAppPush.request')
external JSPromise<JSString> _request(
  JSString url,
  JSString method,
  JSString? token,
  JSString? body,
);
@JS('orAppPush.wallTimeToEpoch')
external JSNumber _wallTimeToEpoch(
  JSString localDate,
  JSString localTime,
  JSString timeZone,
);
@JS('orAppPush.serviceWorkerState')
external JSPromise<JSString> _serviceWorkerState();

class PushBridge {
  const PushBridge();
  String permission() => _permission().toDart;
  String timeZone() => _timeZone().toDart;
  String randomToken([int bytes = 32]) => _randomToken(bytes.toJS).toDart;
  Future<String> subscribe(String vapidPublicKey) async =>
      (await _subscribe(vapidPublicKey.toJS).toDart).toDart;
  Future<String> request(
    String url,
    String method, {
    String? token,
    String? body,
  }) async => (await _request(
    url.toJS,
    method.toJS,
    token?.toJS,
    body?.toJS,
  ).toDart).toDart;
  int wallTimeToEpoch(String localDate, String localTime, String timeZone) =>
      _wallTimeToEpoch(localDate.toJS, localTime.toJS, timeZone.toJS).toDartInt;
  Future<String> serviceWorkerState() async =>
      (await _serviceWorkerState().toDart).toDart;
}
