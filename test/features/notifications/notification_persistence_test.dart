import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/reminders/models/reminder_definition.dart';
import 'package:or_app/features/schedule/models/schedule_record.dart';

void main() {
  test('Schedule notification and multi-ordinal configuration round-trips', () {
    final source = ScheduleRecord(
      id: 'schedule',
      localDate: '2026-10-13',
      type: ScheduleType.personal,
      title: 'Schedule',
      recurrence: ReminderRecurrence.monthlyWeekday,
      recurrenceMonthWeek: 2,
      recurrenceMonthWeeks: const [2, 3],
      notificationOffsetsMinutes: const [0, 60, 1440],
      notificationTimeZone: 'Asia/Tokyo',
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );

    final restored = ScheduleRecord.fromRecord(source.toRecord());
    expect(restored.recurrenceMonthWeeks, [2, 3]);
    expect(restored.notificationOffsetsMinutes, [0, 60, 1440]);
    expect(restored.notificationTimeZone, 'Asia/Tokyo');
  });

  test('Reminder notification and multi-ordinal configuration round-trips', () {
    final source = ReminderDefinition(
      id: 'reminder',
      title: 'Reminder',
      startDate: '2026-10-13',
      allDay: false,
      time: '09:00',
      recurrence: ReminderRecurrence.monthlyWeekday,
      monthWeek: 2,
      monthWeeks: const [2, 3],
      notificationOffsetsMinutes: const [15, 60],
      notificationTimeZone: 'Asia/Tokyo',
      active: true,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );

    final restored = ReminderDefinition.fromRecord(source.toRecord());
    expect(restored.monthWeeks, [2, 3]);
    expect(restored.notificationOffsetsMinutes, [15, 60]);
    expect(restored.notificationTimeZone, 'Asia/Tokyo');
  });

  test('legacy records keep defaults and legacy biweekly meaning', () {
    final legacy = ReminderDefinition.fromRecord({
      'id': 'legacy',
      'title': 'Legacy',
      'startDate': '2026-10-13',
      'allDay': true,
      'recurrence': 'biweekly',
      'active': true,
      'createdAt': DateTime.utc(2026).toIso8601String(),
      'updatedAt': DateTime.utc(2026).toIso8601String(),
    });
    expect(legacy.recurrence, ReminderRecurrence.biweekly);
    expect(legacy.monthWeeks, isEmpty);
    expect(legacy.notificationOffsetsMinutes, isEmpty);
  });
}
