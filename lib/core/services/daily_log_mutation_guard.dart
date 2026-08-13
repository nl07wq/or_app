import '../../features/daily_log_confirmation/models/daily_log_confirmation_lifecycle_projection.dart';
import '../../features/operation_date/models/operation_state.dart';
import '../../features/repositories/app_repository_container.dart';
import '../repositories/daily_log_confirmation_repository.dart';

class ConfirmedDailyLogException implements Exception {
  const ConfirmedDailyLogException();

  static const message = 'DAILY CLOSE IN PROGRESS';

  @override
  String toString() => message;
}

class DailyLogIntegrityException implements Exception {
  final Object cause;

  const DailyLogIntegrityException(this.cause);

  static const message = 'Daily Logの状態を確認できないため、記録を変更できません。';

  @override
  String toString() => '$message ($cause)';
}

class DailyLogMutationGuard {
  DailyLogMutationGuard._();

  static Future<DailyLogConfirmationLifecycleProjection> getLifecycleProjection(
    DateTime date,
  ) async {
    try {
      return await DailyLogConfirmationRepository.getLifecycleProjection(date);
    } catch (error) {
      throw DailyLogIntegrityException(error);
    }
  }

  static Future<bool> isDateLocked(DateTime date) async {
    if (!AppRepositoryRegistry.hasContainer) return false;
    final state = await AppRepositoryRegistry.container.operationState
        .requireCurrent();
    final localDate =
        '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
    return state.operationDate.value == localDate &&
        state.phase != OperationPhase.open &&
        state.phase != OperationPhase.awaitingDebrief;
  }

  static Future<bool> isDateConfirmed(DateTime date) => isDateLocked(date);

  static Future<void> assertDateEditable(DateTime date) async {
    if (await isDateLocked(date)) throw const ConfirmedDailyLogException();
  }

  static Future<void> assertDateMutable(DateTime date) =>
      assertDateEditable(date);
}
