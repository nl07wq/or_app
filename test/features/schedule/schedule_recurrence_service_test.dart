import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/reminders/models/reminder_definition.dart';
import 'package:or_app/features/schedule/models/schedule_record.dart';
import 'package:or_app/features/schedule/repository/schedule_repository.dart';
import 'package:or_app/features/schedule/services/schedule_recurrence_service.dart';

void main() {
  test('projects weekly series with stable occurrence identities', () async {
    final repository = _MemoryScheduleRepository([
      _series('series-a', '2026-01-05', ReminderRecurrence.weekly),
    ]);
    final values = await ScheduleRecurrenceService(repository).inRange(
      DateTimeRange(start: DateTime(2026, 1, 1), end: DateTime(2026, 1, 31)),
    );
    expect(values.map((value) => value.id), [
      'series-a@2026-01-05',
      'series-a@2026-01-12',
      'series-a@2026-01-19',
      'series-a@2026-01-26',
    ]);
  });

  test(
    'projects every Reminder-supported recurrence rule with local dates',
    () async {
      final cases =
          <({ScheduleRecord record, DateTimeRange range, List<String> dates})>[
            (
              record: _series('daily', '2026-01-01', ReminderRecurrence.daily),
              range: DateTimeRange(
                start: DateTime(2026, 1, 1),
                end: DateTime(2026, 1, 3),
              ),
              dates: ['2026-01-01', '2026-01-02', '2026-01-03'],
            ),
            (
              record: _series(
                'weekdays',
                '2026-01-02',
                ReminderRecurrence.weekdays,
              ),
              range: DateTimeRange(
                start: DateTime(2026, 1, 2),
                end: DateTime(2026, 1, 5),
              ),
              dates: ['2026-01-02', '2026-01-05'],
            ),
            (
              record: _series(
                'weekends',
                '2026-01-03',
                ReminderRecurrence.weekends,
              ),
              range: DateTimeRange(
                start: DateTime(2026, 1, 3),
                end: DateTime(2026, 1, 5),
              ),
              dates: ['2026-01-03', '2026-01-04'],
            ),
            (
              record: _series(
                'biweekly',
                '2026-01-05',
                ReminderRecurrence.biweekly,
              ),
              range: DateTimeRange(
                start: DateTime(2026, 1, 1),
                end: DateTime(2026, 2, 3),
              ),
              dates: ['2026-01-05', '2026-01-19', '2026-02-02'],
            ),
            (
              record: _series(
                'monthly',
                '2026-01-31',
                ReminderRecurrence.monthly,
              ),
              range: DateTimeRange(
                start: DateTime(2026, 1, 1),
                end: DateTime(2026, 3, 31),
              ),
              dates: ['2026-01-31', '2026-03-31'],
            ),
            (
              record: _series(
                'yearly',
                '2024-02-29',
                ReminderRecurrence.yearly,
              ),
              range: DateTimeRange(
                start: DateTime(2024, 1, 1),
                end: DateTime(2028, 12, 31),
              ),
              dates: ['2024-02-29', '2028-02-29'],
            ),
            (
              record: _series(
                'custom-weekdays',
                '2026-01-05',
                ReminderRecurrence.customWeekdays,
                weekdays: const [DateTime.monday, DateTime.wednesday],
              ),
              range: DateTimeRange(
                start: DateTime(2026, 1, 5),
                end: DateTime(2026, 1, 11),
              ),
              dates: ['2026-01-05', '2026-01-07'],
            ),
            (
              record: _series(
                'custom-month',
                '2026-01-15',
                ReminderRecurrence.customMonthDays,
                monthDays: const [15],
                monthEnd: true,
              ),
              range: DateTimeRange(
                start: DateTime(2026, 1, 1),
                end: DateTime(2026, 2, 28),
              ),
              dates: ['2026-01-15', '2026-01-31', '2026-02-15', '2026-02-28'],
            ),
          ];

      for (final item in cases) {
        final values = await ScheduleRecurrenceService(
          _MemoryScheduleRepository([item.record]),
        ).inRange(item.range);
        expect(values.map((value) => value.localDate), item.dates);
      }
    },
  );

  test(
    'occurrence override replaces one date and exclusion removes one date',
    () async {
      final series = _series(
        'series-a',
        '2026-01-05',
        ReminderRecurrence.weekly,
      );
      final repository = _MemoryScheduleRepository([
        series,
        ScheduleRecord(
          id: 'series-a@2026-01-12',
          seriesId: 'series-a',
          occurrenceDate: '2026-01-12',
          localDate: '2026-01-13',
          type: ScheduleType.personal,
          title: 'Moved',
          createdAt: series.createdAt,
          updatedAt: series.updatedAt,
        ),
        ScheduleRecord(
          id: 'series-a@2026-01-19',
          seriesId: 'series-a',
          occurrenceDate: '2026-01-19',
          occurrenceExcluded: true,
          localDate: '2026-01-19',
          type: ScheduleType.personal,
          title: 'Weekly',
          createdAt: series.createdAt,
          updatedAt: series.updatedAt,
        ),
      ]);
      final values = await ScheduleRecurrenceService(repository).inRange(
        DateTimeRange(start: DateTime(2026, 1, 1), end: DateTime(2026, 1, 31)),
      );
      expect(values.map((value) => value.localDate), [
        '2026-01-05',
        '2026-01-13',
        '2026-01-26',
      ]);
    },
  );

  test(
    'scoped edits preserve history, split future, and keep valid overrides',
    () async {
      final series = _series(
        'series-a',
        '2026-01-05',
        ReminderRecurrence.weekly,
      );
      final repository = _MemoryScheduleRepository([series]);
      final service = ScheduleRecurrenceService(repository);
      DateTime clock() => DateTime.utc(2026, 1, 1, 12);

      await service.editOccurrence(
        occurrence: _occurrence(series, '2026-01-12'),
        draft: _draft('2026-01-13', 'Moved'),
        scope: ScheduleRecurrenceScope.occurrence,
        clock: clock,
      );
      await service.editOccurrence(
        occurrence: _occurrence(series, '2026-01-19'),
        draft: _draft('2026-01-19', 'Future'),
        scope: ScheduleRecurrenceScope.future,
        clock: clock,
      );

      final afterSplit = await service.inRange(_january);
      expect(afterSplit.map((value) => '${value.localDate}:${value.title}'), [
        '2026-01-05:Weekly',
        '2026-01-13:Moved',
        '2026-01-19:Future',
        '2026-01-26:Future',
      ]);
      final stored = await repository.findAll();
      expect(
        stored.singleWhere((value) => value.id == series.id).recurrenceEnd,
        '2026-01-18',
      );
      expect(stored.where((value) => value.isRecurringSeries), hasLength(2));

      final futureSeries = stored.singleWhere(
        (value) => value.isRecurringSeries && value.id != series.id,
      );
      await service.editOccurrence(
        occurrence: _occurrence(futureSeries, '2026-01-26'),
        draft: _draft(
          '2026-01-26',
          'Future revised',
          recurrence: ReminderRecurrence.monthly,
        ),
        scope: ScheduleRecurrenceScope.all,
        clock: clock,
      );
      // The moved Jan 13 override belongs to the old series. No override for a
      // date that the revised future rule no longer generates is retained.
      final afterAll = await service.inRange(_january);
      expect(afterAll.map((value) => '${value.localDate}:${value.title}'), [
        '2026-01-05:Weekly',
        '2026-01-13:Moved',
        '2026-01-26:Future revised',
      ]);
    },
  );

  test(
    'scoped deletes exclude one occurrence, terminate future, and delete all',
    () async {
      final series = _series(
        'series-a',
        '2026-01-05',
        ReminderRecurrence.weekly,
      );
      final repository = _MemoryScheduleRepository([series]);
      final service = ScheduleRecurrenceService(repository);
      DateTime clock() => DateTime.utc(2026, 1, 1, 12);

      await service.deleteOccurrence(
        occurrence: _occurrence(series, '2026-01-12'),
        scope: ScheduleRecurrenceScope.occurrence,
        clock: clock,
      );
      expect(
        (await service.inRange(_january)).map((value) => value.localDate),
        ['2026-01-05', '2026-01-19', '2026-01-26'],
      );

      await service.deleteOccurrence(
        occurrence: _occurrence(series, '2026-01-19'),
        scope: ScheduleRecurrenceScope.future,
        clock: clock,
      );
      expect(
        (await service.inRange(_january)).map((value) => value.localDate),
        ['2026-01-05'],
      );
      expect(
        (await repository.findAll())
            .singleWhere((value) => value.id == series.id)
            .recurrenceEnd,
        '2026-01-18',
      );

      await service.deleteOccurrence(
        occurrence: _occurrence(series, '2026-01-05'),
        scope: ScheduleRecurrenceScope.all,
        clock: clock,
      );
      expect(await repository.findAll(), isEmpty);
      expect(await service.inRange(_january), isEmpty);
    },
  );
}

