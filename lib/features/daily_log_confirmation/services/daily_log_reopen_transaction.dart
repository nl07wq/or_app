import '../../../data/indexed_db/indexed_db_database_contract.dart';
import '../../../data/indexed_db/indexed_db_store_names.dart';
import '../../import_export/services/backup_canonical_codec.dart';
import '../../operation_date/models/operation_local_date.dart';
import '../../operation_date/models/operation_state.dart';
import '../models/daily_log_confirmation_lifecycle.dart';
import '../models/daily_log_confirmation_lifecycle_projection.dart';
import '../models/persisted_daily_log_confirmation_record.dart';
import '../repository/daily_log_confirmation_repository.dart';
import 'daily_log_confirmation_lifecycle_error.dart';

class DailyLogReopenTransaction {
  final IndexedDbDatabase _database;
  final DailyLogConfirmationLifecycleStore _confirmations;

  const DailyLogReopenTransaction(this._database, this._confirmations);

  Future<PersistedDailyLogConfirmationRecord> reopen({
    required String localDate,
    required DateTime reopenedAt,
  }) {
    final target = OperationLocalDate.parse(localDate);
    final recordId = PersistedDailyLogConfirmationRecord.canonicalId(localDate);
    return _database.runTransaction<PersistedDailyLogConfirmationRecord>(
      storeNames: const [
        IndexedDbStoreNames.dailyLogConfirmations,
        IndexedDbStoreNames.operationState,
      ],
      mode: IndexedDbTransactionMode.readWrite,
      action: (transaction) async {
        final state = await _readOperationState(transaction, localDate);
        final stateBefore = BackupCanonicalCodec.encode(state.toRecord());
        if (state.phase != OperationPhase.open) {
          throw _error(
            DailyLogConfirmationLifecycleErrorCode.reopenOperationStateInvalid,
            'operationState',
            localDate,
            'Operation Stateがopenではありません。',
            store: IndexedDbStoreNames.operationState,
            recordId: OperationState.canonicalId,
          );
        }
        if (target.compareTo(state.operationDate) > 0) {
          throw _error(
            DailyLogConfirmationLifecycleErrorCode.reopenFutureDate,
            'validateTargetDate',
            localDate,
            'Current Operation Dateより後の日付は再編集できません。',
            recordId: recordId,
          );
        }

        final otherConfirmationsBefore = await _otherConfirmationsDigest(
          transaction,
          recordId,
        );
        final existingValue = await transaction.findById(
          IndexedDbStoreNames.dailyLogConfirmations,
          recordId,
        );
        if (existingValue == null) {
          throw _error(
            DailyLogConfirmationLifecycleErrorCode.reopenConfirmationMissing,
            'readConfirmation',
            localDate,
            '対象日のDaily Log Confirmationがありません。',
            store: IndexedDbStoreNames.dailyLogConfirmations,
            recordId: recordId,
          );
        }

        late final PersistedDailyLogConfirmationRecord existing;
        try {
          existing = PersistedDailyLogConfirmationRecord.fromRecord(
            existingValue,
          );
        } catch (error) {
          throw _error(
            DailyLogConfirmationLifecycleErrorCode.reopenSnapshotInvalid,
            'parseConfirmation',
            localDate,
            '対象日のConfirmation Snapshotが不正です。',
            store: IndexedDbStoreNames.dailyLogConfirmations,
            recordId: recordId,
            cause: error,
          );
        }
        final projection = DailyLogConfirmationLifecycleProjection.fromRecord(
          existing,
        );
        if (projection.isReopened) {
          throw _error(
            DailyLogConfirmationLifecycleErrorCode.reopenAlreadyReopened,
            'validateLifecycle',
            localDate,
            '対象日は既に再編集状態です。',
            recordId: recordId,
          );
        }
        if (!projection.isFinalized || !projection.isLocked) {
          throw _error(
            DailyLogConfirmationLifecycleErrorCode.reopenInvalidLifecycle,
            'validateLifecycle',
            localDate,
            '対象日のLifecycleは再編集へ移行できません。',
            recordId: recordId,
          );
        }

        late final PersistedDailyLogConfirmationRecord replacement;
        try {
          replacement = PersistedDailyLogConfirmationRecord.reopenedFrom(
            existing: existing,
            reopenedAt: reopenedAt,
          );
        } catch (error) {
          throw _error(
            DailyLogConfirmationLifecycleErrorCode.reopenSnapshotInvalid,
            'buildReopenedRecord',
            localDate,
            '再編集用Confirmationを安全に構築できません。',
            recordId: recordId,
            cause: error,
          );
        }

        late final PersistedDailyLogConfirmationRecord readBack;
        try {
          readBack = await _confirmations.updateLifecycleWithReadBack(
            transaction: transaction,
            id: recordId,
            expectedRevision: existing.projectedRevision,
            expectedLifecycle: DailyLogConfirmationLifecycleStatus.finalized,
            replacement: replacement,
          );
        } on DailyLogConfirmationLifecycleReadBackException catch (error) {
          throw _error(
            DailyLogConfirmationLifecycleErrorCode.reopenReadBackFailed,
            'readBackConfirmation',
            localDate,
            '再編集後のConfirmationを検証できません。',
            store: IndexedDbStoreNames.dailyLogConfirmations,
            recordId: recordId,
            cause: error,
          );
        } on DailyLogConfirmationLifecycleException {
          rethrow;
        } catch (error) {
          throw _error(
            DailyLogConfirmationLifecycleErrorCode.reopenWriteFailed,
            'writeConfirmation',
            localDate,
            '再編集状態を保存できません。',
            store: IndexedDbStoreNames.dailyLogConfirmations,
            recordId: recordId,
            cause: error,
          );
        }

        if (readBack.lifecycleStatus !=
                DailyLogConfirmationLifecycleStatus.reopened ||
            readBack.projectedRevision != existing.projectedRevision ||
            readBack.snapshotDigest != existing.projectedSnapshotDigest ||
            readBack.originalSnapshotDigest !=
                existing.projectedOriginalSnapshotDigest ||
            BackupCanonicalCodec.encode(readBack.data.toJson()) !=
                BackupCanonicalCodec.encode(existing.data.toJson()) ||
            !DailyLogConfirmationLifecycleProjection.fromRecord(
              readBack,
            ).isEditable) {
          throw _error(
            DailyLogConfirmationLifecycleErrorCode.reopenReadBackFailed,
            'verifyLifecycle',
            localDate,
            '再編集後のLifecycleまたはSnapshotが一致しません。',
            recordId: recordId,
          );
        }

        final stateAfter = await _readOperationState(transaction, localDate);
        if (BackupCanonicalCodec.encode(stateAfter.toRecord()) != stateBefore) {
          throw _error(
            DailyLogConfirmationLifecycleErrorCode.operationStateChanged,
            'verifyOperationState',
            localDate,
            'Operation Stateが再編集処理中に変更されました。',
            store: IndexedDbStoreNames.operationState,
            recordId: OperationState.canonicalId,
          );
        }
        if (await _otherConfirmationsDigest(transaction, recordId) !=
            otherConfirmationsBefore) {
          throw _error(
            DailyLogConfirmationLifecycleErrorCode.transactionAborted,
            'verifyOtherConfirmations',
            localDate,
            '対象日以外のConfirmationが変更されました。',
          );
        }
        return readBack;
      },
    );
  }

