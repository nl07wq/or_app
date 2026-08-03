import '../../../core/models/daily_log_confirmation.dart';
import '../models/daily_log_confirmation_lifecycle_projection.dart';
import '../models/persisted_daily_log_confirmation_record.dart';

abstract interface class DailyLogConfirmationStore {
  Future<void> save(DailyLogConfirmation confirmation);

  Future<DailyLogConfirmation?> findByLocalDate(String localDate);

  Future<DailyLogConfirmation?> findLatest();

  Future<List<DailyLogConfirmation>> findAll();

  Future<bool> isConfirmed(String localDate);

  Future<void> deleteByLocalDate(String localDate);

  Future<void> clear();
}

abstract interface class DailyLogConfirmationLifecycleStore {
  Future<void> createV2(PersistedDailyLogConfirmationRecord record);

  Future<PersistedDailyLogConfirmationRecord?> findPersistedByLocalDate(
    String localDate,
  );

  Future<List<PersistedDailyLogConfirmationRecord>> findAllPersisted();

  Future<DailyLogConfirmationLifecycleProjection> findLifecycleProjection(
    String localDate,
  );
}
