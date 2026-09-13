import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/models/operation_date_range.dart';

void main() {
  group('OperationDateRange trailing presets', () {
    final end = DateTime(2026, 9, 13, 23, 59);

    test('fixed-day ranges include the end date exactly once', () {
      final week = OperationDateRange.trailingFixedDays(end, 7);
      final fifteen = OperationDateRange.trailingFixedDays(end, 15);

      expect(_date(week.start), '2026-09-07');
      expect(_date(week.end), '2026-09-13');
      expect(week.inclusiveDayCount, 7);
      expect(_date(fifteen.start), '2026-08-30');
      expect(fifteen.inclusiveDayCount, 15);
    });

    test('calendar presets avoid an extra inclusive boundary date', () {
      expect(
        _date(OperationDateRange.trailingCalendarMonths(end, 1).start),
        '2026-08-14',
      );
      expect(
        _date(OperationDateRange.trailingCalendarMonths(end, 3).start),
        '2026-06-14',
      );
      expect(
        _date(OperationDateRange.trailingCalendarMonths(end, 6).start),
        '2026-03-14',
      );
      expect(
        _date(OperationDateRange.trailingCalendarYears(end, 1).start),
        '2025-09-14',
      );
    });

    test(
      'month end clamps before applying the inclusive trailing boundary',
      () {
        expect(
          _date(
            OperationDateRange.trailingCalendarMonths(
              DateTime(2026, 3, 31),
              1,
            ).start,
          ),
          '2026-03-01',
        );
        expect(
          _date(
            OperationDateRange.trailingCalendarMonths(
              DateTime(2026, 8, 31),
              6,
            ).start,
          ),
          '2026-03-01',
        );
      },
    );

    test('leap-day year subtraction clamps deterministically', () {
      final range = OperationDateRange.trailingCalendarYears(
        DateTime(2024, 2, 29),
        1,
      );
      expect(_date(range.start), '2023-03-01');
      expect(_date(range.end), '2024-02-29');
    });

    test('custom ranges retain both explicitly selected endpoints', () {
      final range = OperationDateRange.customInclusive(
        DateTime(2026, 8, 13),
        DateTime(2026, 9, 13),
      );
      expect(range.inclusiveDayCount, 32);
      expect(
        OperationDateRange.customInclusive(
          DateTime(2026, 9, 13),
          DateTime(2026, 9, 13),
        ).inclusiveDayCount,
        1,
      );
    });
  });
}

String _date(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
