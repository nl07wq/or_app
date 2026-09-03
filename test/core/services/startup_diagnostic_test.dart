import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/services/startup_diagnostic.dart';

void main() {
  test('startup diagnostic keeps a bounded, copyable trace', () {
    final diagnostic = StartupDiagnostic.testing(eventLimit: 2)..beginRun();

    diagnostic.record('DART', 'ONE', presentation: 'BOOT');
    diagnostic.record('FLUTTER', 'TWO', presentation: 'INITIALIZING');
    diagnostic.record('FLUTTER', 'THREE', presentation: 'MAIN_UI');

    expect(diagnostic.events, hasLength(2));
    expect(diagnostic.events.first['event'], 'TWO');
    expect(diagnostic.copyText(), contains('OR-APP STARTUP DIAGNOSTIC'));
    expect(diagnostic.copyText(), contains('THREE'));
  });

  test('startup diagnostic clear does not affect the current run identity', () {
    final diagnostic = StartupDiagnostic.testing()..beginRun();
    final runId = diagnostic.startupRunId;
    diagnostic.record('DART', 'DART_MAIN_ENTER');

    diagnostic.clear();

    expect(diagnostic.events, isEmpty);
    expect(diagnostic.startupRunId, runId);
  });
}
