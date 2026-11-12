import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/services/system_diagnostics.dart';

void main() {
  test('diagnostics bounds events and deduplicates asset records', () {
    final diagnostics = SystemDiagnostics.testing(eventLimit: 2)
      ..beginSession()
      ..record('TEST', 'ONE')
      ..recordAssetOnce('asset.png', bytes: 10, width: 2, height: 3)
      ..recordAssetOnce('asset.png', bytes: 10, width: 2, height: 3)
      ..record('TEST', 'THREE');

    final events = diagnostics.sessions.single['events']! as List;
    expect(events, hasLength(2));
    expect(diagnostics.copyText(), contains('estimatedDecodedBytes'));
  });

  test('an unfinished restored session is only marked as suspected', () {
    final first = SystemDiagnostics.testing()..beginSession();
    first.record('BASE_CAMP', 'DASHBOARD_FIRST_FRAME');
    final restored = SystemDiagnostics.testing(
      initialSessions: first.sessions
          .map((session) => Map<String, Object?>.from(session))
          .toList(),
    )..beginSession();

    expect(restored.previousSessionAbnormalSuspected, isTrue);
    expect(restored.sessions.first['abnormalTerminationSuspected'], isTrue);
    expect(restored.sessions.first['status'], 'active');
  });

  test('completed sessions are not classified as abnormal', () {
    final first = SystemDiagnostics.testing()
      ..beginSession()
      ..completeSession();
    final restored = SystemDiagnostics.testing(
      initialSessions: first.sessions
          .map((session) => Map<String, Object?>.from(session))
          .toList(),
    )..beginSession();

    expect(restored.previousSessionAbnormalSuspected, isFalse);
  });
}
