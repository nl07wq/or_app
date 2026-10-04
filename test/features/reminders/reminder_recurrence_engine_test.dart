import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/reminders/models/reminder_definition.dart';
import 'package:or_app/features/reminders/services/reminder_recurrence_engine.dart';

void main() {
  ReminderDefinition definition({
    ReminderRecurrence recurrence = ReminderRecurrence.none,
    String start = '2026-10-01',
    String? end,
    List<int> weekdays = const [],
    List<int> monthDays = const [],
  }) => ReminderDefinition(
    id: 'r',
    title: 'Reminder',
    startDate: start,
    allDay: true,
    recurrence: recurrence,
    recurrenceEnd: end,
    weekdays: weekdays,
    monthDays: monthDays,
    active: true,
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
  );
  final range = DateTimeRange(
    start: DateTime(2026, 10, 1),
    end: DateTime(2026, 10, 10),
  );
  final engine = const ReminderRecurrenceEngine();

  test('supports single, daily, weekday, weekend, weekly and biweekly', () {
    expect(engine.datesFor(definition(), range), ['2026-10-01']);
    expect(
      engine.datesFor(definition(recurrence: ReminderRecurrence.daily), range),
      hasLength(10),
    );
    expect(
      engine.datesFor(
        definition(recurrence: ReminderRecurrence.weekdays),
        range,
      ),
      hasLength(7),
    );
    expect(
      engine.datesFor(
        definition(recurrence: ReminderRecurrence.weekends),
        range,
      ),
      ['2026-10-03', '2026-10-04', '2026-10-10'],
    );
    expect(
      engine.datesFor(definition(recurrence: ReminderRecurrence.weekly), range),
      ['2026-10-01', '2026-10-08'],
    );
    expect(
      engine.datesFor(
        definition(recurrence: ReminderRecurrence.biweekly),
        range,
      ),
      ['2026-10-01'],
    );
  });

  test(
    'supports custom weekdays, month days, and an inclusive end boundary',
    () {
      expect(
        engine.datesFor(
          definition(
            recurrence: ReminderRecurrence.customWeekdays,
            weekdays: [2, 4],
          ),
          range,
        ),
        ['2026-10-01', '2026-10-06', '2026-10-08'],
      );
      expect(
        engine.datesFor(
          definition(
            recurrence: ReminderRecurrence.customMonthDays,
            monthDays: [1, 8],
          ),
          range,
        ),
        ['2026-10-01', '2026-10-08'],
      );
      expect(
        engine.datesFor(
          definition(recurrence: ReminderRecurrence.daily, end: '2026-10-03'),
          range,
        ),
        ['2026-10-01', '2026-10-02', '2026-10-03'],
      );
    },
  );
}
