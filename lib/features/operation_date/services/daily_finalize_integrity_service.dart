import '../../../core/models/daily_log_confirmation.dart';
import '../../daily_log_confirmation/models/persisted_daily_log_confirmation_record.dart';
import '../../daily_log_confirmation/repository/daily_log_confirmation_repository.dart';
import '../../import_export/services/backup_canonical_codec.dart';
import '../models/daily_finalize_result.dart';
import '../models/operation_active_attempt.dart';
import '../models/operation_local_date.dart';
import '../models/operation_state.dart';
import '../repository/operation_state_repository.dart';

class DailyFinalizeIntegrityService {
  final OperationStateRepository _operationState;
  final DailyLogConfirmationStore _confirmations;

  const DailyFinalizeIntegrityService(
    this._operationState,
    this._confirmations,
  );

  String confirmationDigest(DailyLogConfirmation confirmation) =>
      BackupCanonicalCodec.digest(confirmation.toJson());

  Future<OperationState> saveState(
    OperationState current,
    OperationState desired,
  ) async {
    final OperationState saved;
    try {
      saved = await _operationState.compareAndSaveRevision(
        desired,
        expectedRevision: current.revision,
      );
    } on OperationStateRevisionConflictException catch (error) {
      throw DailyFinalizeException(
        DailyFinalizeFailureCode.stateConflict,
        error,
      );
    } catch (error) {
      throw DailyFinalizeException(
        DailyFinalizeFailureCode.advanceWriteFailed,
        error,
      );
    }
    try {
      final verified = await _operationState.requireCurrent();
      if (verified.revision != saved.revision ||
          !verified.hasSameMutableContent(saved)) {
        throw StateError('Operation state read-back mismatch.');
      }
      return verified;
    } catch (error) {
      throw DailyFinalizeException(
        DailyFinalizeFailureCode.advanceReadbackFailed,
        error,
      );
    }
  }

  Future<void> verifyStoredConfirmation(OperationState state) =>
      verifyConfirmation(
        state.operationDate,
        state.activeAttempt!.confirmationId!,
        state.activeAttempt!.confirmationDigest!,
      );

  Future<void> verifyConfirmation(
    OperationLocalDate date,
    String expectedId,
    String expectedDigest,
  ) async {
    final canonicalId = PersistedDailyLogConfirmationRecord.canonicalId(
      date.value,
    );
    final confirmation = await _confirmations.findByLocalDate(date.value);
    if (expectedId != canonicalId || confirmation == null) {
      throw DailyFinalizeException(
        DailyFinalizeFailureCode.confirmationReadbackFailed,
        StateError('Confirmation read-back is missing.'),
      );
    }
    if (confirmationDigest(confirmation) != expectedDigest) {
      throw DailyFinalizeException(
        DailyFinalizeFailureCode.confirmationDigestMismatch,
        StateError('Confirmation digest does not match.'),
      );
    }
  }

  Future<void> recordFailure(
    OperationState state,
    DailyFinalizeFailureCode code,
  ) async {
    final attempt = state.activeAttempt;
    if (state.phase == OperationPhase.open || attempt == null) return;
    try {
      await _operationState.compareAndSaveRevision(
        state.copyWith(
          activeAttempt: OperationActiveAttempt(
            idempotencyKey: attempt.idempotencyKey,
            targetLocalDate: attempt.targetLocalDate,
            startedAt: attempt.startedAt,
            confirmationId: attempt.confirmationId,
            confirmationDigest: attempt.confirmationDigest,
            backupPackageDigest: attempt.backupPackageDigest,
            backupGeneratedAt: attempt.backupGeneratedAt,
            failureCode: code.name,
          ),
        ),
        expectedRevision: state.revision,
      );
    } catch (_) {
      // The original integrity failure remains authoritative.
    }
  }

  DailyFinalizeFailureCode failureCode(Object error) {
    if (error is DailyFinalizeException) return error.code;
    if (error is OperationStateRevisionConflictException) {
      return DailyFinalizeFailureCode.stateConflict;
    }
    return DailyFinalizeFailureCode.advanceWriteFailed;
  }
}
