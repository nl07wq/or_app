import '../../../core/models/daily_log_confirmation.dart';
import '../../../data/indexed_db/indexed_db_database_contract.dart';
import '../../../data/indexed_db/indexed_db_store_names.dart';
import '../../daily_log_confirmation/models/persisted_daily_log_confirmation_record.dart';
import '../../import_export/services/backup_canonical_codec.dart';
import '../models/operation_active_attempt.dart';
import '../models/daily_finalize_result.dart';
import '../models/operation_state.dart';
import '../repository/operation_state_repository.dart';

class DailyFinalizeTransaction {
  final IndexedDbDatabase _database;
  final DateTime Function() _now;

  DailyFinalizeTransaction(this._database, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  Future<OperationState> saveConfirmationAndMarkPending({
    required OperationState expectedState,
    required DailyLogConfirmation confirmation,
    required String confirmationDigest,
  }) async {
    try {
      return await _database.runTransaction<OperationState>(
        storeNames: const [
          IndexedDbStoreNames.dailyLogConfirmations,
          IndexedDbStoreNames.operationState,
        ],
        mode: IndexedDbTransactionMode.readWrite,
        action: (transaction) async {
          final current = await _readState(transaction);
          if (current.revision != expectedState.revision) {
            throw OperationStateRevisionConflictException(
              expectedRevision: expectedState.revision,
              actualRevision: current.revision,
            );
          }
          if (current.phase != OperationPhase.finalizing ||
              current.activeAttempt?.idempotencyKey !=
                  expectedState.activeAttempt?.idempotencyKey) {
            throw StateError(
              'Operation state is not the expected finalizing lock.',
            );
          }

          final localDate = current.operationDate.value;
          final id = PersistedDailyLogConfirmationRecord.canonicalId(localDate);
          final existingValue = await transaction.findById(
            IndexedDbStoreNames.dailyLogConfirmations,
            id,
          );
          if (existingValue != null) {
            final existing = PersistedDailyLogConfirmationRecord.fromRecord(
              existingValue,
            );
            if (_digest(existing.data) != confirmationDigest) {
              throw DailyFinalizeException(
                DailyFinalizeFailureCode.confirmationDigestMismatch,
                StateError('Existing confirmation has different content.'),
              );
            }
          } else {
            final timestamp = _now().toUtc();
            await transaction.put(
              IndexedDbStoreNames.dailyLogConfirmations,
              PersistedDailyLogConfirmationRecord.initialFinalizedV2(
                id: id,
                localDate: localDate,
                data: confirmation,
                timestamp: timestamp,
              ).toRecord(),
            );
          }

          final attempt = current.activeAttempt!;
          final next = current.copyWith(
            phase: OperationPhase.finalizedPendingBackup,
            revision: current.revision + 1,
            activeAttempt: OperationActiveAttempt(
              idempotencyKey: attempt.idempotencyKey,
              targetLocalDate: attempt.targetLocalDate,
              startedAt: attempt.startedAt,
              confirmationId: id,
              confirmationDigest: confirmationDigest,
            ),
            updatedAt: _nextTimestamp(current.updatedAt),
          );
          await transaction.put(
            IndexedDbStoreNames.operationState,
            next.toRecord(),
          );
          await _verifyConfirmation(transaction, id, confirmationDigest);
          final readBack = await _readState(transaction);
          if (!_recordsEqual(next.toRecord(), readBack.toRecord())) {
            throw StateError('Operation state read-back mismatch.');
          }
          return readBack;
        },
      );
    } on DailyFinalizeException {
      rethrow;
    } on OperationStateRevisionConflictException {
      rethrow;
    } catch (error) {
      throw DailyFinalizeException(
        DailyFinalizeFailureCode.confirmationWriteFailed,
        error,
      );
    }
  }

  Future<OperationState> _readState(IndexedDbTransaction transaction) async {
    final records = await transaction.findAll(
      IndexedDbStoreNames.operationState,
    );
    if (records.length != 1) {
      throw StateError('Operation state store must contain one record.');
    }
    return OperationState.fromRecord(records.single);
  }

  Future<void> _verifyConfirmation(
    IndexedDbTransaction transaction,
    String id,
    String digest,
  ) async {
    final value = await transaction.findById(
      IndexedDbStoreNames.dailyLogConfirmations,
      id,
    );
    if (value == null ||
        _digest(PersistedDailyLogConfirmationRecord.fromRecord(value).data) !=
            digest) {
      throw DailyFinalizeException(
        DailyFinalizeFailureCode.confirmationReadbackFailed,
        StateError('Confirmation read-back mismatch.'),
      );
    }
  }

  String _digest(DailyLogConfirmation value) =>
      BackupCanonicalCodec.digest(value.toJson());

  DateTime _nextTimestamp(DateTime current) {
    final now = _now().toUtc();
    return now.isAfter(current)
        ? now
        : current.add(const Duration(microseconds: 1));
  }

  bool _recordsEqual(Map<String, Object?> first, Map<String, Object?> second) =>
      BackupCanonicalCodec.encode(first) == BackupCanonicalCodec.encode(second);
}
