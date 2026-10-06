import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/reminders/models/reminder_occurrence.dart';
import 'package:or_app/features/reminders/models/reminder_definition.dart';
import 'package:or_app/features/reminders/repository/indexed_db_reminder_repository.dart';
import 'package:or_app/features/reminders/services/legacy_reminder_migration_service.dart';
import 'package:or_app/features/reminders/services/reminder_occurrence_service.dart';
import 'package:or_app/features/schedule/models/schedule_record.dart';
import 'package:or_app/features/schedule/repository/indexed_db_schedule_repository.dart';

import '../../repositories/indexed_db/fake_indexed_db_database.dart';

void main() {
  test(
    'migrates legacy reminder once and preserves completion as occurrence state',
    () async {
      final database = FakeIndexedDbDatabase();
      final schedules = IndexedDbScheduleRepository(database);
      final reminders = IndexedDbReminderRepository(database);
      await schedules.save(
        ScheduleRecord(
          id: 'old',
          localDate: '2026-10-06',
          type: ScheduleType.other,
          title: '榊発注',
          kind: ScheduleEntryKind.reminder,
          allDay: false,
          startTime: '08:00',
          memo: 'note',
          completed: true,
          createdAt: DateTime.utc(2026, 10, 1),
          updatedAt: DateTime.utc(2026, 10, 2),
        ),
      );
      final migration = LegacyReminderMigrationService(schedules, reminders);
      expect(await migration.migrate(now: () => DateTime.utc(2026, 10, 7)), 1);
      expect(await migration.migrate(), 0);
      final definition = (await reminders.findDefinitions()).single;
      expect(definition.title, '榊発注');
      expect(definition.time, '08:00');
      expect(definition.note, 'note');
      final occurrence = (await ReminderOccurrenceService(reminders).inRange(
        DateTimeRange(start: DateTime(2026, 10, 6), end: DateTime(2026, 10, 6)),
      )).single;
      expect(occurrence.status, ReminderOccurrenceStatus.completed);
      expect((await schedules.findAll()).single.id, 'old');
    },
  );

  test(
    'completion and restore only change the selected dynamic occurrence',
    () async {
      final database = FakeIndexedDbDatabase();
      final reminders = IndexedDbReminderRepository(database);
      final now = DateTime.utc(2026, 10, 1);
      await reminders.saveDefinition(_daily(now));
      final service = ReminderOccurrenceService(reminders);
      final occurrences = await service.inRange(
        DateTimeRange(start: DateTime(2026, 10, 1), end: DateTime(2026, 10, 2)),
      );
      await service.complete(occurrences.first, now);
      final afterComplete = await service.inRange(
        DateTimeRange(start: DateTime(2026, 10, 1), end: DateTime(2026, 10, 2)),
      );
      expect(afterComplete.map((value) => value.status), [
        ReminderOccurrenceStatus.completed,
        ReminderOccurrenceStatus.pending,
      ]);
      await service.restore(afterComplete.first);
      expect(
        (await service.inRange(
          DateTimeRange(
            start: DateTime(2026, 10, 1),
            end: DateTime(2026, 10, 1),
          ),
        )).single.status,
        ReminderOccurrenceStatus.pending,
      );
    },
  );

  test('future change uses the scheduled time as its boundary', () async {
    final database = FakeIndexedDbDatabase();
    final reminders = IndexedDbReminderRepository(database);
    final boundary = DateTime(2026, 10, 20, 14);
    await reminders.saveDefinition(
      ReminderDefinition(
        id: 'old',
        title: 'Old',
        startDate: '2026-10-20',
        allDay: false,
        time: '08:00',
        recurrence: ReminderRecurrence.daily,
        active: false,
        createdAt: boundary,
        updatedAt: boundary,
        retiredAt: boundary,
      ),
    );
    await reminders.saveDefinition(
      ReminderDefinition(
        id: 'new',
        title: 'New',
        startDate: '2026-10-20',
        allDay: false,
        time: '18:00',
        recurrence: ReminderRecurrence.daily,
        active: true,
        createdAt: boundary,
        updatedAt: boundary,
        effectiveFrom: boundary,
      ),
    );
    final values = await ReminderOccurrenceService(reminders).inRange(
      DateTimeRange(start: DateTime(2026, 10, 20), end: DateTime(2026, 10, 21)),
    );
    expect(
      values.map((value) => '${value.localDate}:${value.definition.title}'),
      ['2026-10-20:Old', '2026-10-20:New', '2026-10-21:New'],
    );
  });
}

ReminderDefinition _daily(DateTime now) => ReminderDefinition(
  id: 'daily',
  title: 'Daily',
  startDate: '2026-10-01',
  allDay: true,
  recurrence: ReminderRecurrence.daily,
  active: true,
  createdAt: now,
  updatedAt: now,
);
