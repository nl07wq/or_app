enum RepositoryErrorCode {
  unknown,
  databaseOpenFailed,
  platformUnsupported,
  transactionFailed,
  quotaExceeded,
  serializationFailed,
  invalidRecord,
  unsupportedRecordVersion,
  migrationFailed,
  verificationFailed,
  partialCorruption,
}

class RepositoryException implements Exception {
  final String operation;
  final RepositoryErrorCode code;
  final Object cause;

  const RepositoryException({
    required this.operation,
    this.code = RepositoryErrorCode.unknown,
    required this.cause,
  });

  @override
  String toString() => 'RepositoryException($operation, ${code.name}): $cause';
}
