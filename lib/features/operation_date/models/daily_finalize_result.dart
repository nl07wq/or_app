import 'operation_local_date.dart';

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

  const DailyFinalizeException(this.code, this.cause);

  @override
  String toString() => '${code.name}: $cause';
}
