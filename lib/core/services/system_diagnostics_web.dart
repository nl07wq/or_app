// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/foundation.dart';

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
  String? _lastStartupPhase;
  String? _lastMapPhase;

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
      _trackPhase(layer, event);
      final effectiveFields = <String, Object?>{
        ...fields,
        if (event == 'SLOW_FRAME_BATCH') ..._phaseFields,
      };
      final events = _current!['events']! as List<Map<String, Object?>>;
      events.add(<String, Object?>{
        'timestamp': DateTime.now().toIso8601String(),
        'layer': layer,
        'event': event,
        if (effectiveFields.isNotEmpty) 'fields': effectiveFields,
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
    _errorSubscription ??= html.window.onError.listen(_recordWindowError);
    html.window.addEventListener('unhandledrejection', (event) {
      final rejection = event is html.PromiseRejectionEvent ? event : null;
      final reason = rejection?.reason;
      final reasonStack = _jsPropertyText(reason, 'stack');
      final reasonText = reason == null
          ? null
          : _bounded(reason.toString(), 2000);
      final boundedReasonStack = reasonStack == null
          ? null
          : _bounded(reasonStack, 6000);
      record(
        'JAVASCRIPT',
        'UNHANDLED_PROMISE_REJECTION',
        fields: <String, Object?>{
          'eventType': event.type,
          'reasonType': ?reason?.runtimeType.toString(),
          'reason': ?reasonText,
          'reasonName': ?_jsPropertyText(reason, 'name'),
          'reasonMessage': ?_jsPropertyText(reason, 'message'),
          'stack': ?boundedReasonStack,
          ..._phaseFields,
        },
      );
    });
  }

  void _recordWindowError(html.Event event) {
    final error = event is html.ErrorEvent ? event : null;
    final errorObject = error?.error;
    final eventMessage = _nonEmpty(error?.message);
    final objectMessage = _jsPropertyText(errorObject, 'message');
    final errorStack = _jsPropertyText(errorObject, 'stack');
    final boundedErrorStack = errorStack == null
        ? null
        : _bounded(errorStack, 6000);
    _recordWindowErrorDetails(<String, Object?>{
      'eventType': event.type,
      'message':
          eventMessage ?? objectMessage ?? _bounded(event.toString(), 2000),
      'errorType': ?errorObject?.runtimeType.toString(),
      'errorName': ?_jsPropertyText(errorObject, 'name'),
      'errorMessage': ?objectMessage,
      'stack': ?boundedErrorStack,
      'filename': ?error?.filename,
      'line': ?error?.lineno,
      'column': ?error?.colno,
    });
  }

  @visibleForTesting
  void recordWindowErrorDetailsForTesting(Map<String, Object?> fields) =>
      _recordWindowErrorDetails(fields);

  void _recordWindowErrorDetails(Map<String, Object?> fields) {
    record(
      'JAVASCRIPT',
      'WINDOW_ERROR',
      fields: <String, Object?>{...fields, ..._phaseFields},
    );
  }

  Map<String, Object?> get _phaseFields => <String, Object?>{
    'lastStartupPhase': ?_lastStartupPhase,
    'lastMapPhase': ?_lastMapPhase,
  };

  void _trackPhase(String layer, String event) {
    if (event == 'DART_MAIN_ENTER' || event.startsWith('DASHBOARD_')) {
      _lastStartupPhase = '$layer/$event';
    }
    if (event.startsWith('MAP_') || event.startsWith('FACILITY_')) {
      _lastMapPhase = '$layer/$event';
    }
  }

  String? _jsPropertyText(Object? object, String property) {
    if (object == null) return null;
    try {
      final jsObject = object as JSObject;
      if (!jsObject.has(property)) return null;
      return _nonEmpty(jsObject[property]?.dartify()?.toString());
    } catch (_) {
      return null;
    }
  }

  String? _nonEmpty(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  String _bounded(String value, int limit) => value.length <= limit
      ? value
      : '${value.substring(0, limit)}\n...[TRUNCATED]';

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
    _lastStartupPhase = null;
    _lastMapPhase = null;
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
