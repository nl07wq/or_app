import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/notifications/services/notification_profile_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
    'unavailable notification storage leaves a recoverable status',
    () async {
      final controller = NotificationProfileController(
        preferencesLoader: () =>
            Future<SharedPreferences>.error(StateError('storage unavailable')),
      );

      await expectLater(controller.initialize(), throwsStateError);

      expect(controller.value.profile, 'unavailable');
      expect(
        controller.value.error,
        'Notification profile storage is unavailable.',
      );
    },
  );
}
