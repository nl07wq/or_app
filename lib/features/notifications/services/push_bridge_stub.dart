class PushBridge {
  const PushBridge();
  String permission() => 'unsupported';
  String timeZone() => 'Etc/UTC';
  String randomToken([int bytes = 32]) =>
      'unsupported_${DateTime.now().microsecondsSinceEpoch}';
  Future<String> subscribe(String vapidPublicKey) =>
      Future.error(UnsupportedError('Web Push is unavailable.'));
  Future<String> request(
    String url,
    String method, {
    String? token,
    String? body,
  }) => Future.error(UnsupportedError('Notification API is unavailable.'));
  int wallTimeToEpoch(String localDate, String localTime, String timeZone) =>
      DateTime.parse('${localDate}T$localTime:00Z').millisecondsSinceEpoch;
  Future<String> serviceWorkerState() async => 'unsupported';
}
