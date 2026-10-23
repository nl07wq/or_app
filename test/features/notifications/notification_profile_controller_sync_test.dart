import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/notifications/services/notification_profile_controller.dart';
import 'package:or_app/features/notifications/services/push_bridge.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _profileId = 'profile-12345678901234567890';
const _profileSecret = 'profile-secret-12345678901234567890';
const _outboxKey = 'or_app_notification_outbox_v1';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'newer outbox generation survives an older in-flight reconciliation',
    () async {
      final bridge = _RecordingPushBridge(holdFirstReconcile: true);
      final controller = await _configuredController(bridge);
      final preferences = await SharedPreferences.getInstance();
      const generationA = '{"generation":"A","projections":[]}';
      const generationB = '{"generation":"B","projections":[]}';
      await preferences.setString(_outboxKey, generationA);

      final first = controller.syncPending();
      await bridge.waitForReconcileCount(1);
      await preferences.setString(_outboxKey, generationB);
      final second = controller.syncPending();
      bridge.releaseFirstReconcile();
      await Future.wait([first, second]);

      expect(bridge.reconcileBodies, [generationA, generationB]);
      expect(preferences.getString(_outboxKey), isNull);
      expect(controller.value.pendingSync, isFalse);
      controller.dispose();
    },
  );

  test(
    'concurrent requests share one drain and do not duplicate one generation',
    () async {
      final bridge = _RecordingPushBridge(holdFirstReconcile: true);
      final controller = await _configuredController(bridge);
      final preferences = await SharedPreferences.getInstance();
      const body = '{"generation":"A","projections":[]}';
      await preferences.setString(_outboxKey, body);

      final first = controller.syncPending();
      await bridge.waitForReconcileCount(1);
      final second = controller.syncPending();
      bridge.releaseFirstReconcile();
      await Future.wait([first, second]);

      expect(bridge.reconcileBodies, [body]);
      controller.dispose();
    },
  );

  test(
    'failed delivery preserves the durable outbox for a later recovery',
    () async {
      final bridge = _RecordingPushBridge(failReconcile: true);
      final controller = await _configuredController(bridge);
      final preferences = await SharedPreferences.getInstance();
      const body = '{"generation":"recover","projections":[]}';
      await preferences.setString(_outboxKey, body);

      await controller.syncPending();
      expect(preferences.getString(_outboxKey), body);
      expect(controller.value.pendingSync, isTrue);

      bridge.failReconcile = false;
      await controller.recoverOnForeground();
      expect(bridge.reconcileBodies, [body, body]);
      expect(preferences.getString(_outboxKey), isNull);
      controller.dispose();
    },
  );
}

Future<NotificationProfileController> _configuredController(
  _RecordingPushBridge bridge,
) async {
  final controller = NotificationProfileController(
    bridge: bridge,
    apiBase: 'https://notifications.example.test',
  );
  await controller.initialize();
  await controller.recoverProfile(_profileId, 'recovery-token');
  return controller;
}

class _RecordingPushBridge extends PushBridge {
  _RecordingPushBridge({
    this.holdFirstReconcile = false,
    this.failReconcile = false,
  });

  final bool holdFirstReconcile;
  bool failReconcile;
  final List<String> reconcileBodies = <String>[];
  final Completer<void> _firstReconcileGate = Completer<void>();
  bool _firstReconcileHeld = false;

  @override
  String permission() => 'granted';

  @override
  String randomToken([int bytes = 32]) => 'installation-12345678901234567890';

  @override
  Future<String> request(
    String url,
    String method, {
    String? token,
    String? body,
  }) async {
    if (url.endsWith('/recover')) return '{"profileSecret":"$_profileSecret"}';
    if (url.endsWith('/status')) return '{}';
    if (url.endsWith('/projections/reconcile')) {
      reconcileBodies.add(body!);
      if (holdFirstReconcile && !_firstReconcileHeld) {
        _firstReconcileHeld = true;
        await _firstReconcileGate.future;
      }
      if (failReconcile) throw StateError('offline');
      return '{}';
    }
    throw StateError('unexpected request: $method $url');
  }

  Future<void> waitForReconcileCount(int count) async {
    for (
      var attempts = 0;
      reconcileBodies.length < count && attempts < 20;
      attempts++
    ) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(reconcileBodies.length, greaterThanOrEqualTo(count));
  }

  void releaseFirstReconcile() {
    if (!_firstReconcileGate.isCompleted) _firstReconcileGate.complete();
  }
}
