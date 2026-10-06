import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/notifications/models/notification_configuration.dart';

void main() {
  test('canonical equivalent offsets deduplicate', () {
    final oneHour = canonicalNotificationOffset(
      1,
      NotificationOffsetUnit.hours,
    );
    final sixtyMinutes = canonicalNotificationOffset(
      60,
      NotificationOffsetUnit.minutes,
    );
    final configuration = NotificationConfiguration(
      offsetsMinutes: [oneHour, sixtyMinutes, 60],
      timeZone: 'Asia/Tokyo',
    );

    expect(configuration.offsetsMinutes, [60]);
  });

  test('zero and multiple notification offsets remain sorted', () {
    final configuration = NotificationConfiguration(
      offsetsMinutes: [1440, 0, 15, 60],
      timeZone: 'Asia/Tokyo',
    );

    expect(configuration.offsetsMinutes, [0, 15, 60, 1440]);
    expect(notificationOffsetLabel(0), '開始時刻');
    expect(notificationOffsetLabel(1440), '1日前');
  });
}
