import '../../../core/models/daily_log_confirmation.dart';
import '../../../data/indexed_db/indexed_db_database_contract.dart';
import '../../../data/indexed_db/indexed_db_store_names.dart';
import '../../import_export/services/backup_canonical_codec.dart';
import '../../operation_date/models/operation_local_date.dart';
import '../../operation_date/models/operation_state.dart';
import '../../daily_aggregate/models/daily_aggregate_v1.dart';
import '../../daily_aggregate/repository/daily_aggregate_repository.dart';
import '../models/daily_log_confirmation_lifecycle.dart';
import '../models/daily_log_confirmation_lifecycle_projection.dart';
import '../models/persisted_daily_log_confirmation_record.dart';
import '../repository/daily_log_confirmation_repository.dart';
import 'daily_log_confirmation_lifecycle_error.dart';
import 'daily_log_confirmation_source_snapshot.dart';

class DailyLogRefinalizeTransaction {
  final IndexedDbDatabase _database;
  final DailyLogConfirmationLifecycleStore _confirmations;
  final DailyLogConfirmationSourceSnapshotReader _sourceReader;
  final DailyAggregateRepository? _dailyAggregates;

  const DailyLogRefinalizeTransaction(
    this._database,
    this._confirmations,
    this._sourceReader, {
    DailyAggregateRepository? dailyAggregates,
  }) : _dailyAggregates = dailyAggregates;

