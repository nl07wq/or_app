import 'dart:convert';

/// Temporary, bounded lifecycle trace used to diagnose Web/PWA startup only.
class StartupDiagnostic {
  StartupDiagnostic({this.eventLimit = 200, bool inMemory = false});

  factory StartupDiagnostic.testing({int eventLimit = 3}) =>
      StartupDiagnostic(eventLimit: eventLimit, inMemory: true);

  static final StartupDiagnostic instance = StartupDiagnostic();

  static const bootSessionStorageKey =
      'or_app.initial_boot_presentation_claimed.v1';

  final int eventLimit;
  final List<Map<String, Object?>> _events = [];
  int _sequence = 0;
  final String _documentRunId = 'non-web-document';
  String? _startupRunId;
  String? _currentPresentation;

  String get documentRunId => _documentRunId;

  String? get startupRunId => _startupRunId;

  String? get currentPresentation => _currentPresentation;

  String bootSessionClaim() => 'unavailable';

  void beginRun() {
    _startupRunId = 'startup-${DateTime.now().microsecondsSinceEpoch}';
  }

  void record(
    String layer,
    String event, {
    String? state,
    String? presentation,
    Map<String, Object?> fields = const {},
  }) {
    if (presentation != null) {
      _currentPresentation = presentation;
    }
    final entry = <String, Object?>{
      'sequence': ++_sequence,
      'timestamp': DateTime.now().toIso8601String(),
      'documentRunId': _documentRunId,
      'startupRunId': _startupRunId,
      'layer': layer,
      'event': event,
      if (state case final String state) 'state': state,
      if (presentation case final String presentation)
        'presentation': presentation,
      if (fields.isNotEmpty) 'fields': fields,
    };
    _events.add(entry);
    if (_events.length > eventLimit) {
      _events.removeRange(0, _events.length - eventLimit);
    }
  }

  List<Map<String, Object?>> get events => List.unmodifiable(_events);

  void clear() {
    _events.clear();
    _sequence = 0;
  }

  String copyText() => const JsonEncoder.withIndent(
    '  ',
  ).convert({'title': 'OR-APP STARTUP DIAGNOSTIC', 'events': _events});
}
