import '../repositories/daily_log_confirmation_repository.dart';

class ConfirmedDailyLogException implements Exception {
  const ConfirmedDailyLogException();

  static const message = 'この日のログは確認済みです。修正する場合は訂正手続きを開始してください。';

  @override
  String toString() => message;
}

class DailyLogMutationGuard {
  DailyLogMutationGuard._();

  static Future<bool> isDateConfirmed(DateTime date) async =>
      await DailyLogConfirmationRepository.findByDate(date) != null;

  static Future<void> assertDateMutable(DateTime date) async {
    if (await isDateConfirmed(date)) throw const ConfirmedDailyLogException();
  }
}
