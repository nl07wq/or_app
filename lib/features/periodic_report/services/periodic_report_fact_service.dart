import '../../../core/models/operation_calendar_period.dart';
import '../../daily_aggregate/repository/daily_aggregate_repository.dart';
import '../../training/models/training_record_read_model.dart';
import '../../training/repository/training_session_repository.dart';
import '../models/periodic_report.dart';
import '../repository/periodic_report_repository.dart';

class IncompletePeriodicReportException implements Exception {
  const IncompletePeriodicReportException({
    required this.reportType,
    required this.periodEnd,
    required this.currentOperationDate,
  });

  final PeriodicReportType reportType;
  final DateTime periodEnd;
  final DateTime currentOperationDate;

  @override
  String toString() => 'Periodic report period has not completed.';
}

class PeriodicReportFactService {
  const PeriodicReportFactService({
    required this.dailyAggregates,
    required this.training,
    required this.reports,
  });

  static const theoreticalWeightKcalPerKg = 7700.0;

  final DailyAggregateRepository dailyAggregates;
  final TrainingSessionRepository training;
  final PeriodicReportRepository reports;

  Future<PeriodicReportFacts> generate({
    required PeriodicReportType reportType,
    required DateTime anchor,
    required DateTime currentOperationDate,
  }) async {
    final period = _period(reportType, anchor);
    if (!period.isCompleteAt(currentOperationDate)) {
      throw IncompletePeriodicReportException(
        reportType: reportType,
        periodEnd: period.end,
        currentOperationDate: currentOperationDate,
      );
    }
    final current = await _generate(period);
    final previous = await _generate(period.previous());
    return _withComparisons(current, previous);
  }

  Future<PeriodicReportFacts> _generate(OperationCalendarPeriod period) =>
      period.type == OperationCalendarPeriodType.yearly
      ? _fromMonthlyFacts(period)
      : _fromDailyFacts(period);

  Future<PeriodicReportFacts> _fromDailyFacts(
    OperationCalendarPeriod period,
  ) async {
    final start = _date(period.start);
    final end = _date(period.end);
    final daily = await dailyAggregates.getRange(start, end);
    final trainingRecords = (await training.findAllRecords())
        .where(
          (record) =>
              record.localDate.compareTo(start) >= 0 &&
              record.localDate.compareTo(end) <= 0,
        )
        .toList();
    final dates = daily.map((value) => value.operationDate).toSet();
    final missing = [
      for (
        var date = period.start;
        !date.isAfter(period.end);
        date = date.add(const Duration(days: 1))
      )
        if (!dates.contains(_date(date))) _date(date),
    ];
    final metrics = <String, PeriodicMetricFact>{};
    _add(
      metrics,
      'weightKg',
      _metric(
        daily.map((value) => value.weightKg),
        total: false,
        startEnd: true,
      ),
    );
    _add(
      metrics,
      'bodyFatPercent',
      _metric(daily.map((value) => value.bodyFatPercent), total: false),
    );
    _add(
      metrics,
      'intakeCaloriesKcal',
      _metric(daily.map((value) => value.intakeCaloriesKcal)),
    );
    _add(metrics, 'proteinG', _metric(daily.map((value) => value.proteinG)));
    _add(metrics, 'fatG', _metric(daily.map((value) => value.fatG)));
    _add(metrics, 'carbsG', _metric(daily.map((value) => value.carbsG)));
    _add(
      metrics,
      'hydrationMl',
      _metric(daily.map((value) => value.hydrationMl)),
    );
    _add(
      metrics,
      'calorieBalanceKcal',
      _metric(daily.map((value) => value.estimatedCalorieBalanceKcal)),
    );
    _add(
      metrics,
      'officialSteps',
      _metric(daily.map((value) => value.officialSteps?.toDouble())),
    );
    _add(
      metrics,
      'sleepDurationMinutes',
      _metric(
        daily.map((value) => value.sleepDurationMinutes?.toDouble()),
        total: false,
      ),
    );
    _add(
      metrics,
      'sleepScore',
      _metric(daily.map((value) => value.sleepScore?.toDouble()), total: false),
    );
    _add(
      metrics,
      'conditionLevel',
      _metric(
        daily.map((value) => value.plantarFasciitisLevel?.toDouble()),
        total: false,
      ),
    );
    final statusCounts = <String, int>{};
    for (final value in daily.map((item) => item.operationStatus)) {
      if (value == null) continue;
      statusCounts[value] = (statusCounts[value] ?? 0) + 1;
    }
    final trainingDates = trainingRecords
        .map((record) => record.localDate)
        .toSet();
    final exercises = <String>{};
    for (final record in trainingRecords) {
      exercises.addAll(_exerciseNames(record));
    }
    final balance = metrics['calorieBalanceKcal']?.total;
    final actual = metrics['weightKg']?.change;
    return PeriodicReportFacts(
      reportType: _reportType(period.type),
      periodId: period.id,
      startDate: start,
      endDate: end,
      expectedDailyCount: period.expectedDayCount,
      availableDailyCount: daily.length,
      missingDailyDates: missing,
      sourceMonthlyFactIds: const [],
      missingMonthlyFactIds: const [],
      metrics: metrics,
      previousPeriodComparisons: const {},
      operationStatusCounts: statusCounts,
      trainingSessionCount: trainingRecords.length,
      trainingDays: trainingDates.length,
      exercisesPerformed: exercises.toList()..sort(),
      theoreticalWeightChangeKg: balance == null
          ? null
          : balance / theoreticalWeightKcalPerKg,
      actualWeightChangeKg: actual,
    );
  }

