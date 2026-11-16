const slowStartupEvidenceSchemaVersion = 1;
const slowStartupIncidentLimit = 5;

const documentToDartMainThresholdMs = 5000.0;
const documentToDashboardInteractiveThresholdMs = 10000.0;
const dartMainToDashboardInteractiveThresholdMs = 5000.0;
const facilityPreparationThresholdMs = 3000.0;
const waterPreparationThresholdMs = 4000.0;
const walkerPreparationThresholdMs = 5000.0;

Map<String, Object?>? slowStartupTrigger(
  String event,
  Map<String, Object?> fields,
) {
  final candidates = switch (event) {
    'BROWSER_STARTUP_TIMING' => <(String, double, double)>[
      (
        'document_to_dart_main',
        _number(fields['documentToDartMainMs']),
        documentToDartMainThresholdMs,
      ),
    ],
    'DASHBOARD_INTERACTIVE' => <(String, double, double)>[
      (
        'document_to_dashboard_interactive',
        _number(fields['documentToDashboardInteractiveMs']),
        documentToDashboardInteractiveThresholdMs,
      ),
      (
        'dart_main_to_dashboard_interactive',
        _number(fields['dartMainToDashboardInteractiveMs']),
        dartMainToDashboardInteractiveThresholdMs,
      ),
    ],
    'FACILITY_OBJECTS_ATOMIC_PREPARE_COMPLETE' => <(String, double, double)>[
      (
        'facility_atomic_preparation',
        _number(fields['durationMs']),
        facilityPreparationThresholdMs,
      ),
    ],
    'WATER_FX_INIT_COMPLETE' => <(String, double, double)>[
      (
        'water_fx_preparation',
        _number(fields['durationMs']),
        waterPreparationThresholdMs,
      ),
    ],
    'WALKER_STAGED_PRECACHE_COMPLETE' ||
    'WALKER_STAGED_PRECACHE_INCOMPLETE' => <(String, double, double)>[
      (
        'walker_preparation',
        _number(fields['durationMs']),
        walkerPreparationThresholdMs,
      ),
    ],
    _ => const <(String, double, double)>[],
  };
  for (final candidate in candidates) {
    if (candidate.$2 >= candidate.$3) {
      return <String, Object?>{
        'type': candidate.$1,
        'observedMs': candidate.$2,
        'thresholdMs': candidate.$3,
        'event': event,
      };
    }
  }
  return null;
}

bool shouldRefreshSlowStartupIncident(String event) =>
    event == 'DART_MAIN_ENTER' ||
    event == 'BROWSER_STARTUP_TIMING' ||
    event == 'DASHBOARD_INTERACTIVE' ||
    event == 'MAP_DISPLAY_COMPLETE' ||
    event == 'FACILITY_OBJECTS_ATOMIC_PREPARE_COMPLETE' ||
    event == 'WATER_FX_INIT_COMPLETE' ||
    event == 'WALKER_STAGED_PRECACHE_COMPLETE' ||
    event == 'WALKER_STAGED_PRECACHE_INCOMPLETE' ||
    event == 'RIFLE_REGRIP_PRECACHE_COMPLETE' ||
    event == 'RIFLE_REGRIP_PRECACHE_INCOMPLETE' ||
    event == 'DEFERRED_MAP_ANIMATION_PREPARE_COMPLETE' ||
    event == 'SLOW_FRAME_BATCH' ||
    event == 'APP_LIFECYCLE_STATE';

