import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('startup recovery retires only identifiable legacy Flutter workers', () {
    final source = File('web/index.html').readAsStringSync();

    expect(
      source,
      contains("scriptNameIs(script, 'flutter_service_worker.js')"),
    );
    expect(source, contains("scriptNameIs(script, 'or_app_push_sw.js')"));
    expect(source, contains('registration.active'));
    expect(source, contains('registration.waiting'));
    expect(source, contains('registration.installing'));
    expect(source, contains('scripts.length === 0'));
    expect(source, contains('script === null'));
    expect(source, contains('if (retired && attempts < 2)'));
    expect(source, isNot(contains('retired || hadController')));
  });

  test('push status verifies worker identity, permission and subscription', () {
    final source = File('web/or_app_push_bridge.js').readAsStringSync();

    expect(source, contains('registrationUsesPushWorker(current)'));
    expect(source, contains("Notification.permission !== 'granted'"));
    expect(source, contains("'PushManager' in window"));
    expect(source, contains('current.pushManager.getSubscription()'));
    expect(source, contains("subscription ? 'registered' : 'not_subscribed'"));
  });
}
