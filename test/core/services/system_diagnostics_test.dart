import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/services/diagnostic_sanitizer.dart';
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

  test('navigation evidence sanitizes valid and invalid URI inputs', () {
    const invalidRoute = 'http://or-app.invalid:bad/path?password=hidden';
    expect(() => Uri.parse(invalidRoute), throwsFormatException);
    final diagnostics = SystemDiagnostics.testing()
      ..recordNavigation(
        action: 'push',
        previousRoute: '/dashboard',
        requestedRoute: '/calendar?token=secret&day=16#private',
        routeType: 'MaterialPageRoute<void>',
      )
      ..recordNavigation(
        action: 'push',
        previousRoute: '/calendar',
        requestedRoute: invalidRoute,
      )
      ..recordWindowErrorDetailsForTesting(<String, Object?>{
        'errorName': 'FormatException',
      });

    final trace = diagnostics.copyText();
    expect(trace, contains('calendar'));
    expect(trace, contains('queryKeys'));
    expect(trace, contains('day'));
    expect(trace, contains('http://or-app.invalid:bad/path'));
    expect(trace, contains('"valid": false'));
    expect(trace, contains('recentNavigation'));
    expect(trace, isNot(contains('secret')));
    expect(trace, isNot(contains('hidden')));
  });

  test('URI sanitizer never retains query values or fragments', () {
    final sanitized = sanitizeDiagnosticUri(
      'https://example.test/path?access_token=abc&date=2026-11-16#memo',
    );
    expect(sanitized['path'], '/path');
    expect(sanitized['queryKeys'], <String>['date']);
    expect(sanitized['hasFragment'], isTrue);
    expect('$sanitized', isNot(contains('abc')));
    expect('$sanitized', isNot(contains('memo')));
  });

  test(
    'startup stages record success, failure, and monotonic duration',
    () async {
      final diagnostics = SystemDiagnostics.testing();
      final value = await diagnostics.traceStage<int>(
        'successful_stage',
        () async {
          await Future<void>.delayed(const Duration(milliseconds: 2));
          return 7;
        },
      );
      expect(value, 7);

      await expectLater(
        diagnostics.traceStage<void>(
          'failed_stage',
          () async => throw StateError('expected'),
        ),
        throwsStateError,
      );

      final events = diagnostics.sessions.single['events']! as List;
      final completed = events.cast<Map>().firstWhere(
        (event) => event['event'] == 'STAGE_COMPLETE',
      );
      final completedFields = completed['fields']! as Map;
      expect(completedFields['elapsedMs'] as num, greaterThanOrEqualTo(1));
      expect(completedFields['durationClock'], 'monotonic');
      expect(
        events.cast<Map>().any(
          (event) =>
              event['event'] == 'STAGE_FAILED' &&
              (event['fields'] as Map)['errorType'] == 'StateError',
        ),
        isTrue,
      );
    },
  );

  test(
    'startup stage records lifecycle changes during async waiting',
    () async {
      final diagnostics = SystemDiagnostics.testing()
        ..recordLifecycleState('resumed');
      final release = Completer<void>();
      final stage = diagnostics.traceStage<void>(
        'backgrounded_stage',
        () => release.future,
      );
      diagnostics.recordLifecycleState('paused');
      diagnostics.recordLifecycleState('resumed');
      release.complete();
      await stage;

      final events = diagnostics.sessions.single['events']! as List;
      final completed = events.cast<Map>().firstWhere(
        (event) =>
            event['event'] == 'STAGE_COMPLETE' &&
            (event['fields'] as Map)['stage'] == 'backgrounded_stage',
      );
      final fields = completed['fields']! as Map;
      expect(fields['startLifecycle'], 'resumed');
      expect(fields['endLifecycle'], 'resumed');
      expect(fields['lifecycleChanged'], isTrue);
    },
  );

  test('critical evidence survives the per-session retention limit', () {
    final diagnostics = SystemDiagnostics.testing(eventLimit: 4)
      ..recordNavigation(action: 'push', requestedRoute: '/calendar')
      ..record('ASSET', 'ROUTINE_1')
      ..record('ASSET', 'ROUTINE_2')
      ..record('ASSET', 'ROUTINE_3')
      ..recordWindowErrorDetailsForTesting(<String, Object?>{
        'errorName': 'FormatException',
      })
      ..record('ASSET', 'ROUTINE_4');

    final events = diagnostics.sessions.single['events']! as List;
    expect(events, hasLength(4));
    expect(
      events.cast<Map>().any((event) => event['event'] == 'ROUTE_REQUEST'),
      isTrue,
    );
    expect(
      events.cast<Map>().any((event) => event['event'] == 'WINDOW_ERROR'),
      isTrue,
    );
    expect(diagnostics.copyText(), contains('FormatException'));
  });

  test('diagnostic collection overhead remains bounded', () {
    final diagnostics = SystemDiagnostics.testing(eventLimit: 200)
      ..beginSession();
    final stopwatch = Stopwatch()..start();
    for (var index = 0; index < 1000; index++) {
      diagnostics.record(
        'TEST',
        'ROUTINE_EVENT',
        fields: <String, Object?>{'sequence': index},
      );
    }
    stopwatch.stop();
    // This guards against accidental expensive serialization on every event.
    // Production Web persistence remains batched by the existing 500ms timer.
    expect(stopwatch.elapsedMilliseconds, lessThan(500));
    // ignore: avoid_print
    print('DIAGNOSTIC_1000_EVENT_OVERHEAD_US=${stopwatch.elapsedMicroseconds}');
  });

  test('slow startup thresholds freeze an independent bounded incident', () {
    final diagnostics = SystemDiagnostics.testing(eventLimit: 2)
      ..record('APPLICATION', 'DART_MAIN_ENTER')
      ..record(
        'ASSET',
        'FACILITY_OBJECTS_ATOMIC_PREPARE_COMPLETE',
        fields: const <String, Object?>{'durationMs': 3000},
      )
      ..record('ASSET', 'ROUTINE_1')
      ..record('ASSET', 'ROUTINE_2')
      ..record('ASSET', 'ROUTINE_3');

    expect(diagnostics.sessions.single['events'], hasLength(2));
    expect(diagnostics.slowStartupIncidentCount, 1);
    expect(
      diagnostics.copySlowStartupEvidenceText(),
      allOf(contains('facility_atomic_preparation'), contains('3000')),
    );
    expect(diagnostics.copyText(), contains('preDartEvidence'));
  });

  test(
    'slow startup evidence survives restart and retains newest five',
    () async {
      var incidents = <Map<String, Object?>>[];
      for (var index = 0; index < 6; index++) {
        final diagnostics =
            SystemDiagnostics.testing(initialSlowStartupIncidents: incidents)
              ..record(
                'ASSET',
                'WATER_FX_INIT_COMPLETE',
                fields: <String, Object?>{'durationMs': 4000 + index},
              );
        final decoded = jsonDecode(diagnostics.copySlowStartupEvidenceText());
        final decodedIncidents = (decoded as Map)['incidents'] as List;
        incidents = decodedIncidents
            .whereType<Map>()
            .map(
              (incident) => incident.map<String, Object?>(
                (key, value) => MapEntry(key.toString(), value),
              ),
            )
            .toList(growable: false);
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }

      final restored = SystemDiagnostics.testing(
        initialSlowStartupIncidents: incidents,
      );
      expect(restored.slowStartupIncidentCount, 5);
      expect(restored.copyText(), contains('slowStartupEvidence'));
    },
  );

  test('all requested slow startup trigger thresholds are inclusive', () {
    final diagnostics = SystemDiagnostics.testing()
      ..record(
        'BROWSER',
        'BROWSER_STARTUP_TIMING',
        fields: const <String, Object?>{'documentToDartMainMs': 5000},
      )
      ..record(
        'ASSET',
        'WALKER_STAGED_PRECACHE_COMPLETE',
        fields: const <String, Object?>{'durationMs': 5000},
      )
      ..record(
        'ASSET',
        'WATER_FX_INIT_COMPLETE',
        fields: const <String, Object?>{'durationMs': 4000},
      );

    final export = diagnostics.copySlowStartupEvidenceText();
    expect(export, contains('document_to_dart_main'));
    expect(export, contains('walker_preparation'));
    expect(export, contains('water_fx_preparation'));
  });
}
