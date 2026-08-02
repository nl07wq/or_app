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

  const ReportSyncException(this.code, this.message);

  @override
  String toString() => '${code.stableId}: $message';
}
