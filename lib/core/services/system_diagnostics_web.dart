// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'diagnostic_sanitizer.dart';
import 'slow_start_evidence.dart';

class SystemDiagnostics {
  SystemDiagnostics({this.eventLimit = 200, this.sessionLimit = 5});

  static final SystemDiagnostics instance = SystemDiagnostics();
  static const storageKey = 'or_app.system_diagnostics.v2';
  static const uriEvidenceStorageKey = 'or_app.uri_exception_evidence.v2';
  static const slowStartupEvidenceStorageKey = 'or_app.slow_start_evidence.v1';
  static const preDartEvidenceStorageKey = 'or_app.pre_dart_evidence.v1';
  static const uriEvidenceSchemaVersion = 2;
  static const _uriIncidentLimit = 5;
  static const _navigationMessageLimit = 24;
  static const _flushDelay = Duration(milliseconds: 500);
  static const _heartbeatInterval = Duration(seconds: 20);

  final int eventLimit;
  final int sessionLimit;
  final List<Map<String, Object?>> _sessions = [];
  final Set<String> _recordedAssets = <String>{};
  final List<Map<String, Object?>> _recentNavigation = [];
  final List<Map<String, Object?>> _navigationMessages = [];
  final List<Map<String, Object?>> _uriIncidents = [];
  final List<Map<String, Object?>> _slowStartupIncidents = [];
  final Stopwatch _monotonicClock = Stopwatch()..start();
  int _navigationSequence = 0;
  bool _uriEvidenceLoaded = false;
  bool _slowStartupEvidenceLoaded = false;
  double? _dartMainMonotonicMs;
  double? _documentToDartMainMs;
  Map<String, Object?>? _current;
  Timer? _flushTimer;
  Timer? _heartbeatTimer;
  StreamSubscription<html.Event>? _errorSubscription;
  StreamSubscription<html.PopStateEvent>? _popStateSubscription;
  StreamSubscription<html.Event>? _hashChangeSubscription;
  StreamSubscription<html.Event>? _startupTimingSubscription;
  double? _browserDartMainMs;
  bool _lifecycleInstalled = false;
  String? _lastStartupPhase;
  String? _lastMapPhase;
  String _lifecycleState = 'unknown';
  int _lifecycleRevision = 0;

  String? get sessionId => _current?['sessionId'] as String?;
  bool get uriEvidenceOperational => true;
  int get uriIncidentCount {
    _loadUriEvidenceIfNeeded();
    return _uriIncidents.length;
  }

  List<Map<String, Object?>> get uriIncidentSummaries {
    _loadUriEvidenceIfNeeded();
    return _uriIncidents
        .map(
          (incident) => <String, Object?>{
            'incidentId': incident['incidentId'],
            'timestamp': incident['timestamp'],
            'captureCompleteness': incident['captureCompleteness'],
            'status': incident['status'],
          },
        )
        .toList(growable: false);
  }

  bool get slowStartupEvidenceOperational => true;
  int get slowStartupIncidentCount {
    _loadSlowStartupEvidenceIfNeeded();
    return _slowStartupIncidents.length;
  }

