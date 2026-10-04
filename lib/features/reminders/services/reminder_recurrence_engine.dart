import 'package:flutter/material.dart';

import '../models/reminder_definition.dart';

class ReminderRecurrenceEngine {
  const ReminderRecurrenceEngine();

  Iterable<String> datesFor(
    ReminderDefinition definition,
    DateTimeRange range,
  ) sync* {
    final start = _date(definition.startDate);
    final from = _dateKey(range.start).compareTo(definition.startDate) < 0
        ? start
        : _date(_dateKey(range.start));
    final to = _date(_dateKey(range.end));
    for (
      var date = from;
      !date.isAfter(to);
      date = date.add(const Duration(days: 1))
    ) {
      final key = _dateKey(date);
      if (key.compareTo(definition.startDate) < 0) continue;
      final end = definition.recurrenceEnd;
      if (end != null && key.compareTo(end) > 0) continue;
      if (_matches(definition, date)) yield key;
    }
  }

  bool _matches(ReminderDefinition definition, DateTime date) {
    final start = _date(definition.startDate);
    switch (definition.recurrence) {
      case ReminderRecurrence.none:
        return _same(date, start);
      case ReminderRecurrence.daily:
        return true;
      case ReminderRecurrence.weekdays:
        return date.weekday <= DateTime.friday;
      case ReminderRecurrence.weekends:
        return date.weekday >= DateTime.saturday;
      case ReminderRecurrence.weekly:
        return date.weekday == start.weekday;
      case ReminderRecurrence.biweekly:
        return date.weekday == start.weekday &&
            date.difference(start).inDays % 14 == 0;
      case ReminderRecurrence.monthly:
        return date.day == start.day;
      case ReminderRecurrence.yearly:
        return date.month == start.month && date.day == start.day;
      case ReminderRecurrence.customWeekdays:
        return definition.weekdays.contains(date.weekday);
      case ReminderRecurrence.customMonthDays:
        return definition.monthDays.contains(date.day) ||
            (definition.monthEnd && date.day == _lastDayOfMonth(date));
    }
  }

  DateTime _date(String value) => DateTime.parse(value);
  String _dateKey(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
  bool _same(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
  int _lastDayOfMonth(DateTime value) =>
      DateTime(value.year, value.month + 1, 0).day;
}
