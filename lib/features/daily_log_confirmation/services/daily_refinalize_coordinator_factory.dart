import '../../../core/services/daily_log_confirmation_service.dart';
import '../../daily_aggregate/services/daily_aggregate_engine.dart';
import '../../command_center/services/daily_estimated_total_burn_service.dart';
import '../../repositories/app_repository_container.dart';
import '../repository/indexed_db_daily_log_confirmation_repository.dart';
import 'daily_log_confirmation_source_snapshot.dart';
import 'daily_log_refinalize_transaction.dart';
import 'daily_refinalize_coordinator.dart';

abstract final class DailyRefinalizeCoordinatorFactory {
  static DailyRefinalizeCoordinator production() {
    final container = AppRepositoryRegistry.container;
    final confirmations = IndexedDbDailyLogConfirmationRepository(
      container.database,
    );
    final sourceReader = DailyLogConfirmationSourceSnapshotReader(
      container.database,
    );
    final aggregateEngine = DailyAggregateEngine(
      statusRepository: container.status,
      readFood: container.foodMixedRead.readForLocalDate,
      activityRepository: container.activity,
      trainingRepository: container.training,
      dailyAggregateRepository: container.dailyAggregates,
    );
    final burnService = DailyEstimatedTotalBurnService(
      statusRepository: container.status,
      trainingRepository: container.training,
    );
    return DailyRefinalizeCoordinator(
      confirmations,
      sourceReader,
      DailyLogRefinalizeTransaction(
        container.database,
        confirmations,
        sourceReader,
        dailyAggregates: container.dailyAggregates,
      ),
      buildDailyConfirmation: (localDate, _, confirmedAt) async =>
          DailyLogConfirmationService.buildForLocalDate(
            localDate.value,
            estimatedTotalBurnKcal: await burnService.calculate(
              localDate.value,
            ),
            confirmedAt: confirmedAt,
          ),
      buildDailyAggregate: (localDate, estimatedExpenditureKcal) =>
          aggregateEngine.build(
            localDate,
            estimatedExpenditureKcal: estimatedExpenditureKcal,
          ),
    );
  }
}
