import '../../body_history/services/body_history_source_resolver.dart';
import '../../daily_aggregate/services/daily_aggregate_engine.dart';
import '../../operation_date/models/operation_state.dart';
import '../../repositories/app_repository_container.dart';
import '../models/daily_assessment.dart';
import 'daily_estimated_total_burn_service.dart';
import 'training_readiness_fact_builder.dart';

class DailyAssessmentFactLoader {
  DailyAssessmentFactLoader(this.container, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final AppRepositoryContainer container;
  final DateTime Function() _clock;

  Future<DailyAssessmentFacts> load(OperationState state) async {
    final operationDate = state.operationDate;
    final weightStart = operationDate.addDays(-13).value;
    final currentStatus = await container.status.findByLocalDate(
      operationDate.value,
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
    final trainingReadiness = TrainingReadinessFactBuilder.build(
      operationDate: operationDate.value,
      currentTime: _clock(),
      records: await container.training.findAllRecords(),
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
      weightHistory: weightHistory,
      trainingReadiness: trainingReadiness,
    );
  }
}
