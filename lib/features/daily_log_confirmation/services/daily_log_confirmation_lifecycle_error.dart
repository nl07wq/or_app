enum DailyLogConfirmationLifecycleErrorCode {
  reopenConfirmationMissing,
  reopenAlreadyReopened,
  reopenInvalidLifecycle,
  reopenSnapshotInvalid,
  reopenFutureDate,
  reopenOperationStateInvalid,
  reopenWriteFailed,
  reopenReadBackFailed,
  refinalizeConfirmationMissing,
  refinalizeNotReopened,
  refinalizeFutureDate,
  refinalizeSourceInvalid,
  refinalizeSourceChanged,
  refinalizeSnapshotFailed,
  refinalizeDigestFailed,
  refinalizeWriteFailed,
  refinalizeReadBackFailed,
  operationStateChanged,
  transactionAborted,
}

class DailyLogConfirmationLifecycleException implements Exception {
  final DailyLogConfirmationLifecycleErrorCode code;
  final String stage;
  final String localDate;
  final String? store;
  final String? recordId;
  final String message;
  final Object? cause;

  const DailyLogConfirmationLifecycleException({
    required this.code,
    required this.stage,
    required this.localDate,
    this.store,
    this.recordId,
    required this.message,
    this.cause,
  });

  @override
  String toString() =>
      'DailyLogConfirmationLifecycleException(${code.name}, $stage, '
      '$localDate): $message';
}
