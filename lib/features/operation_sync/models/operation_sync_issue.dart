enum OperationSyncIssueLevel {
  blocking('blocking'),
  warning('warning'),
  information('information');

  const OperationSyncIssueLevel(this.stableId);
  final String stableId;
}

enum OperationSyncIssueCode {
  duplicateNoChange('duplicateNoChange'),
  recordIdConflict('recordIdConflict'),
  canonicalConflict('canonicalConflict'),
  referenceConflict('referenceConflict'),
  versionUnsupported('versionUnsupported'),
  migrationUnavailable('migrationUnavailable'),
  historicalFinalizedConflict('historicalFinalizedConflict'),
  operationStateConflict('operationStateConflict'),
  processingStateConflict('processingStateConflict'),
  integrityFailure('integrityFailure'),
  packageDigestMismatch('packageDigestMismatch'),
  sectionDigestMismatch('sectionDigestMismatch'),
  recordDigestMismatch('recordDigestMismatch'),
  packageTooLarge('packageTooLarge'),
  recordLimitExceeded('recordLimitExceeded'),
  adapterUnavailable('adapterUnavailable');

  const OperationSyncIssueCode(this.stableId);
  final String stableId;
}

class OperationSyncIssue {
  final OperationSyncIssueLevel level;
  final OperationSyncIssueCode code;
  final String message;
  final String? module;
  final String? recordId;

  const OperationSyncIssue({
    required this.level,
    required this.code,
    required this.message,
    this.module,
    this.recordId,
  });
}

enum OperationSyncRecordDisposition { create, noChange, conflict }

class OperationSyncRecordInspection {
  final OperationSyncRecordDisposition disposition;
  final List<OperationSyncIssue> issues;

  const OperationSyncRecordInspection({
    required this.disposition,
    this.issues = const [],
  });

  const OperationSyncRecordInspection.create()
    : disposition = OperationSyncRecordDisposition.create,
      issues = const [];

  const OperationSyncRecordInspection.noChange()
    : disposition = OperationSyncRecordDisposition.noChange,
      issues = const [];
}

class OperationSyncException implements Exception {
  final OperationSyncIssueCode code;
  final String message;

  const OperationSyncException(this.code, this.message);

  @override
  String toString() => '${code.stableId}: $message';
}
