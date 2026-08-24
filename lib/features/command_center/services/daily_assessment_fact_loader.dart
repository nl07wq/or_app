import '../../body_history/services/body_history_source_resolver.dart';
import '../../operation_date/models/operation_state.dart';
import '../../repositories/app_repository_container.dart';
import '../models/daily_assessment.dart';
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
    final previousDate = state.lastFinalizedDate;
    final previousAggregate = previousDate == null
        ? null
        : await container.dailyAggregates.getByDate(previousDate.value);
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
      previousFinalizedAggregate: previousAggregate,
      weightHistory: weightHistory,
      trainingReadiness: trainingReadiness,
    );
  }
}
