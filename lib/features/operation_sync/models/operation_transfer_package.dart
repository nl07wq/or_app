enum OperationTransferSourceType {
  currentAppTransfer('currentAppTransfer');

  const OperationTransferSourceType(this.stableId);
  final String stableId;
}

enum OperationTransferMode {
  fullTransfer('fullTransfer');

  const OperationTransferMode(this.stableId);
  final String stableId;
}

class OperationTransferRecord {
  final String recordId;
  final int recordVersion;
  final String localDate;
  final Map<String, Object?> canonicalPayload;
  final String recordDigest;

  OperationTransferRecord({
    required this.recordId,
    required this.recordVersion,
    required this.localDate,
    required Map<String, Object?> canonicalPayload,
    required this.recordDigest,
  }) : canonicalPayload = Map.unmodifiable(canonicalPayload);

  Map<String, Object?> toJson() => {
    'recordId': recordId,
    'recordVersion': recordVersion,
    'localDate': localDate,
    'canonicalPayload': canonicalPayload,
    'recordDigest': recordDigest,
  };

  Map<String, Object?> digestPayload() => {
    'recordId': recordId,
    'recordVersion': recordVersion,
    'localDate': localDate,
    'canonicalPayload': canonicalPayload,
  };
}

class OperationTransferSection {
  final String module;
  final String schemaVersion;
  final List<OperationTransferRecord> records;
  final String sectionDigest;

  OperationTransferSection({
    required this.module,
    required this.schemaVersion,
    required Iterable<OperationTransferRecord> records,
    required this.sectionDigest,
  }) : records = List.unmodifiable(records);

  Map<String, Object?> toJson() => {
    'module': module,
    'schemaVersion': schemaVersion,
    'records': [for (final record in records) record.toJson()],
    'sectionDigest': sectionDigest,
  };

  Map<String, Object?> digestPayload() => {
    'module': module,
    'schemaVersion': schemaVersion,
    'recordDigests': [for (final record in records) record.recordDigest],
  };
}

class OperationTransferSectionSummary {
  final String module;
  final List<int> recordVersionSet;
  final int recordCount;
  final String sectionDigest;

  OperationTransferSectionSummary({
    required this.module,
    required Iterable<int> recordVersionSet,
    required this.recordCount,
    required this.sectionDigest,
  }) : recordVersionSet = List.unmodifiable(recordVersionSet);

  Map<String, Object?> toJson() => {
    'module': module,
    'recordVersionSet': recordVersionSet,
    'recordCount': recordCount,
    'sectionDigest': sectionDigest,
  };
}

class OperationTransferManifest {
  final int sectionCount;
  final int recordCount;
  final List<OperationTransferSectionSummary> sectionSummaries;
  final String sourceCheckpoint;
  final String? sourceLastFinalizedDate;
  final String sourceOperationDate;
  final DateTime packageCreatedAt;

  OperationTransferManifest({
    required this.sectionCount,
    required this.recordCount,
    required Iterable<OperationTransferSectionSummary> sectionSummaries,
    required this.sourceCheckpoint,
    required this.sourceLastFinalizedDate,
    required this.sourceOperationDate,
    required this.packageCreatedAt,
  }) : sectionSummaries = List.unmodifiable(sectionSummaries);

  Map<String, Object?> toJson() => {
    'sectionCount': sectionCount,
    'recordCount': recordCount,
    'sectionSummaries': [
      for (final summary in sectionSummaries) summary.toJson(),
    ],
    'sourceCheckpoint': sourceCheckpoint,
    'sourceLastFinalizedDate': sourceLastFinalizedDate,
    'sourceOperationDate': sourceOperationDate,
    'packageCreatedAt': packageCreatedAt.toUtc().toIso8601String(),
  };
}

class OperationTransferPackage {
  static const formatName = 'operation-reboot-transfer';
  static const currentEnvelopeVersion = 1;
  static const currentSchemaVersion = '1.0';
  static const sourceApplicationName = 'operation-reboot-app';

  final String format;
  final int envelopeVersion;
  final String schemaVersion;
  final String packageId;
  final DateTime createdAt;
  final String sourceApplication;
  final String sourceApplicationVersion;
  final OperationTransferSourceType sourceType;
  final OperationTransferMode transferMode;
  final OperationTransferManifest manifest;
  final List<OperationTransferSection> sections;
  final String packageDigest;

  OperationTransferPackage({
    this.format = formatName,
    this.envelopeVersion = currentEnvelopeVersion,
    this.schemaVersion = currentSchemaVersion,
    required this.packageId,
    required this.createdAt,
    this.sourceApplication = sourceApplicationName,
    required this.sourceApplicationVersion,
    this.sourceType = OperationTransferSourceType.currentAppTransfer,
    this.transferMode = OperationTransferMode.fullTransfer,
    required this.manifest,
    required Iterable<OperationTransferSection> sections,
    required this.packageDigest,
  }) : sections = List.unmodifiable(sections);

  Map<String, Object?> toJson() => {
    ...digestPayload(),
    'packageDigest': packageDigest,
  };

  Map<String, Object?> digestPayload() => {
    'format': format,
    'envelopeVersion': envelopeVersion,
    'schemaVersion': schemaVersion,
    'packageId': packageId,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'sourceApplication': sourceApplication,
    'sourceApplicationVersion': sourceApplicationVersion,
    'sourceType': sourceType.stableId,
    'transferMode': transferMode.stableId,
    'manifest': manifest.toJson(),
    'sections': [for (final section in sections) section.toJson()],
  };
}
