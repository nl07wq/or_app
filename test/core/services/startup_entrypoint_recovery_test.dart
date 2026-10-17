import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'first Flutter frame is not gated by notification profile initialization',
    () {
      final source = File('lib/main.dart').readAsStringSync();
      final runApp = source.indexOf('runApp(const OperationRebootApp());');
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
    },
  );
}
