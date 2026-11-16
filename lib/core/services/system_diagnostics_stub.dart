import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'diagnostic_sanitizer.dart';
import 'slow_start_evidence.dart';

class SystemDiagnostics {
  SystemDiagnostics({
    this.eventLimit = 200,
    this.sessionLimit = 5,
    List<Map<String, Object?>> initialSessions = const [],
    List<Map<String, Object?>> initialUriIncidents = const [],
    List<Map<String, Object?>> initialSlowStartupIncidents = const [],
  }) {
    _sessions.addAll(initialSessions);
    _uriIncidents.addAll(initialUriIncidents);
    _slowStartupIncidents.addAll(initialSlowStartupIncidents);
  }

  factory SystemDiagnostics.testing({
    int eventLimit = 200,
    int sessionLimit = 5,
    List<Map<String, Object?>> initialSessions = const [],
    List<Map<String, Object?>> initialUriIncidents = const [],
    List<Map<String, Object?>> initialSlowStartupIncidents = const [],
  }) => SystemDiagnostics(
    eventLimit: eventLimit,
    sessionLimit: sessionLimit,
    initialSessions: initialSessions,
    initialUriIncidents: initialUriIncidents,
    initialSlowStartupIncidents: initialSlowStartupIncidents,
  );

  static final SystemDiagnostics instance = SystemDiagnostics();

  final int eventLimit;
  final int sessionLimit;
  final List<Map<String, Object?>> _sessions = [];
  Map<String, Object?>? _current;
  final Set<String> _recordedAssets = <String>{};
  final List<Map<String, Object?>> _recentNavigation = [];
  final List<Map<String, Object?>> _navigationMessages = [];
  final List<Map<String, Object?>> _uriIncidents = [];
  final List<Map<String, Object?>> _slowStartupIncidents = [];
  final Stopwatch _monotonicClock = Stopwatch()..start();
  double? _dartMainMonotonicMs;
  double? _documentToDartMainMs;
  int _navigationSequence = 0;
  String? _lastStartupPhase;
  String? _lastMapPhase;
  String _lifecycleState = 'unknown';
  int _lifecycleRevision = 0;

  String? get sessionId => _current?['sessionId'] as String?;
  bool get uriEvidenceOperational => true;
  int get uriIncidentCount => _uriIncidents.length;
  bool get slowStartupEvidenceOperational => true;
  int get slowStartupIncidentCount => _slowStartupIncidents.length;
  List<Map<String, Object?>> get slowStartupIncidentSummaries =>
      _slowStartupIncidents
          .map(
            (incident) => <String, Object?>{
              'incidentId': incident['incidentId'],
              'timestamp': incident['timestamp'],
              'captureCompleteness': incident['captureCompleteness'],
              'status': incident['status'],
              'triggers': incident['triggers'],
            },
          )
          .toList(growable: false);
  List<Map<String, Object?>> get uriIncidentSummaries => _uriIncidents
      .map(
        (incident) => <String, Object?>{
          'incidentId': incident['incidentId'],
          'timestamp': incident['timestamp'],
          'captureCompleteness': incident['captureCompleteness'],
          'status': incident['status'],
        },
      )
      .toList(growable: false);
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
    if (event == 'DART_MAIN_ENTER') {
      _dartMainMonotonicMs = _monotonicClock.elapsedMicroseconds / 1000;
    }
    if (event == 'BROWSER_STARTUP_TIMING') {
      final value = fields['documentToDartMainMs'];
      if (value is num) _documentToDartMainMs = value.toDouble();
    }
    final nowMonotonicMs = _monotonicClock.elapsedMicroseconds / 1000;
    final effectiveFields = <String, Object?>{
      ...fields,
      if (event == 'DASHBOARD_INTERACTIVE' && _dartMainMonotonicMs != null)
        'dartMainToDashboardInteractiveMs':
            nowMonotonicMs - _dartMainMonotonicMs!,
      if (event == 'DASHBOARD_INTERACTIVE' &&
          _documentToDartMainMs != null &&
          _dartMainMonotonicMs != null)
        'documentToDashboardInteractiveMs':
            _documentToDartMainMs! + nowMonotonicMs - _dartMainMonotonicMs!,
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
    _updateSlowStartupEvidence(event, effectiveFields);
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
    final eventId = _nextNavigationId('route');
    final entry = <String, Object?>{
      'navigationEventId': eventId,
      'sequence': _navigationSequence,
      'action': sanitizeDiagnosticText(action, limit: 32),
      'previousRoute': sanitizeDiagnosticUri(previousRoute),
      'requestedRoute': sanitizeDiagnosticUri(requestedRoute),
      if (routeType != null)
        'routeType': sanitizeDiagnosticText(routeType, limit: 80),
    };
    _rememberNavigation(entry);
    record('NAVIGATION', 'ROUTE_REQUEST', fields: entry);
  }

