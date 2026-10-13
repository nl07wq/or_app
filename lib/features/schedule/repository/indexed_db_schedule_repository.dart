import 'package:flutter/material.dart';

import '../../../data/indexed_db/indexed_db_database_contract.dart';
import '../../../data/indexed_db/indexed_db_store_names.dart';
import '../../reminders/models/reminder_definition.dart';
import '../../reminders/services/reminder_recurrence_engine.dart';
import '../../repositories/repository_exception.dart';
import '../models/schedule_record.dart';
import 'schedule_repository.dart';

class IndexedDbScheduleRepository implements ScheduleRepository {
  IndexedDbScheduleRepository(this._database, {DateTime Function()? now})
    : _now = now ?? DateTime.now;
  final IndexedDbDatabase _database;
  final DateTime Function() _now;
  static const _recurrenceEngine = ReminderRecurrenceEngine();

  @override
  Future<List<ScheduleRecord>> findAll() => _all();

  @override
  Future<List<ScheduleRecord>> findForDate(String localDate) async =>
      (await _all()).where((record) => record.localDate == localDate).toList();

  @override
  Future<List<ScheduleRecord>> findForMonth(DateTime month) async {
    final prefix =
        '${month.year.toString().padLeft(4, '0')}-${month.month.toString().padLeft(2, '0')}';
    return (await _all())
        .where((record) => record.localDate.startsWith(prefix))
        .toList();
  }

  @override
  Future<ScheduleRecord?> findWorkForDate(String localDate) async {
    final work = (await findForDate(localDate))
        .where(
          (record) =>
              record.kind == ScheduleEntryKind.schedule &&
              record.type == ScheduleType.work,
        )
        .toList();
    if (work.length > 1) {
      throw StateError('Multiple WORK schedules exist for $localDate.');
    }
    return work.isEmpty ? null : work.single;
  }

  @override
  Future<void> save(ScheduleRecord record) async {
    if (record.title.trim().isEmpty) {
      throw ArgumentError.value(record.title, 'title');
    }
    try {
      await _database.runTransaction<void>(
        storeNames: const [IndexedDbStoreNames.scheduleRecords],
        mode: IndexedDbTransactionMode.readWrite,
        action: (transaction) async {
          if (record.kind == ScheduleEntryKind.schedule &&
              record.type == ScheduleType.work) {
            final existingWork =
                (await transaction.findAll(IndexedDbStoreNames.scheduleRecords))
                    .map(ScheduleRecord.fromRecord)
                    .where(_isWorkSchedule)
                    .any((value) => _conflictsWithWork(value, record));
            if (existingWork) {
              throw StateError('A WORK schedule already exists for this date.');
            }
          }
          final existing = await transaction.findById(
            IndexedDbStoreNames.scheduleRecords,
            record.id,
          );
          final timestamp = _now().toUtc();
          await transaction.put(
            IndexedDbStoreNames.scheduleRecords,
            ScheduleRecord(
              id: record.id,
              localDate: record.localDate,
              type: record.type,
              title: record.title.trim(),
              kind: record.kind,
              allDay: record.allDay,
              startTime: record.startTime,
              endTime: record.endTime,
              endDate: record.endDate,
              breakDuration: record.breakDuration,
              memo: record.memo,
              completed: record.completed,
              recurrence: record.recurrence,
              recurrenceEnd: record.recurrenceEnd,
              recurrenceWeekdays: record.recurrenceWeekdays,
              recurrenceMonthDays: record.recurrenceMonthDays,
              recurrenceMonthEnd: record.recurrenceMonthEnd,
              recurrenceMonthWeek: record.recurrenceMonthWeek,
              recurrenceMonthWeeks: record.recurrenceMonthWeeks,
              notificationOffsetsMinutes: record.notificationOffsetsMinutes,
              notificationTimeZone: record.notificationTimeZone,
              seriesId: record.seriesId,
              occurrenceDate: record.occurrenceDate,
              occurrenceExcluded: record.occurrenceExcluded,
              createdAt: existing == null
                  ? timestamp
                  : ScheduleRecord.fromRecord(existing).createdAt,
              updatedAt: timestamp,
            ).toRecord(),
          );
        },
      );
    } catch (error) {
      throw RepositoryException(operation: 'schedule.save', cause: error);
    }
  }