  Future<PeriodicReportFacts> _fromMonthlyFacts(
    OperationCalendarPeriod period,
  ) async {
    final monthly = <PeriodicReportFacts>[];
    final sourceIds = <String>[];
    final missingIds = <String>[];
    for (var month = 1; month <= 12; month++) {
      final id =
          'monthly:${period.start.year.toString().padLeft(4, '0')}-'
          '${month.toString().padLeft(2, '0')}';
      final report = await reports.read(id);
      if (report == null) {
        missingIds.add(id);
      } else {
        sourceIds.add(id);
        monthly.add(report.facts);
      }
    }
    final metricNames = monthly.expand((value) => value.metrics.keys).toSet();
    final metrics = <String, PeriodicMetricFact>{};
    for (final name in metricNames) {
      final values = [
        for (final fact in monthly)
          if (fact.metrics[name] != null) fact.metrics[name]!,
      ];
      if (values.isNotEmpty) metrics[name] = _combine(values);
    }
    final statuses = <String, int>{};
    for (final facts in monthly) {
      for (final entry in facts.operationStatusCounts.entries) {
        statuses[entry.key] = (statuses[entry.key] ?? 0) + entry.value;
      }
    }
    final balance = metrics['calorieBalanceKcal']?.total;
    final actual = metrics['weightKg']?.change;
    return PeriodicReportFacts(
      reportType: PeriodicReportType.yearly,
      periodId: period.id,
      startDate: _date(period.start),
      endDate: _date(period.end),
      expectedDailyCount: period.expectedDayCount,
      availableDailyCount: monthly.fold(
        0,
        (sum, facts) => sum + facts.availableDailyCount,
      ),
      missingDailyDates: monthly.expand((value) => value.missingDailyDates),
      sourceMonthlyFactIds: sourceIds,
      missingMonthlyFactIds: missingIds,
      metrics: metrics,
      previousPeriodComparisons: const {},
      operationStatusCounts: statuses,
      trainingSessionCount: monthly.fold(
        0,
        (sum, facts) => sum + facts.trainingSessionCount,
      ),
      trainingDays: monthly.fold(0, (sum, facts) => sum + facts.trainingDays),
      exercisesPerformed:
          monthly.expand((value) => value.exercisesPerformed).toSet().toList()
            ..sort(),
      theoreticalWeightChangeKg: balance == null
          ? null
          : balance / theoreticalWeightKcalPerKg,
      actualWeightChangeKg: actual,
    );
  }

