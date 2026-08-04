import '../repositories/daily_log_confirmation_repository.dart';
import '../../features/daily_log_confirmation/models/daily_log_confirmation_lifecycle_projection.dart';

class ConfirmedDailyLogException implements Exception {
  const ConfirmedDailyLogException();

  static const message = 'この日のログは確認済みです。修正する場合は訂正手続きを開始してください。';

  @override
  String toString() => message;
}

class DailyLogIntegrityException implements Exception {
  final Object cause;

  const DailyLogIntegrityException(this.cause);

  static const message = 'この日の確定状態を確認できないため、記録を変更できません。';

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

  static Future<bool> isDateLocked(DateTime date) async =>
      (await getLifecycleProjection(date)).isLocked;

  static Future<bool> isDateConfirmed(DateTime date) => isDateLocked(date);

  static Future<void> assertDateEditable(DateTime date) async {
    if (await isDateLocked(date)) throw const ConfirmedDailyLogException();
  }

  static Future<void> assertDateMutable(DateTime date) =>
      assertDateEditable(date);
}
