import '../../../core/models/daily_log_confirmation.dart';
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

class DailyFinalizeCoordinator {
  static final Set<String> _activeFinalizeKeys = <String>{};

  final OperationStateRepository _operationState;
  final DailyLogConfirmationStore _confirmations;
  final DailyFinalizeTransaction _transaction;
  final DailyFinalizeBackupVerifier _backupVerifier;
  final DailyFinalizeIntegrityService _integrity;
  final Future<void> Function() restoreNextDate;
  final BuildDailyConfirmation buildDailyConfirmation;
  final DateTime Function() _now;

  DailyFinalizeCoordinator(
    this._operationState,
    this._confirmations,
    this._transaction,
    this._backupVerifier, {
    DailyFinalizeIntegrityService? integrity,
    required this.restoreNextDate,
    required this.buildDailyConfirmation,
    DateTime Function()? now,
  }) : _integrity =
           integrity ??
           DailyFinalizeIntegrityService(_operationState, _confirmations),
       _now = now ?? DateTime.now;

  Future<DailyFinalizeResult> finalize({
    required OperationLocalDate targetLocalDate,
    double? estimatedTotalBurnKcal,
  }) async {
    final key = 'daily-finalize:${targetLocalDate.value}';
    if (!_activeFinalizeKeys.add(key)) {
      throw DailyFinalizeException(
        DailyFinalizeFailureCode.stateConflict,
        StateError('Daily finalize is already running for this date.'),
      );
    }
    try {
      return await _finalize(
        targetLocalDate: targetLocalDate,
        estimatedTotalBurnKcal: estimatedTotalBurnKcal,
      );
    } finally {
      _activeFinalizeKeys.remove(key);
    }
  }

  Future<DailyFinalizeResult> _finalize({
    required OperationLocalDate targetLocalDate,
    double? estimatedTotalBurnKcal,
  }) async {
    var state = await _operationState.requireCurrent();
    if (state.operationDate != targetLocalDate) {
      throw DailyFinalizeException(
        DailyFinalizeFailureCode.validationFailed,
        StateError('Historical dates cannot be finalized.'),
      );
    }
    if (state.phase != OperationPhase.open) {
      _verifyAttemptKey(state);
      return _resume(state, estimatedTotalBurnKcal);
    }

    final confirmation = await _buildConfirmation(
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
    } on OperationStateRevisionConflictException catch (error) {
      throw DailyFinalizeException(
        DailyFinalizeFailureCode.stateConflict,
        error,
      );
    } catch (error) {
      throw DailyFinalizeException(
        DailyFinalizeFailureCode.stateConflict,
        error,
      );
    }
    return _resume(
      state,
      estimatedTotalBurnKcal,
      preparedConfirmation: confirmation,
    );
  }

  Future<DailyFinalizeResult> recover() async {
    final state = await _operationState.requireCurrent();
    if (state.phase == OperationPhase.open) {
      throw StateError('No daily finalize recovery is required.');
    }
    _verifyAttemptKey(state);
    return _resume(state, null);
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

  Future<DailyFinalizeResult> _resume(
    OperationState initialState,
    double? estimatedTotalBurnKcal, {
    DailyLogConfirmation? preparedConfirmation,
  }) async {
    var state = initialState;
    try {
      if (state.phase == OperationPhase.finalizing) {
        final existing = await _confirmations.findByLocalDate(
          state.operationDate.value,
        );
        final confirmation =
            preparedConfirmation ??
            existing ??
            await _buildConfirmation(
              state.operationDate,
              estimatedTotalBurnKcal,
            );
        final digest = _integrity.confirmationDigest(confirmation);
        state = await _transaction.saveConfirmationAndMarkPending(
          expectedState: state,
          confirmation: confirmation,
          confirmationDigest: digest,
        );
      }

      if (state.phase == OperationPhase.finalizedPendingBackup) {
        await _integrity.verifyStoredConfirmation(state);
        final backup = await _backupVerifier.generateAndVerify();
        final attempt = state.activeAttempt!;
        state = await _integrity.saveState(
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

      if (state.phase != OperationPhase.advancing) {
        throw StateError('Unsupported daily finalize recovery phase.');
      }
      await _integrity.verifyStoredConfirmation(state);
      final finalizedDate = state.operationDate;
      final attempt = state.activeAttempt!;
      final nextDate = finalizedDate.addDays(1);
      state = await _integrity.saveState(
        state,
        state.copyWith(
          operationDate: nextDate,
          phase: OperationPhase.open,
          lastFinalizedDate: finalizedDate,
          clearActiveAttempt: true,
        ),
      );
      if (state.operationDate != nextDate ||
          state.phase != OperationPhase.open ||
          state.lastFinalizedDate != finalizedDate) {
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
    } catch (error) {
      await _integrity.recordFailure(state, _integrity.failureCode(error));
      if (error is DailyFinalizeException) rethrow;
      throw DailyFinalizeException(_integrity.failureCode(error), error);
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
}
