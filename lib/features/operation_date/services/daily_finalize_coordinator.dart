import '../../../core/models/daily_log_confirmation.dart';
import '../../daily_aggregate/models/daily_aggregate_v1.dart';
import '../../daily_log_confirmation/repository/daily_log_confirmation_repository.dart';
import '../models/daily_finalize_result.dart';
import '../models/operation_active_attempt.dart';
import '../models/operation_local_date.dart';
import '../models/operation_state.dart';
import '../repository/operation_state_repository.dart';
import 'daily_finalize_backup_verifier.dart';
import 'daily_finalize_integrity_service.dart';
import 'daily_finalize_transaction.dart';

typedef BuildDailyConfirmation =
    Future<DailyLogConfirmation> Function(
      OperationLocalDate localDate,
      double? estimatedTotalBurnKcal,
    );
typedef BuildDailyAggregate =
    Future<DailyAggregateV1> Function(
      String date,
      double? estimatedExpenditureKcal,
    );
typedef ReadDailyAggregate = Future<DailyAggregateV1?> Function(String date);
typedef SaveDailyAggregate =
    Future<DailyAggregateV1> Function(DailyAggregateV1 aggregate);
typedef ValidatePreparedDailyDebrief = Future<void> Function(String date);

class DailyFinalizeCoordinator {
  static final Set<String> _activeKeys = <String>{};

  final OperationStateRepository _operationState;
  final DailyLogConfirmationStore _confirmations;
  final DailyFinalizeTransaction _transaction;
  final DailyFinalizeBackupVerifier _backupVerifier;
  final DailyFinalizeIntegrityService _integrity;
  final Future<void> Function() restoreNextDate;
  final BuildDailyConfirmation buildDailyConfirmation;
  final BuildDailyAggregate buildDailyAggregate;
  final ReadDailyAggregate readDailyAggregate;
  final SaveDailyAggregate saveDailyAggregate;
  final ValidatePreparedDailyDebrief validatePreparedDailyDebrief;
  final DateTime Function() _now;

  DailyFinalizeCoordinator(
    this._operationState,
    this._confirmations,
    this._transaction,
    this._backupVerifier, {
    DailyFinalizeIntegrityService? integrity,
    required this.restoreNextDate,
    required this.buildDailyConfirmation,
    required this.buildDailyAggregate,
    required this.readDailyAggregate,
    required this.saveDailyAggregate,
    required this.validatePreparedDailyDebrief,
    DateTime Function()? now,
  }) : _integrity =
           integrity ??
           DailyFinalizeIntegrityService(_operationState, _confirmations),
       _now = now ?? DateTime.now;

  Future<DailyClosePreparationResult> prepareDailyDebrief({
    required OperationLocalDate targetLocalDate,
    double? estimatedTotalBurnKcal,
  }) async {
    return _runOnce('daily-close-prepare:${targetLocalDate.value}', () async {
      var state = await _operationState.requireCurrent();
      if (state.operationDate != targetLocalDate) {
        throw DailyFinalizeException(
          DailyFinalizeFailureCode.validationFailed,
          StateError('Historical dates cannot be prepared for daily close.'),
        );
      }
      if (state.phase == OperationPhase.awaitingDebrief) {
        _verifyAttemptKey(state);
        final preparedConfirmation = await _buildConfirmation(
          targetLocalDate,
          estimatedTotalBurnKcal,
        );
        final startedAt = _now().toUtc();
        try {
          state = await _operationState.compareAndSaveRevision(
            state.copyWith(
              phase: OperationPhase.finalizing,
              activeAttempt: OperationActiveAttempt(
                idempotencyKey: 'daily-finalize:${targetLocalDate.value}',
                targetLocalDate: targetLocalDate,
                startedAt: startedAt,
              ),
              updatedAt: startedAt,
            ),
            expectedRevision: state.revision,
          );
        } on Object catch (error) {
          throw DailyFinalizeException(
            DailyFinalizeFailureCode.stateConflict,
            error,
          );
        }
        return _resumePreparation(
          state,
          estimatedTotalBurnKcal,
          preparedConfirmation: preparedConfirmation,
        );
      }
      if (state.phase != OperationPhase.open &&
          state.phase != OperationPhase.finalizing) {
        throw DailyFinalizeException(
          DailyFinalizeFailureCode.stateConflict,
          StateError('Daily close cannot be prepared in ${state.phase.name}.'),
        );
      }

      DailyLogConfirmation? preparedConfirmation;
      if (state.phase == OperationPhase.open) {
        preparedConfirmation = await _buildConfirmation(
          targetLocalDate,
          estimatedTotalBurnKcal,
        );
        final startedAt = _now().toUtc();
        final attempt = OperationActiveAttempt(
          idempotencyKey: 'daily-finalize:${targetLocalDate.value}',
          targetLocalDate: targetLocalDate,
          startedAt: startedAt,
        );
        try {
          state = await _operationState.compareAndSaveRevision(
            state.copyWith(
              phase: OperationPhase.finalizing,
              activeAttempt: attempt,
              updatedAt: startedAt,
            ),
            expectedRevision: state.revision,
          );
        } on Object catch (error) {
          throw DailyFinalizeException(
            DailyFinalizeFailureCode.stateConflict,
            error,
          );
        }
      }
      _verifyAttemptKey(state);
      return _resumePreparation(
        state,
        estimatedTotalBurnKcal,
        preparedConfirmation: preparedConfirmation,
      );
    });
  }

