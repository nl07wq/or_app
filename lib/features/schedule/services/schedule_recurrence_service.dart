import 'package:flutter/material.dart';

import '../../reminders/models/reminder_definition.dart';
import '../../reminders/services/reminder_recurrence_engine.dart';
import '../models/schedule_record.dart';
import '../repository/schedule_repository.dart';

/// The mutation scope selected when changing a projected Schedule occurrence.
///
/// This is deliberately shared by Calendar UI and the recurrence service so
/// that scope semantics are persisted independently of a particular screen.
enum ScheduleRecurrenceScope { occurrence, future, all }

/// Projects Schedule series through the proven Reminder recurrence engine.
/// Overrides and exclusions remain Schedule records, so the existing store
/// export/import paths preserve the complete series without a new store.
class ScheduleRecurrenceService {
  ScheduleRecurrenceService(
    this._repository, {
    ReminderRecurrenceEngine? engine,
  }) : _engine = engine ?? const ReminderRecurrenceEngine();

  final ScheduleRepository _repository;
  final ReminderRecurrenceEngine _engine;

  /// Applies an edit to a generated occurrence without rewriting history.
  Future<void> editOccurrence({
    required ScheduleRecord occurrence,
    required ScheduleRecord draft,
    required ScheduleRecurrenceScope scope,
    DateTime Function()? clock,
  }) async {
    final records = await _repository.findAll();
    final series = _seriesFor(records, occurrence);
    final boundary = occurrence.occurrenceDate!;
    final now = (clock ?? DateTime.now)().toUtc();
    switch (scope) {
      case ScheduleRecurrenceScope.occurrence:
        await _repository.save(
          _occurrenceOverride(series, draft, boundary, now),
        );
      case ScheduleRecurrenceScope.all:
        final replacement = _seriesReplacement(
          series,
          draft,
          id: series.id,
          seriesId: series.effectiveSeriesId,
          now: now,
        );
        await _repository.save(replacement);
        // An override is retained only while its original occurrence remains
        // part of the edited series. This gives a changed recurrence rule a
        // deterministic result instead of leaving orphaned moved records.
        for (final value in records.where(
          (value) =>
              value.isOccurrenceOverride &&
              value.effectiveSeriesId == series.effectiveSeriesId &&
              !_isScheduled(replacement, value.occurrenceDate!),
        )) {
          await _repository.delete(value.id);
        }
      case ScheduleRecurrenceScope.future:
        await _repository.save(_endingAt(series, _dayBefore(boundary), now));
        // Overrides after the split belonged to the old series definition.
        // They cannot leak into the new series or reappear after a restart.
        for (final value in records.where(
          (value) =>
              value.isOccurrenceOverride &&
              value.effectiveSeriesId == series.effectiveSeriesId &&
              value.occurrenceDate!.compareTo(boundary) >= 0,
        )) {
          await _repository.delete(value.id);
        }
        final id = 'schedule_${now.microsecondsSinceEpoch}';
        await _repository.save(
          _seriesReplacement(series, draft, id: id, seriesId: id, now: now),
        );
    }
  }

  /// Deletes either one generated occurrence, the selected occurrence onward,
  /// or the whole logical series.
  Future<void> deleteOccurrence({
    required ScheduleRecord occurrence,
    required ScheduleRecurrenceScope scope,
    DateTime Function()? clock,
  }) async {
    final records = await _repository.findAll();
    final series = _seriesFor(records, occurrence);
    final boundary = occurrence.occurrenceDate!;
    final now = (clock ?? DateTime.now)().toUtc();
    switch (scope) {
      case ScheduleRecurrenceScope.occurrence:
        await _repository.save(
          ScheduleRecord(
            id: '${series.effectiveSeriesId}@$boundary',
            seriesId: series.effectiveSeriesId,
            occurrenceDate: boundary,
            occurrenceExcluded: true,
            localDate: boundary,
            type: series.type,
            title: series.title,
            kind: series.kind,
            allDay: series.allDay,
            startTime: series.startTime,
            endTime: series.endTime,
            breakDuration: series.breakDuration,
            memo: series.memo,
            completed: series.completed,
            createdAt: series.createdAt,
            updatedAt: now,
          ),
        );
      case ScheduleRecurrenceScope.future:
        await _repository.save(_endingAt(series, _dayBefore(boundary), now));
        for (final value in records.where(
          (value) =>
              value.isOccurrenceOverride &&
              value.effectiveSeriesId == series.effectiveSeriesId &&
              value.occurrenceDate!.compareTo(boundary) >= 0,
        )) {
          await _repository.delete(value.id);
        }
      case ScheduleRecurrenceScope.all:
        for (final value in records.where(
          (value) =>
              value.id == series.id ||
              value.effectiveSeriesId == series.effectiveSeriesId,
        )) {
          await _repository.delete(value.id);
        }
    }
  }

