import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/reminders/models/reminder_definition.dart';
import 'package:or_app/features/reminders/services/reminder_occurrence_service.dart';
import 'package:or_app/features/repositories/app_repository_container.dart';
import 'package:or_app/features/schedule/models/schedule_plan_revision.dart';
import 'package:or_app/features/schedule/models/schedule_record.dart';
import 'package:or_app/features/schedule/pages/calendar_page.dart';

import '../../repositories/indexed_db/fake_indexed_db_database.dart';

void main() {
  late AppRepositoryContainer container;

  setUp(() {
    container = AppRepositoryContainer.indexedDb(FakeIndexedDbDatabase());
    AppRepositoryRegistry.install(container);
  });

  tearDown(AppRepositoryRegistry.resetForTesting);

  testWidgets(
    'mounted Calendar reacts immediately to create edit date and delete',
    (tester) async {
      final today = DateUtils.dateOnly(DateTime.now());
      final tomorrow = today.add(const Duration(days: 1));
      final todayKey = _dateKey(today);
      final tomorrowKey = _dateKey(tomorrow);
      final createdAt = DateTime.utc(2026, 10, 7);
      await container.schedules.save(
        ScheduleRecord(
          id: 'schedule-control',
          localDate: todayKey,
          type: ScheduleType.work,
          title: 'Schedule remains',
          allDay: true,
          createdAt: createdAt,
          updatedAt: createdAt,
        ),
      );
      await _pumpCalendar(tester, today);
      expect(find.text('Schedule remains'), findsOneWidget);
      expect(find.text('Live reminder'), findsNothing);

      await container.reminders.saveDefinition(
        _definition(
          id: 'live',
          title: 'Live reminder',
          startDate: todayKey,
          time: '09:15',
          createdAt: createdAt,
        ),
      );
      notifySchedulePlanChanged();
      await tester.pumpAndSettle();

      expect(find.text('Live reminder'), findsOneWidget);
      expect(find.text('09:15'), findsOneWidget);
      expect(
        find.byKey(ValueKey('calendar-reminder-bell-live@$todayKey')),
        findsOneWidget,
      );

      await container.reminders.saveDefinition(
        _definition(
          id: 'live',
          title: 'Live reminder',
          startDate: todayKey,
          time: '09:30',
          createdAt: createdAt,
        ),
      );
      notifySchedulePlanChanged();
      await tester.pumpAndSettle();

      expect(find.text('09:15'), findsNothing);
      expect(find.text('09:30'), findsOneWidget);
      expect(find.text('Live reminder'), findsOneWidget);
      final edited = await container.reminders.findDefinitions();
      expect(edited, hasLength(1));
      expect(edited.single.id, 'live');

      await container.reminders.saveDefinition(
        _definition(
          id: 'live',
          title: 'Live reminder',
          startDate: tomorrowKey,
          time: '09:30',
          createdAt: createdAt,
        ),
      );
      notifySchedulePlanChanged();
      await tester.pumpAndSettle();

      expect(find.text('Live reminder'), findsNothing);
      expect(find.text('Schedule remains'), findsOneWidget);
      await _selectCalendarDate(tester, tomorrowKey);
      expect(find.text('Live reminder'), findsOneWidget);
      expect(find.text('09:30'), findsOneWidget);

      await container.reminders.deleteDefinition('live');
      notifySchedulePlanChanged();
      await tester.pumpAndSettle();
      expect(find.text('Live reminder'), findsNothing);
      expect(
        find.byKey(ValueKey('calendar-reminder-bell-live@$tomorrowKey')),
        findsNothing,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: CalendarPage(
            key: const ValueKey('reloaded-calendar'),
            initialDate: tomorrow,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Live reminder'), findsNothing);
      expect(await container.reminders.findDefinitions(), isEmpty);
    },
  );

  testWidgets(
    'completion and recurrence invalidation update a mounted Calendar range',
    (tester) async {
      final today = DateUtils.dateOnly(DateTime.now());
      final tomorrow = today.add(const Duration(days: 1));
      final todayKey = _dateKey(today);
      final tomorrowKey = _dateKey(tomorrow);
      final createdAt = DateTime.utc(2026, 10, 7);
      var definition = _definition(
        id: 'daily-live',
        title: 'Daily live',
        startDate: todayKey,
        time: '10:00',
        recurrence: ReminderRecurrence.daily,
        createdAt: createdAt,
      );
      await container.reminders.saveDefinition(definition);
      await container.schedules.save(
        ScheduleRecord(
          id: 'tomorrow-schedule',
          localDate: tomorrowKey,
          type: ScheduleType.appointment,
          title: 'Tomorrow schedule',
          allDay: true,
          createdAt: createdAt,
          updatedAt: createdAt,
        ),
      );
      await _pumpCalendar(tester, today);

      final todayOccurrence = (await ReminderOccurrenceService(
        container.reminders,
      ).inRange(DateTimeRange(start: today, end: today))).single;
      await ReminderOccurrenceService(
        container.reminders,
      ).complete(todayOccurrence, DateTime.now());
      notifySchedulePlanChanged();
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Icon>(
              find.byKey(
                ValueKey('calendar-reminder-bell-daily-live@$todayKey'),
              ),
            )
            .icon,
        Icons.check_circle,
      );
      expect(find.text('Daily live'), findsOneWidget);

      await _selectCalendarDate(tester, tomorrowKey);
      expect(find.text('Daily live'), findsOneWidget);
      expect(find.text('Tomorrow schedule'), findsOneWidget);

      definition = _definition(
        id: 'daily-live',
        title: 'Daily live',
        startDate: todayKey,
        time: '10:00',
        recurrence: ReminderRecurrence.none,
        createdAt: createdAt,
      );
      await container.reminders.saveDefinition(definition);
      notifySchedulePlanChanged();
      await tester.pumpAndSettle();
      expect(find.text('Daily live'), findsNothing);
      expect(find.text('Tomorrow schedule'), findsOneWidget);

      await container.reminders.deleteDefinition('daily-live');
      notifySchedulePlanChanged();
      await tester.pumpAndSettle();
      expect(find.text('Tomorrow schedule'), findsOneWidget);
    },
  );
}

Future<void> _pumpCalendar(WidgetTester tester, DateTime initialDate) async {
  await tester.pumpWidget(
    MaterialApp(home: CalendarPage(initialDate: initialDate)),
  );
  await tester.pumpAndSettle();
}

Future<void> _selectCalendarDate(WidgetTester tester, String dateKey) async {
  final day = find.byKey(ValueKey('calendar-day-$dateKey'));
  final target = find.ancestor(of: day, matching: find.byType(InkWell)).last;
  await tester.tap(target);
  await tester.pumpAndSettle();
}

ReminderDefinition _definition({
  required String id,
  required String title,
  required String startDate,
  required String time,
  required DateTime createdAt,
  ReminderRecurrence recurrence = ReminderRecurrence.none,
}) => ReminderDefinition(
  id: id,
  title: title,
  startDate: startDate,
  allDay: false,
  time: time,
  recurrence: recurrence,
  notificationOffsetsMinutes: const [5],
  notificationTimeZone: 'Asia/Tokyo',
  active: true,
  createdAt: createdAt,
  updatedAt: DateTime.now().toUtc(),
);

String _dateKey(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';
