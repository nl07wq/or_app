import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/services/active_session_heartbeat.dart';
import 'package:or_app/core/services/boot_presentation_session.dart';

void main() {
  final now = DateTime(2026, 9, 4, 12);

  ActiveSessionHeartbeat heartbeatWithAge(Duration age) {
    final storage = InMemoryActiveSessionStorage({
      ActiveSessionHeartbeat.storageKey: jsonEncode({
        'version': 1,
        'lastAliveAtMs': now.subtract(age).millisecondsSinceEpoch,
        'documentRunId': 'document-a',
      }),
    });
    return ActiveSessionHeartbeat(
      now: () => now,
      storage: storage,
      documentRunId: 'document-b',
    );
  }

  test('recent heartbeat creates an active-session reentry claim denial', () {
    final heartbeat = heartbeatWithAge(const Duration(seconds: 5));

    final result = heartbeat.classifyAtStartup();

    expect(
      result.classification,
      ActiveSessionClassification.activeSessionReentry,
    );
    expect(result.heartbeatAgeMs, 5000);
    final session = BootPresentationSession(activeSessionHeartbeat: heartbeat);
    expect(session.claimInitialBootPresentation(), isFalse);
    expect(session.lastClaimReason, 'activeSessionReentry');
  });

  test(
    'heartbeat remains active until, but not at, the ten-minute boundary',
    () {
      final nearExpiry = heartbeatWithAge(
        ActiveSessionHeartbeat.sessionTimeout - const Duration(seconds: 1),
      );
      expect(
        nearExpiry.classifyAtStartup().classification,
        ActiveSessionClassification.activeSessionReentry,
      );

      final atExpiry = heartbeatWithAge(ActiveSessionHeartbeat.sessionTimeout);
      expect(
        atExpiry.classifyAtStartup().classification,
        ActiveSessionClassification.newSession,
      );
    },
  );

  test(
    'absent, malformed, and future heartbeats fail open to a new session',
    () {
      final absent = ActiveSessionHeartbeat(
        now: () => now,
        storage: InMemoryActiveSessionStorage(),
      );
      expect(
        absent.classifyAtStartup().classification,
        ActiveSessionClassification.newSession,
      );

      final malformed = ActiveSessionHeartbeat(
        now: () => now,
        storage: InMemoryActiveSessionStorage({
          ActiveSessionHeartbeat.storageKey: 'not-json',
        }),
      );
      expect(
        malformed.classifyAtStartup().classification,
        ActiveSessionClassification.newSession,
      );

      final future = ActiveSessionHeartbeat(
        now: () => now,
        storage: InMemoryActiveSessionStorage({
          ActiveSessionHeartbeat.storageKey: jsonEncode({
            'version': 1,
            'lastAliveAtMs': now
                .add(const Duration(seconds: 1))
                .millisecondsSinceEpoch,
          }),
        }),
      );
      expect(
        future.classifyAtStartup().classification,
        ActiveSessionClassification.newSession,
      );
    },
  );

  test(
    'retired PAGEHIDE marker is removed and cannot affect classification',
    () {
      final storage = InMemoryActiveSessionStorage({
        ActiveSessionHeartbeat.retiredReentryMarkerKey: '{"pageHideAtMs":1}',
      });
      final heartbeat = ActiveSessionHeartbeat(
        now: () => now,
        storage: storage,
      );

      expect(
        heartbeat.classifyAtStartup().classification,
        ActiveSessionClassification.newSession,
      );
      expect(
        storage.read(ActiveSessionHeartbeat.retiredReentryMarkerKey),
        isNull,
      );
    },
  );

  test('storage failures fail open to a new session without throwing', () {
    final heartbeat = ActiveSessionHeartbeat(
      now: () => now,
      storage: _ThrowingActiveSessionStorage(),
    );

    expect(
      heartbeat.classifyAtStartup().classification,
      ActiveSessionClassification.newSession,
    );
    heartbeat.start();
    heartbeat.dispose();
  });

  test(
    'reset removes the actual heartbeat and restores ordinary boot eligibility',
    () {
      final storage = InMemoryActiveSessionStorage({
        ActiveSessionHeartbeat.storageKey: jsonEncode({
          'version': 1,
          'lastAliveAtMs': now.millisecondsSinceEpoch,
        }),
        'unrelated': 'preserved',
      });
      final heartbeat = ActiveSessionHeartbeat(
        now: () => now,
        storage: storage,
      );
      expect(
        heartbeat.classifyAtStartup().classification,
        ActiveSessionClassification.activeSessionReentry,
      );
      expect(heartbeat.resetHeartbeat(), isTrue);
      expect(storage.read(ActiveSessionHeartbeat.storageKey), isNull);
      expect(storage.read('unrelated'), 'preserved');
      expect(
        heartbeat.classifyAtStartup().classification,
        ActiveSessionClassification.newSession,
      );
    },
  );

  test('reset keeps the current document heartbeat-silent until it exits', () {
    var current = now;
    final storage = InMemoryActiveSessionStorage();
    final heartbeat = ActiveSessionHeartbeat(
      now: () => current,
      storage: storage,
    );
    heartbeat.start();
    expect(storage.read(ActiveSessionHeartbeat.storageKey), isNotNull);

    expect(heartbeat.resetHeartbeat(), isTrue);
    expect(storage.read(ActiveSessionHeartbeat.storageKey), isNull);
    current = current.add(const Duration(seconds: 1));
    heartbeat.heartbeatNow();
    heartbeat.handleVisibilityChange(false);
    heartbeat.handleVisibilityChange(true);
    heartbeat.start();
    expect(storage.read(ActiveSessionHeartbeat.storageKey), isNull);
    heartbeat.dispose();

    final nextDocument = ActiveSessionHeartbeat(
      now: () => current,
      storage: storage,
    );
    expect(
      nextDocument.classifyAtStartup().classification,
      ActiveSessionClassification.newSession,
    );
    nextDocument.start();
    expect(storage.read(ActiveSessionHeartbeat.storageKey), isNotNull);
    nextDocument.dispose();
  });

  test('heartbeat stops while hidden and resumes when visible', () {
    var current = now;
    final storage = InMemoryActiveSessionStorage();
    final heartbeat = ActiveSessionHeartbeat(
      now: () => current,
      storage: storage,
    );

    heartbeat.start();
    final first = _lastAlive(storage);
    current = current.add(const Duration(seconds: 1));
    heartbeat.handleVisibilityChange(false);
    final hidden = _lastAlive(storage);
    current = current.add(const Duration(minutes: 5));
    heartbeat.heartbeatNow();
    expect(_lastAlive(storage), hidden);
    expect(hidden, greaterThanOrEqualTo(first));

    heartbeat.handleVisibilityChange(true);
    expect(_lastAlive(storage), current.millisecondsSinceEpoch);
    heartbeat.dispose();
  });
}

int _lastAlive(InMemoryActiveSessionStorage storage) {
  final decoded = jsonDecode(storage.read(ActiveSessionHeartbeat.storageKey)!);
  return decoded['lastAliveAtMs'] as int;
}

class _ThrowingActiveSessionStorage implements ActiveSessionStorage {
  @override
  String? read(String key) => throw StateError('storage unavailable');

  @override
  void remove(String key) => throw StateError('storage unavailable');

  @override
  void write(String key, String value) =>
      throw StateError('storage unavailable');
}