  List<Map<String, Object?>> get slowStartupIncidentSummaries {
    _loadSlowStartupEvidenceIfNeeded();
    return _slowStartupIncidents
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
  }

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
      _current!['lastAliveAt'] = DateTime.now().toIso8601String();
      _updateSlowStartupEvidence(event, effectiveFields);
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
    final eventId = _nextNavigationId('route');
    final entry = <String, Object?>{
      'navigationEventId': eventId,
      'sequence': _navigationSequence,
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

  String captureNavigationPlatformMessage(ByteData? message) {
    _loadUriEvidenceIfNeeded();
    final messageId = _nextNavigationId('message');
    final entry = <String, Object?>{
      'navigationEventId': messageId,
      'sessionId': sessionId,
      'sequence': _navigationSequence,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'monotonicOffsetMs': _monotonicClock.elapsedMicroseconds / 1000,
      'channel': SystemChannels.navigation.name,
      'messageByteLength': message?.lengthInBytes ?? 0,
      'browserBefore': _browserNavigationMetadata(),
      'status': 'sent',
    };
    try {
      final call = const JSONMethodCodec().decodeMethodCall(message);
      entry['method'] = call.method;
      final arguments = call.arguments;
      if (arguments is Map) {
        final uri = arguments['uri'];
        if (uri is String) entry.addAll(_rawUriEvidence(uri));
        entry['replace'] = arguments['replace'] == true;
        entry['historyState'] = _historyStateMetadata(arguments['state']);
      } else {
        entry['argumentsType'] = arguments?.runtimeType.toString();
      }
    } catch (error) {
      entry['messageDecodeErrorType'] = error.runtimeType.toString();
      entry['messageDecodeError'] = _bounded(error.toString(), 1000);
    }
    _navigationMessages.add(entry);
    if (_navigationMessages.length > _navigationMessageLimit) {
      _navigationMessages.removeRange(
        0,
        _navigationMessages.length - _navigationMessageLimit,
      );
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
    if (entry == null) return;
    entry['status'] = 'response_completed';
    entry['responseMonotonicOffsetMs'] =
        _monotonicClock.elapsedMicroseconds / 1000;
  }

  void freezeUriExceptionEvidence({
    required String trigger,
    Object? error,
    StackTrace? stackTrace,
    String? messageId,
    Map<String, Object?> errorFields = const <String, Object?>{},
  }) {
    try {
      _loadUriEvidenceIfNeeded();
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
        'schemaVersion': uriEvidenceSchemaVersion,
        'incidentId': 'uri-incident-${now.microsecondsSinceEpoch}',
        'status': 'unresolved',
        'timestamp': now.toIso8601String(),
        'monotonicOffsetMs': _monotonicClock.elapsedMicroseconds / 1000,
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
          'message': error == null ? null : _bounded(error.toString(), 2000),
          'stack': stackTrace == null
              ? null
              : _bounded(stackTrace.toString(), 6000),
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
        'browserAtFreeze': _browserNavigationMetadata(),
        'build': const <String, Object?>{
          'appReleaseCommit': String.fromEnvironment(
            'OR_APP_RELEASE_COMMIT',
            defaultValue: 'NOT AVAILABLE',
          ),
          'flutterVersion': String.fromEnvironment(
            'OR_APP_FLUTTER_VERSION',
            defaultValue: '3.44.6',
          ),
          'frameworkRevision': String.fromEnvironment(
            'OR_APP_FLUTTER_FRAMEWORK_REVISION',
            defaultValue: 'ee80f08bbf97172ec030b8751ceab557177a34a6',
          ),
          'engineRevision': String.fromEnvironment(
            'OR_APP_FLUTTER_ENGINE_REVISION',
            defaultValue: '83675ed27633283e7fc296c8bca22e841224c096',
          ),
        },
        'platform': <String, Object?>{
          'userAgent': _bounded(html.window.navigator.userAgent, 500),
          'language': html.window.navigator.language,
        },
      };
      _uriIncidents.add(incident);
      if (_uriIncidents.length > _uriIncidentLimit) {
        _uriIncidents.removeRange(0, _uriIncidents.length - _uriIncidentLimit);
      }
      _flushUriEvidenceNow();
      record(
        'NAVIGATION',
        'URI_EXCEPTION_EVIDENCE_FROZEN',
        fields: <String, Object?>{
          'incidentId': incident['incidentId'],
          'captureCompleteness': incident['captureCompleteness'],
          'correlation': incident['correlation'],
        },
      );
    } catch (_) {
      // Evidence collection must never replace the original failure.
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
          'browser': _browserNavigationMetadata(),
          'recentNavigation': _recentNavigation
              .map((entry) => Map<String, Object?>.from(entry))
              .toList(growable: false),
          ..._phaseFields,
        },
      );
      freezeUriExceptionEvidence(
        trigger: 'unhandled_promise_rejection',
        error: reason,
        errorFields: <String, Object?>{
          'reasonName': ?_jsPropertyText(reason, 'name'),
          'reasonMessage': ?_jsPropertyText(reason, 'message'),
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

  void installStartupTimingHandlers() {
    _startupTimingSubscription ??= html.window.on['or-app-run-app-complete']
        .listen((_) => recordBrowserStartupTiming(completed: true));
  }

  void recordBrowserStartupTiming({bool completed = false}) {
    try {
      final timing = globalContext.getProperty<JSObject?>(
        '__orAppStartupTiming'.toJS,
      );
      if (timing == null) return;
      final dartMainMs = _browserDartMainMs ??= html.window.performance.now();
      if (!completed) _markPreDartEvidenceReachedDart(dartMainMs);
      record(
        'BROWSER',
        completed
            ? 'BROWSER_STARTUP_TIMING_COMPLETE'
            : 'BROWSER_STARTUP_TIMING',
        fields: <String, Object?>{
          'documentStartMs': _jsNumber(timing, 'documentStartMs') ?? 0,
          'bootstrapRequestedMs': _jsNumber(timing, 'bootstrapRequestedMs'),
          'bootstrapScriptLoadedMs': _jsNumber(
            timing,
            'bootstrapScriptLoadedMs',
          ),
          'mainPreloadRequestedMs': _jsNumber(timing, 'mainPreloadRequestedMs'),
          'mainPreloadLoadedMs': _jsNumber(timing, 'mainPreloadLoadedMs'),
          'preFlutterHostCreatedMs': _jsNumber(
            timing,
            'preFlutterHostCreatedMs',
          ),
          'firstContentfulPaintMs': _jsNumber(timing, 'firstContentfulPaintMs'),
          'canvasKitPreloadRequestedMs': _jsNumber(
            timing,
            'canvasKitPreloadRequestedMs',
          ),
          'canvasKitPreloadVariant': _jsPropertyText(
            timing,
            'canvasKitPreloadVariant',
          ),
          'entrypointLoadedMs': _jsNumber(timing, 'entrypointLoadedMs'),
          'engineInitializeStartMs': _jsNumber(
            timing,
            'engineInitializeStartMs',
          ),
          'engineInitializeCompleteMs': _jsNumber(
            timing,
            'engineInitializeCompleteMs',
          ),
          'engineResourceTimingsJson': _jsPropertyText(
            timing,
            'engineResourceTimingsJson',
          ),
          'runAppStartMs': _jsNumber(timing, 'runAppStartMs'),
          'runAppCompleteMs': _jsNumber(timing, 'runAppCompleteMs'),
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
    freezeUriExceptionEvidence(trigger: 'window_error', errorFields: fields);
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
      parseError = _bounded(error.toString(), 1000);
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

  String copyUriEvidenceText() {
    _loadUriEvidenceIfNeeded();
    return const JsonEncoder.withIndent('  ').convert(<String, Object?>{
      'title': 'OR-APP URI EXCEPTION EVIDENCE',
      'schemaVersion': uriEvidenceSchemaVersion,
      'captureOperational': true,
      'incidents': _uriIncidents,
    });
  }

  String copySlowStartupEvidenceText() {
    _loadSlowStartupEvidenceIfNeeded();
    return const JsonEncoder.withIndent('  ').convert(<String, Object?>{
      'title': 'OR-APP SLOW STARTUP EVIDENCE',
      'schemaVersion': slowStartupEvidenceSchemaVersion,
      'captureOperational': true,
      'retentionLimit': slowStartupIncidentLimit,
      'incidents': _slowStartupIncidents,
      'preDartEvidence': _readPreDartEvidence(),
    });
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
    _loadUriEvidenceIfNeeded();
    _loadSlowStartupEvidenceIfNeeded();
    return const JsonEncoder.withIndent(' ').convert(<String, Object?>{
      'title': 'OR-APP SYSTEM DIAGNOSTICS',
      'sessions': _sessions,
      'uriExceptionEvidence': <String, Object?>{
        'schemaVersion': uriEvidenceSchemaVersion,
        'captureOperational': true,
        'incidents': _uriIncidents,
      },
      'slowStartupEvidence': <String, Object?>{
        'schemaVersion': slowStartupEvidenceSchemaVersion,
        'captureOperational': true,
        'retentionLimit': slowStartupIncidentLimit,
        'incidents': _slowStartupIncidents,
      },
      'preDartEvidence': <String, Object?>{
        'schemaVersion': 1,
        'records': _readPreDartEvidence(),
      },
    });
  }

  void _updateSlowStartupEvidence(String event, Map<String, Object?> fields) {
    _loadSlowStartupEvidenceIfNeeded();
    final trigger = slowStartupTrigger(event, fields);
    if (trigger != null) {
      upsertSlowStartupIncident(
        incidents: _slowStartupIncidents,
        session: _current!,
        trigger: trigger,
        lifecycleState: _lifecycleState,
        build: const <String, Object?>{
          'appReleaseCommit': String.fromEnvironment(
            'OR_APP_RELEASE_COMMIT',
            defaultValue: 'NOT AVAILABLE',
          ),
        },
        platform: <String, Object?>{
          'userAgent': _bounded(html.window.navigator.userAgent, 500),
          'language': html.window.navigator.language,
        },
        preDartEvidence: _readPreDartEvidence(),
      );
      _flushSlowStartupEvidenceNow();
      return;
    }
    final incident = _slowStartupIncidents.lastOrNull;
    if (incident?['sessionId'] == sessionId &&
        shouldRefreshSlowStartupIncident(event)) {
      refreshSlowStartupIncident(
        incident: incident!,
        session: _current!,
        lifecycleState: _lifecycleState,
        build: const <String, Object?>{
          'appReleaseCommit': String.fromEnvironment(
            'OR_APP_RELEASE_COMMIT',
            defaultValue: 'NOT AVAILABLE',
          ),
        },
        platform: <String, Object?>{
          'userAgent': _bounded(html.window.navigator.userAgent, 500),
          'language': html.window.navigator.language,
        },
        preDartEvidence: _readPreDartEvidence(),
      );
      _flushSlowStartupEvidenceNow();
    }
  }

  void _loadSlowStartupEvidenceIfNeeded() {
    if (_slowStartupEvidenceLoaded) return;
    _slowStartupEvidenceLoaded = true;
    try {
      final raw = html.window.localStorage[slowStartupEvidenceStorageKey];
      if (raw == null) return;
      final decoded = jsonDecode(raw);
      if (decoded is! Map || decoded['incidents'] is! List) return;
      _slowStartupIncidents.addAll(
        (decoded['incidents'] as List).whereType<Map>().map(
          (incident) =>
              incident.map((key, value) => MapEntry(key.toString(), value)),
        ),
      );
      if (_slowStartupIncidents.length > slowStartupIncidentLimit) {
        _slowStartupIncidents.removeRange(
          0,
          _slowStartupIncidents.length - slowStartupIncidentLimit,
        );
      }
    } catch (_) {}
  }

  void _flushSlowStartupEvidenceNow() {
    try {
      html.window.localStorage[slowStartupEvidenceStorageKey] =
          jsonEncode(<String, Object?>{
            'schemaVersion': slowStartupEvidenceSchemaVersion,
            'incidents': _slowStartupIncidents,
          });
    } catch (_) {}
  }

  List<Map<String, Object?>> _readPreDartEvidence() {
    try {
      final raw = html.window.localStorage[preDartEvidenceStorageKey];
      if (raw == null) return const [];
      final decoded = jsonDecode(raw);
      if (decoded is! Map || decoded['records'] is! List) return const [];
      return (decoded['records'] as List)
          .whereType<Map>()
          .map(
            (record) =>
                record.map((key, value) => MapEntry(key.toString(), value)),
          )
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  void _markPreDartEvidenceReachedDart(double dartMainMs) {
    try {
      final records = _readPreDartEvidence();
      if (records.isEmpty) return;
      records.last
        ..['dartMainMs'] = dartMainMs
        ..['status'] = 'dart_reached';
      html.window.localStorage[preDartEvidenceStorageKey] =
          jsonEncode(<String, Object?>{
            'schemaVersion': 1,
            'records': records.length <= 5
                ? records
                : records.sublist(records.length - 5),
          });
    } catch (_) {}
  }

  void _loadUriEvidenceIfNeeded() {
    if (_uriEvidenceLoaded) return;
    _uriEvidenceLoaded = true;
    try {
      final raw = html.window.localStorage[uriEvidenceStorageKey];
      if (raw == null) return;
      final decoded = jsonDecode(raw);
      if (decoded is! Map || decoded['incidents'] is! List) return;
      _uriIncidents.addAll(
        (decoded['incidents'] as List).whereType<Map>().map(
          (incident) =>
              incident.map((key, value) => MapEntry(key.toString(), value)),
        ),
      );
      if (_uriIncidents.length > _uriIncidentLimit) {
        _uriIncidents.removeRange(0, _uriIncidents.length - _uriIncidentLimit);
      }
    } catch (_) {}
  }

  void _flushUriEvidenceNow() {
    try {
      html.window.localStorage[uriEvidenceStorageKey] = jsonEncode(
        <String, Object?>{
          'schemaVersion': uriEvidenceSchemaVersion,
          'incidents': _uriIncidents,
        },
      );
    } catch (_) {}
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
