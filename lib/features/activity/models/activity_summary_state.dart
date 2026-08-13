import 'package:flutter/foundation.dart';

import '../../../core/engine/activity_summary.dart';
import '../../../core/models/activity_data.dart';
import '../../../core/models/morning_data.dart';
import '../../../core/repositories/morning_repository.dart';
import '../../operation_date/services/operation_date_service.dart';
import '../repository/activity_repository.dart';
import '../services/activity_summary_engine.dart';
import '../../../core/services/daily_log_mutation_guard.dart';

final ValueNotifier<ActivitySummary> activitySummaryNotifier = ValueNotifier(
  const ActivitySummary.empty(),
);

const _repository = LocalActivityRepository();
const _summaryEngine = ActivitySummaryEngine();

Future<void> refreshActivitySummary({String? localDate}) async {
  activitySummaryNotifier.value = await loadActivitySummary(
    localDate: localDate,
  );
}

Future<ActivitySummary> loadActivitySummary({String? localDate}) async {
  final targetLocalDate =
      localDate ?? (await const OperationDateService().current()).value;
  final targetDate = DateTime.parse(targetLocalDate);
  final record = await _repository.findByDate(targetDate);
  final previous = await loadPreviousActivity(targetDate);
  final legacyMorning = await _loadMorning(targetDate);
  return record == null
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
  final readBack = await _repository.findById(data.id);
  if (readBack == null ||
      !_isSameDate(readBack.date, data.date) ||
      readBack.id != data.id) {
    throw StateError('targetRecordReadBackFailed');
  }
  if (await _isCurrentOperationDate(data.date)) {
    activitySummaryNotifier.value = summary;
  }
}

Future<void> deleteActivity(DateTime date) async {
  await DailyLogMutationGuard.assertDateMutable(date);
  await _repository.deleteByDate(date);
  if (await _repository.findByDate(date) != null) {
    throw StateError('targetRecordDeleteReadBackFailed');
  }

  if (await _isCurrentOperationDate(date)) {
    activitySummaryNotifier.value = const ActivitySummary.empty();
  }
}

Future<bool> _isCurrentOperationDate(DateTime date) async {
  final current = await const OperationDateService().current();
  return current.value == _formatLocalDate(date);
}

String _formatLocalDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

bool _isSameDate(DateTime first, DateTime second) =>
    first.year == second.year &&
    first.month == second.month &&
    first.day == second.day;

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
