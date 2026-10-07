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

  test('reminder time edit keeps identity and replaces its trigger', () {
    const planner = NotificationProjectionPlanner(tokyoWallTime);
    final before = planner.project(
      [
        _reminder(time: '09:15', offsets: const [5]),
      ],
      privacyMode: NotificationPrivacyMode.titleVisible,
      now: DateTime.utc(2026, 10, 1),
    );
    final after = planner.project(
      [
        _reminder(time: '09:30', offsets: const [5]),
      ],
      privacyMode: NotificationPrivacyMode.titleVisible,
      now: DateTime.utc(2026, 10, 1),
    );

    expect(after.single.id, before.single.id);
    expect(before.single.triggerAt, DateTime.utc(2026, 10, 8, 0, 10));
    expect(after.single.triggerAt, DateTime.utc(2026, 10, 8, 0, 25));
  });

  test('date and offset edits omit every stale reminder projection', () {
    const planner = NotificationProjectionPlanner(tokyoWallTime);
    final before = planner.project(
      [
        _reminder(time: '09:15', offsets: const [5, 10]),
      ],
      privacyMode: NotificationPrivacyMode.titleVisible,
      now: DateTime.utc(2026, 10, 1),
    );
    final afterDate = planner.project(
      [
        _reminder(
          localDate: '2026-10-09',
          time: '09:15',
          offsets: const [5, 10],
        ),
      ],
      privacyMode: NotificationPrivacyMode.titleVisible,
      now: DateTime.utc(2026, 10, 1),
    );
    final afterOffsets = planner.project(
      [
        _reminder(time: '09:15', offsets: const [5, 15]),
      ],
      privacyMode: NotificationPrivacyMode.titleVisible,
      now: DateTime.utc(2026, 10, 1),
    );

    expect(
      before
          .map((value) => value.id)
          .toSet()
          .intersection(afterDate.map((value) => value.id).toSet()),
      isEmpty,
    );
    expect(
      afterOffsets.map((value) => value.id),
      contains(
        '${before.first.entityType}:${before.first.entityId}@2026-10-08:5',
      ),
    );
    expect(
      afterOffsets.map((value) => value.id),
      isNot(
        contains(
          '${before.first.entityType}:${before.first.entityId}@2026-10-08:10',
        ),
      ),
    );
    expect(afterOffsets, hasLength(2));
  });

  test('privacy mode cannot change reminder projection identity', () {
    const planner = NotificationProjectionPlanner(tokyoWallTime);
    final visible = planner.project(
      [
        _reminder(time: '09:15', offsets: const [5, 10, 10]),
      ],
      privacyMode: NotificationPrivacyMode.titleVisible,
      now: DateTime.utc(2026, 10, 1),
    );
    final hidden = planner.project(
      [
        _reminder(time: '09:15', offsets: const [5, 10, 10]),
      ],
      privacyMode: NotificationPrivacyMode.contentHidden,
      now: DateTime.utc(2026, 10, 1),
    );

    expect(hidden.map((value) => value.id), visible.map((value) => value.id));
    expect(
      hidden.map((value) => value.triggerAt),
      visible.map((value) => value.triggerAt),
    );
    expect(visible.every((value) => value.title == 'テスト'), isTrue);
    expect(hidden.every((value) => value.title == null), isTrue);
    expect(hidden, hasLength(2));
  });

  test('reminder projection reconciliation input is idempotent', () {
    const planner = NotificationProjectionPlanner(tokyoWallTime);
    final occurrence = _reminder(time: '09:30', offsets: const [5, 15, 30]);
    final first = planner
        .project(
          [occurrence],
          privacyMode: NotificationPrivacyMode.titleVisible,
          now: DateTime.utc(2026, 10, 1),
        )
        .map((value) => value.toJson())
        .toList();
    final second = planner
        .project(
          [occurrence],
          privacyMode: NotificationPrivacyMode.titleVisible,
          now: DateTime.utc(2026, 10, 1),
        )
        .map((value) => value.toJson())
        .toList();

    expect(second, first);
  });
}

NotificationSourceOccurrence _reminder({
  String localDate = '2026-10-08',
  required String time,
  required List<int> offsets,
}) => NotificationSourceOccurrence(
  entityType: 'reminder',
  entityId: 'reminder-id@$localDate',
  localDate: localDate,
  allDay: false,
  startTime: time,
  timeZone: 'Asia/Tokyo',
  offsetsMinutes: offsets,
  title: 'テスト',
);