  String captureNavigationPlatformMessage(ByteData? message) {
    final messageId = _nextNavigationId('message');
    final entry = <String, Object?>{
      'navigationEventId': messageId,
      'sessionId': sessionId,
      'sequence': _navigationSequence,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'monotonicOffsetMs': _monotonicClock.elapsedMicroseconds / 1000,
      'channel': SystemChannels.navigation.name,
      'messageByteLength': message?.lengthInBytes ?? 0,
      'status': 'sent',
    };
    try {
      final call = const JSONMethodCodec().decodeMethodCall(message);
      entry['method'] = call.method;
      if (call.arguments case final Map arguments) {
        final uri = arguments['uri'];
        if (uri is String) entry.addAll(_rawUriEvidence(uri));
        entry['replace'] = arguments['replace'] == true;
      }
    } catch (error) {
      entry['messageDecodeErrorType'] = error.runtimeType.toString();
      entry['messageDecodeError'] = error.toString();
    }
    _navigationMessages.add(entry);
    if (_navigationMessages.length > 24) {
      _navigationMessages.removeRange(0, _navigationMessages.length - 24);
    }
    record(
      'NAVIGATION',
      'PLATFORM_MESSAGE_SENT',
      fields: <String, Object?>{
        'navigationEventId': messageId,
        'method': entry['method'],
        'rawUriLength': entry['rawUriLength'],
        'collectorParseResult': entry['collectorParseResult'],
      },
    );
    return messageId;
  }

  void completeNavigationPlatformMessage(String messageId) {
    final entry = _navigationMessages
        .where((candidate) => candidate['navigationEventId'] == messageId)
        .lastOrNull;
    if (entry != null) entry['status'] = 'response_completed';
  }