  Future<DailyFinalizeResult> finalize({
    required OperationLocalDate targetLocalDate,
  }) async {
    return _runOnce('daily-finalize:${targetLocalDate.value}', () async {
      var state = await _operationState.requireCurrent();
      if (state.operationDate != targetLocalDate ||
          state.phase != OperationPhase.awaitingDebrief) {
        throw DailyFinalizeException(
          DailyFinalizeFailureCode.validationFailed,
          StateError('Daily close is not awaiting a debrief.'),
        );
      }
      _verifyAttemptKey(state);
      await validateAwaitingState(state);
      await validateCurrentSourceSnapshot(state);
      await validatePreparedDailyDebrief(targetLocalDate.value);

      try {
        final backup = await _backupVerifier.generateAndVerify();
        state = await _markAdvancing(state, backup);
        return await _advance(state);
      } catch (error) {
        await _integrity.recordFailure(state, _integrity.failureCode(error));
        if (error is DailyFinalizeException) rethrow;
        throw DailyFinalizeException(_integrity.failureCode(error), error);
      }
    });
  }

  Future<DailyFinalizeResult?> recover() async {
    var state = await _operationState.requireCurrent();
    if (state.phase == OperationPhase.open) {
      throw StateError('No daily finalize recovery is required.');
    }
    if (state.phase == OperationPhase.awaitingDebrief) {
      await validateAwaitingState(state);
      return null;
    }
    _verifyAttemptKey(state);
    if (state.phase == OperationPhase.finalizing) {
      await _resumePreparation(state, null);
      return null;
    }

    try {
      if (state.phase == OperationPhase.finalizedPendingBackup) {
        await _ensureLegacyAggregate(state);
        final backup = await _backupVerifier.generateAndVerify();
        state = await _markAdvancing(state, backup);
      }
      if (state.phase != OperationPhase.advancing) {
        throw StateError('Unsupported daily finalize recovery phase.');
      }
      await _ensureLegacyAggregate(state);
      return await _advance(state);
    } catch (error) {
      await _integrity.recordFailure(state, _integrity.failureCode(error));
      if (error is DailyFinalizeException) rethrow;
      throw DailyFinalizeException(_integrity.failureCode(error), error);
    }
  }

  Future<void> validateAwaitingState([OperationState? value]) async {
    final state = value ?? await _operationState.requireCurrent();
    if (state.phase != OperationPhase.awaitingDebrief) {
      throw StateError('Operation is not awaiting a daily debrief.');
    }
    _verifyAttemptKey(state);
    await _integrity.verifyStoredConfirmation(state);
    final aggregate = await readDailyAggregate(state.operationDate.value);
    if (aggregate == null ||
        aggregate.operationDate != state.operationDate.value ||
        aggregate.sourceType != DailyAggregateSourceType.records) {
      throw StateError('Prepared Daily Aggregate is missing or invalid.');
    }
  }

  Future<void> validateCurrentSourceSnapshot([OperationState? value]) async {
    final state = value ?? await _operationState.requireCurrent();
    if (state.phase != OperationPhase.awaitingDebrief) {
      throw StateError('Operation is not awaiting a daily debrief.');
    }
    _verifyAttemptKey(state);
    final stored = await _confirmations.findByLocalDate(
      state.operationDate.value,
    );
    if (stored == null) {
      throw StateError('Prepared confirmation is missing.');
    }
    final current = await _buildConfirmation(
      state.operationDate,
      stored.estimatedTotalBurnKcal,
    );
    final comparable = current.copyWith(confirmedAt: stored.confirmedAt);
    if (_integrity.confirmationDigest(comparable) !=
        state.activeAttempt!.confirmationDigest) {
      throw StateError(
        'Current Daily Log source changed. Re-create DAILY DEBRIEF.',
      );
    }
  }

