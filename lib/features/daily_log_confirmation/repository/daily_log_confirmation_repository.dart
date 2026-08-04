import '../../../core/models/daily_log_confirmation.dart';
import '../../../data/indexed_db/indexed_db_database_contract.dart';
import '../models/daily_log_confirmation_lifecycle.dart';
import '../models/daily_log_confirmation_lifecycle_projection.dart';
import '../models/persisted_daily_log_confirmation_record.dart';

class DailyLogConfirmationLifecycleReadBackException implements Exception {
  final String message;

  const DailyLogConfirmationLifecycleReadBackException(this.message);

  @override
  String toString() => message;
}

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

  Future<PersistedDailyLogConfirmationRecord> updateLifecycleWithReadBack({
    required IndexedDbTransaction transaction,
    required String id,
    required int expectedRevision,
    required DailyLogConfirmationLifecycleStatus expectedLifecycle,
    required PersistedDailyLogConfirmationRecord replacement,
  });
}