  PeriodicReportFacts _withComparisons(
    PeriodicReportFacts current,
    PeriodicReportFacts previous,
  ) {
    final comparisons = <String, PeriodicMetricComparison>{};
    for (final entry in current.metrics.entries) {
      final before = previous.metrics[entry.key];
      if (before == null) continue;
      final comparison = PeriodicMetricComparison(
        totalDelta: _delta(entry.value.total, before.total),
        averageDelta: _delta(entry.value.average, before.average),
        startDelta: _delta(entry.value.start, before.start),
        endDelta: _delta(entry.value.end, before.end),
        changeDelta: _delta(entry.value.change, before.change),
      );
      if (comparison.available) comparisons[entry.key] = comparison;
    }
    return PeriodicReportFacts(
      reportType: current.reportType,
      periodId: current.periodId,
      startDate: current.startDate,
      endDate: current.endDate,
      expectedDailyCount: current.expectedDailyCount,
      availableDailyCount: current.availableDailyCount,
      missingDailyDates: current.missingDailyDates,
      sourceMonthlyFactIds: current.sourceMonthlyFactIds,
      missingMonthlyFactIds: current.missingMonthlyFactIds,
      metrics: current.metrics,
      previousPeriodComparisons: comparisons,
      operationStatusCounts: current.operationStatusCounts,
      trainingSessionCount: current.trainingSessionCount,
      trainingDays: current.trainingDays,
      exercisesPerformed: current.exercisesPerformed,
      theoreticalWeightChangeKg: current.theoreticalWeightChangeKg,
      actualWeightChangeKg: current.actualWeightChangeKg,
    );
  }

  static PeriodicMetricFact _combine(List<PeriodicMetricFact> values) {
    final count = values.fold(0, (sum, value) => sum + value.sampleCount);
    final totalValues = values.map((value) => value.total).whereType<double>();
    final minimumValues = values
        .map((value) => value.minimum)
        .whereType<double>();
    final maximumValues = values
        .map((value) => value.maximum)
        .whereType<double>();
    final first = values.map((value) => value.start).whereType<double>();
    final last = values.reversed.map((value) => value.end).whereType<double>();
    final total = totalValues.isEmpty
        ? null
        : totalValues.reduce((a, b) => a + b);
    final weighted = values
        .where((value) => value.average != null && value.sampleCount > 0)
        .fold<double>(
          0,
          (sum, value) => sum + value.average! * value.sampleCount,
        );
    final average = count == 0 ? null : weighted / count;
    final start = first.isEmpty ? null : first.first;
    final end = last.isEmpty ? null : last.first;
    return PeriodicMetricFact(
      sampleCount: count,
      total: total,
      average: average,
      minimum: minimumValues.isEmpty ? null : minimumValues.reduce(_min),
      maximum: maximumValues.isEmpty ? null : maximumValues.reduce(_max),
      start: start,
      end: end,
      change: count < 2 || start == null || end == null ? null : end - start,
    );
  }

  static PeriodicMetricFact? _metric(
    Iterable<double?> source, {
    bool total = true,
    bool startEnd = false,
  }) {
    final values = source.whereType<double>().toList();
    if (values.isEmpty) return null;
    final sum = values.reduce((a, b) => a + b);
    return PeriodicMetricFact(
      sampleCount: values.length,
      total: total ? sum : null,
      average: sum / values.length,
      minimum: values.reduce(_min),
      maximum: values.reduce(_max),
      start: startEnd ? values.first : null,
      end: startEnd ? values.last : null,
      change: startEnd && values.length >= 2
          ? values.last - values.first
          : null,
    );
  }

  static void _add(
    Map<String, PeriodicMetricFact> values,
    String name,
    PeriodicMetricFact? fact,
  ) {
    if (fact != null) values[name] = fact;
  }

  static Iterable<String> _exerciseNames(TrainingRecordReadModel record) =>
      record.v2Data?.exercises.map((value) => value.exerciseName) ??
      record.v1Data!.exercises.map((value) => value.exerciseName);

  static OperationCalendarPeriod _period(
    PeriodicReportType type,
    DateTime anchor,
  ) => switch (type) {
    PeriodicReportType.weekly => OperationCalendarPeriod.week(anchor),
    PeriodicReportType.monthly => OperationCalendarPeriod.month(anchor),
    PeriodicReportType.yearly => OperationCalendarPeriod.year(anchor),
  };

  static PeriodicReportType _reportType(OperationCalendarPeriodType type) =>
      switch (type) {
        OperationCalendarPeriodType.weekly => PeriodicReportType.weekly,
        OperationCalendarPeriodType.monthly => PeriodicReportType.monthly,
        OperationCalendarPeriodType.yearly => PeriodicReportType.yearly,
      };

  static double? _delta(double? current, double? previous) =>
      current == null || previous == null ? null : current - previous;

  static double _min(double a, double b) => a < b ? a : b;
  static double _max(double a, double b) => a > b ? a : b;
  static String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}