Map<String, Object?> upsertSlowStartupIncident({
  required List<Map<String, Object?>> incidents,
  required Map<String, Object?> session,
  required Map<String, Object?> trigger,
  required String lifecycleState,
  required Map<String, Object?> build,
  required Map<String, Object?> platform,
  List<Map<String, Object?>> preDartEvidence = const [],
}) {
  final sessionId = session['sessionId'];
  final now = DateTime.now().toUtc();
  Map<String, Object?>? incident;
  for (final candidate in incidents) {
    if (candidate['sessionId'] == sessionId) {
      incident = candidate;
      break;
    }
  }
  if (incident == null) {
    incident = <String, Object?>{
      'schemaVersion': slowStartupEvidenceSchemaVersion,
      'incidentId': 'slow-start-${now.microsecondsSinceEpoch}',
      'sessionId': sessionId,
      'timestamp': now.toIso8601String(),
      'status': 'unresolved',
      'triggers': <Map<String, Object?>>[],
    };
    incidents.add(incident);
    if (incidents.length > slowStartupIncidentLimit) {
      incidents.removeRange(0, incidents.length - slowStartupIncidentLimit);
    }
  }
  final rawTriggers = incident['triggers'];
  final triggers = rawTriggers is List
      ? rawTriggers
            .whereType<Map>()
            .map(
              (entry) =>
                  entry.map((key, value) => MapEntry(key.toString(), value)),
            )
            .toList()
      : <Map<String, Object?>>[];
  incident['triggers'] = triggers;
  final type = trigger['type'];
  final existing = triggers.indexWhere((entry) => entry['type'] == type);
  final stamped = <String, Object?>{
    ...trigger,
    'capturedAt': now.toIso8601String(),
  };
  if (existing < 0) {
    triggers.add(stamped);
  } else {
    triggers[existing] = stamped;
  }
  refreshSlowStartupIncident(
    incident: incident,
    session: session,
    lifecycleState: lifecycleState,
    build: build,
    platform: platform,
    preDartEvidence: preDartEvidence,
  );
  return incident;
}

void refreshSlowStartupIncident({
  required Map<String, Object?> incident,
  required Map<String, Object?> session,
  required String lifecycleState,
  required Map<String, Object?> build,
  required Map<String, Object?> platform,
  List<Map<String, Object?>> preDartEvidence = const [],
}) {
  final events = (session['events'] as List? ?? const <Object>[])
      .whereType<Map>()
      .map(
        (event) => event.map((key, value) => MapEntry(key.toString(), value)),
      )
      .toList(growable: false);
  incident
    ..['updatedAt'] = DateTime.now().toUtc().toIso8601String()
    ..['captureCompleteness'] = _captureCompleteness(events, preDartEvidence)
    ..['lifecycleAtCapture'] = lifecycleState
    ..['build'] = build
    ..['platform'] = platform
    ..['preDartEvidence'] = preDartEvidence
    ..['metrics'] = _metrics(events)
    ..['startupTrace'] = events;
}

String _captureCompleteness(
  List<Map<String, Object?>> events,
  List<Map<String, Object?>> preDartEvidence,
) {
  final hasBrowserTiming = events.any(
    (event) => event['event'] == 'BROWSER_STARTUP_TIMING',
  );
  if (hasBrowserTiming) return 'document_and_dart_trace';
  if (preDartEvidence.isNotEmpty) return 'pre_dart_evidence_without_timing';
  return 'dart_trace_only_document_timing_unavailable';
}

Map<String, Object?> _metrics(List<Map<String, Object?>> events) {
  final metrics = <String, Object?>{};
  for (final event in events) {
    final name = event['event'];
    final fields = event['fields'];
    if (fields is! Map) continue;
    switch (name) {
      case 'BROWSER_STARTUP_TIMING':
        metrics['browserStartup'] = Map<String, Object?>.from(fields);
      case 'DASHBOARD_INTERACTIVE':
        metrics['dashboardInteractive'] = Map<String, Object?>.from(fields);
      case 'MAP_DISPLAY_COMPLETE':
        metrics['map'] = Map<String, Object?>.from(fields);
      case 'FACILITY_OBJECTS_ATOMIC_PREPARE_COMPLETE':
        metrics['facilities'] = Map<String, Object?>.from(fields);
      case 'WATER_FX_INIT_COMPLETE':
        metrics['water'] = Map<String, Object?>.from(fields);
      case 'WALKER_STAGED_PRECACHE_COMPLETE' ||
          'WALKER_STAGED_PRECACHE_INCOMPLETE':
        metrics['walker'] = Map<String, Object?>.from(fields);
      case 'RIFLE_REGRIP_PRECACHE_COMPLETE' ||
          'RIFLE_REGRIP_PRECACHE_INCOMPLETE':
        metrics['rifleRegrip'] = Map<String, Object?>.from(fields);
      case 'SLOW_FRAME_BATCH':
        final slowFrames =
            metrics.putIfAbsent('slowFrames', () => <Map<String, Object?>>[])!
                as List<Map<String, Object?>>;
        slowFrames.add(Map<String, Object?>.from(fields));
    }
  }
  return metrics;
}

double _number(Object? value) => value is num ? value.toDouble() : -1;
