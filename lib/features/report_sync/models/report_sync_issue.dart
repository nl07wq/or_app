enum ReportSyncIssueCode {
  duplicateNoChange('duplicateNoChange'),
  requestNotFound('requestNotFound'),
  requestDigestMismatch('requestDigestMismatch'),
  responseDigestMismatch('responseDigestMismatch'),
  operationDateMismatch('operationDateMismatch'),
  confirmationDigestMismatch('confirmationDigestMismatch'),
  exchangeTypeMismatch('exchangeTypeMismatch'),
  schemaMismatch('schemaMismatch'),
  recordConflict('recordConflict'),
  integrityFailure('integrityFailure');

  const ReportSyncIssueCode(this.stableId);
  final String stableId;
}

class ReportSyncException implements Exception {
  final ReportSyncIssueCode code;
  final String message;
  final ReportSyncValidationError? validationError;

  const ReportSyncException(this.code, this.message, {this.validationError});

  @override
  String toString() => '${code.stableId}: $message';
}

class ReportSyncValidationError {
  const ReportSyncValidationError({
    required this.code,
    required this.jsonPath,
    required this.message,
    required this.expected,
    required this.actualType,
    required this.actualValuePreview,
  });

  final String code;
  final String jsonPath;
  final String message;
  final String expected;
  final String actualType;
  final String actualValuePreview;
}
