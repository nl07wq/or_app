import 'dart:convert';

import 'package:flutter/foundation.dart';

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
  String? _lastStartupPhase;
  String? _lastMapPhase;

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
    if (events.length > eventLimit) {
      events.removeRange(0, events.length - eventLimit);
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
  }

  void completeSession() {
    if (_current == null) return;
    heartbeat();
    _current!['status'] = 'completed';
  }

  void installGlobalErrorHandlers() {}

  void recordBrowserStartupTiming() {}

  @visibleForTesting
  void recordWindowErrorDetailsForTesting(Map<String, Object?> fields) {
    record(
      'JAVASCRIPT',
      'WINDOW_ERROR',
      fields: <String, Object?>{...fields, ..._phaseFields},
    );
  }

  Future<bool> export() async => false;

  void clear() {
    _sessions.clear();
    _current = null;
    _recordedAssets.clear();
    _lastStartupPhase = null;
    _lastMapPhase = null;
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

  String copyText() =>
      const JsonEncoder.withIndent('  ').convert(<String, Object?>{
        'title': 'OR-APP SYSTEM DIAGNOSTICS',
        'sessions': _sessions,
      });
}
