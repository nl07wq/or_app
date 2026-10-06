import 'package:flutter/material.dart';

import '../models/reminder_definition.dart';
import '../models/reminder_occurrence.dart';
import '../repository/reminder_repository.dart';
import 'reminder_recurrence_engine.dart';

/// Computes only the occurrences requested by a projection. Future dates are
/// never materialized as records; only state changes are persisted.
class ReminderOccurrenceService {
  ReminderOccurrenceService(
    this._repository, {
    ReminderRecurrenceEngine? engine,
  }) : _engine = engine ?? const ReminderRecurrenceEngine();

  final ReminderRepository _repository;
  final ReminderRecurrenceEngine _engine;

  Future<List<ReminderOccurrence>> inRange(
    DateTimeRange range, {
    bool includeCompleted = true,
  }) async {
    final definitions = await _repository.findDefinitions();
    final states = await _repository.findStates();
    final byId = {for (final state in states) state.id: state};
    final values = <ReminderOccurrence>[];
    for (final definition in definitions) {
      for (final date in _engine.datesFor(definition, range)) {
        if (!_isActiveFor(definition, date)) continue;
        final state = byId['${definition.id}@$date'];
        final status = state?.status ?? ReminderOccurrenceStatus.pending;
        if (status == ReminderOccurrenceStatus.skipped) continue;
        if (!includeCompleted && status != ReminderOccurrenceStatus.pending) {
          continue;
        }
        values.add(
          ReminderOccurrence(
            definition: definition,
            localDate: date,
            status: status,
          ),
        );
      }
    }
    values.sort(_compare);
    return List.unmodifiable(values);
  }

  Future<List<ReminderOccurrence>> completed() async {
    final definitions = {
      for (final definition in await _repository.findDefinitions())
        definition.id: definition,
    };
    final values = <ReminderOccurrence>[];
    for (final state in await _repository.findStates()) {
      if (state.status != ReminderOccurrenceStatus.completed) continue;
      final definition = definitions[state.definitionId];
      if (definition != null) {
        values.add(
          ReminderOccurrence(
            definition: definition,
            localDate: state.localDate,
            status: state.status,
          ),
        );
      }
    }
    values.sort((a, b) => b.localDate.compareTo(a.localDate));
    return List.unmodifiable(values);
  }

  /// Returns the next pending occurrence for each recurrence slot used by
  /// the compact ALL projection. Calendar and Dashboard continue to use
  /// [inRange] and are intentionally unaffected by this policy.
  Future<List<ReminderOccurrence>> nextPendingBySlot(DateTime from) async {
    final definitions = await _repository.findDefinitions();
    final states = await _repository.findStates();
    final byId = {for (final state in states) state.id: state};
    final statesByDefinition = <String, List<ReminderOccurrenceState>>{};
    for (final state in states) {
      statesByDefinition.putIfAbsent(state.definitionId, () => []).add(state);
    }
    final values = <String, ReminderOccurrence>{};
    final firstDate = DateUtils.dateOnly(from);

    for (final definition in definitions) {
      final slots = _slotsFor(definition);
      if (slots.isEmpty) continue;
      final definitionStart = DateTime.parse(definition.startDate);
      final searchStart = definitionStart.isAfter(firstDate)
          ? definitionStart
          : firstDate;
      final recurrenceEnd = DateTime.tryParse(definition.recurrenceEnd ?? '');
      if (recurrenceEnd != null && recurrenceEnd.isBefore(searchStart)) {
        continue;
      }
      var latestRelevantDate = searchStart;
      for (final state in statesByDefinition[definition.id] ?? const []) {
        final stateDate = DateTime.tryParse(state.localDate);
        if (stateDate != null && stateDate.isAfter(latestRelevantDate)) {
          latestRelevantDate = stateDate;
        }
      }
      final searchEnd =
          recurrenceEnd ?? latestRelevantDate.add(const Duration(days: 1465));
      final found = <String, ReminderOccurrence>{};
      for (final date in _engine.datesFor(
        definition,
        DateTimeRange(start: searchStart, end: searchEnd),
      )) {
        if (!_isActiveFor(definition, date)) continue;
        final occurrenceSlots = _slotsForDate(definition, date);
        if (occurrenceSlots.isEmpty) continue;
        final state = byId['${definition.id}@$date'];
        final status = state?.status ?? ReminderOccurrenceStatus.pending;
        if (status != ReminderOccurrenceStatus.pending) continue;
        final occurrence = ReminderOccurrence(
          definition: definition,
          localDate: date,
          status: status,
        );
        for (final slot in occurrenceSlots) {
          if (slots.contains(slot)) found.putIfAbsent(slot, () => occurrence);
        }
        if (found.length == slots.length) break;
      }
      for (final occurrence in found.values) {
        values[occurrence.id] = occurrence;
      }
    }

    final result = values.values.toList()..sort(_compare);
    return List.unmodifiable(result);
  }

