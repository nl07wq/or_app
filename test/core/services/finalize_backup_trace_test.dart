import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/services/finalize_backup_trace.dart';

void main() {
  test('records bounded source-specific parity events as copyable JSON', () {
    final trace = FinalizeBackupTrace(eventLimit: 2);

    trace.record('DASHBOARD', 'FINALIZE_STARTED', operationDate: '2026-09-08');
    trace.record(
      'COMMAND_CENTER',
      'BACKUP_PROMPT_REQUESTED',
      operationDate: '2026-09-08',
      fields: {'navigatorMounted': true},
    );
    trace.record('COMMAND_CENTER', 'BACKUP_PROMPT_VISIBLE');

    expect(trace.events, hasLength(2));
    expect(trace.events.first['source'], 'COMMAND_CENTER');
    expect(
      trace.copyText(),
      contains('OR-APP DAILY FINALIZE BACKUP PARITY TRACE'),
    );
    expect(trace.copyText(), contains('BACKUP_PROMPT_VISIBLE'));

    trace.clear();
    expect(trace.events, isEmpty);
  });
}