  Future<OperationState> _readOperationState(
    IndexedDbTransaction transaction,
    String localDate,
  ) async {
    try {
      final records = await transaction.findAll(
        IndexedDbStoreNames.operationState,
      );
      if (records.length != 1) {
        throw StateError('Operation State must contain exactly one record.');
      }
      return OperationState.fromRecord(records.single);
    } catch (error) {
      if (error is DailyLogConfirmationLifecycleException) rethrow;
      throw _error(
        DailyLogConfirmationLifecycleErrorCode.reopenOperationStateInvalid,
        'readOperationState',
        localDate,
        'Operation Stateを検証できません。',
        store: IndexedDbStoreNames.operationState,
        recordId: OperationState.canonicalId,
        cause: error,
      );
    }
  }

  Future<String> _otherConfirmationsDigest(
    IndexedDbTransaction transaction,
    String excludedId,
  ) async {
    final values = await transaction.findAll(
      IndexedDbStoreNames.dailyLogConfirmations,
    );
    final others =
        [
          for (final value in values)
            if (value['id'] != excludedId) value,
        ]..sort(
          (first, second) =>
              (first['id'] as String).compareTo(second['id'] as String),
        );
    return BackupCanonicalCodec.digest(others);
  }

  DailyLogConfirmationLifecycleException _error(
    DailyLogConfirmationLifecycleErrorCode code,
    String stage,
    String localDate,
    String message, {
    String? store,
    String? recordId,
    Object? cause,
  }) => DailyLogConfirmationLifecycleException(
    code: code,
    stage: stage,
    localDate: localDate,
    store: store,
    recordId: recordId,
    message: message,
    cause: cause,
  );
}
