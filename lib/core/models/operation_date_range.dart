import 'package:flutter/material.dart';

/// An inclusive range of operation dates. It deliberately has no time-of-day
/// semantics: callers normalize an anchor once, then use the same boundaries
/// for labels, queries, charts, and denominators.
class OperationDateRange {
  const OperationDateRange._(this.start, this.end);

  final DateTime start;
  final DateTime end;

  factory OperationDateRange.customInclusive(DateTime start, DateTime end) {
    final normalizedStart = _dateOnly(start);
    final normalizedEnd = _dateOnly(end);
    if (normalizedStart.isAfter(normalizedEnd)) {
      throw ArgumentError.value(end, 'end', 'must not precede start');
    }
    return OperationDateRange._(normalizedStart, normalizedEnd);
  }

  factory OperationDateRange.trailingFixedDays(DateTime end, int days) {
    if (days < 1) throw ArgumentError.value(days, 'days', 'must be positive');
    final normalizedEnd = _dateOnly(end);
    return OperationDateRange._(
      normalizedEnd.subtract(Duration(days: days - 1)),
      normalizedEnd,
    );
  }

  factory OperationDateRange.trailingCalendarMonths(DateTime end, int months) {
    if (months < 1) {
      throw ArgumentError.value(months, 'months', 'must be positive');
    }
    final normalizedEnd = _dateOnly(end);
    return OperationDateRange._(
      _subtractMonthsClamped(
        normalizedEnd,
        months,
      ).add(const Duration(days: 1)),
      normalizedEnd,
    );
  }

  factory OperationDateRange.trailingCalendarYears(DateTime end, int years) {
    if (years < 1) {
      throw ArgumentError.value(years, 'years', 'must be positive');
    }
    final normalizedEnd = _dateOnly(end);
    final rawStart = DateTime(
      normalizedEnd.year - years,
      normalizedEnd.month,
      normalizedEnd.day.clamp(
        1,
        _daysInMonth(normalizedEnd.year - years, normalizedEnd.month),
      ),
    );
    return OperationDateRange._(
      rawStart.add(const Duration(days: 1)),
      normalizedEnd,
    );
  }

  DateTimeRange toDateTimeRange() => DateTimeRange(start: start, end: end);

  int get inclusiveDayCount => end.difference(start).inDays + 1;

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static DateTime _subtractMonthsClamped(DateTime date, int months) {
    final monthIndex = date.year * 12 + date.month - 1 - months;
    final targetYear = monthIndex ~/ 12;
    final targetMonth = monthIndex % 12 + 1;
    return DateTime(
      targetYear,
      targetMonth,
      date.day.clamp(1, _daysInMonth(targetYear, targetMonth)),
    );
  }

  static int _daysInMonth(int year, int month) =>
      DateTime(year, month + 1, 0).day;
}
