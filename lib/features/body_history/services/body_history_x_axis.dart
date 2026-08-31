import 'dart:math' as math;

import '../models/body_history_models.dart';

class BodyHistoryXAxisTick {
  final double x;
  final String label;

  const BodyHistoryXAxisTick({required this.x, required this.label});
}

class BodyHistoryXAxis {
  static const double minimumLabelWidthCandidate = 40;

  const BodyHistoryXAxis();

  List<BodyHistoryXAxisTick> ticks({
    required String startDate,
    required String endDate,
    required BodyHistoryPeriod period,
    required BodyHistoryGranularity granularity,
    required double availablePlotWidth,
  }) {
    final start = _parse(startDate);
    final end = _parse(endDate);
    final totalDays = end.difference(start).inDays + 1;
    final maximumLabels = math.max(
      2,
      (availablePlotWidth / minimumLabelWidthCandidate).floor(),
    );
    var dates = _presetDates(start, end, period, totalDays);
    if (_usesCalendarPreset(period, totalDays)) {
      dates = _suppressBoundaryCollisions(dates, start, end, period, totalDays);
    } else if (dates.length > maximumLabels && totalDays > 7) {
      dates = _presetSelection(dates, maximumLabels, totalDays);
    }
    return _formatTicks(dates, start, granularity);
  }

  static bool _usesCalendarPreset(BodyHistoryPeriod period, int totalDays) =>
      switch (period) {
        BodyHistoryPeriod.oneMonth ||
        BodyHistoryPeriod.threeMonths ||
        BodyHistoryPeriod.sixMonths ||
        BodyHistoryPeriod.oneYear => true,
        BodyHistoryPeriod.oneWeek || BodyHistoryPeriod.fifteenDays => false,
        BodyHistoryPeriod.allTime ||
        BodyHistoryPeriod.custom => totalDays > 20 && totalDays <= 550,
      };

  static List<DateTime> _suppressBoundaryCollisions(
    List<DateTime> dates,
    DateTime start,
    DateTime end,
    BodyHistoryPeriod period,
    int totalDays,
  ) {
    final nominalDays = switch (period) {
      BodyHistoryPeriod.oneMonth => 5,
      BodyHistoryPeriod.threeMonths => 10,
      BodyHistoryPeriod.sixMonths => 15,
      BodyHistoryPeriod.oneYear => 30,
      BodyHistoryPeriod.oneWeek || BodyHistoryPeriod.fifteenDays => totalDays,
      BodyHistoryPeriod.allTime ||
      BodyHistoryPeriod.custom => switch (totalDays) {
        <= 45 => 5,
        <= 120 => 10,
        <= 210 => 15,
        _ => 30,
      },
    };
    final minimumDistanceDays = (nominalDays * 2 + 2) ~/ 3;
    return [
      for (final date in dates)
        if (date == start ||
            date == end ||
            (date.difference(start).inDays >= minimumDistanceDays &&
                end.difference(date).inDays >= minimumDistanceDays))
          date,
    ];
  }

  static List<DateTime> _presetSelection(
    List<DateTime> dates,
    int maximumLabels,
    int totalDays,
  ) {
    final selected = <DateTime>{dates.first, dates.last};
    final priorities = switch (totalDays) {
      <= 45 => <bool Function(DateTime)>[(date) => date.day == 15],
      <= 120 => <bool Function(DateTime)>[
        (date) => date.day == 1,
        (date) => date.day == 15,
        (date) => date.day == 25,
      ],
      <= 210 => <bool Function(DateTime)>[
        (date) => date.day == 1,
        (date) => date.day == 15,
      ],
      <= 550 => <bool Function(DateTime)>[(date) => date.day == 1],
      _ => <bool Function(DateTime)>[],
    };
    for (final matches in priorities) {
      final slots = maximumLabels - selected.length;
      if (slots <= 0) break;
      final candidates = dates
          .where((date) => !selected.contains(date) && matches(date))
          .toList(growable: false);
      selected.addAll(_evenSelection(candidates, slots));
    }
    if (selected.length < maximumLabels) {
      final remaining = dates
          .where((date) => !selected.contains(date))
          .toList();
      selected.addAll(
        _evenSelection(remaining, maximumLabels - selected.length),
      );
    }
    final result = selected.toList()..sort();
    return result.toList(growable: false);
  }

  static List<DateTime> _evenSelection(List<DateTime> values, int count) {
    if (count <= 0 || values.isEmpty) return const [];
    if (values.length <= count) return List.of(values);
    if (count == 1) return [values.first];
    return [
      for (var index = 0; index < count; index++)
        values[(index * (values.length - 1) / (count - 1)).round()],
    ];
  }