  Future<void> complete(ReminderOccurrence occurrence, DateTime now) =>
      _repository.saveState(
        ReminderOccurrenceState(
          id: occurrence.id,
          definitionId: occurrence.definition.id,
          localDate: occurrence.localDate,
          status: ReminderOccurrenceStatus.completed,
          updatedAt: now.toUtc(),
          completedAt: now.toUtc(),
        ),
      );

  Future<void> restore(ReminderOccurrence occurrence) =>
      _repository.deleteState(occurrence.id);

  Future<void> skip(ReminderOccurrence occurrence, DateTime now) =>
      _repository.saveState(
        ReminderOccurrenceState(
          id: occurrence.id,
          definitionId: occurrence.definition.id,
          localDate: occurrence.localDate,
          status: ReminderOccurrenceStatus.skipped,
          updatedAt: now.toUtc(),
        ),
      );

  int _compare(ReminderOccurrence a, ReminderOccurrence b) {
    final date = a.localDate.compareTo(b.localDate);
    if (date != 0) return date;
    final aTime = a.definition.time ?? '';
    final bTime = b.definition.time ?? '';
    return aTime == bTime
        ? a.definition.id.compareTo(b.definition.id)
        : aTime.compareTo(bTime);
  }

  bool _isActiveFor(ReminderDefinition definition, String date) {
    final scheduled = _scheduledAt(definition, date);
    final effective = definition.effectiveFrom;
    if (effective != null && scheduled.isBefore(effective.toLocal())) {
      return false;
    }
    final retired = definition.retiredAt;
    if (retired != null && !scheduled.isBefore(retired.toLocal())) return false;
    return definition.active || retired != null;
  }

  DateTime _scheduledAt(ReminderDefinition definition, String localDate) {
    final date = DateTime.parse(localDate);
    final parts = definition.time?.split(':');
    final hour = parts == null ? 0 : int.tryParse(parts.first) ?? 0;
    final minute = parts == null || parts.length < 2
        ? 0
        : int.tryParse(parts[1]) ?? 0;
    return DateTime(date.year, date.month, date.day, hour, minute);
  }

  Set<String> _slotsFor(ReminderDefinition definition) =>
      switch (definition.recurrence) {
        ReminderRecurrence.customWeekdays => {
          for (final weekday in definition.weekdays) 'weekday:$weekday',
        },
        ReminderRecurrence.customMonthDays => {
          for (final day in definition.monthDays) 'monthDay:$day',
          if (definition.monthEnd) 'monthEnd',
        },
        _ => const {'definition'},
      };

  Set<String> _slotsForDate(ReminderDefinition definition, String localDate) {
    final date = DateTime.parse(localDate);
    return switch (definition.recurrence) {
      ReminderRecurrence.customWeekdays => {'weekday:${date.weekday}'},
      ReminderRecurrence.customMonthDays => {
        if (definition.monthDays.contains(date.day)) 'monthDay:${date.day}',
        if (definition.monthEnd &&
            date.day == DateTime(date.year, date.month + 1, 0).day)
          'monthEnd',
      },
      _ => const {'definition'},
    };
  }
}
