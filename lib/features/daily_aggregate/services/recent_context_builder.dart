import '../../operation_date/models/operation_local_date.dart';
import '../models/daily_aggregate_v1.dart';
import '../models/recent_context.dart';
import '../repository/daily_aggregate_repository.dart';

enum RecentContextWindow { dailyBrief, dailyDebrief }

class RecentContextBuilder {
  final DailyAggregateRepository _repository;

  const RecentContextBuilder(this._repository);

  Future<RecentContext> build({
    required String targetDate,
    required RecentContextWindow window,
  }) async {
    final target = OperationLocalDate.parse(targetDate);
    final (start, end) = switch (window) {
      RecentContextWindow.dailyBrief => (
        target.addDays(-7),
        target.addDays(-1),
      ),
      RecentContextWindow.dailyDebrief => (target.addDays(-6), target),
    };
    final records =
        (await _repository.getRange(start.value, end.value))
            .where(
              (record) =>
                  record.sourceType == DailyAggregateSourceType.records &&
                  record.operationDate.compareTo(start.value) >= 0 &&
                  record.operationDate.compareTo(end.value) <= 0,
            )
            .toList()
          ..sort((a, b) => a.operationDate.compareTo(b.operationDate));

    return RecentContext(
      windowStart: start.value,
      windowEnd: end.value,
      weightKg: _metric(records, (record) => record.weightKg),
      bodyFatPercent: _metric(records, (record) => record.bodyFatPercent),
      sleepDurationMinutes: _metric(
        records,
        (record) => record.sleepDurationMinutes,
      ),
      sleepScore: _metric(records, (record) => record.sleepScore),
      plantarFasciitisLevel: _metric(
        records,
        (record) => record.plantarFasciitisLevel,
      ),
      intakeCaloriesKcal: _metric(
        records,
        (record) => record.intakeCaloriesKcal,
      ),
      proteinG: _metric(records, (record) => record.proteinG),
      estimatedExpenditureKcal: _metric(
        records,
        (record) => record.estimatedExpenditureKcal,
      ),
      estimatedCalorieBalanceKcal: _metric(
        records,
        (record) => record.estimatedCalorieBalanceKcal,
      ),
      hydrationMl: _metric(records, (record) => record.hydrationMl),
      officialSteps: _metric(records, (record) => record.officialSteps),
    );
  }

  static RecentContextMetric _metric(
    List<DailyAggregateV1> records,
    num? Function(DailyAggregateV1 record) select,
  ) {
    final values = [for (final record in records) ?select(record)];
    if (values.isEmpty) {
      return const RecentContextMetric(
        average: null,
        start: null,
        end: null,
        validCount: 0,
      );
    }
    return RecentContextMetric(
      average:
          values.fold<double>(0, (sum, value) => sum + value) / values.length,
      start: values.first,
      end: values.last,
      validCount: values.length,
    );
  }
}
