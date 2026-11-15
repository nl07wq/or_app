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

  test('slow frames retain the latest startup and map phases', () {
    final diagnostics = SystemDiagnostics.testing()
      ..record('APPLICATION', 'DART_MAIN_ENTER')
      ..record('BASE_CAMP', 'DASHBOARD_FIRST_FRAME')
      ..record('BASE_CAMP', 'MAP_BACKGROUND_READY')
      ..record(
        'PERFORMANCE',
        'SLOW_FRAME_BATCH',
        fields: const <String, Object?>{'worstFrameMs': 1344},
      );

    final events = diagnostics.sessions.single['events']! as List;
    final slow = (events.last as Map)['fields'] as Map;
    expect(slow['worstFrameMs'], 1344);
    expect(slow['lastStartupPhase'], 'BASE_CAMP/DASHBOARD_FIRST_FRAME');
    expect(slow['lastMapPhase'], 'BASE_CAMP/MAP_BACKGROUND_READY');
  });

  test(
    'window errors retain available browser details without health data',
    () {
      final diagnostics = SystemDiagnostics.testing()
        ..record('BASE_CAMP', 'DASHBOARD_FIRST_FRAME')
        ..record('ASSET', 'FACILITY_OBJECTS_ATOMIC_PREPARE_START')
        ..recordWindowErrorDetailsForTesting(<String, Object?>{
          'eventType': 'error',
          'errorType': 'NativeError',
          'errorName': 'TypeError',
          'errorMessage': 'synthetic browser failure',
          'stack': 'synthetic stack',
          'filename': 'main.dart.js',
          'line': 7167,
          'column': 8,
        });

      final trace = diagnostics.copyText();
      expect(trace, contains('WINDOW_ERROR'));
      expect(trace, contains('TypeError'));
      expect(trace, contains('synthetic browser failure'));
      expect(trace, contains('synthetic stack'));
      expect(trace, contains('main.dart.js'));
      expect(trace, contains('7167'));
      expect(trace, contains('BASE_CAMP/DASHBOARD_FIRST_FRAME'));
      expect(trace, contains('ASSET/FACILITY_OBJECTS_ATOMIC_PREPARE_START'));
      expect(trace, isNot(contains('health')));
    },
  );
}
