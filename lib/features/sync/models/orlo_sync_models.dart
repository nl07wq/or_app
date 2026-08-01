class OrloSyncSource {
  const OrloSyncSource({
    required this.type,
    required this.generatedAt,
    required this.producer,
    this.producerVersion,
  });

  final String type;
  final DateTime generatedAt;
  final String producer;
  final String? producerVersion;

  Map<String, Object?> toJson() => {
    'type': type,
    'generatedAt': generatedAt.toUtc().toIso8601String(),
    'producer': producer,
    'producerVersion': producerVersion,
  };
}

class OrloSyncEnvelope {
  const OrloSyncEnvelope({
    required this.envelopeVersion,
    required this.schemaVersion,
    required this.dataType,
    required this.packageId,
    required this.idempotencyKey,
    required this.source,
    required this.operationDate,
    required this.payload,
  });

  static const format = 'orlo-sync';
  static const currentEnvelopeVersion = 1;
  static const currentSchemaVersion = '1.0';

  final int envelopeVersion;
  final String schemaVersion;
  final String dataType;
  final String packageId;
  final String idempotencyKey;
  final OrloSyncSource source;
  final String? operationDate;
  final Map<String, Object?> payload;

  Map<String, Object?> toJson() => {
    'format': format,
    'envelopeVersion': envelopeVersion,
    'schemaVersion': schemaVersion,
    'dataType': dataType,
    'packageId': packageId,
    'idempotencyKey': idempotencyKey,
    'source': source.toJson(),
    'operationDate': operationDate,
    'payload': payload,
  };
}

enum SyncIssueSeverity { blockingError, warning, conflict, information }

class SyncIssue {
  const SyncIssue({
    required this.code,
    required this.path,
    required this.message,
    required this.severity,
    this.expected,
    this.actual,
  });

  final String code;
  final String path;
  final String message;
  final SyncIssueSeverity severity;
  final Object? expected;
  final Object? actual;
}

class SyncValidationResult {
  const SyncValidationResult(this.issues);

  final List<SyncIssue> issues;

  bool get hasBlockingErrors =>
      issues.any((issue) => issue.severity == SyncIssueSeverity.blockingError);
  bool get hasConflicts =>
      issues.any((issue) => issue.severity == SyncIssueSeverity.conflict);
  bool get canImport => !hasBlockingErrors && !hasConflicts;
}

class SyncPreviewCounts {
  const SyncPreviewCounts({
    this.records = 0,
    this.create = 0,
    this.update = 0,
    this.noOp = 0,
    this.conflict = 0,
  });

  final int records;
  final int create;
  final int update;
  final int noOp;
  final int conflict;
}

class SyncPreview {
  const SyncPreview({
    required this.envelope,
    required this.payloadDigest,
    required this.validation,
    required this.counts,
  });

  final OrloSyncEnvelope envelope;
  final String payloadDigest;
  final SyncValidationResult validation;
  final SyncPreviewCounts counts;

  bool get canImport => validation.canImport;
  int get warningCount => validation.issues
      .where((issue) => issue.severity == SyncIssueSeverity.warning)
      .length;
  int get blockingErrorCount => validation.issues
      .where((issue) => issue.severity == SyncIssueSeverity.blockingError)
      .length;
}

class SyncImportResult {
  const SyncImportResult({
    required this.success,
    required this.packageId,
    required this.payloadDigest,
    required this.issues,
  });

  final bool success;
  final String packageId;
  final String payloadDigest;
  final List<SyncIssue> issues;
}

class SyncQuarantineCandidate {
  const SyncQuarantineCandidate({
    required this.packageId,
    required this.dataType,
    required this.schemaVersion,
    required this.receivedAt,
    required this.issueCodes,
    required this.rawDigest,
    required this.summary,
  });

  final String? packageId;
  final String? dataType;
  final String? schemaVersion;
  final DateTime receivedAt;
  final List<String> issueCodes;
  final String rawDigest;
  final String summary;
}
