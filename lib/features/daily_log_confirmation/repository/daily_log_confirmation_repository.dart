import '../../../core/models/daily_log_confirmation.dart';

abstract interface class DailyLogConfirmationStore {
  Future<void> save(DailyLogConfirmation confirmation);

  Future<DailyLogConfirmation?> findByLocalDate(String localDate);

  Future<DailyLogConfirmation?> findLatest();

  Future<List<DailyLogConfirmation>> findAll();

  Future<bool> isConfirmed(String localDate);

  Future<void> deleteByLocalDate(String localDate);

  Future<void> clear();
}
