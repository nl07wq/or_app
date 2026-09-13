import 'package:flutter/material.dart';

import '../../../core/models/operation_date_range.dart';
import '../models/body_history_models.dart';

/// Shared trailing-preset interpretation for Data Center Body, Nutrition, and
/// Digestive History. Explicit custom ranges retain both selected endpoints.
DateTimeRange resolveDataCenterHistoryRange(
  BodyHistoryPeriod period,
  DateTime anchor, {
  DateTimeRange? customRange,
}) {
  if (period == BodyHistoryPeriod.custom && customRange != null) {
    return OperationDateRange.customInclusive(
      customRange.start,
      customRange.end,
    ).toDateTimeRange();
  }
  final end = DateTime(anchor.year, anchor.month, anchor.day);
  return switch (period) {
    BodyHistoryPeriod.oneWeek => OperationDateRange.trailingFixedDays(
      end,
      7,
    ).toDateTimeRange(),
    BodyHistoryPeriod.fifteenDays => OperationDateRange.trailingFixedDays(
      end,
      15,
    ).toDateTimeRange(),
    BodyHistoryPeriod.oneMonth => OperationDateRange.trailingCalendarMonths(
      end,
      1,
    ).toDateTimeRange(),
    BodyHistoryPeriod.threeMonths => OperationDateRange.trailingCalendarMonths(
      end,
      3,
    ).toDateTimeRange(),
    BodyHistoryPeriod.sixMonths => OperationDateRange.trailingCalendarMonths(
      end,
      6,
    ).toDateTimeRange(),
    BodyHistoryPeriod.oneYear => OperationDateRange.trailingCalendarYears(
      end,
      1,
    ).toDateTimeRange(),
    BodyHistoryPeriod.allTime => DateTimeRange(start: DateTime(1), end: end),
    BodyHistoryPeriod.custom => DateTimeRange(start: end, end: end),
  };
}
