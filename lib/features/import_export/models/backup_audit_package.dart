import 'backup_package.dart';

class BackupAuditPackage {
  static const schemaName = 'operation-reboot-audit-archive';
  static const schemaVersion = 14;

  const BackupAuditPackage({
    required this.archiveId,
    required this.normalExportId,
    required this.normalPackageDigest,
    required this.exportedAt,
    required this.source,
    required this.archiveComplete,
    required this.digests,
    required this.data,
  });

  final String archiveId;
  final String normalExportId;
  final String normalPackageDigest;
  final DateTime exportedAt;
  final BackupSource source;
  final bool archiveComplete;
  final BackupDigests digests;
  final Map<String, List<Map<String, Object?>>> data;

  Map<String, Object?> toJson() => {
    'schema': schemaName,
    'schemaVersion': schemaVersion,
    'archiveId': archiveId,
    'normalExportId': normalExportId,
    'normalPackageDigest': normalPackageDigest,
    'exportedAt': exportedAt.toUtc().toIso8601String(),
    'source': source.toJson(),
    'archiveComplete': archiveComplete,
    'digests': digests.toJson(),
    'data': data,
  };
}

class BackupV14Bundle {
  const BackupV14Bundle({required this.normal, required this.audit});

  final BackupPackage normal;
  final BackupAuditPackage audit;
}

abstract final class BackupAuditSections {
  static const revisionBodies = 'revisionBodies';
  static const reportSyncMealSnapshots = 'reportSyncMealSnapshots';
  static const operationSyncHistory = 'operationSyncHistory';
  static const all = [
    revisionBodies,
    reportSyncMealSnapshots,
    operationSyncHistory,
  ];
}
