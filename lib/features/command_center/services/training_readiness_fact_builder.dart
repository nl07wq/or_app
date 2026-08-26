import '../../../core/models/operation_calendar_period.dart';
import '../../training/models/training_record_read_model.dart';
import '../models/daily_assessment.dart';

abstract final class TrainingReadinessFactBuilder {
  static TrainingReadinessFacts? build({
    required String operationDate,
    required DateTime currentTime,
    required Iterable<TrainingRecordReadModel> records,
  }) {
    final targetDate = DateTime.parse(operationDate);
    final eligible =
        records
            .where(
              (record) =>
                  record.strengthTrainingPerformed &&
                  !DateTime.parse(record.localDate).isAfter(targetDate),
            )
            .toList()
          ..sort(_compareRecords);
    if (eligible.isEmpty) return null;

    final last7Start = targetDate.subtract(const Duration(days: 6));
    final weekStart = OperationCalendarPeriod.week(targetDate).start;
    final latest = eligible.last;

    return TrainingReadinessFacts(
      lastTraining: _lastTrainingInterval(latest, currentTime, targetDate),
      last7DaysSessionCount: eligible.where((record) {
        final date = DateTime.parse(record.localDate);
        return !date.isBefore(last7Start) && !date.isAfter(targetDate);
      }).length,
      currentWeekSessionCount: eligible.where((record) {
        final date = DateTime.parse(record.localDate);
        return !date.isBefore(weekStart) && !date.isAfter(targetDate);
      }).length,
      consecutiveTrainingDays: _consecutiveDays(eligible),
      recentIntervals: _recentIntervals(eligible),
    );
  }

  static TrainingReadinessIntervalFact _lastTrainingInterval(
    TrainingRecordReadModel record,
    DateTime currentTime,
    DateTime targetDate,
  ) {
    final endTime = _endTime(record);
    if (endTime != null) {
      return TrainingReadinessIntervalFact.hours(
        currentTime.difference(endTime).inHours,
      );
    }
    return TrainingReadinessIntervalFact.calendarDays(
      targetDate.difference(DateTime.parse(record.localDate)).inDays,
    );
  }

  static List<TrainingReadinessIntervalFact> _recentIntervals(
    List<TrainingRecordReadModel> records,
  ) {
    final result = <TrainingReadinessIntervalFact>[];
    for (
      var index = records.length - 1;
      index > 0 && result.length < 3;
      index--
    ) {
      final current = records[index];
      final previous = records[index - 1];
      final currentStart = _startTime(current);
      final previousEnd = _endTime(previous);
      if (currentStart != null && previousEnd != null) {
        result.add(
          TrainingReadinessIntervalFact.hours(
            currentStart.difference(previousEnd).inHours,
          ),
        );
      } else {
        result.add(
          TrainingReadinessIntervalFact.calendarDays(
            DateTime.parse(
              current.localDate,
            ).difference(DateTime.parse(previous.localDate)).inDays,
          ),
        );
      }
    }
    return result;
  }

  static int _consecutiveDays(List<TrainingRecordReadModel> records) {
    final dates =
        records
            .map((record) => DateTime.parse(record.localDate))
            .toSet()
            .toList()
          ..sort();
    var count = 1;
    for (var index = dates.length - 1; index > 0; index--) {
      if (dates[index].difference(dates[index - 1]).inDays != 1) break;
      count++;
    }
    return count;
  }

  static int _compareRecords(
    TrainingRecordReadModel first,
    TrainingRecordReadModel second,
  ) {
    final dateOrder = first.localDate.compareTo(second.localDate);
    if (dateOrder != 0) return dateOrder;
    return _sortTime(first).compareTo(_sortTime(second));
  }

  static DateTime _sortTime(TrainingRecordReadModel record) =>
      _endTime(record) ?? _startTime(record) ?? record.sortDateTime;

  static DateTime? _startTime(TrainingRecordReadModel record) {
    final value = record.v2Data?.startTime;
    return value == null ? null : DateTime.parse(value);
  }

  static DateTime? _endTime(TrainingRecordReadModel record) {
    final value = record.v2Data?.endTime;
    return value == null ? null : DateTime.parse(value);
  }
}
