import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/body_history/models/body_history_models.dart';
import 'package:or_app/features/body_history/services/history_period_range.dart';

void main() {
  final anchor = DateTime(2026, 9, 13);

  test(
    'all Data Center history presets resolve through one range contract',
    () {
      expect(_range(BodyHistoryPeriod.oneWeek), ('2026-09-07', '2026-09-13'));
      expect(_range(BodyHistoryPeriod.fifteenDays), (
        '2026-08-30',
        '2026-09-13',
      ));
      expect(_range(BodyHistoryPeriod.oneMonth), ('2026-08-14', '2026-09-13'));
      expect(_range(BodyHistoryPeriod.threeMonths), (
        '2026-06-14',
        '2026-09-13',
      ));
      expect(_range(BodyHistoryPeriod.sixMonths), ('2026-03-14', '2026-09-13'));
      expect(_range(BodyHistoryPeriod.oneYear), ('2025-09-14', '2026-09-13'));
    },
  );

  test('custom range remains inclusive and is not normalized as a preset', () {
    final range = resolveDataCenterHistoryRange(
      BodyHistoryPeriod.custom,
      anchor,
      customRange: DateTimeRange(start: DateTime(2026, 8, 13), end: anchor),
    );
    expect(
      (_date(range.start), _date(range.end)),
      ('2026-08-13', '2026-09-13'),
    );
  });
}

(String, String) _range(BodyHistoryPeriod period) {
  final value = resolveDataCenterHistoryRange(period, DateTime(2026, 9, 13));
  return (_date(value.start), _date(value.end));
}

String _date(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
