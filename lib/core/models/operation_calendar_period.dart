enum OperationCalendarPeriodType { weekly, monthly, yearly }

class OperationCalendarPeriod {
  const OperationCalendarPeriod({
    required this.type,
    required this.id,
    required this.start,
    required this.end,
  });

  final OperationCalendarPeriodType type;
  final String id;
  final DateTime start;
  final DateTime end;

  int get expectedDayCount => end.difference(start).inDays + 1;

  bool isCompleteAt(DateTime operationDate) =>
      _dateOnly(operationDate).isAfter(end);

  OperationCalendarPeriod previous() => switch (type) {
    OperationCalendarPeriodType.weekly => OperationCalendarPeriod.week(
      start.subtract(const Duration(days: 7)),
    ),
    OperationCalendarPeriodType.monthly => OperationCalendarPeriod.month(
      DateTime(start.year, start.month - 1),
    ),
    OperationCalendarPeriodType.yearly => OperationCalendarPeriod.year(
      DateTime(start.year - 1),
    ),
  };

  factory OperationCalendarPeriod.week(DateTime anchor) {
    final date = _dateOnly(anchor);
    final monday = date.subtract(
      Duration(days: date.weekday - DateTime.monday),
    );
    return OperationCalendarPeriod(
      type: OperationCalendarPeriodType.weekly,
      id: 'weekly:${_localDate(monday)}',
      start: monday,
      end: monday.add(const Duration(days: 6)),
    );
  }

  factory OperationCalendarPeriod.month(DateTime anchor) {
    final start = _calendarDate(anchor, anchor.year, anchor.month, 1);
    final end = _calendarDate(anchor, anchor.year, anchor.month + 1, 0);
    return OperationCalendarPeriod(
      type: OperationCalendarPeriodType.monthly,
      id:
          'monthly:${start.year.toString().padLeft(4, '0')}-'
          '${start.month.toString().padLeft(2, '0')}',
      start: start,
      end: end,
    );
  }

  factory OperationCalendarPeriod.year(DateTime anchor) {
    final start = _calendarDate(anchor, anchor.year, 1, 1);
    return OperationCalendarPeriod(
      type: OperationCalendarPeriodType.yearly,
      id: 'yearly:${start.year.toString().padLeft(4, '0')}',
      start: start,
      end: _calendarDate(anchor, anchor.year, 12, 31),
    );
  }

  static DateTime _dateOnly(DateTime value) =>
      _calendarDate(value, value.year, value.month, value.day);

  static DateTime _calendarDate(
    DateTime source,
    int year,
    int month,
    int day,
  ) => source.isUtc
      ? DateTime.utc(year, month, day)
      : DateTime(year, month, day);

  static String _localDate(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}
