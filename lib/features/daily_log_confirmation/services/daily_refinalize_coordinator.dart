import '../../../core/models/daily_log_confirmation.dart';
import '../../operation_date/models/operation_local_date.dart';
import '../../daily_aggregate/models/daily_aggregate_v1.dart';
import '../models/daily_log_confirmation_lifecycle.dart';
import '../models/persisted_daily_log_confirmation_record.dart';
import '../repository/daily_log_confirmation_repository.dart';
import 'daily_log_confirmation_lifecycle_error.dart';
import 'daily_log_confirmation_source_snapshot.dart';
import 'daily_log_refinalize_transaction.dart';

typedef BuildRefinalizedDailyConfirmation =
    Future<DailyLogConfirmation> Function(
      OperationLocalDate localDate,
      double? estimatedTotalBurnKcal,
      DateTime confirmedAt,
    );
typedef BuildRefinalizedDailyAggregate =
    Future<DailyAggregateV1> Function(
      String localDate,
      double? estimatedExpenditureKcal,
    );

class DailyRefinalizeCoordinator {
  static final Set<String> _activeDates = <String>{};

  final DailyLogConfirmationLifecycleStore _confirmations;
  final DailyLogConfirmationSourceSnapshotReader _sourceReader;
  final DailyLogRefinalizeTransaction _transaction;
  final BuildRefinalizedDailyConfirmation buildDailyConfirmation;
  final BuildRefinalizedDailyAggregate? buildDailyAggregate;
  final DateTime Function() _now;

  DailyRefinalizeCoordinator(
    this._confirmations,
    this._sourceReader,
    this._transaction, {
    required this.buildDailyConfirmation,
    this.buildDailyAggregate,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  Future<PersistedDailyLogConfirmationRecord> refinalize({
    required OperationLocalDate targetLocalDate,
    double? estimatedTotalBurnKcal,
  }) async {
    final localDate = targetLocalDate.value;
    if (!_activeDates.add(localDate)) {
      throw DailyLogConfirmationLifecycleException(
        code: DailyLogConfirmationLifecycleErrorCode.transactionAborted,
        stage: 'executionGuard',
        localDate: localDate,
        recordId: PersistedDailyLogConfirmationRecord.canonicalId(localDate),
        message: '同じ対象日の再確定処理が既に進行中です。',
      );
    }
    try {
      final now = _now();
      if (targetLocalDate.compareTo(OperationLocalDate.fromDateTime(now)) > 0) {
        throw DailyLogConfirmationLifecycleException(
          code: DailyLogConfirmationLifecycleErrorCode.refinalizeFutureDate,
          stage: 'validateCalendarDate',
          localDate: localDate,
          recordId: PersistedDailyLogConfirmationRecord.canonicalId(localDate),
          message: '未来日は再確定できません。',
        );
      }
      final existing = await _confirmations.findPersistedByLocalDate(localDate);
      if (existing == null) {
        throw DailyLogConfirmationLifecycleException(
          code: DailyLogConfirmationLifecycleErrorCode
              .refinalizeConfirmationMissing,
          stage: 'readConfirmation',
          localDate: localDate,
          recordId: PersistedDailyLogConfirmationRecord.canonicalId(localDate),
          message: '対象日のDaily Log Confirmationがありません。',
        );
      }
      if (existing.recordVersion !=
              PersistedDailyLogConfirmationRecord.currentRecordVersion ||
          existing.projectedLifecycleStatus !=
              DailyLogConfirmationLifecycleStatus.reopened) {
        throw DailyLogConfirmationLifecycleException(
          code: DailyLogConfirmationLifecycleErrorCode.refinalizeNotReopened,
          stage: 'validateLifecycle',
          localDate: localDate,
          recordId: existing.id,
          message: '対象日は再編集状態ではありません。',
        );
      }

      late final DailyLogConfirmationSourceSnapshot sourcesBefore;
      try {
        sourcesBefore = await _sourceReader.read(localDate);
      } catch (error) {
        throw DailyLogConfirmationLifecycleException(
          code: DailyLogConfirmationLifecycleErrorCode.refinalizeSourceInvalid,
          stage: 'readSourcesBeforeSnapshot',
          localDate: localDate,
          message: '対象日のSource Recordを検証できません。',
          cause: error,
        );
      }
      final timestamp = now.toUtc();
      late final DailyLogConfirmation snapshot;
      try {
        snapshot = await buildDailyConfirmation(
          targetLocalDate,
          estimatedTotalBurnKcal,
          timestamp,
        );
      } catch (error) {
        throw DailyLogConfirmationLifecycleException(
          code: DailyLogConfirmationLifecycleErrorCode.refinalizeSnapshotFailed,
          stage: 'buildSnapshot',
          localDate: localDate,
          message: '対象日のDaily Log Snapshotを再生成できません。',
          cause: error,
        );
      }

      late final DailyLogConfirmationSourceSnapshot sourcesAfter;
      try {
        sourcesAfter = await _sourceReader.read(localDate);
      } catch (error) {
        throw DailyLogConfirmationLifecycleException(
          code: DailyLogConfirmationLifecycleErrorCode.refinalizeSourceInvalid,
          stage: 'readSourcesAfterSnapshot',
          localDate: localDate,
          message: 'Snapshot生成後のSource Recordを検証できません。',
          cause: error,
        );
      }
      if (!sourcesBefore.hasSameContent(sourcesAfter)) {
        throw DailyLogConfirmationLifecycleException(
          code: DailyLogConfirmationLifecycleErrorCode.refinalizeSourceChanged,
          stage: 'compareSourcesAfterSnapshot',
          localDate: localDate,
          message: 'Snapshot生成中にSource Recordが変更されました。',
        );
      }

      final dailyAggregate = await buildDailyAggregate?.call(
        localDate,
        snapshot.estimatedTotalBurnKcal,
      );

      return await _transaction.refinalize(
        localDate: localDate,
        snapshot: snapshot,
        expectedSources: sourcesAfter,
        refinalizedAt: timestamp,
        dailyAggregate: dailyAggregate,
      );
    } on DailyLogConfirmationLifecycleException {
      rethrow;
    } catch (error) {
      throw DailyLogConfirmationLifecycleException(
        code: DailyLogConfirmationLifecycleErrorCode.transactionAborted,
        stage: 'refinalizeTransaction',
        localDate: localDate,
        recordId: PersistedDailyLogConfirmationRecord.canonicalId(localDate),
        message: '再確定Transactionを完了できません。',
        cause: error,
      );
    } finally {
      _activeDates.remove(localDate);
    }
  }
}
