import '../../daily_log_confirmation/models/persisted_daily_log_confirmation_record.dart';
import '../../operation_date/models/operation_state.dart';
import '../models/backup_package.dart';
import 'backup_canonical_codec.dart';

abstract final class BackupOperationStateIntegrity {
  static void validate(Map<String, List<Map<String, Object?>>> data) {
    final stateRecords = data[BackupSections.operationState];
    if (stateRecords == null || stateRecords.length != 1) {
      throw const BackupException(
        'invalid_operation_state_count',
        'Schema 3.0 requires exactly one operation state record.',
      );
    }
    final state = OperationState.fromRecord(stateRecords.single);
    final confirmations = <String, PersistedDailyLogConfirmationRecord>{
      for (final record in data[BackupSections.confirmations] ?? const [])
        if (PersistedDailyLogConfirmationRecord.fromRecord(record)
            case final confirmation)
          confirmation.id: confirmation,
    };
    if (state.phase == OperationPhase.open) {
      final last = state.lastFinalizedDate;
      if (last != null) {
        final expected = DateTime.parse(
          last.value,
        ).add(const Duration(days: 1));
        final expectedValue = _localDate(expected);
        if (state.operationDate.value != expectedValue ||
            !confirmations.containsKey(
              PersistedDailyLogConfirmationRecord.canonicalId(last.value),
            )) {
          throw const BackupException(
            'operation_state_confirmation_mismatch',
            'Open operation state does not match its finalized confirmation.',
          );
        }
      }
      return;
    }
    final attempt = state.activeAttempt!;
    final expectedId = PersistedDailyLogConfirmationRecord.canonicalId(
      state.operationDate.value,
    );
    final confirmation = confirmations[expectedId];
    if (attempt.targetLocalDate != state.operationDate ||
        attempt.confirmationId != expectedId ||
        confirmation == null ||
        attempt.confirmationDigest !=
            BackupCanonicalCodec.digest(confirmation.data.toJson())) {
      throw const BackupException(
        'operation_state_confirmation_mismatch',
        'Processing operation state does not match its confirmation.',
      );
    }
  }

  static bool isProcessing(Map<String, List<Map<String, Object?>>> data) {
    final records = data[BackupSections.operationState];
    return records != null &&
        records.length == 1 &&
        OperationState.fromRecord(records.single).phase != OperationPhase.open;
  }

  static String _localDate(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}
