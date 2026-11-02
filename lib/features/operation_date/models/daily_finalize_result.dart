import 'operation_local_date.dart';
import '../../import_export/services/backup_schema_diagnostics.dart';

enum DailyFinalizeFailureCode {
  validationFailed,
  confirmationWriteFailed,
  confirmationReadbackFailed,
  confirmationDigestMismatch,
  backupGenerationFailed,
  backupValidationFailed,
  backupDigestMismatch,
  advanceWriteFailed,
  advanceReadbackFailed,
  stateConflict,
}

class DailyClosePreparationResult {
  final OperationLocalDate operationDate;
  final String confirmationId;
  final String confirmationDigest;

  const DailyClosePreparationResult({
    required this.operationDate,
    required this.confirmationId,
    required this.confirmationDigest,
  });
}

class DailyFinalizeResult {
  final OperationLocalDate finalizedDate;
  final OperationLocalDate nextOperationDate;
  final String confirmationId;
  final String confirmationDigest;
  final String backupPackageDigest;

  const DailyFinalizeResult({
    required this.finalizedDate,
    required this.nextOperationDate,
    required this.confirmationId,
    required this.confirmationDigest,
    required this.backupPackageDigest,
  });
}

class DailyFinalizeException implements Exception {
  final DailyFinalizeFailureCode code;
  final Object cause;
  final BackupSchemaDiagnostics? diagnostics;

  const DailyFinalizeException(this.code, this.cause, {this.diagnostics});

  @override
  String toString() => '${code.name}: $cause';
}
