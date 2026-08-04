import '../../repositories/app_repository_container.dart';
import '../../operation_date/models/operation_local_date.dart';
import '../models/persisted_daily_log_confirmation_record.dart';
import '../repository/indexed_db_daily_log_confirmation_repository.dart';
import 'daily_log_confirmation_lifecycle_error.dart';
import 'daily_log_reopen_transaction.dart';

class DailyLogReopenService {
  static final Set<String> _activeDates = <String>{};

  final DailyLogReopenTransaction _transaction;
  final DateTime Function() _now;

  DailyLogReopenService(this._transaction, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  factory DailyLogReopenService.production() {
    final container = AppRepositoryRegistry.container;
    return DailyLogReopenService(
      DailyLogReopenTransaction(
        container.database,
        IndexedDbDailyLogConfirmationRepository(container.database),
      ),
    );
  }

  Future<PersistedDailyLogConfirmationRecord> reopen(String localDate) async {
    PersistedDailyLogConfirmationRecord.validateLocalDate(localDate);
    if (!_activeDates.add(localDate)) {
      throw DailyLogConfirmationLifecycleException(
        code: DailyLogConfirmationLifecycleErrorCode.transactionAborted,
        stage: 'executionGuard',
        localDate: localDate,
        recordId: PersistedDailyLogConfirmationRecord.canonicalId(localDate),
        message: '同じ対象日の再編集処理が既に進行中です。',
      );
    }
    try {
      final now = _now();
      if (OperationLocalDate.parse(
            localDate,
          ).compareTo(OperationLocalDate.fromDateTime(now)) >
          0) {
        throw DailyLogConfirmationLifecycleException(
          code: DailyLogConfirmationLifecycleErrorCode.reopenFutureDate,
          stage: 'validateCalendarDate',
          localDate: localDate,
          recordId: PersistedDailyLogConfirmationRecord.canonicalId(localDate),
          message: '未来日は再編集できません。',
        );
      }
      return await _transaction.reopen(
        localDate: localDate,
        reopenedAt: now.toUtc(),
      );
    } on DailyLogConfirmationLifecycleException {
      rethrow;
    } catch (error) {
      throw DailyLogConfirmationLifecycleException(
        code: DailyLogConfirmationLifecycleErrorCode.transactionAborted,
        stage: 'reopenTransaction',
        localDate: localDate,
        recordId: PersistedDailyLogConfirmationRecord.canonicalId(localDate),
        message: '再編集Transactionを完了できません。',
        cause: error,
      );
    } finally {
      _activeDates.remove(localDate);
    }
  }
}
