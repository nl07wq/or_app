import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/reminders/models/reminder_definition.dart';
import 'package:or_app/features/reminders/services/reminder_recurrence_engine.dart';
import 'package:or_app/features/schedule/widgets/shared_date_time_recurrence_editor.dart';

ReminderDefinition definition({
  required ReminderRecurrence recurrence,
  List<int> monthWeeks = const [],
}) => ReminderDefinition(
  id: 'r',
  title: 'r',
  startDate: '2026-10-13',
  allDay: true,
  recurrence: recurrence,
  monthWeeks: monthWeeks,
  active: true,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

void main() {
  test('new-style 隔週 projects multiple monthly ordinals on start weekday', () {
    final dates = const ReminderRecurrenceEngine().datesFor(
      definition(
        recurrence: ReminderRecurrence.monthlyWeekday,
        monthWeeks: const [2, 3],
      ),
      DateTimeRange(start: DateTime(2026, 10, 1), end: DateTime(2026, 12, 31)),
    );

    expect(dates, [
      '2026-10-13',
      '2026-10-20',
      '2026-11-10',
      '2026-11-17',
      '2026-12-08',
      '2026-12-15',
    ]);
    expect(
      recurrenceSettingsSummary(
        DateTime(2026, 10, 13),
        SharedRecurrenceValue(
          recurrence: ReminderRecurrence.monthlyWeekday,
          monthWeeks: const {2, 3},
        ),
      ),
      '第2・第3・火',
    );
  });

  test('legacy biweekly remains every 14 days', () {
    final dates = const ReminderRecurrenceEngine().datesFor(
      definition(recurrence: ReminderRecurrence.biweekly),
      DateTimeRange(start: DateTime(2026, 10, 1), end: DateTime(2026, 11, 30)),
    );
    expect(dates, ['2026-10-13', '2026-10-27', '2026-11-10', '2026-11-24']);
  });
}