  static List<DateTime> _presetDates(
    DateTime start,
    DateTime end,
    BodyHistoryPeriod period,
    int totalDays,
  ) {
    switch (period) {
      case BodyHistoryPeriod.oneWeek:
        return _dates(start, end, _intervals[0]);
      case BodyHistoryPeriod.fifteenDays:
        return _dates(start, end, _intervals[1]);
      case BodyHistoryPeriod.oneMonth:
        return _monthDays(start, end, const [1, 5, 10, 15, 20, 25, 30]);
      case BodyHistoryPeriod.threeMonths:
        return _monthDays(start, end, const [1, 15, 25]);
      case BodyHistoryPeriod.sixMonths:
        return _monthDays(start, end, const [1, 15]);
      case BodyHistoryPeriod.oneYear:
        return _monthDays(start, end, const [1]);
      case BodyHistoryPeriod.allTime:
      case BodyHistoryPeriod.custom:
        break;
    }
    if (totalDays <= 7) return _dates(start, end, _intervals[0]);
    if (totalDays <= 20) return _dates(start, end, _intervals[1]);
    if (totalDays <= 45) {
      return _monthDays(start, end, const [1, 5, 10, 15, 20, 25, 30]);
    }
    if (totalDays <= 120) return _monthDays(start, end, const [1, 15, 25]);
    if (totalDays <= 210) return _monthDays(start, end, const [1, 15]);
    if (totalDays <= 550) return _monthDays(start, end, const [1]);
    final intervalIndex = _initialIntervalIndex(totalDays);
    return _dates(start, end, _intervals[intervalIndex]);
  }

  static List<DateTime> _monthDays(
    DateTime start,
    DateTime end,
    List<int> days,
  ) {
    final values = <DateTime>[];
    for (
      var month = DateTime.utc(start.year, start.month);
      !month.isAfter(end);
      month = DateTime.utc(month.year, month.month + 1)
    ) {
      for (final day in days) {
        final date = DateTime.utc(month.year, month.month, day);
        if (!date.isBefore(start) && !date.isAfter(end)) values.add(date);
      }
    }
    if (values.isEmpty || values.first != start) values.insert(0, start);
    if (values.last != end) values.add(end);
    return values;
  }

  static int _initialIntervalIndex(int totalDays) {
    if (totalDays <= 7) return 0;
    if (totalDays <= 20) return 1;
    if (totalDays <= 45) return 3;
    if (totalDays <= 120) return 6;
    if (totalDays <= 550) return 7;
    return 8;
  }

  static const _intervals = <_CalendarInterval>[
    _CalendarInterval.days(1),
    _CalendarInterval.days(2),
    _CalendarInterval.days(3),
    _CalendarInterval.days(5),
    _CalendarInterval.days(7),
    _CalendarInterval.days(10),
    _CalendarInterval.days(15),
    _CalendarInterval.months(1),
    _CalendarInterval.months(3),
    _CalendarInterval.months(6),
    _CalendarInterval.months(12),
  ];

  static List<DateTime> _dates(
    DateTime start,
    DateTime end,
    _CalendarInterval interval,
  ) {
    if (interval.days case final days?) {
      if (days == 5 || days == 10 || days == 15) {
        return [
          for (
            var date = start;
            !date.isAfter(end);
            date = date.add(const Duration(days: 1))
          )
            if (date == start || date.day % days == 0) date,
        ];
      }
      return [
        for (
          var date = start;
          !date.isAfter(end);
          date = date.add(Duration(days: days))
        )
          date,
      ];
    }
    var date = DateTime.utc(start.year, start.month);
    if (date.isBefore(start)) {
      date = DateTime.utc(start.year, start.month + 1);
    }
    return [
      for (
        ;
        !date.isAfter(end);
        date = DateTime.utc(date.year, date.month + interval.months!)
      )
        date,
    ];
  }

  static List<BodyHistoryXAxisTick> _formatTicks(
    List<DateTime> dates,
    DateTime rangeStart,
    BodyHistoryGranularity granularity,
  ) {
    final result = <BodyHistoryXAxisTick>[];
    DateTime? previous;
    for (final date in dates) {
      result.add(
        BodyHistoryXAxisTick(
          x: date.difference(rangeStart).inDays.toDouble(),
          label: _label(date, previous, granularity),
        ),
      );
      previous = date;
    }
    return result;
  }

  static String _label(
    DateTime date,
    DateTime? previous,
    BodyHistoryGranularity granularity,
  ) {
    final yearChanged = previous != null && previous.year != date.year;
    final monthChanged =
        previous == null || previous.month != date.month || yearChanged;
    if (granularity == BodyHistoryGranularity.monthly) {
      return previous == null || yearChanged
          ? '${date.year}/${date.month}'
          : '${date.month}';
    }
    if (yearChanged) return '${date.year}/${date.month}/${date.day}';
    if (monthChanged) return '${date.month}/${date.day}';
    return '${date.day}';
  }

  static DateTime _parse(String value) => DateTime.parse('${value}T00:00:00Z');
}

class _CalendarInterval {
  final int? days;
  final int? months;

  const _CalendarInterval.days(this.days) : months = null;
  const _CalendarInterval.months(this.months) : days = null;
}
