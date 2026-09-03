// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use, prefer_initializing_formals

import 'dart:convert';
import 'dart:html' as html;

/// Temporary, bounded lifecycle trace used to diagnose Web/PWA startup only.
class StartupDiagnostic {
  StartupDiagnostic({this.eventLimit = 200, bool inMemory = false})
    : _inMemory = inMemory;

  factory StartupDiagnostic.testing({int eventLimit = 3}) =>
      StartupDiagnostic(eventLimit: eventLimit, inMemory: true);

  static final StartupDiagnostic instance = StartupDiagnostic();

  static const storageKey = 'or_app.startup_diagnostic.v1';
  static const bootSessionStorageKey =
      'or_app.initial_boot_presentation_claimed.v1';
  static const _documentRunKey = 'or_app.startup_diagnostic.document_run_id';

  final int eventLimit;
  final bool _inMemory;
  final List<Map<String, Object?>> _memoryEvents = [];
  String? _startupRunId;
  String? _currentPresentation;

  String get documentRunId {
    try {
      final value = html.window.sessionStorage[_documentRunKey];
      if (value != null && value.isNotEmpty) return value;
    } catch (_) {}
    return 'dart-${DateTime.now().microsecondsSinceEpoch}';
  }

  String? get startupRunId => _startupRunId;

  String? get currentPresentation => _currentPresentation;

  String bootSessionClaim() {
    try {
      return html.window.sessionStorage[bootSessionStorageKey] == 'true'
          ? 'present:true'
          : 'absent';
    } catch (_) {
      return 'unavailable';
    }
  }

  void beginRun() {
    _startupRunId =
        'startup-${DateTime.now().microsecondsSinceEpoch}-${documentRunId.hashCode.abs()}';
  }

  void record(
    String layer,
    String event, {
    String? state,
    String? presentation,
    Map<String, Object?> fields = const {},
  }) {
    try {
      if (presentation != null) {
        _currentPresentation = presentation;
      }
      final payload = _read();
      final events = payload.events;
      final sequence = payload.sequence + 1;
      events.add(<String, Object?>{
        'sequence': sequence,
        'timestamp': DateTime.now().toIso8601String(),
        'documentRunId': documentRunId,
        'startupRunId': _startupRunId,
        'layer': layer,
        'event': event,
        if (state case final String state) 'state': state,
        if (presentation case final String presentation)
          'presentation': presentation,
        if (fields.isNotEmpty) 'fields': fields,
      });
      if (events.length > eventLimit) {
        events.removeRange(0, events.length - eventLimit);
      }
      _write(sequence, events);
    } catch (_) {
      // Diagnostics are deliberately fail-open.
    }
  }

  List<Map<String, Object?>> get events {
    try {
      return List.unmodifiable(_read().events);
    } catch (_) {
      return const [];
    }
  }

  void clear() {
    try {
      if (_inMemory) {
        _memoryEvents.clear();
      } else {
        html.window.localStorage.remove(storageKey);
      }
    } catch (_) {}
  }

  String copyText() => const JsonEncoder.withIndent(
    '  ',
  ).convert({'title': 'OR-APP STARTUP DIAGNOSTIC', 'events': events});

  ({int sequence, List<Map<String, Object?>> events}) _read() {
    if (_inMemory) {
      return (sequence: _memoryEvents.length, events: _memoryEvents);
    }
    final raw = html.window.localStorage[storageKey];
    if (raw == null) return (sequence: 0, events: <Map<String, Object?>>[]);
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return (sequence: 0, events: <Map<String, Object?>>[]);
    final rawEvents = decoded['events'];
    final events = rawEvents is List
        ? rawEvents
              .whereType<Map>()
              .map(
                (item) =>
                    item.map((key, value) => MapEntry(key.toString(), value)),
              )
              .toList()
        : <Map<String, Object?>>[];
    return (
      sequence: decoded['sequence'] as int? ?? events.length,
      events: events,
    );
  }

  void _write(int sequence, List<Map<String, Object?>> events) {
    if (_inMemory) return;
    html.window.localStorage[storageKey] = jsonEncode({
      'sequence': sequence,
      'events': events,
    });
  }
}
