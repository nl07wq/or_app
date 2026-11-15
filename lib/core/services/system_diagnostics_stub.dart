import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'diagnostic_sanitizer.dart';

class SystemDiagnostics {
  SystemDiagnostics({
    this.eventLimit = 200,
    this.sessionLimit = 5,
    List<Map<String, Object?>> initialSessions = const [],
  }) {
    _sessions.addAll(initialSessions);
  }

  factory SystemDiagnostics.testing({
    int eventLimit = 200,
    int sessionLimit = 5,
    List<Map<String, Object?>> initialSessions = const [],
  }) => SystemDiagnostics(
    eventLimit: eventLimit,
    sessionLimit: sessionLimit,
    initialSessions: initialSessions,
  );

  static final SystemDiagnostics instance = SystemDiagnostics();

  final int eventLimit;
  final int sessionLimit;
  final List<Map<String, Object?>> _sessions = [];
  Map<String, Object?>? _current;
  final Set<String> _recordedAssets = <String>{};
  final List<Map<String, Object?>> _recentNavigation = [];
  String? _lastStartupPhase;
  String? _lastMapPhase;
  String _lifecycleState = 'unknown';
  int _lifecycleRevision = 0;

  String? get sessionId => _current?['sessionId'] as String?;
  List<Map<String, Object?>> get sessions => List.unmodifiable(_sessions);
  bool get previousSessionAbnormalSuspected => _sessions.any(
    (session) => session['abnormalTerminationSuspected'] == true,
  );

  void beginSession() {
    if (_current != null) return;
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
  }

  void record(
    String layer,
    String event, {
    Map<String, Object?> fields = const {},
  }) {
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
    final entry = <String, Object?>{
      'action': sanitizeDiagnosticText(action, limit: 32),
      'previousRoute': sanitizeDiagnosticUri(previousRoute),
      'requestedRoute': sanitizeDiagnosticUri(requestedRoute),
      if (routeType != null)
        'routeType': sanitizeDiagnosticText(routeType, limit: 80),
    };
    _rememberNavigation(entry);
    record('NAVIGATION', 'ROUTE_REQUEST', fields: entry);
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
  }

  void completeSession() {
    if (_current == null) return;
    heartbeat();
    _current!['status'] = 'completed';
  }

  void installGlobalErrorHandlers() {}

  void installNavigationBoundaryHandlers() {}

  void recordBrowserStartupTiming() {}

  @visibleForTesting
  void recordWindowErrorDetailsForTesting(Map<String, Object?> fields) {
    record(
      'JAVASCRIPT',
      'WINDOW_ERROR',
      fields: <String, Object?>{
        ...fields,
        'recentNavigation': List<Map<String, Object?>>.from(_recentNavigation),
        ..._phaseFields,
      },
    );
  }

  Future<bool> export() async => false;

  void clear() {
    _sessions.clear();
    _current = null;
    _recordedAssets.clear();
    _recentNavigation.clear();
    _lastStartupPhase = null;
    _lastMapPhase = null;
    _lifecycleState = 'unknown';
    _lifecycleRevision = 0;
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

  String copyText() =>
      const JsonEncoder.withIndent('  ').convert(<String, Object?>{
        'title': 'OR-APP SYSTEM DIAGNOSTICS',
        'sessions': _sessions,
      });
}
