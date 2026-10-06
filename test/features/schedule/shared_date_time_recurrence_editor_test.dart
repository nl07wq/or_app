import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/reminders/models/reminder_definition.dart';
import 'package:or_app/features/schedule/widgets/shared_date_time_recurrence_editor.dart';

void main() {
  Future<void> pumpEditor(
    WidgetTester tester, {
    required SharedRecurrenceValue value,
    required ValueChanged<SharedRecurrenceValue> onChanged,
  }) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SharedRecurrenceEditor(
          startDate: DateTime(2026, 10, 9),
          value: value,
          onChanged: onChanged,
        ),
      ),
    ),
  );

  testWidgets('weekly derives its weekday and exposes no weekday selector', (
    tester,
  ) async {
    await pumpEditor(
      tester,
      value: SharedRecurrenceValue(recurrence: ReminderRecurrence.weekly),
      onChanged: (_) {},
    );
    expect(find.text('繰り返しの設定'), findsOneWidget);
    expect(find.text('月'), findsNothing);
    expect(find.text('第1'), findsNothing);
  });

  testWidgets('monthly-weekday exposes only week-of-month choices', (
    tester,
  ) async {
    SharedRecurrenceValue? changed;
    await pumpEditor(
      tester,
      value: SharedRecurrenceValue(
        recurrence: ReminderRecurrence.monthlyWeekday,
      ),
      onChanged: (value) => changed = value,
    );
    expect(find.text('第1'), findsOneWidget);
    expect(find.text('第5'), findsOneWidget);
    expect(find.text('月'), findsNothing);
    await tester.tap(find.text('第3'));
    expect(changed?.monthWeek, 3);
  });

  testWidgets('custom weekdays alone exposes weekday selection', (
    tester,
  ) async {
    await pumpEditor(
      tester,
      value: SharedRecurrenceValue(
        recurrence: ReminderRecurrence.customWeekdays,
      ),
      onChanged: (_) {},
    );
    expect(find.text('月'), findsOneWidget);
    expect(find.text('第1'), findsNothing);
  });

  testWidgets('date time editor hides time range for all-day entries', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SharedDateTimeEditor(
            date: DateTime(2026, 10, 9),
            allDay: true,
            startTime: null,
            endTime: null,
            onDateChanged: (_) {},
            onAllDayChanged: (_) {},
            onStartTimeChanged: (_) {},
            onEndTimeChanged: (_) {},
          ),
        ),
      ),
    );
    expect(find.textContaining('開始時刻'), findsNothing);
    expect(find.textContaining('終了時刻'), findsNothing);
  });

  test('retains every Reminder-authoritative effective rule summary', () {
    final friday = DateTime(2026, 10, 9);
    String summary(
      ReminderRecurrence recurrence, {
      Set<int> weekdays = const <int>{},
      Set<int> monthDays = const <int>{},
      bool monthEnd = false,
      int? monthWeek,
    }) => recurrenceSettingsSummary(
      friday,
      SharedRecurrenceValue(
        recurrence: recurrence,
        weekdays: weekdays,
        monthDays: monthDays,
        monthEnd: monthEnd,
        monthWeek: monthWeek,
      ),
    );

    expect(summary(ReminderRecurrence.daily), '開始日から毎日');
    expect(summary(ReminderRecurrence.weekdays), '月・火・水・木・金');
    expect(summary(ReminderRecurrence.weekends), '土・日');
    expect(summary(ReminderRecurrence.weekly), '金');
    expect(summary(ReminderRecurrence.monthly), '9日');
    expect(summary(ReminderRecurrence.yearly), '10月9日');
    expect(summary(ReminderRecurrence.customWeekdays, weekdays: {1, 5}), '月・金');
    expect(
      summary(
        ReminderRecurrence.customMonthDays,
        monthDays: {1, 15},
        monthEnd: true,
      ),
      '1日・15日・月末',
    );
  });

  test('derived summaries react to start-date changes and preserve legacy', () {
    final weekly = SharedRecurrenceValue(recurrence: ReminderRecurrence.weekly);
    expect(recurrenceSettingsSummary(DateTime(2026, 10, 9), weekly), '金');
    expect(recurrenceSettingsSummary(DateTime(2026, 10, 12), weekly), '月');
    final newBiweekly = SharedRecurrenceValue(
      recurrence: ReminderRecurrence.monthlyWeekday,
      monthWeek: 2,
    );
    expect(
      recurrenceSettingsSummary(DateTime(2026, 10, 9), newBiweekly),
      '第2・金',
    );
    expect(
      recurrenceSettingsSummary(
        DateTime(2026, 10, 9),
        SharedRecurrenceValue(recurrence: ReminderRecurrence.biweekly),
      ),
      '14日ごと・金',
    );
  });
}
