import 'package:flutter/foundation.dart';

import '../../../core/engine/activity_summary.dart';
import '../../../core/models/activity_data.dart';
import '../../../core/models/morning_data.dart';
import '../../../core/repositories/morning_repository.dart';
import '../../../core/services/app_clock.dart';
import '../repository/activity_repository.dart';
import '../services/activity_summary_engine.dart';
import '../../../core/services/daily_log_mutation_guard.dart';

final ValueNotifier<ActivitySummary> activitySummaryNotifier = ValueNotifier(
  const ActivitySummary.empty(),
);

const _repository = LocalActivityRepository();
const _summaryEngine = ActivitySummaryEngine();

Future<void> refreshActivitySummary() async {
  final today = AppClock.today();
  final record = await _repository.findByDate(today);
  final previous = await loadPreviousActivity(today);
  final legacyMorning = await _loadMorning(today);
  activitySummaryNotifier.value = record == null
      ? const ActivitySummary.empty()
      : _summaryEngine.generate(
          record: record,
          previousCarryOver: previous?.carryOver ?? 0,
          legacyMorning: legacyMorning,
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
  final summary = _summaryEngine.generate(
    record: data,
    previousCarryOver: previous?.carryOver ?? 0,
    legacyMorning: await _loadMorning(data.date),
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

Future<MorningData?> _loadMorning(DateTime date) async {
  final records = await MorningRepository.getAll();
  for (final record in records) {
    final recordDate = DateTime.parse(record.date);
    if (recordDate.year == date.year &&
        recordDate.month == date.month &&
        recordDate.day == date.day) {
      return record;
    }
  }
  return null;
}
