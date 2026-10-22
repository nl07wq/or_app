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
    expect(changed?.monthWeeks, contains(3));
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
    expect(find.text('時刻未設定'), findsNothing);
  });

  testWidgets('date time editor always uses deterministic 24-hour rows', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SharedDateTimeEditor(
            date: DateTime(2026, 10, 9),
            allDay: false,
            startTime: const TimeOfDay(hour: 7, minute: 0),
            endTime: const TimeOfDay(hour: 18, minute: 5),
            onDateChanged: (_) {},
            onAllDayChanged: (_) {},
            onStartTimeChanged: (_) {},
            onEndTimeChanged: (_) {},
          ),
        ),
      ),
    );
    expect(find.text('07:00'), findsOneWidget);
    expect(find.text('18:05'), findsOneWidget);
    expect(find.textContaining('AM'), findsNothing);
    expect(find.textContaining('PM'), findsNothing);
  });

  testWidgets('date time editor cards fit supported phone widths', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final width in [320.0, 375.0, 390.0, 430.0]) {
      await tester.binding.setSurfaceSize(Size(width, 844));
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: Size(width, 844),
              textScaler: const TextScaler.linear(1.3),
            ),
            child: Scaffold(
              body: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: SharedDateTimeEditor(
                    date: DateTime(2026, 10, 9),
                    endDate: DateTime(2026, 10, 10),
                    allDay: false,
                    startTime: const TimeOfDay(hour: 7, minute: 0),
                    endTime: const TimeOfDay(hour: 18, minute: 0),
                    showOverdueNote: true,
                    onDateChanged: (_) {},
                    onEndDateChanged: (_) {},
                    onAllDayChanged: (_) {},
                    onStartTimeChanged: (_) {},
                    onEndTimeChanged: (_) {},
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'width $width');
      expect(find.text('07:00'), findsOneWidget);
      expect(find.text('18:00'), findsOneWidget);
    }
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