  bool _isWorkSchedule(ScheduleRecord value) =>
      value.kind == ScheduleEntryKind.schedule &&
      value.type == ScheduleType.work;

  /// A persisted recurrence series and one of its overrides describe the same
  /// logical WORK.  They are intentionally allowed to share an operation
  /// date; unrelated WORK entries are not.
  bool _conflictsWithWork(ScheduleRecord existing, ScheduleRecord candidate) {
    if (existing.id == candidate.id ||
        existing.effectiveSeriesId == candidate.effectiveSeriesId) {
      return false;
    }
    if (existing.localDate == candidate.localDate) return true;
    if (_occursOn(existing, candidate.localDate) ||
        _occursOn(candidate, existing.localDate)) {
      return true;
    }
    return _recurrencesOverlap(existing, candidate);
  }

  bool _occursOn(ScheduleRecord value, String date) {
    if (!value.isRecurringSeries) return false;
    final day = DateTime.parse(date);
    final definition = _definition(value);
    return _recurrenceEngine
        .datesFor(definition, DateTimeRange(start: day, end: day))
        .contains(date);
  }

  /// A bounded horizon covers the supported daily, weekly, monthly and yearly
  /// rules while keeping duplicate checks inexpensive during a save.
  bool _recurrencesOverlap(ScheduleRecord first, ScheduleRecord second) {
    if (!first.isRecurringSeries || !second.isRecurringSeries) return false;
    final firstStart = DateTime.parse(first.localDate);
    final secondStart = DateTime.parse(second.localDate);
    final start = firstStart.isAfter(secondStart) ? firstStart : secondStart;
    final firstEnd = first.recurrenceEnd == null
        ? start.add(const Duration(days: 366 * 8))
        : DateTime.parse(first.recurrenceEnd!);
    final secondEnd = second.recurrenceEnd == null
        ? start.add(const Duration(days: 366 * 8))
        : DateTime.parse(second.recurrenceEnd!);
    final end = firstEnd.isBefore(secondEnd) ? firstEnd : secondEnd;
    if (end.isBefore(start)) return false;
    final range = DateTimeRange(start: start, end: end);
    final dates = _recurrenceEngine.datesFor(_definition(first), range).toSet();
    return _recurrenceEngine
        .datesFor(_definition(second), range)
        .any(dates.contains);
  }

  ReminderDefinition _definition(ScheduleRecord value) => ReminderDefinition(
    id: value.effectiveSeriesId,
    title: value.title,
    startDate: value.localDate,
    allDay: value.allDay,
    recurrence: value.recurrence,
    active: true,
    createdAt: value.createdAt,
    updatedAt: value.updatedAt,
    time: value.startTime,
    recurrenceEnd: value.recurrenceEnd,
    weekdays: value.recurrenceWeekdays,
    monthDays: value.recurrenceMonthDays,
    monthEnd: value.recurrenceMonthEnd,
    monthWeek: value.recurrenceMonthWeek,
    monthWeeks: value.recurrenceMonthWeeks,
  );

  @override
  Future<void> delete(String id) =>
      _database.deleteById(IndexedDbStoreNames.scheduleRecords, id);

  Future<List<ScheduleRecord>> _all() async {
    try {
      final records = (await _database.findAll(
        IndexedDbStoreNames.scheduleRecords,
      )).map(ScheduleRecord.fromRecord).toList();
      records.sort(
        (a, b) => a.localDate == b.localDate
            ? a.id.compareTo(b.id)
            : a.localDate.compareTo(b.localDate),
      );
      return List.unmodifiable(records);
    } catch (error) {
      throw RepositoryException(operation: 'schedule.read', cause: error);
    }
  }
}
