// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/foundation.dart';

import 'diagnostic_sanitizer.dart';

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
  final List<Map<String, Object?>> _recentNavigation = [];
  Map<String, Object?>? _current;
  Timer? _flushTimer;
  Timer? _heartbeatTimer;
  StreamSubscription<html.Event>? _errorSubscription;
  StreamSubscription<html.PopStateEvent>? _popStateSubscription;
  StreamSubscription<html.Event>? _hashChangeSubscription;
  bool _lifecycleInstalled = false;
  String? _lastStartupPhase;
  String? _lastMapPhase;
  String _lifecycleState = 'unknown';
  int _lifecycleRevision = 0;

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
      _trimEvents(events);
      _current!['lastAliveAt'] = DateTime.now().toIso8601String();
      _scheduleWrite();
    } catch (_) {
      // Diagnostics must always fail open.
    }
  }

  String get lifecycleState => _lifecycleState;

  void recordLifecycleState(String state) {
    _lifecycleState = sanitizeDiagnosticText(state, limit: 40);
    _lifecycleRevision++;
    record(
      'LIFECYCLE',
      'APP_LIFECYCLE_STATE',
      fields: <String, Object?>{'state': _lifecycleState},
    );
  }

  Future<T> traceStage<T>(
    String stage,
    Future<T> Function() action, {
    Map<String, Object?> fields = const {},
  }) async {
    final watch = Stopwatch()..start();
    final startLifecycle = _lifecycleState;
    final startRevision = _lifecycleRevision;
    record(
      'STARTUP_STAGE',
      'STAGE_START',
      fields: <String, Object?>{
        'stage': stage,
        'lifecycle': startLifecycle,
        ...fields,
      },
    );
    try {
      final result = await action();
      record(
        'STARTUP_STAGE',
        'STAGE_COMPLETE',
        fields: <String, Object?>{
          'stage': stage,
          'elapsedMs': watch.elapsedMicroseconds / 1000,
          'durationClock': 'monotonic',
          'startLifecycle': startLifecycle,
          'endLifecycle': _lifecycleState,
          'lifecycleChanged': startRevision != _lifecycleRevision,
          ...fields,
        },
      );
      return result;
    } catch (error) {
      record(
        'STARTUP_STAGE',
        'STAGE_FAILED',
        fields: <String, Object?>{
          'stage': stage,
          'elapsedMs': watch.elapsedMicroseconds / 1000,
          'durationClock': 'monotonic',
          'startLifecycle': startLifecycle,
          'endLifecycle': _lifecycleState,
          'lifecycleChanged': startRevision != _lifecycleRevision,
          'errorType': error.runtimeType.toString(),
          ...fields,
        },
      );
      rethrow;
    }
  }

  void recordNavigation({
    required String action,
    String? previousRoute,
    String? requestedRoute,
    String? routeType,
  }) {
    final before = _browserNavigationMetadata();
    final entry = <String, Object?>{
      'action': sanitizeDiagnosticText(action, limit: 32),
      'previousRoute': sanitizeDiagnosticUri(previousRoute),
      'requestedRoute': sanitizeDiagnosticUri(requestedRoute),
      if (routeType != null)
        'routeType': sanitizeDiagnosticText(routeType, limit: 80),
      'browserBefore': before,
    };
    _rememberNavigation(entry);
    scheduleMicrotask(() {
      record(
        'NAVIGATION',
        'ROUTE_REQUEST',
        fields: <String, Object?>{
          ...entry,
          'browserAfter': _browserNavigationMetadata(),
        },
      );
    });
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
          'browser': _browserNavigationMetadata(),
          'recentNavigation': _recentNavigation
              .map((entry) => Map<String, Object?>.from(entry))
              .toList(growable: false),
          ..._phaseFields,
        },
      );
    });
  }

  void installNavigationBoundaryHandlers() {
    _popStateSubscription ??= html.window.onPopState.listen((_) {
      _recordBrowserNavigationEvent('popstate');
    });
    _hashChangeSubscription ??= html.window.onHashChange.listen((_) {
      _recordBrowserNavigationEvent('hashchange');
    });
  }

  void recordBrowserStartupTiming() {
    try {
      final timing = globalContext.getProperty<JSObject?>(
        '__orAppStartupTiming'.toJS,
      );
      if (timing == null) return;
      final dartMainMs = html.window.performance.now();
      record(
        'BROWSER',
        'BROWSER_STARTUP_TIMING',
        fields: <String, Object?>{
          'documentStartMs': _jsNumber(timing, 'documentStartMs') ?? 0,
          'bootstrapRequestedMs': _jsNumber(timing, 'bootstrapRequestedMs'),
          'bootstrapScriptLoadedMs': _jsNumber(
            timing,
            'bootstrapScriptLoadedMs',
          ),
          'dartMainMs': dartMainMs,
          'documentToDartMainMs': dartMainMs,
        },
      );
    } catch (_) {
      // Browser timing is optional evidence and never gates application boot.
    }
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
      fields: <String, Object?>{
        ...fields,
        'browser': _browserNavigationMetadata(),
        'recentNavigation': List<Map<String, Object?>>.from(_recentNavigation),
        ..._phaseFields,
      },
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

  void _recordBrowserNavigationEvent(String action) {
    final entry = <String, Object?>{
      'action': action,
      'browser': _browserNavigationMetadata(),
    };
    _rememberNavigation(entry);
    record('NAVIGATION', 'BROWSER_ROUTE_NOTIFICATION', fields: entry);
  }

  Map<String, Object?> _browserNavigationMetadata() {
    final state = html.window.history.state;
    return <String, Object?>{
      'url': sanitizeDiagnosticUri(html.window.location.href),
      'visibility': html.document.visibilityState,
      'historyLength': html.window.history.length,
      'historyState': _historyStateMetadata(state),
    };
  }

  Map<String, Object?> _historyStateMetadata(Object? state) {
    if (state == null) return const <String, Object?>{'present': false};
    try {
      final value = state;
      if (value is Map) {
        return <String, Object?>{
          'present': true,
          'type': 'map',
          'keys': value.keys
              .map((key) => sanitizeDiagnosticText('$key', limit: 48))
              .where((key) => !_sensitiveKey(key))
              .take(12)
              .toList(growable: false),
        };
      }
      return <String, Object?>{
        'present': true,
        'type': value.runtimeType.toString(),
      };
    } catch (_) {
      return const <String, Object?>{'present': true, 'type': 'unavailable'};
    }
  }

  bool _sensitiveKey(String key) {
    final lower = key.toLowerCase();
    return lower.contains('token') ||
        lower.contains('secret') ||
        lower.contains('password') ||
        lower.contains('auth');
  }

  void _rememberNavigation(Map<String, Object?> entry) {
    _recentNavigation.add(<String, Object?>{
      'timestamp': DateTime.now().toIso8601String(),
      ...entry,
    });
    if (_recentNavigation.length > 12) {
      _recentNavigation.removeRange(0, _recentNavigation.length - 12);
    }
  }

  void _trimEvents(List<Map<String, Object?>> events) {
    while (events.length > eventLimit) {
      final removable = events.indexWhere((event) => !_isCritical(event));
      events.removeAt(removable < 0 ? 0 : removable);
    }
  }

  bool _isCritical(Map<String, Object?> event) {
    final layer = event['layer'];
    final name = event['event'];
    return layer == 'STARTUP_STAGE' ||
        layer == 'NAVIGATION' ||
        name == 'WINDOW_ERROR' ||
        name == 'UNHANDLED_PROMISE_REJECTION';
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

  double? _jsNumber(JSObject object, String property) {
    if (!object.has(property)) return null;
    final value = object[property]?.dartify();
    return value is num ? value.toDouble() : null;
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
    _recentNavigation.clear();
    _lastStartupPhase = null;
    _lastMapPhase = null;
    _lifecycleState = 'unknown';
    _lifecycleRevision = 0;
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