  Future<List<ScheduleRecord>> inRange(DateTimeRange range) async {
    final records = await _repository.findAll();
    final overrides = <String, ScheduleRecord>{
      for (final record in records)
        if (record.isOccurrenceOverride)
          '${record.effectiveSeriesId}@${record.occurrenceDate}': record,
    };
    final result = <ScheduleRecord>[
      ...records.where(
        (record) =>
            !record.isRecurringSeries &&
            !record.isOccurrenceOverride &&
            _inRange(record.localDate, range),
      ),
    ];
    final seriesById = {
      for (final record in records.where((record) => record.isRecurringSeries))
        record.effectiveSeriesId: record,
    };
    for (final series in seriesById.values) {
      final definition = ReminderDefinition(
        id: series.effectiveSeriesId,
        title: series.title,
        startDate: series.localDate,
        allDay: series.allDay,
        recurrence: series.recurrence,
        active: true,
        createdAt: series.createdAt,
        updatedAt: series.updatedAt,
        note: series.memo,
        time: series.startTime,
        recurrenceEnd: series.recurrenceEnd,
        weekdays: series.recurrenceWeekdays,
        monthDays: series.recurrenceMonthDays,
        monthEnd: series.recurrenceMonthEnd,
        monthWeek: series.recurrenceMonthWeek,
        monthWeeks: series.recurrenceMonthWeeks,
      );
      for (final date in _engine.datesFor(definition, range)) {
        final override = overrides['${series.effectiveSeriesId}@$date'];
        if (override?.occurrenceExcluded == true) continue;
        result.add(
          override ??
              ScheduleRecord(
                id: '${series.effectiveSeriesId}@$date',
                seriesId: series.effectiveSeriesId,
                occurrenceDate: date,
                localDate: date,
                type: series.type,
                title: series.title,
                kind: series.kind,
                allDay: series.allDay,
                startTime: series.startTime,
                endTime: series.endTime,
                breakDuration: series.breakDuration,
                memo: series.memo,
                completed: series.completed,
                recurrence: series.recurrence,
                recurrenceEnd: series.recurrenceEnd,
                recurrenceWeekdays: series.recurrenceWeekdays,
                recurrenceMonthDays: series.recurrenceMonthDays,
                recurrenceMonthEnd: series.recurrenceMonthEnd,
                recurrenceMonthWeek: series.recurrenceMonthWeek,
                recurrenceMonthWeeks: series.recurrenceMonthWeeks,
                notificationOffsetsMinutes: series.notificationOffsetsMinutes,
                notificationTimeZone: series.notificationTimeZone,
                createdAt: series.createdAt,
                updatedAt: series.updatedAt,
              ),
        );
      }
    }
    // A single-occurrence edit can move an occurrence across a month boundary.
    // Its displayed date, rather than its original recurrence date, owns the
    // Calendar placement in that case.
    for (final override in overrides.values) {
      final series = seriesById[override.effectiveSeriesId];
      if (!override.occurrenceExcluded &&
          _inRange(override.localDate, range) &&
          series != null &&
          _isScheduled(series, override.occurrenceDate!) &&
          !result.any((value) => value.id == override.id)) {
        result.add(override);
      }
    }
    result.sort(
      (a, b) => a.localDate == b.localDate
          ? a.id.compareTo(b.id)
          : a.localDate.compareTo(b.localDate),
    );
    return result;
  }

  bool _inRange(String localDate, DateTimeRange range) =>
      localDate.compareTo(_key(range.start)) >= 0 &&
      localDate.compareTo(_key(range.end)) <= 0;

