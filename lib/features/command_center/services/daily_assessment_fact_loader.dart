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
}