  Future<DailyClosePreparationResult> _resumePreparation(
    OperationState state,
    double? estimatedTotalBurnKcal, {
    DailyLogConfirmation? preparedConfirmation,
  }) async {
    try {
      final confirmation =
          preparedConfirmation ??
          await _buildConfirmation(state.operationDate, estimatedTotalBurnKcal);
      final aggregate = await buildDailyAggregate(
        state.operationDate.value,
        confirmation.estimatedTotalBurnKcal,
      );
      final digest = _integrity.confirmationDigest(confirmation);
      final awaiting = await _transaction.savePreparedDailyClose(
        expectedState: state,
        confirmation: confirmation,
        confirmationDigest: digest,
        dailyAggregate: aggregate,
      );
      await validateAwaitingState(awaiting);
      return _preparationResult(awaiting);
    } catch (error) {
      await _integrity.recordFailure(state, _integrity.failureCode(error));
      if (error is DailyFinalizeException) rethrow;
      throw DailyFinalizeException(_integrity.failureCode(error), error);
    }
  }

  Future<OperationState> _markAdvancing(
    OperationState state,
    VerifiedFinalizeBackup backup,
  ) {
    final attempt = state.activeAttempt!;
    return _integrity.saveState(
      state,
      state.copyWith(
        phase: OperationPhase.advancing,
        activeAttempt: OperationActiveAttempt(
          idempotencyKey: attempt.idempotencyKey,
          targetLocalDate: attempt.targetLocalDate,
          startedAt: attempt.startedAt,
          confirmationId: attempt.confirmationId,
          confirmationDigest: attempt.confirmationDigest,
          backupPackageDigest: backup.packageDigest,
          backupGeneratedAt: backup.generatedAt,
        ),
      ),
    );
  }

  Future<DailyFinalizeResult> _advance(OperationState state) async {
    await _integrity.verifyStoredConfirmation(state);
    final finalizedDate = state.operationDate;
    final attempt = state.activeAttempt!;
    final nextDate = finalizedDate.addDays(1);
    final advanced = await _transaction.advanceAndIssueUndoEntitlement(
      expectedState: state,
    );
    if (advanced.operationDate != nextDate ||
        advanced.phase != OperationPhase.open ||
        advanced.lastFinalizedDate != finalizedDate ||
        advanced.undoableFinalizeDate != finalizedDate ||
        advanced.undoableFinalizeConfirmationId != attempt.confirmationId) {
      throw StateError('Operation date advance read-back mismatch.');
    }
    await _integrity.verifyConfirmation(
      finalizedDate,
      attempt.confirmationId!,
      attempt.confirmationDigest!,
    );
    await restoreNextDate();
    return DailyFinalizeResult(
      finalizedDate: finalizedDate,
      nextOperationDate: nextDate,
      confirmationId: attempt.confirmationId!,
      confirmationDigest: attempt.confirmationDigest!,
      backupPackageDigest: attempt.backupPackageDigest!,
    );
  }

  Future<void> _ensureLegacyAggregate(OperationState state) async {
    final existing = await readDailyAggregate(state.operationDate.value);
    if (existing != null) return;
    await _integrity.verifyStoredConfirmation(state);
    final confirmation = await _confirmations.findByLocalDate(
      state.operationDate.value,
    );
    final aggregate = await buildDailyAggregate(
      state.operationDate.value,
      confirmation?.estimatedTotalBurnKcal,
    );
    await saveDailyAggregate(aggregate);
  }

  DailyClosePreparationResult _preparationResult(OperationState state) {
    final attempt = state.activeAttempt!;
    return DailyClosePreparationResult(
      operationDate: state.operationDate,
      confirmationId: attempt.confirmationId!,
      confirmationDigest: attempt.confirmationDigest!,
    );
  }

  void _verifyAttemptKey(OperationState state) {
    final expected = 'daily-finalize:${state.operationDate.value}';
    if (state.activeAttempt?.idempotencyKey != expected) {
      throw DailyFinalizeException(
        DailyFinalizeFailureCode.stateConflict,
        StateError('Daily finalize idempotency key does not match.'),
      );
    }
  }

  Future<DailyLogConfirmation> _buildConfirmation(
    OperationLocalDate localDate,
    double? estimatedTotalBurnKcal,
  ) async {
    try {
      return await buildDailyConfirmation(localDate, estimatedTotalBurnKcal);
    } catch (error) {
      throw DailyFinalizeException(
        DailyFinalizeFailureCode.validationFailed,
        error,
      );
    }
  }

  Future<T> _runOnce<T>(String key, Future<T> Function() action) async {
    if (!_activeKeys.add(key)) {
      throw DailyFinalizeException(
        DailyFinalizeFailureCode.stateConflict,
        StateError('Daily close action is already running for this date.'),
      );
    }
    try {
      return await action();
    } finally {
      _activeKeys.remove(key);
    }
  }
}