  String _key(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  ScheduleRecord _seriesFor(
    List<ScheduleRecord> records,
    ScheduleRecord occurrence,
  ) => records.firstWhere(
    (value) =>
        value.id == occurrence.effectiveSeriesId && value.isRecurringSeries,
  );

  bool _isScheduled(ScheduleRecord series, String occurrenceDate) {
    final date = DateTime.parse(occurrenceDate);
    return _engine
        .datesFor(_definition(series), DateTimeRange(start: date, end: date))
        .contains(occurrenceDate);
  }

  ReminderDefinition _definition(ScheduleRecord series) => ReminderDefinition(
    id: series.effectiveSeriesId,
    title: series.title,
    startDate: series.localDate,
    allDay: series.allDay,
    recurrence: series.recurrence,
    active: true,
    createdAt: series.createdAt,
    updatedAt: series.updatedAt,
    note: series.memo,
    time: series.startTime,
    recurrenceEnd: series.recurrenceEnd,
    weekdays: series.recurrenceWeekdays,
    monthDays: series.recurrenceMonthDays,
    monthEnd: series.recurrenceMonthEnd,
    monthWeek: series.recurrenceMonthWeek,
    monthWeeks: series.recurrenceMonthWeeks,
  );

  ScheduleRecord _occurrenceOverride(
    ScheduleRecord series,
    ScheduleRecord draft,
    String occurrenceDate,
    DateTime now,
  ) => ScheduleRecord(
    id: '${series.effectiveSeriesId}@$occurrenceDate',
    seriesId: series.effectiveSeriesId,
    occurrenceDate: occurrenceDate,
    localDate: draft.localDate,
    type: draft.type,
    title: draft.title,
    kind: draft.kind,
    allDay: draft.allDay,
    startTime: draft.startTime,
    endTime: draft.endTime,
    breakDuration: draft.breakDuration,
    memo: draft.memo,
    completed: draft.completed,
    notificationOffsetsMinutes: draft.notificationOffsetsMinutes,
    notificationTimeZone: draft.notificationTimeZone,
    createdAt: series.createdAt,
    updatedAt: now,
  );

  ScheduleRecord _seriesReplacement(
    ScheduleRecord previous,
    ScheduleRecord draft, {
    required String id,
    required String seriesId,
    required DateTime now,
  }) => ScheduleRecord(
    id: id,
    seriesId: seriesId,
    localDate: draft.localDate,
    type: draft.type,
    title: draft.title,
    kind: draft.kind,
    allDay: draft.allDay,
    startTime: draft.startTime,
    endTime: draft.endTime,
    breakDuration: draft.breakDuration,
    memo: draft.memo,
    completed: draft.completed,
    recurrence: draft.recurrence,
    recurrenceEnd: draft.recurrenceEnd,
    recurrenceWeekdays: draft.recurrenceWeekdays,
    recurrenceMonthDays: draft.recurrenceMonthDays,
    recurrenceMonthEnd: draft.recurrenceMonthEnd,
    recurrenceMonthWeek: draft.recurrenceMonthWeek,
    recurrenceMonthWeeks: draft.recurrenceMonthWeeks,
    notificationOffsetsMinutes: draft.notificationOffsetsMinutes,
    notificationTimeZone: draft.notificationTimeZone,
    createdAt: previous.createdAt,
    updatedAt: now,
  );

  ScheduleRecord _endingAt(
    ScheduleRecord series,
    String requestedEnd,
    DateTime now,
  ) {
    final end =
        series.recurrenceEnd != null &&
            series.recurrenceEnd!.compareTo(requestedEnd) < 0
        ? series.recurrenceEnd!
        : requestedEnd;
    return ScheduleRecord(
      id: series.id,
      seriesId: series.seriesId,
      localDate: series.localDate,
      type: series.type,
      title: series.title,
      kind: series.kind,
      allDay: series.allDay,
      startTime: series.startTime,
      endTime: series.endTime,
      breakDuration: series.breakDuration,
      memo: series.memo,
      completed: series.completed,
      recurrence: series.recurrence,
      recurrenceEnd: end,
      recurrenceWeekdays: series.recurrenceWeekdays,
      recurrenceMonthDays: series.recurrenceMonthDays,
      recurrenceMonthEnd: series.recurrenceMonthEnd,
      recurrenceMonthWeek: series.recurrenceMonthWeek,
      recurrenceMonthWeeks: series.recurrenceMonthWeeks,
      notificationOffsetsMinutes: series.notificationOffsetsMinutes,
      notificationTimeZone: series.notificationTimeZone,
      createdAt: series.createdAt,
      updatedAt: now,
    );
  }

  String _dayBefore(String value) =>
      _key(DateTime.parse(value).subtract(const Duration(days: 1)));
}
