import '../../../core/models/daily_log_confirmation.dart';
import '../../../data/indexed_db/indexed_db_database_contract.dart';
import '../../../data/indexed_db/indexed_db_store_names.dart';
import '../../daily_log_confirmation/models/persisted_daily_log_confirmation_record.dart';
import '../../daily_aggregate/models/daily_aggregate_v1.dart';
import '../../daily_aggregate/repository/indexed_db_daily_aggregate_repository.dart';
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

  Future<OperationState> savePreparedDailyClose({
    required OperationState expectedState,
    required DailyLogConfirmation confirmation,
    required String confirmationDigest,
    required DailyAggregateV1 dailyAggregate,
  }) async {
    try {
      return await _database.runTransaction<OperationState>(
        storeNames: const [
          IndexedDbStoreNames.dailyLogConfirmations,
          IndexedDbStoreNames.dailyAggregateRecords,
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
          if (dailyAggregate.operationDate != localDate ||
              dailyAggregate.sourceType != DailyAggregateSourceType.records) {
            throw StateError(
              'Daily Aggregate does not match the prepared date.',
            );
          }
          await IndexedDbDailyAggregateRepository(
            _database,
          ).putInTransaction(transaction, dailyAggregate);
          final next = current.copyWith(
            phase: OperationPhase.awaitingDebrief,
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

  Future<OperationState> advanceAndIssueUndoEntitlement({
    required OperationState expectedState,
  }) async {
    try {
      return await _database.runTransaction<OperationState>(
        storeNames: const [
          IndexedDbStoreNames.dailyLogConfirmations,
          IndexedDbStoreNames.dailyAggregateRecords,
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
          final attempt = current.activeAttempt;
          if (current.phase != OperationPhase.advancing ||
              attempt == null ||
              attempt.idempotencyKey !=
                  expectedState.activeAttempt?.idempotencyKey ||
              attempt.confirmationId == null ||
              attempt.confirmationDigest == null) {
            throw StateError(
              'Operation state is not the expected advancing lock.',
            );
          }

          await _verifyConfirmation(
            transaction,
            attempt.confirmationId!,
            attempt.confirmationDigest!,
          );
          final finalizedDate = current.operationDate;
          await _verifyAggregate(transaction, finalizedDate.value);
          final timestamp = _nextTimestamp(current.updatedAt);
          final next = OperationState(
            operationDate: finalizedDate.addDays(1),
            phase: OperationPhase.open,
            revision: current.revision + 1,
            lastFinalizedDate: finalizedDate,
            undoableFinalizeDate: finalizedDate,
            undoableFinalizeConfirmationId: attempt.confirmationId,
            undoableFinalizeCreatedAt: timestamp,
            activeAttempt: null,
            createdAt: current.createdAt,
            updatedAt: timestamp,
          );
          await transaction.put(
            IndexedDbStoreNames.operationState,
            next.toRecord(),
          );

          await _verifyConfirmation(
            transaction,
            attempt.confirmationId!,
            attempt.confirmationDigest!,
          );
          final readBack = await _readState(transaction);
          if (!_recordsEqual(next.toRecord(), readBack.toRecord())) {
            throw StateError('Operation state advance read-back mismatch.');
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
        DailyFinalizeFailureCode.advanceWriteFailed,
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

  Future<void> _verifyAggregate(
    IndexedDbTransaction transaction,
    String localDate,
  ) async {
    final value = await transaction.findById(
      IndexedDbStoreNames.dailyAggregateRecords,
      localDate,
    );
    if (value == null) {
      throw StateError('Daily Aggregate read-back is missing.');
    }
    final aggregate = DailyAggregateV1.fromJson(value);
    if (aggregate.operationDate != localDate ||
        aggregate.sourceType != DailyAggregateSourceType.records) {
      throw StateError('Daily Aggregate read-back is invalid.');
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
