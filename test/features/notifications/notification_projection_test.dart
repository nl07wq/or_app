import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/notifications/models/notification_configuration.dart';
import 'package:or_app/features/notifications/services/notification_projection.dart';

int tokyoWallTime(String date, String time, String zone) {
  expect(zone, 'Asia/Tokyo');
  return DateTime.parse('${date}T$time:00+09:00').millisecondsSinceEpoch;
}

void main() {
  const timed = NotificationSourceOccurrence(
    entityType: 'schedule',
    entityId: 'series@2026-10-08',
    localDate: '2026-10-08',
    allDay: false,
    startTime: '09:00',
    timeZone: 'Asia/Tokyo',
    offsetsMinutes: [0, 15, 60, 60],
    title: '診察',
  );

  test('timed projections use start time and deduplicate offsets', () {
    final values = const NotificationProjectionPlanner(tokyoWallTime).project(
      [timed],
      privacyMode: NotificationPrivacyMode.titleVisible,
      now: DateTime.utc(2026, 10, 1),
    );

    expect(values, hasLength(3));
    expect(values.first.triggerAt, DateTime.utc(2026, 10, 7, 23));
    expect(values.last.triggerAt, DateTime.utc(2026, 10, 8));
    expect(values.last.title, '診察');
  });

  test('all-day authority is pinned local midnight', () {
    final values = const NotificationProjectionPlanner(tokyoWallTime).project(
      [
        const NotificationSourceOccurrence(
          entityType: 'reminder',
          entityId: 'daily@2026-10-08',
          localDate: '2026-10-08',
          allDay: true,
          startTime: '19:30',
          timeZone: 'Asia/Tokyo',
          offsetsMinutes: [0],
          title: 'ignored time',
        ),
      ],
      privacyMode: NotificationPrivacyMode.contentHidden,
      now: DateTime.utc(2026, 10, 1),
    );

    expect(values.single.triggerAt, DateTime.utc(2026, 10, 7, 15));
    expect(values.single.title, isNull);
    expect(values.single.toJson(), isNot(contains('title')));
  });

  test('past projections are cancelled by omission during reconciliation', () {
    final values = const NotificationProjectionPlanner(tokyoWallTime).project(
      [timed],
      privacyMode: NotificationPrivacyMode.titleVisible,
      now: DateTime.utc(2026, 10, 9),
    );
    expect(values, isEmpty);
  });
}