final _january = DateTimeRange(
  start: DateTime(2026, 1, 1),
  end: DateTime(2026, 1, 31),
);

ScheduleRecord _series(
  String id,
  String date,
  ReminderRecurrence recurrence, {
  List<int> weekdays = const [],
  List<int> monthDays = const [],
  bool monthEnd = false,
}) => ScheduleRecord(
  id: id,
  localDate: date,
  type: ScheduleType.personal,
  title: 'Weekly',
  recurrence: recurrence,
  recurrenceWeekdays: weekdays,
  recurrenceMonthDays: monthDays,
  recurrenceMonthEnd: monthEnd,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

ScheduleRecord _occurrence(ScheduleRecord series, String date) =>
    ScheduleRecord(
      id: '${series.effectiveSeriesId}@$date',
      seriesId: series.effectiveSeriesId,
      occurrenceDate: date,
      localDate: date,
      type: series.type,
      title: series.title,
      recurrence: series.recurrence,
      createdAt: series.createdAt,
      updatedAt: series.updatedAt,
    );

ScheduleRecord _draft(
  String date,
  String title, {
  ReminderRecurrence recurrence = ReminderRecurrence.weekly,
}) => ScheduleRecord(
  id: 'draft',
  localDate: date,
  type: ScheduleType.personal,
  title: title,
  recurrence: recurrence,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

class _MemoryScheduleRepository implements ScheduleRepository {
  _MemoryScheduleRepository(this.records);
  final List<ScheduleRecord> records;
  @override
  Future<void> delete(String id) async =>
      records.removeWhere((value) => value.id == id);
  @override
  Future<List<ScheduleRecord>> findAll() async => List.unmodifiable(records);
  @override
  Future<List<ScheduleRecord>> findForDate(String localDate) async =>
      records.where((value) => value.localDate == localDate).toList();
  @override
  Future<List<ScheduleRecord>> findForMonth(DateTime month) async => records;
  @override
  Future<ScheduleRecord?> findWorkForDate(String localDate) async => null;
  @override
  Future<void> save(ScheduleRecord record) async {
    records.removeWhere((value) => value.id == record.id);
    records.add(record);
  }
}
