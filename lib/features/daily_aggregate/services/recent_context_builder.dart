import '../../operation_date/models/operation_local_date.dart';
import '../models/daily_aggregate_v1.dart';
import '../models/recent_context.dart';
import '../repository/daily_aggregate_repository.dart';

enum RecentContextWindow { dailyBrief, dailyDebrief }

class RecentContextComparisonClassifier {
  const RecentContextComparisonClassifier._();

  static String weight(double current, double average) =>
      _percentage(current, average, major: 1.5, same: 0.5);

  static String bodyFat(double current, double average) =>
      _absolute(current, average, major: 1, same: 0.3);

  static String sleepDuration(double current, double average) =>
      _percentage(current, average, major: 20, same: 8);

  static String sleepScore(double current, double average) =>
      _absolute(current, average, major: 15, same: 5);

  static String footCondition(double current, double average) {
    final difference = current - average;
    if (difference >= 2) return '平均より明確に高い';
    if (difference >= 1) return '平均よりやや高い';
    if (difference > -1) return '同水準';
    if (difference > -2) return '平均よりやや低い';
    return '平均より明確に低い';
  }

  static String calories(double current, double average) =>
      _percentage(current, average, major: 15, same: 5);

  static String protein(double current, double average) =>
      _percentage(current, average, major: 20, same: 8);

  static String hydration(double current, double average) =>
      _percentage(current, average, major: 20, same: 8);

  static String officialSteps(double current, double average) =>
      _percentage(current, average, major: 25, same: 10);

  static String estimatedExpenditure(double current, double average) =>
      _percentage(current, average, major: 15, same: 5);

  static String estimatedCalorieBalance(double current, double average) =>
      _absolute(current, average, major: 400, same: 150);

  static String _percentage(
    double current,
    double average, {
    required double major,
    required double same,
  }) {
    final differencePercent = average == 0
        ? current == 0
              ? 0.0
              : current.isNegative
              ? double.negativeInfinity
              : double.infinity
        : (current - average) / average * 100;
    return _fiveLevels(
      differencePercent,
      lowerMajor: -major,
      lowerSame: -same,
      upperSame: same,
      upperMajor: major,
    );
  }

  static String _absolute(
    double current,
    double average, {
    required double major,
    required double same,
  }) => _fiveLevels(
    current - average,
    lowerMajor: -major,
    lowerSame: -same,
    upperSame: same,
    upperMajor: major,
  );

  static String _fiveLevels(
    double difference, {
    required double lowerMajor,
    required double lowerSame,
    required double upperSame,
    required double upperMajor,
  }) {
    if (difference <= lowerMajor) return '大きく下回る';
    if (difference < lowerSame) return '下回る';
    if (difference <= upperSame) return '同水準';
    if (difference < upperMajor) return '上回る';
    return '大きく上回る';
  }
}

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
    final currentRecord = window == RecentContextWindow.dailyDebrief
        ? records
              .where((record) => record.operationDate == targetDate)
              .firstOrNull
        : null;

    return RecentContext(
      windowStart: start.value,
      windowEnd: end.value,
      weightKg: _metric(
        records,
        (record) => record.weightKg,
        currentValue: currentRecord?.weightKg,
        classify: RecentContextComparisonClassifier.weight,
      ),
      bodyFatPercent: _metric(
        records,
        (record) => record.bodyFatPercent,
        currentValue: currentRecord?.bodyFatPercent,
        classify: RecentContextComparisonClassifier.bodyFat,
      ),
      sleepDurationMinutes: _metric(
        records,
        (record) => record.sleepDurationMinutes,
        currentValue: currentRecord?.sleepDurationMinutes,
        classify: RecentContextComparisonClassifier.sleepDuration,
      ),
      sleepScore: _metric(
        records,
        (record) => record.sleepScore,
        currentValue: currentRecord?.sleepScore,
        classify: RecentContextComparisonClassifier.sleepScore,
      ),
      plantarFasciitisLevel: _metric(
        records,
        (record) => record.plantarFasciitisLevel,
        currentValue: currentRecord?.plantarFasciitisLevel,
        classify: RecentContextComparisonClassifier.footCondition,
      ),
      intakeCaloriesKcal: _metric(
        records,
        (record) => record.intakeCaloriesKcal,
        currentValue: currentRecord?.intakeCaloriesKcal,
        classify: RecentContextComparisonClassifier.calories,
      ),
      proteinG: _metric(
        records,
        (record) => record.proteinG,
        currentValue: currentRecord?.proteinG,
        classify: RecentContextComparisonClassifier.protein,
      ),
      estimatedExpenditureKcal: _metric(
        records,
        (record) => record.estimatedExpenditureKcal,
        currentValue: currentRecord?.estimatedExpenditureKcal,
        classify: RecentContextComparisonClassifier.estimatedExpenditure,
      ),
      estimatedCalorieBalanceKcal: _metric(
        records,
        (record) => record.estimatedCalorieBalanceKcal,
        currentValue: currentRecord?.estimatedCalorieBalanceKcal,
        classify: RecentContextComparisonClassifier.estimatedCalorieBalance,
      ),
      hydrationMl: _metric(
        records,
        (record) => record.hydrationMl,
        currentValue: currentRecord?.hydrationMl,
        classify: RecentContextComparisonClassifier.hydration,
      ),
      officialSteps: _metric(
        records,
        (record) => record.officialSteps,
        currentValue: currentRecord?.officialSteps,
        classify: RecentContextComparisonClassifier.officialSteps,
      ),
    );
  }

  static RecentContextMetric _metric(
    List<DailyAggregateV1> records,
    num? Function(DailyAggregateV1 record) select, {
    num? currentValue,
    String Function(double current, double average)? classify,
  }) {
    final values = [for (final record in records) ?select(record)];
    if (values.isEmpty) {
      return const RecentContextMetric(
        average: null,
        start: null,
        end: null,
        validCount: 0,
        comparisonLevel: null,
      );
    }
    final average =
        values.fold<double>(0, (sum, value) => sum + value) / values.length;
    return RecentContextMetric(
      average: average,
      start: values.first,
      end: values.last,
      validCount: values.length,
      comparisonLevel: currentValue == null || classify == null
          ? null
          : classify(currentValue.toDouble(), average),
    );
  }
}
