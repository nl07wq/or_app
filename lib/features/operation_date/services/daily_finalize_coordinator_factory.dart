import '../../../core/services/daily_log_confirmation_service.dart';
import '../../../core/services/daily_state_restore_service.dart';
import '../../import_export/services/backup_export_service.dart';
import '../../repositories/app_repository_container.dart';
import 'daily_finalize_backup_verifier.dart';
import 'daily_finalize_coordinator.dart';
import 'daily_finalize_transaction.dart';

abstract final class DailyFinalizeCoordinatorFactory {
  static DailyFinalizeCoordinator production() {
    final container = AppRepositoryRegistry.container;
    return DailyFinalizeCoordinator(
      container.operationState,
      container.confirmation,
      DailyFinalizeTransaction(container.database),
      DailyFinalizeBackupVerifier(BackupExportService()),
      restoreNextDate: () => DailyStateRestoreService.restore(force: true),
      buildDailyConfirmation: (localDate, estimatedTotalBurnKcal) =>
          DailyLogConfirmationService.buildForLocalDate(
            localDate.value,
            estimatedTotalBurnKcal: estimatedTotalBurnKcal,
          ),
    );
  }
}
