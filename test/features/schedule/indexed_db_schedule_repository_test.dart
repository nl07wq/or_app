import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/reminders/models/reminder_definition.dart';
import 'package:or_app/features/schedule/models/schedule_record.dart';
import 'package:or_app/features/schedule/repository/indexed_db_schedule_repository.dart';

import '../../repositories/indexed_db/fake_indexed_db_database.dart';

void main() {
  ScheduleRecord record({
    required String id,
    required String date,
    ScheduleType type = ScheduleType.personal,
  }) => ScheduleRecord(
    id: id,
    localDate: date,
    type: type,
    title: type.name,
    startTime: '07:00',
    endTime: '18:00',
    breakDuration: '01:00',
    createdAt: DateTime.utc(2026, 9, 30),
    updatedAt: DateTime.utc(2026, 9, 30),
  );

  test(
    'schedule persists independently by date and survives repository reload',
    () async {
      final database = FakeIndexedDbDatabase();
      final first = IndexedDbScheduleRepository(database);
      await first.save(record(id: 'a', date: '2026-10-01'));
      await first.save(record(id: 'b', date: '2026-10-02'));

      final reloaded = IndexedDbScheduleRepository(database);
      expect((await reloaded.findForDate('2026-10-01')).single.id, 'a');
      expect((await reloaded.findForDate('2026-10-02')).single.id, 'b');
      expect((await reloaded.findAll()).map((value) => value.id), ['a', 'b']);
    },
  );

  test('schedule saves pin notification timezones to Asia/Tokyo', () async {
    final database = FakeIndexedDbDatabase();
    final repository = IndexedDbScheduleRepository(database);
    await repository.save(
      ScheduleRecord(
        id: 'legacy-zone',
        localDate: '2026-10-08',
        type: ScheduleType.appointment,
        title: 'appointment',
        startTime: '15:15',
        notificationTimeZone: 'Etc/UTC',
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      ),
    );
    expect(
      database.rawRecord(
        'schedule_records',
        'legacy-zone',
      )?['notificationTimeZone'],
      'Asia/Tokyo',
    );
    expect((await repository.findAll()).single.startTime, '15:15');
  });

  test('one WORK schedule per operation date is enforced by type', () async {
    final repository = IndexedDbScheduleRepository(FakeIndexedDbDatabase());
    await repository.save(
      record(id: 'work-a', date: '2026-10-01', type: ScheduleType.work),
    );
    expect(await repository.findWorkForDate('2026-10-01'), isNotNull);
    await expectLater(
      repository.save(
        record(id: 'work-b', date: '2026-10-01', type: ScheduleType.work),
      ),
      throwsA(isA<Object>()),
    );
  });

  test(
    'overnight schedules retain their end date without claiming next day',
    () async {
      final repository = IndexedDbScheduleRepository(FakeIndexedDbDatabase());
      await repository.save(
        ScheduleRecord(
          id: 'overnight',
          localDate: '2026-10-13',
          endDate: '2026-10-14',
          type: ScheduleType.work,
          title: 'night shift',
          startTime: '23:00',
          endTime: '00:15',
          createdAt: DateTime.utc(2026),
          updatedAt: DateTime.utc(2026),
        ),
      );
      final restored = (await repository.findForDate('2026-10-13')).single;
      expect(restored.endDate, '2026-10-14');
      expect(await repository.findWorkForDate('2026-10-14'), isNull);
    },
  );

  test(
    'WORK recurrence rejects an unrelated occurrence but permits override',
    () async {
      final repository = IndexedDbScheduleRepository(FakeIndexedDbDatabase());
      await repository.save(
        ScheduleRecord(
          id: 'series',
          localDate: '2026-10-13',
          type: ScheduleType.work,
          title: 'recurring work',
          recurrence: ReminderRecurrence.daily,
          createdAt: DateTime.utc(2026),
          updatedAt: DateTime.utc(2026),
        ),
      );
      await repository.save(
        ScheduleRecord(
          id: 'series@2026-10-13',
          seriesId: 'series',
          occurrenceDate: '2026-10-13',
          localDate: '2026-10-13',
          type: ScheduleType.work,
          title: 'edited recurring work',
          createdAt: DateTime.utc(2026),
          updatedAt: DateTime.utc(2026),
        ),
      );
      await expectLater(
        repository.save(
          record(id: 'other', date: '2026-10-14', type: ScheduleType.work),
        ),
        throwsA(isA<Object>()),
      );
    },
  );

  test('a new recurring WORK cannot expand onto an existing WORK', () async {
    final repository = IndexedDbScheduleRepository(FakeIndexedDbDatabase());
    await repository.save(
      record(id: 'existing', date: '2026-10-14', type: ScheduleType.work),
    );
    await expectLater(
      repository.save(
        ScheduleRecord(
          id: 'new-daily',
          localDate: '2026-10-13',
          type: ScheduleType.work,
          title: 'daily work',
          recurrence: ReminderRecurrence.daily,
          createdAt: DateTime.utc(2026),
          updatedAt: DateTime.utc(2026),
        ),
      ),
      throwsA(isA<Object>()),
    );
  });

  test(
    'editing unrelated schedule fields retains multiple reminders',
    () async {
      final repository = IndexedDbScheduleRepository(FakeIndexedDbDatabase());
      final original = ScheduleRecord(
        id: 'reminders',
        localDate: '2026-10-13',
        type: ScheduleType.personal,
        title: 'original',
        notificationOffsetsMinutes: const [10, 60, 150],
        notificationTimeZone: 'Asia/Tokyo',
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      );
      await repository.save(original);
      await repository.save(
        ScheduleRecord(
          id: original.id,
          localDate: original.localDate,
          type: original.type,
          title: 'renamed',
          notificationOffsetsMinutes: original.notificationOffsetsMinutes,
          notificationTimeZone: original.notificationTimeZone,
          createdAt: original.createdAt,
          updatedAt: DateTime.utc(2026, 1, 2),
        ),
      );
      final restored = (await repository.findAll()).single;
      expect(restored.notificationOffsetsMinutes, [10, 60, 150]);
      expect(restored.notificationTimeZone, 'Asia/Tokyo');
    },
  );

  test('delete affects only the selected plan record', () async {
    final repository = IndexedDbScheduleRepository(FakeIndexedDbDatabase());
    await repository.save(record(id: 'a', date: '2026-10-01'));
    await repository.save(record(id: 'b', date: '2026-10-01'));
    await repository.delete('a');
    expect(
      (await repository.findForDate('2026-10-01')).map((value) => value.id),
      ['b'],
    );
  });

  test(
    'recurrence series metadata and occurrence exceptions survive reload',
    () async {
      final database = FakeIndexedDbDatabase();
      final repository = IndexedDbScheduleRepository(database);
      await repository.save(
        ScheduleRecord(
          id: 'series',
          localDate: '2026-10-01',
          type: ScheduleType.personal,
          title: 'series',
          recurrence: ReminderRecurrence.weekly,
          recurrenceEnd: '2026-12-31',
          recurrenceWeekdays: const [4],
          createdAt: DateTime.utc(2026),
          updatedAt: DateTime.utc(2026),
        ),
      );
      await repository.save(
        ScheduleRecord(
          id: 'series@2026-10-08',
          seriesId: 'series',
          occurrenceDate: '2026-10-08',
          occurrenceExcluded: true,
          localDate: '2026-10-08',
          type: ScheduleType.personal,
          title: 'series',
          createdAt: DateTime.utc(2026),
          updatedAt: DateTime.utc(2026),
        ),
      );
      final values = await IndexedDbScheduleRepository(database).findAll();
      expect(values.first.recurrence, ReminderRecurrence.weekly);
      expect(values.first.recurrenceEnd, '2026-12-31');
      expect(values.last.occurrenceExcluded, isTrue);
      expect(values.last.effectiveSeriesId, 'series');
    },
  );

  test('new month-week recurrence metadata survives reload', () async {
    final database = FakeIndexedDbDatabase();
    final repository = IndexedDbScheduleRepository(database);
    await repository.save(
      ScheduleRecord(
        id: 'monthly-week',
        localDate: '2026-10-09',
        type: ScheduleType.personal,
        title: 'Second Friday',
        recurrence: ReminderRecurrence.monthlyWeekday,
        recurrenceMonthWeek: 2,
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      ),
    );
    final restored = await IndexedDbScheduleRepository(database).findAll();
    expect(restored.single.recurrence, ReminderRecurrence.monthlyWeekday);
    expect(restored.single.recurrenceMonthWeek, 2);
  });
}
