import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'first Flutter frame is not gated by notification profile initialization',
    () {
      final source = File('lib/main.dart').readAsStringSync();
      final runApp = source.indexOf('runApp(');
      final notificationStart = source.indexOf(
        'unawaited(_initializeNotificationProfile(diagnostic));',
      );

      expect(runApp, greaterThanOrEqualTo(0));
      expect(notificationStart, greaterThan(runApp));
      expect(
        source.indexOf(
          'await NotificationProfileController.instance.initialize();',
        ),
        greaterThan(runApp),
      );
      expect(source, contains('NOTIFICATION_PROFILE_INITIALIZATION_FAILED'));
      expect(
        source,
        contains('startBackgroundRecovery()'),
        reason: 'configured profiles must reconcile after repository startup',
      );
      expect(
        source.indexOf(
          'final initialization = initializationService.initialize();',
        ),
        lessThan(
          source.indexOf(
            'await DeviceSettingsController.instance.initialize();',
          ),
        ),
        reason: 'database and device settings startup must overlap',
      );
      expect(
        source,
        contains('initializationService: initializationService'),
        reason: 'the prestarted single-flight service must own StartupGate',
      );
    },
  );
}
