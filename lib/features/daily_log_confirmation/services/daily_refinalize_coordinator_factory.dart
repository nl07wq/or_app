import '../../../core/services/daily_log_confirmation_service.dart';
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
    return DailyRefinalizeCoordinator(
      confirmations,
      sourceReader,
      DailyLogRefinalizeTransaction(
        container.database,
        confirmations,
        sourceReader,
      ),
      buildDailyConfirmation:
          (localDate, estimatedTotalBurnKcal, confirmedAt) =>
              DailyLogConfirmationService.buildForLocalDate(
                localDate.value,
                estimatedTotalBurnKcal: estimatedTotalBurnKcal,
                confirmedAt: confirmedAt,
              ),
    );
  }
}
