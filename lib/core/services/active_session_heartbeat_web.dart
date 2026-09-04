// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;

enum ActiveSessionClassification { newSession, activeSessionReentry }

class ActiveSessionResult {
  const ActiveSessionResult({
    required this.classification,
    required this.heartbeatPresent,
    this.heartbeatAgeMs,
  });

  final ActiveSessionClassification classification;
  final bool heartbeatPresent;
  final int? heartbeatAgeMs;
}

abstract class ActiveSessionStorage {
  String? read(String key);
  void write(String key, String value);
  void remove(String key);
}

class InMemoryActiveSessionStorage implements ActiveSessionStorage {
  InMemoryActiveSessionStorage([Map<String, String>? values])
    : values = values ?? <String, String>{};

  final Map<String, String> values;

  @override
  String? read(String key) => values[key];

  @override
  void remove(String key) => values.remove(key);

  @override
  void write(String key, String value) => values[key] = value;
}

class ActiveSessionHeartbeat {
  ActiveSessionHeartbeat({
    DateTime Function()? now,
    ActiveSessionStorage? storage,
    String? documentRunId,
    bool? initiallyVisible,
  }) : _now = now ?? DateTime.now,
       _storage = storage ?? _BrowserActiveSessionStorage(),
       documentRunId = documentRunId ?? _readDocumentRunId(),
       _visible =
           initiallyVisible ?? html.document.visibilityState != 'hidden' {
    _visibilitySubscription = html.document.onVisibilityChange.listen((_) {
      handleVisibilityChange(html.document.visibilityState != 'hidden');
    });
  }

  static final ActiveSessionHeartbeat instance = ActiveSessionHeartbeat();

  static const storageKey = 'or_app.active_session_heartbeat.v1';
  static const retiredReentryMarkerKey = 'or_app.startup_reentry_marker.v1';
  static const sessionTimeout = Duration(minutes: 10);
  static const heartbeatInterval = Duration(seconds: 20);
  static const _documentRunStorageKey =
      'or_app.startup_diagnostic.document_run_id';

  final DateTime Function() _now;
  final ActiveSessionStorage _storage;
  final String documentRunId;
  bool _visible;
  bool _writesSuppressed = false;
  Timer? _timer;
  StreamSubscription<html.Event>? _visibilitySubscription;
  ActiveSessionResult _result = const ActiveSessionResult(
    classification: ActiveSessionClassification.newSession,
    heartbeatPresent: false,
  );

  ActiveSessionResult get result => _result;

  bool resetHeartbeat() {
    try {
      _storage.remove(storageKey);
      _writesSuppressed = true;
      _timer?.cancel();
      _timer = null;
      return true;
    } catch (_) {
      return false;
    }
  }

  ActiveSessionResult classifyAtStartup() {
    try {
      _storage.remove(retiredReentryMarkerKey);
      final marker = _decode(_storage.read(storageKey));
      if (marker == null) {
        return _result = const ActiveSessionResult(
          classification: ActiveSessionClassification.newSession,
          heartbeatPresent: false,
        );
      }
      final age = _now().millisecondsSinceEpoch - marker.lastAliveAtMs;
      final active = age >= 0 && age < sessionTimeout.inMilliseconds;
      return _result = ActiveSessionResult(
        classification: active
            ? ActiveSessionClassification.activeSessionReentry
            : ActiveSessionClassification.newSession,
        heartbeatPresent: true,
        heartbeatAgeMs: age,
      );
    } catch (_) {
      return _result = const ActiveSessionResult(
        classification: ActiveSessionClassification.newSession,
        heartbeatPresent: false,
      );
    }
  }

  void start() {
    if (!_visible || _writesSuppressed) return;
    heartbeatNow();
    _timer ??= Timer.periodic(heartbeatInterval, (_) => heartbeatNow());
  }

  void handleVisibilityChange(bool visible) {
    if (_visible == visible) return;
    if (_writesSuppressed) {
      _visible = visible;
      _timer?.cancel();
      _timer = null;
      return;
    }
    if (visible) {
      _visible = true;
      start();
      return;
    }
    heartbeatNow();
    _visible = false;
    _timer?.cancel();
    _timer = null;
  }

  void heartbeatNow() {
    if (!_visible || _writesSuppressed) return;
    try {
      _storage.write(
        storageKey,
        jsonEncode({
          'version': 1,
          'lastAliveAtMs': _now().millisecondsSinceEpoch,
          'documentRunId': documentRunId,
        }),
      );
    } catch (_) {
      // Storage failure intentionally falls back to the normal Boot policy.
    }
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
    _visibilitySubscription?.cancel();
    _visibilitySubscription = null;
  }

  _HeartbeatMarker? _decode(String? raw) {
    if (raw == null) return null;
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return null;
    final version = decoded['version'];
    final lastAliveAtMs = decoded['lastAliveAtMs'];
    if (version != 1 || lastAliveAtMs is! int) return null;
    return _HeartbeatMarker(lastAliveAtMs);
  }

  static String _readDocumentRunId() {
    try {
      return html.window.sessionStorage[_documentRunStorageKey] ??
          'web-document';
    } catch (_) {
      return 'web-document';
    }
  }
}

class _BrowserActiveSessionStorage implements ActiveSessionStorage {
  @override
  String? read(String key) => html.window.localStorage[key];

  @override
  void remove(String key) => html.window.localStorage.remove(key);

  @override
  void write(String key, String value) => html.window.localStorage[key] = value;
}

class _HeartbeatMarker {
  const _HeartbeatMarker(this.lastAliveAtMs);
  final int lastAliveAtMs;
}
