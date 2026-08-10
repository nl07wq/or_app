import '../../../core/services/daily_log_confirmation_service.dart';
import '../../../core/services/daily_state_restore_service.dart';
import '../../import_export/services/backup_export_service.dart';
import '../../daily_aggregate/services/daily_aggregate_engine.dart';
import '../../command_center/services/daily_estimated_total_burn_service.dart';
import '../../repositories/app_repository_container.dart';
import 'daily_finalize_backup_verifier.dart';
import 'daily_finalize_coordinator.dart';
import 'daily_finalize_transaction.dart';

abstract final class DailyFinalizeCoordinatorFactory {
  static DailyFinalizeCoordinator production() {
    final container = AppRepositoryRegistry.container;
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
    return DailyFinalizeCoordinator(
      container.operationState,
      container.confirmation,
      DailyFinalizeTransaction(container.database),
      DailyFinalizeBackupVerifier(BackupExportService()),
      restoreNextDate: () => DailyStateRestoreService.restore(force: true),
      buildDailyConfirmation: (localDate, _) async =>
          DailyLogConfirmationService.buildForLocalDate(
            localDate.value,
            estimatedTotalBurnKcal: await burnService.calculate(
              localDate.value,
            ),
          ),
      buildDailyAggregate: (date, estimatedExpenditureKcal) => aggregateEngine
          .build(date, estimatedExpenditureKcal: estimatedExpenditureKcal),
    );
  }
}
