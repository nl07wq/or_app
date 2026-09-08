import '../../../core/models/morning_data.dart';
import '../../../core/models/work_type.dart';
import '../../body_history/services/body_history_source_resolver.dart';
import '../../daily_aggregate/services/daily_aggregate_engine.dart';
import '../../operation_date/models/operation_state.dart';
import '../../repositories/app_repository_container.dart';
import '../models/daily_assessment.dart';
import 'daily_estimated_total_burn_service.dart';
import 'daily_weight_reference_resolver.dart';
import 'training_readiness_fact_builder.dart';

class DailyAssessmentFactLoader {
  DailyAssessmentFactLoader(this.container, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final AppRepositoryContainer container;
  final DateTime Function() _clock;

  Future<DailyAssessmentFacts> load(OperationState state) async {
    final operationDate = state.operationDate;
    final weightStart = operationDate.addDays(-27).value;
    final currentStatus = await container.status.findByLocalDate(
      operationDate.value,
    );
    final previousFormalWeight = await _previousFormalValue(
      operationDate.value,
      (status) => status.weight,
    );
    final previousFormalBodyFat = await _previousFormalValue(
      operationDate.value,
      (status) => status.bodyFat,
    );
    final previousDayStatus = await container.status.findByLocalDate(
      operationDate.addDays(-1).value,
    );
    final bodyFatReference = await _bodyFatReference(
      operationDate: operationDate.value,
      statusExists: currentStatus != null,
      measuredToday: currentStatus?.bodyFat,
      previousDayBodyFat: previousDayStatus?.bodyFat,
      previousFormalBodyFat: previousFormalBodyFat,
    );
    final currentFood = await container.foodMixedRead.readForLocalDate(
      operationDate.value,
    );
    final currentAggregate =
        await DailyAggregateEngine(
          statusRepository: container.status,
          readFood: (_) async => currentFood,
          activityRepository: container.activity,
          trainingRepository: container.training,
          dailyAggregateRepository: container.dailyAggregates,
        ).build(
          operationDate.value,
          estimatedExpenditureKcal: await DailyEstimatedTotalBurnService(
            statusRepository: container.status,
            trainingRepository: container.training,
          ).calculate(operationDate.value),
        );
    final weightHistory = await BodyHistorySourceResolver(
      statusRepository: container.status,
      dailyAggregateRepository: container.dailyAggregates,
    ).resolve(startDate: weightStart, endDate: operationDate.value);
    final trainingRecords = await container.training.findAllRecords();
    final trainingReadiness = TrainingReadinessFactBuilder.build(
      operationDate: operationDate.value,
      currentTime: _clock(),
      records: trainingRecords,
    );
    final strengthTrainingPerformed = trainingRecords.any(
      (record) =>
          record.localDate == operationDate.value &&
          record.strengthTrainingPerformed,
    );
    final cardioPerformed = trainingRecords.any(
      (record) =>
          record.localDate == operationDate.value && record.cardioPerformed,
    );

    return DailyAssessmentFacts(
      operationDate: operationDate.value,
      currentStatus: currentStatus,
      currentCalorieBalanceKcal: currentAggregate.estimatedCalorieBalanceKcal,
      currentProteinG: currentAggregate.proteinG,
      currentHydrationMl: currentFood.any((record) => record.waterMl != null)
          ? currentAggregate.hydrationMl
          : null,
      currentOfficialSteps: currentAggregate.officialSteps,
      currentTrainingPerformed: currentAggregate.trainingPerformed == true,
      currentStrengthTrainingPerformed: strengthTrainingPerformed,
      currentCardioPerformed: cardioPerformed,
      weightHistory: weightHistory,
      currentWeightReference: currentStatus == null
          ? const DailyWeightReference.notAvailable()
          : DailyWeightReferenceResolver.resolve(
              operationDate: operationDate.value,
              measuredTodayKg: currentStatus.weight,
              history: weightHistory,
              previousFormalWeightKg: previousFormalWeight,
            ),
      currentBodyFatReference: bodyFatReference,
      previousFormalBodyFatPercent: previousFormalBodyFat,
      workDisplayValue: currentStatus == null
          ? null
          : currentStatus.workType == WorkType.holiday
          ? 'HOLIDAY'
          : '${currentStatus.workStart}–${currentStatus.workEnd}',
      trainingReadiness: trainingReadiness,
    );
  }

  Future<double?> _previousFormalValue(
    String operationDate,
    double? Function(MorningData status) select,
  ) async {
    final records =
        (await container.status.findAllCanonical()).values
            .where(
              (status) =>
                  status.date.compareTo(operationDate) < 0 &&
                  select(status) != null &&
                  select(status)!.isFinite &&
                  select(status)! > 0,
            )
            .toList()
          ..sort((first, second) => second.date.compareTo(first.date));
    return records.isEmpty ? null : select(records.first);
  }

  Future<DailyBodyFatReference> _bodyFatReference({
    required String operationDate,
    required bool statusExists,
    required double? measuredToday,
    required double? previousDayBodyFat,
    required double? previousFormalBodyFat,
  }) async {
    if (!statusExists) return const DailyBodyFatReference.notAvailable();
    final weeklyTrendPt = await _bodyFatWeeklyTrend();
    if (_validBodyFat(measuredToday)) {
      final recentAverage = await _recentBodyFatAverage(
        operationDate: operationDate,
        excludeOperationDate: true,
      );
      return DailyBodyFatReference(
        valuePercent: measuredToday,
        source: DailyBodyFatReferenceSource.measuredToday,
        sampleCount: 1,
        windowDays: 1,
        previousFormalBodyFatPercent: _validBodyFat(previousDayBodyFat)
            ? previousDayBodyFat
            : recentAverage?.value ?? previousFormalBodyFat,
        weeklyTrendPt: weeklyTrendPt,
      );
    }
    final average = await _recentBodyFatAverage(operationDate: operationDate);
    if (average == null) {
      return const DailyBodyFatReference.notAvailable(statusExists: true);
    }
    return DailyBodyFatReference(
      valuePercent: average.value,
      source: DailyBodyFatReferenceSource.sevenDayMean,
      sampleCount: average.sampleCount,
      windowDays: 7,
      previousFormalBodyFatPercent: _validBodyFat(previousDayBodyFat)
          ? previousDayBodyFat
          : previousFormalBodyFat,
      weeklyTrendPt: weeklyTrendPt,
    );
  }

  Future<({double value, int sampleCount})?> _recentBodyFatAverage({
    required String operationDate,
    bool excludeOperationDate = false,
  }) async {
    final target = DateTime.parse(operationDate);
    final start = DateTime(target.year, target.month, target.day - 6);
    final values = [
      for (final status in (await container.status.findAllCanonical()).values)
        if (DateTime.tryParse(status.date) case final DateTime date)
          if (!date.isBefore(start) && !date.isAfter(target))
            if (!excludeOperationDate || status.date != operationDate)
              if (_validBodyFat(status.bodyFat)) status.bodyFat!,
    ];
    if (values.length < 2) return null;
    return (
      value:
          values.fold<double>(0, (sum, value) => sum + value) / values.length,
      sampleCount: values.length,
    );
  }

  /// Mirrors the BODY weight trend structure: compare the mean of the latest
  /// seven formal observations with the preceding seven. A sparse Body Fat
  /// history can still use the WEEK AVERAGE fallback, but it must not claim a
  /// weekly rate without this full comparison basis.
  Future<double?> _bodyFatWeeklyTrend() async {
    final points = [
      for (final status in (await container.status.findAllCanonical()).values)
        if (DateTime.tryParse(status.date) != null)
          if (_validBodyFat(status.bodyFat))
            (date: status.date, value: status.bodyFat!),
    ]..sort((first, second) => first.date.compareTo(second.date));
    if (points.length < 14) return null;
    final recent = points.sublist(points.length - 14);
    final previousMean =
        recent.take(7).fold<double>(0, (sum, point) => sum + point.value) / 7;
    final currentMean =
        recent.skip(7).fold<double>(0, (sum, point) => sum + point.value) / 7;
    return double.parse((currentMean - previousMean).toStringAsFixed(6));
  }

  bool _validBodyFat(double? value) =>
      value != null && value.isFinite && value > 0;
}
