import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/reminders/models/reminder_definition.dart';
import 'package:or_app/features/reminders/models/reminder_occurrence.dart';
import 'package:or_app/features/reminders/repository/indexed_db_reminder_repository.dart';
import 'package:or_app/features/reminders/services/reminder_occurrence_service.dart';

import '../../repositories/indexed_db/fake_indexed_db_database.dart';

void main() {
  test(
    'ALL returns one next occurrence for each basic recurrence rule',
    () async {
      final repository = IndexedDbReminderRepository(FakeIndexedDbDatabase());
      for (final definition in [
        _definition('single', '2026-10-05'),
        _definition(
          'daily',
          '2026-10-01',
          recurrence: ReminderRecurrence.daily,
        ),
        _definition(
          'weekly',
          '2026-10-01',
          recurrence: ReminderRecurrence.weekly,
        ),
        _definition(
          'monthly',
          '2026-09-15',
          recurrence: ReminderRecurrence.monthly,
        ),
        _definition(
          'yearly',
          '2025-10-10',
          recurrence: ReminderRecurrence.yearly,
        ),
      ]) {
        await repository.saveDefinition(definition);
      }

      final values = await ReminderOccurrenceService(
        repository,
      ).nextPendingBySlot(DateTime(2026, 10, 4));
      expect(_datesByDefinition(values), {
        'daily': ['2026-10-04'],
        'single': ['2026-10-05'],
        'weekly': ['2026-10-08'],
        'yearly': ['2026-10-10'],
        'monthly': ['2026-10-15'],
      });
      expect(values, hasLength(5));
    },
  );

  test('yearly February 29 finds the next leap-year occurrence', () async {
    final repository = IndexedDbReminderRepository(FakeIndexedDbDatabase());
    await repository.saveDefinition(
      _definition(
        'leap-year',
        '2024-02-29',
        recurrence: ReminderRecurrence.yearly,
      ),
    );
    final service = ReminderOccurrenceService(repository);

    final occurrences = await service.nextPendingBySlot(DateTime(2026, 10, 4));

    expect(occurrences.map((value) => value.localDate), ['2028-02-29']);
  });

  test(
    'custom weekday slots advance independently after complete and skip',
    () async {
      final repository = IndexedDbReminderRepository(FakeIndexedDbDatabase());
      await repository.saveDefinition(
        _definition(
          'weekdays',
          '2026-10-01',
          recurrence: ReminderRecurrence.customWeekdays,
          weekdays: const [
            DateTime.monday,
            DateTime.wednesday,
            DateTime.friday,
          ],
        ),
      );
      final service = ReminderOccurrenceService(repository);
      final from = DateTime(2026, 10, 4);
      expect(
        (await service.nextPendingBySlot(from)).map((value) => value.localDate),
        ['2026-10-05', '2026-10-07', '2026-10-09'],
      );

      final monday = (await service.nextPendingBySlot(from)).first;
      await service.complete(monday, DateTime.utc(2026, 10, 5, 9));
      expect(
        (await service.nextPendingBySlot(from)).map((value) => value.localDate),
        ['2026-10-07', '2026-10-09', '2026-10-12'],
      );

      final wednesday = (await service.nextPendingBySlot(from)).first;
      await service.skip(wednesday, DateTime.utc(2026, 10, 7, 9));
      expect(
        (await service.nextPendingBySlot(from)).map((value) => value.localDate),
        ['2026-10-09', '2026-10-12', '2026-10-14'],
      );
    },
  );

  test(
    'custom month-day slots return one next pending date per slot',
    () async {
      final repository = IndexedDbReminderRepository(FakeIndexedDbDatabase());
      await repository.saveDefinition(
        _definition(
          'month-days',
          '2026-01-01',
          recurrence: ReminderRecurrence.customMonthDays,
          monthDays: const [1, 15],
          monthEnd: true,
        ),
      );

      final values = await ReminderOccurrenceService(
        repository,
      ).nextPendingBySlot(DateTime(2026, 2, 10));
      expect(values.map((value) => value.localDate), [
        '2026-02-15',
        '2026-02-28',
        '2026-03-01',
      ]);
    },
  );

  test(
    '31 and month-end remain distinct slots but deduplicate one date',
    () async {
      final repository = IndexedDbReminderRepository(FakeIndexedDbDatabase());
      await repository.saveDefinition(
        _definition(
          'month-end',
          '2026-01-01',
          recurrence: ReminderRecurrence.customMonthDays,
          monthDays: const [31],
          monthEnd: true,
        ),
      );
      final service = ReminderOccurrenceService(repository);
      final from = DateTime(2026, 1, 1);
      final january = await service.nextPendingBySlot(from);
      expect(january.map((value) => value.localDate), ['2026-01-31']);

      await service.complete(january.single, DateTime.utc(2026, 1, 31, 9));
      expect(
        (await service.nextPendingBySlot(from)).map((value) => value.localDate),
        ['2026-02-28', '2026-03-31'],
      );
    },
  );

  test(
    'recurrence end removes slots whose next occurrence exceeds it',
    () async {
      final repository = IndexedDbReminderRepository(FakeIndexedDbDatabase());
      await repository.saveDefinition(
        _definition(
          'weekdays',
          '2026-10-01',
          recurrence: ReminderRecurrence.customWeekdays,
          weekdays: const [
            DateTime.monday,
            DateTime.wednesday,
            DateTime.friday,
          ],
          recurrenceEnd: '2026-10-07',
        ),
      );

      final values = await ReminderOccurrenceService(
        repository,
      ).nextPendingBySlot(DateTime(2026, 10, 4));
      expect(values.map((value) => value.localDate), [
        '2026-10-05',
        '2026-10-07',
      ]);
    },
  );

  test(
    'Calendar range projection stays complete across future months',
    () async {
      final repository = IndexedDbReminderRepository(FakeIndexedDbDatabase());
      await repository.saveDefinition(
        _definition(
          'daily',
          '2026-10-01',
          recurrence: ReminderRecurrence.daily,
        ),
      );
      final service = ReminderOccurrenceService(repository);
      for (final month in [10, 11, 12]) {
        final start = DateTime(2026, month, 1);
        final end = DateTime(2026, month + 1, 0);
        final values = await service.inRange(
          DateTimeRange(start: start, end: end),
        );
        expect(values, hasLength(end.day), reason: 'month $month');
        expect(values.first.localDate, _dateKey(start));
        expect(values.last.localDate, _dateKey(end));
      }
      expect(
        await service.nextPendingBySlot(DateTime(2026, 10, 1)),
        hasLength(1),
      );
    },
  );
}

Map<String, List<String>> _datesByDefinition(
  List<ReminderOccurrence> values,
) => <String, List<String>>{
  for (final id in values.map((value) => value.definition.id).toSet())
    id: [
      for (final value in values.where((value) => value.definition.id == id))
        value.localDate,
    ],
};

ReminderDefinition _definition(
  String id,
  String startDate, {
  ReminderRecurrence recurrence = ReminderRecurrence.none,
  String? recurrenceEnd,
  List<int> weekdays = const [],
  List<int> monthDays = const [],
  bool monthEnd = false,
}) => ReminderDefinition(
  id: id,
  title: id,
  startDate: startDate,
  allDay: true,
  recurrence: recurrence,
  recurrenceEnd: recurrenceEnd,
  weekdays: weekdays,
  monthDays: monthDays,
  monthEnd: monthEnd,
  active: true,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

String _dateKey(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';