  Future<PersistedDailyLogConfirmationRecord> refinalize({
    required String localDate,
    required DailyLogConfirmation snapshot,
    required DailyLogConfirmationSourceSnapshot expectedSources,
    required DateTime refinalizedAt,
    DailyAggregateV1? dailyAggregate,
  }) {
    final target = OperationLocalDate.parse(localDate);
    final recordId = PersistedDailyLogConfirmationRecord.canonicalId(localDate);
    return _database.runTransaction<PersistedDailyLogConfirmationRecord>(
      storeNames: [
        IndexedDbStoreNames.dailyLogConfirmations,
        IndexedDbStoreNames.operationState,
        if (dailyAggregate != null) IndexedDbStoreNames.dailyAggregateRecords,
        ...DailyLogConfirmationSourceSnapshotReader.stores,
      ],
      mode: IndexedDbTransactionMode.readWrite,
      action: (transaction) async {
        final state = await _readOperationState(transaction, localDate);
        final stateBefore = BackupCanonicalCodec.encode(state.toRecord());
        if (state.phase != OperationPhase.open) {
          throw _error(
            DailyLogConfirmationLifecycleErrorCode.transactionAborted,
            'operationState',
            localDate,
            'Operation Stateがopenではありません。',
            store: IndexedDbStoreNames.operationState,
            recordId: OperationState.canonicalId,
          );
        }
        if (target.compareTo(state.operationDate) > 0) {
          throw _error(
            DailyLogConfirmationLifecycleErrorCode.refinalizeFutureDate,
            'validateTargetDate',
            localDate,
            'Current Operation Dateより後の日付は再確定できません。',
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
            DailyLogConfirmationLifecycleErrorCode
                .refinalizeConfirmationMissing,
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
            DailyLogConfirmationLifecycleErrorCode.refinalizeNotReopened,
            'parseConfirmation',
            localDate,
            '対象日のConfirmationを検証できません。',
            recordId: recordId,
            cause: error,
          );
        }
        if (existing.recordVersion !=
                PersistedDailyLogConfirmationRecord.currentRecordVersion ||
            existing.lifecycleStatus !=
                DailyLogConfirmationLifecycleStatus.reopened) {
          throw _error(
            DailyLogConfirmationLifecycleErrorCode.refinalizeNotReopened,
            'validateLifecycle',
            localDate,
            '対象日は再編集状態ではありません。',
            recordId: recordId,
          );
        }
        if (PersistedDailyLogConfirmationRecord.localDateFromDate(
              snapshot.date,
            ) !=
            localDate) {
          throw _error(
            DailyLogConfirmationLifecycleErrorCode.refinalizeSnapshotFailed,
            'validateSnapshot',
            localDate,
            '再確定Snapshotの日付が対象日と一致しません。',
            recordId: recordId,
          );
        }

        late final DailyLogConfirmationSourceSnapshot transactionSources;
        try {
          transactionSources = await _sourceReader.readInTransaction(
            transaction,
            localDate,
          );
        } catch (error) {
          throw _error(
            DailyLogConfirmationLifecycleErrorCode.refinalizeSourceInvalid,
            'readSourcesInTransaction',
            localDate,
            '対象日のSource Recordを検証できません。',
            cause: error,
          );
        }
        if (!transactionSources.hasSameContent(expectedSources)) {
          throw _error(
            DailyLogConfirmationLifecycleErrorCode.refinalizeSourceChanged,
            'compareSourcesInTransaction',
            localDate,
            'Snapshot生成後にSource Recordが変更されました。',
          );
        }

        late final PersistedDailyLogConfirmationRecord replacement;
        try {
          replacement = PersistedDailyLogConfirmationRecord.refinalizedFrom(
            existing: existing,
            data: snapshot,
            sourceRecordVersions: transactionSources.sourceRecordVersions,
            refinalizedAt: refinalizedAt,
          );
        } catch (error) {
          throw _error(
            DailyLogConfirmationLifecycleErrorCode.refinalizeSnapshotFailed,
            'buildRefinalizedRecord',
            localDate,
            '再確定用Confirmationを構築できません。',
            recordId: recordId,
            cause: error,
          );
        }
        if (replacement.snapshotDigest !=
            PersistedDailyLogConfirmationRecord.digestSnapshot(snapshot)) {
          throw _error(
            DailyLogConfirmationLifecycleErrorCode.refinalizeDigestFailed,
            'verifyGeneratedDigest',
            localDate,
            '再確定Snapshot Digestが一致しません。',
            recordId: recordId,
          );
        }

        late final PersistedDailyLogConfirmationRecord readBack;
        try {
          readBack = await _confirmations.updateLifecycleWithReadBack(
            transaction: transaction,
            id: recordId,
            expectedRevision: existing.revision!,
            expectedLifecycle: DailyLogConfirmationLifecycleStatus.reopened,
            replacement: replacement,
          );
        } on DailyLogConfirmationLifecycleReadBackException catch (error) {
          throw _error(
            DailyLogConfirmationLifecycleErrorCode.refinalizeReadBackFailed,
            'readBackConfirmation',
            localDate,
            '再確定後のConfirmationを検証できません。',
            store: IndexedDbStoreNames.dailyLogConfirmations,
            recordId: recordId,
            cause: error,
          );
        } on DailyLogConfirmationLifecycleException {
          rethrow;
        } catch (error) {
          throw _error(
            DailyLogConfirmationLifecycleErrorCode.refinalizeWriteFailed,
            'writeConfirmation',
            localDate,
            '再確定後のConfirmationを保存できません。',
            store: IndexedDbStoreNames.dailyLogConfirmations,
            recordId: recordId,
            cause: error,
          );
        }

        final projection = DailyLogConfirmationLifecycleProjection.fromRecord(
          readBack,
        );
        if (!projection.isLocked ||
            readBack.lifecycleStatus !=
                DailyLogConfirmationLifecycleStatus.finalized ||
            readBack.revision != existing.revision! + 1 ||
            readBack.snapshotDigest != replacement.snapshotDigest ||
            readBack.originalSnapshotDigest !=
                existing.originalSnapshotDigest ||
            readBack.previousRevisions.length !=
                existing.previousRevisions.length + 1 ||
            BackupCanonicalCodec.encode(readBack.data.toJson()) !=
                BackupCanonicalCodec.encode(snapshot.toJson())) {
          throw _error(
            DailyLogConfirmationLifecycleErrorCode.refinalizeReadBackFailed,
            'verifyRefinalizedRecord',
            localDate,
            '再確定後のRevision、SnapshotまたはDigestが一致しません。',
            recordId: recordId,
          );
        }

        if (dailyAggregate != null) {
          final repository = _dailyAggregates;
          if (repository == null) {
            throw StateError('Daily Aggregate repository is required.');
          }
          await repository.putInTransaction(transaction, dailyAggregate);
        }

        final sourcesAfter = await _sourceReader.readInTransaction(
          transaction,
          localDate,
        );
        if (!sourcesAfter.hasSameContent(transactionSources)) {
          throw _error(
            DailyLogConfirmationLifecycleErrorCode.refinalizeSourceChanged,
            'verifySourcesAfterWrite',
            localDate,
            '再確定Transaction内でSource Recordが変更されました。',
          );
        }
        final stateAfter = await _readOperationState(transaction, localDate);
        if (BackupCanonicalCodec.encode(stateAfter.toRecord()) != stateBefore) {
          throw _error(
            DailyLogConfirmationLifecycleErrorCode.operationStateChanged,
            'verifyOperationState',
            localDate,
            'Operation Stateが再確定処理中に変更されました。',
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
        DailyLogConfirmationLifecycleErrorCode.transactionAborted,
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
