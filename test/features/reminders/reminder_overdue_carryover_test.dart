import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/reminders/models/reminder_definition.dart';
import 'package:or_app/features/reminders/repository/indexed_db_reminder_repository.dart';
import 'package:or_app/features/reminders/services/reminder_occurrence_service.dart';

import '../../repositories/indexed_db/fake_indexed_db_database.dart';

void main() {
  test(
    'pendingThrough carries unfinished past occurrences without rewriting them',
    () async {
      final repository = IndexedDbReminderRepository(FakeIndexedDbDatabase());
      await repository.saveDefinition(_definition('daily', '2026-10-01'));
      final service = ReminderOccurrenceService(repository);

      final initial = await service.pendingThrough(DateTime(2026, 10, 3));
      expect(initial.map((value) => value.id), [
        'daily@2026-10-01',
        'daily@2026-10-02',
        'daily@2026-10-03',
      ]);
      expect(initial.first.localDate, '2026-10-01');

      await service.complete(initial.first, DateTime.utc(2026, 10, 3, 9));
      final afterCompletion = await service.pendingThrough(
        DateTime(2026, 10, 4),
      );
      expect(afterCompletion.map((value) => value.id), [
        'daily@2026-10-02',
        'daily@2026-10-03',
        'daily@2026-10-04',
      ]);
      expect(
        (await repository.findDefinitions()).single.startDate,
        '2026-10-01',
      );
    },
  );

  test(
    'overdue status is based on local calendar date, never time of day',
    () async {
      final repository = IndexedDbReminderRepository(FakeIndexedDbDatabase());
      await repository.saveDefinition(
        _definition('timed', '2026-10-03', time: '09:00'),
      );
      final occurrence = (await ReminderOccurrenceService(
        repository,
      ).pendingThrough(DateTime(2026, 10, 3))).single;

      expect(
        reminderOccurrenceIsOverdue(occurrence, DateTime(2026, 10, 3, 10)),
        isFalse,
      );
      expect(
        reminderOccurrenceIsOverdue(occurrence, DateTime(2026, 10, 3, 8)),
        isFalse,
      );
      expect(
        reminderOccurrenceIsOverdue(occurrence, DateTime(2026, 10, 4)),
        isTrue,
      );
      expect(
        reminderOccurrenceIsOverdue(occurrence, DateTime(2026, 10, 2, 23, 59)),
        isFalse,
      );
    },
  );
}

ReminderDefinition _definition(String id, String startDate, {String? time}) =>
    ReminderDefinition(
      id: id,
      title: id,
      startDate: startDate,
      allDay: time == null,
      time: time,
      recurrence: ReminderRecurrence.daily,
      active: true,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );
