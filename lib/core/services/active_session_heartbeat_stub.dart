import 'dart:async';
import 'dart:convert';

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

/// Defines the user-facing OR-APP session independently of HTML documents.
class ActiveSessionHeartbeat {
  ActiveSessionHeartbeat({
    DateTime Function()? now,
    ActiveSessionStorage? storage,
    this.documentRunId = 'non-web-document',
    bool initiallyVisible = true,
  }) : _now = now ?? DateTime.now,
       _storage = storage ?? InMemoryActiveSessionStorage(),
       _visible = initiallyVisible;

  static final ActiveSessionHeartbeat instance = ActiveSessionHeartbeat();

  static const storageKey = 'or_app.active_session_heartbeat.v1';
  static const retiredReentryMarkerKey = 'or_app.startup_reentry_marker.v1';
  static const sessionTimeout = Duration(minutes: 10);
  static const heartbeatInterval = Duration(seconds: 20);

  final DateTime Function() _now;
  final ActiveSessionStorage _storage;
  final String documentRunId;
  bool _visible;
  bool _writesSuppressed = false;
  Timer? _timer;
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
      // The former PAGEHIDE-age marker is intentionally retired. It must not
      // influence the heartbeat-based session decision after this release.
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
    // Preserve the actual last-active instant without continuing to refresh
    // it while the document is backgrounded.
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
      // Lifecycle diagnostics/storage must never block application startup.
    }
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
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
}

class _HeartbeatMarker {
  const _HeartbeatMarker(this.lastAliveAtMs);
  final int lastAliveAtMs;
}
