import 'package:flutter/foundation.dart';

import '../../../core/engine/activity_summary.dart';
import '../../../core/models/activity_data.dart';
import '../../../core/services/app_clock.dart';
import '../repository/activity_repository.dart';
import '../../../core/services/daily_log_mutation_guard.dart';

final ValueNotifier<ActivitySummary> activitySummaryNotifier = ValueNotifier(
  const ActivitySummary.empty(),
);

const _repository = LocalActivityRepository();

Future<void> refreshActivitySummary() async {
  final today = AppClock.today();
  final record = await _repository.findByDate(today);
  final previous = await loadPreviousActivity(today);
  activitySummaryNotifier.value = record == null
      ? const ActivitySummary.empty()
      : ActivitySummary.fromActivityData(
          record,
          previousCarryOver: previous?.carryOver ?? 0,
        );
}

/// Returns the previous calendar day's saved Activity record, if any.
///
/// This is read-only: opening an entry form never consumes or alters the
/// prior day's carry-over value.
Future<ActivityData?> loadPreviousActivity(DateTime date) {
  final previousDate = DateTime(date.year, date.month, date.day - 1);
  return _repository.findByDate(previousDate);
}

Future<void> saveActivity(ActivityData data) async {
  final previous = await loadPreviousActivity(data.date);
  final summary = ActivitySummary.fromActivityData(
    data,
    previousCarryOver: previous?.carryOver ?? 0,
  );
  await DailyLogMutationGuard.assertDateMutable(data.date);
  await _repository.save(data);
  if (_isToday(data.date)) {
    activitySummaryNotifier.value = summary;
  }
}

Future<void> deleteActivity(DateTime date) async {
  await DailyLogMutationGuard.assertDateMutable(date);
  await _repository.deleteByDate(date);

  if (_isToday(date)) {
    activitySummaryNotifier.value = const ActivitySummary.empty();
  }
}

bool _isToday(DateTime date) {
  final today = AppClock.today();
  return date.year == today.year &&
      date.month == today.month &&
      date.day == today.day;
}