  void freezeUriExceptionEvidence({
    required String trigger,
    Object? error,
    StackTrace? stackTrace,
    String? messageId,
    Map<String, Object?> errorFields = const <String, Object?>{},
  }) {
    final related = messageId == null
        ? _navigationMessages.lastOrNull
        : _navigationMessages
              .where((entry) => entry['navigationEventId'] == messageId)
              .lastOrNull;
    final relatedOffset = related?['monotonicOffsetMs'];
    final ageMs = relatedOffset is num
        ? _monotonicClock.elapsedMicroseconds / 1000 - relatedOffset
        : null;
    if (messageId == null &&
        (related == null || ageMs == null || ageMs > 5000)) {
      return;
    }
    final relatedId = related?['navigationEventId'];
    if (relatedId != null &&
        _uriIncidents.lastOrNull?['relatedNavigationEventId'] == relatedId) {
      return;
    }
    final now = DateTime.now().toUtc();
    final incident = <String, Object?>{
      'schemaVersion': 2,
      'incidentId': 'uri-incident-${now.microsecondsSinceEpoch}',
      'status': 'unresolved',
      'timestamp': now.toIso8601String(),
      'sessionId': sessionId,
      'trigger': trigger,
      'captureCompleteness': related?['rawUri'] is String
          ? 'engine_input_captured'
          : 'engine_input_unavailable',
      'correlation': messageId != null
          ? 'platform_response_error'
          : 'closest_preceding_message_unconfirmed',
      'relatedNavigationEventId': relatedId,
      'messageToErrorElapsedMs': ?ageMs,
      'error': <String, Object?>{
        'type': ?error?.runtimeType.toString(),
        'message': ?error?.toString(),
        'stack': ?stackTrace?.toString(),
        ...errorFields,
      },
      'relatedPlatformMessage': related == null
          ? null
          : Map<String, Object?>.from(related),
      'preExceptionPlatformMessages': _navigationMessages
          .map((entry) => Map<String, Object?>.from(entry))
          .toList(growable: false),
      'recentApplicationNavigation': _recentNavigation
          .map((entry) => Map<String, Object?>.from(entry))
          .toList(growable: false),
    };
    _uriIncidents.add(incident);
    if (_uriIncidents.length > 5) {
      _uriIncidents.removeRange(0, _uriIncidents.length - 5);
    }
    record(
      'NAVIGATION',
      'URI_EXCEPTION_EVIDENCE_FROZEN',
      fields: <String, Object?>{
        'incidentId': incident['incidentId'],
        'captureCompleteness': incident['captureCompleteness'],
      },
    );
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
    freezeUriExceptionEvidence(trigger: 'window_error', errorFields: fields);
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
    _navigationMessages.clear();
    _uriIncidents.clear();
    _slowStartupIncidents.clear();
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
        'uriExceptionEvidence': <String, Object?>{
          'schemaVersion': 2,
          'captureOperational': true,
          'incidents': _uriIncidents,
        },
        'slowStartupEvidence': <String, Object?>{
          'schemaVersion': slowStartupEvidenceSchemaVersion,
          'captureOperational': true,
          'retentionLimit': slowStartupIncidentLimit,
          'incidents': _slowStartupIncidents,
        },
        'preDartEvidence': const <String, Object?>{
          'schemaVersion': 1,
          'records': <Map<String, Object?>>[],
        },
      });

  String copySlowStartupEvidenceText() =>
      const JsonEncoder.withIndent('  ').convert(<String, Object?>{
        'title': 'OR-APP SLOW STARTUP EVIDENCE',
        'schemaVersion': slowStartupEvidenceSchemaVersion,
        'captureOperational': true,
        'retentionLimit': slowStartupIncidentLimit,
        'incidents': _slowStartupIncidents,
        'preDartEvidence': const <Map<String, Object?>>[],
      });

  void _updateSlowStartupEvidence(String event, Map<String, Object?> fields) {
    final trigger = slowStartupTrigger(event, fields);
    if (trigger != null) {
      upsertSlowStartupIncident(
        incidents: _slowStartupIncidents,
        session: _current!,
        trigger: trigger,
        lifecycleState: _lifecycleState,
        build: const <String, Object?>{'appReleaseCommit': 'test'},
        platform: const <String, Object?>{'runtime': 'dart-vm'},
      );
      return;
    }
    final incident = _slowStartupIncidents.lastOrNull;
    if (incident?['sessionId'] == sessionId &&
        shouldRefreshSlowStartupIncident(event)) {
      refreshSlowStartupIncident(
        incident: incident!,
        session: _current!,
        lifecycleState: _lifecycleState,
        build: const <String, Object?>{'appReleaseCommit': 'test'},
        platform: const <String, Object?>{'runtime': 'dart-vm'},
      );
    }
  }

  String copyUriEvidenceText() =>
      const JsonEncoder.withIndent('  ').convert(<String, Object?>{
        'title': 'OR-APP URI EXCEPTION EVIDENCE',
        'schemaVersion': 2,
        'captureOperational': true,
        'incidents': _uriIncidents,
      });

  String _nextNavigationId(String kind) {
    _navigationSequence++;
    return '$kind-${sessionId ?? 'pre-session'}-$_navigationSequence';
  }

  Map<String, Object?> _rawUriEvidence(String rawUri) {
    final bytes = <int>[];
    for (final unit in rawUri.codeUnits) {
      bytes
        ..add(unit & 0xff)
        ..add((unit >> 8) & 0xff);
    }
    String parseResult = 'success';
    String? parseError;
    try {
      Uri.parse(rawUri);
    } catch (error) {
      parseResult = 'format_exception';
      parseError = error.toString();
    }
    return <String, Object?>{
      'rawUri': rawUri,
      'rawUriLength': rawUri.length,
      'rawUriUtf16LeBase64': base64Encode(bytes),
      'rawUriEncoding': 'utf-16le-code-units',
      'rawUriSanitizedView': sanitizeDiagnosticUri(rawUri),
      'collectorParseResult': parseResult,
      'collectorParseError': ?parseError,
      'exportPolicy': 'local-user-initiated-only',
    };
  }
}
