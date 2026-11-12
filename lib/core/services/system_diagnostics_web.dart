// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;

class SystemDiagnostics {
  SystemDiagnostics({this.eventLimit = 200, this.sessionLimit = 5});

  static final SystemDiagnostics instance = SystemDiagnostics();
  static const storageKey = 'or_app.system_diagnostics.v2';
  static const _flushDelay = Duration(milliseconds: 500);
  static const _heartbeatInterval = Duration(seconds: 20);

  final int eventLimit;
  final int sessionLimit;
  final List<Map<String, Object?>> _sessions = [];
  final Set<String> _recordedAssets = <String>{};
  Map<String, Object?>? _current;
  Timer? _flushTimer;
  Timer? _heartbeatTimer;
  StreamSubscription<html.Event>? _errorSubscription;
  bool _lifecycleInstalled = false;

  String? get sessionId => _current?['sessionId'] as String?;
  List<Map<String, Object?>> get sessions {
    _loadIfNeeded();
    return List.unmodifiable(_sessions);
  }

  bool get previousSessionAbnormalSuspected => sessions.any(
    (session) => session['abnormalTerminationSuspected'] == true,
  );

  void beginSession() {
    if (_current != null) return;
    _loadIfNeeded();
    if (_sessions.lastOrNull case final previous?
        when previous['status'] == 'active') {
      previous['abnormalTerminationSuspected'] = true;
    }
    final now = DateTime.now();
    _current = <String, Object?>{
      'sessionId': 'diagnostic-${now.microsecondsSinceEpoch}',
      'startedAt': now.toIso8601String(),
      'lastAliveAt': now.toIso8601String(),
      'status': 'active',
      'events': <Map<String, Object?>>[],
    };
    _sessions.add(_current!);
    if (_sessions.length > sessionLimit) {
      _sessions.removeRange(0, _sessions.length - sessionLimit);
    }
    _heartbeatTimer ??= Timer.periodic(_heartbeatInterval, (_) => heartbeat());
    if (!_lifecycleInstalled) {
      _lifecycleInstalled = true;
      html.window.addEventListener('pagehide', (_) => completeSession());
    }
    _scheduleWrite();
  }

  void record(
    String layer,
    String event, {
    Map<String, Object?> fields = const {},
  }) {
    try {
      beginSession();
      final events = _current!['events']! as List<Map<String, Object?>>;
      events.add(<String, Object?>{
        'timestamp': DateTime.now().toIso8601String(),
        'layer': layer,
        'event': event,
        if (fields.isNotEmpty) 'fields': fields,
      });
      if (events.length > eventLimit) {
        events.removeRange(0, events.length - eventLimit);
      }
      _current!['lastAliveAt'] = DateTime.now().toIso8601String();
      _scheduleWrite();
    } catch (_) {
      // Diagnostics must always fail open.
    }
  }

  void recordAssetOnce(
    String asset, {
    required int bytes,
    required int width,
    required int height,
    int frames = 1,
  }) {
    if (!_recordedAssets.add(asset)) return;
    record(
      'ASSET',
      'ASSET_LOAD_COMPLETE',
      fields: <String, Object?>{
        'asset': asset,
        'fileBytes': bytes,
        'width': width,
        'height': height,
        'frames': frames,
        'estimatedDecodedBytes': width * height * 4 * frames,
      },
    );
  }

  void heartbeat() {
    if (_current == null) return;
    _current!['lastAliveAt'] = DateTime.now().toIso8601String();
    _scheduleWrite();
  }

  void completeSession() {
    if (_current == null) return;
    heartbeat();
    _current!['status'] = 'completed';
    _flushNow();
  }

  void installGlobalErrorHandlers() {
    _errorSubscription ??= html.window.onError.listen((event) {
      final error = event is html.ErrorEvent ? event : null;
      record(
        'JAVASCRIPT',
        'WINDOW_ERROR',
        fields: <String, Object?>{
          'message': error?.message ?? event.toString(),
          'filename': ?error?.filename,
          'line': ?error?.lineno,
          'column': ?error?.colno,
        },
      );
    });
    html.window.addEventListener('unhandledrejection', (event) {
      record(
        'JAVASCRIPT',
        'UNHANDLED_PROMISE_REJECTION',
        fields: <String, Object?>{'eventType': event.type},
      );
    });
  }

  Future<bool> export() async {
    try {
      final blob = html.Blob(<Object>[copyText()], 'application/json');
      final url = html.Url.createObjectUrlFromBlob(blob);
      html.AnchorElement(href: url)
        ..download = 'or_app_system_diagnostics.json'
        ..click();
      html.Url.revokeObjectUrl(url);
      return true;
    } catch (_) {
      return false;
    }
  }

  void clear() {
    _flushTimer?.cancel();
    _sessions.clear();
    _current = null;
    _recordedAssets.clear();
    try {
      html.window.localStorage.remove(storageKey);
    } catch (_) {}
  }

  String copyText() {
    _loadIfNeeded();
    return const JsonEncoder.withIndent(' ').convert(<String, Object?>{
      'title': 'OR-APP SYSTEM DIAGNOSTICS',
      'sessions': _sessions,
    });
  }

  void _loadIfNeeded() {
    if (_sessions.isNotEmpty || _current != null) return;
    try {
      final raw = html.window.localStorage[storageKey];
      if (raw == null) return;
      final decoded = jsonDecode(raw);
      if (decoded is! Map || decoded['sessions'] is! List) return;
      _sessions.addAll(
        (decoded['sessions'] as List).whereType<Map>().map(
          (session) =>
              session.map((key, value) => MapEntry(key.toString(), value)),
        ),
      );
    } catch (_) {}
  }

  void _scheduleWrite() {
    _flushTimer ??= Timer(_flushDelay, _flushNow);
  }

  void _flushNow() {
    _flushTimer?.cancel();
    _flushTimer = null;
    try {
      html.window.localStorage[storageKey] = jsonEncode(<String, Object?>{
        'version': 2,
        'sessions': _sessions,
      });
    } catch (_) {}
  }
}
