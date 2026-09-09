import 'dart:convert';

/// Temporary, bounded parity trace for the Dashboard and Command Center
/// post-finalize Backup presentation investigation. It deliberately records
/// lifecycle metadata only; no formal record contents are captured.
class FinalizeBackupTrace {
  FinalizeBackupTrace({this.eventLimit = 120});

  static final FinalizeBackupTrace instance = FinalizeBackupTrace();

  final int eventLimit;
  final List<Map<String, Object?>> _events = [];
  int _sequence = 0;

  List<Map<String, Object?>> get events => List.unmodifiable(_events);

  void record(
    String source,
    String event, {
    String? operationDate,
    Map<String, Object?> fields = const {},
  }) {
    _events.add({
      'sequence': ++_sequence,
      'timestamp': DateTime.now().toIso8601String(),
      'source': source,
      'event': event,
      'operationDate': ?operationDate,
      if (fields.isNotEmpty) 'fields': fields,
    });
    if (_events.length > eventLimit) {
      _events.removeRange(0, _events.length - eventLimit);
    }
  }

  void clear() {
    _events.clear();
    _sequence = 0;
  }

  String copyText() => const JsonEncoder.withIndent('  ').convert({
    'title': 'OR-APP DAILY FINALIZE BACKUP PARITY TRACE',
    'events': _events,
  });
}
