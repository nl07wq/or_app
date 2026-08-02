import '../models/operation_sync_issue.dart';
import '../models/operation_sync_preview.dart';
import '../models/operation_transfer_package.dart';

abstract interface class OperationTransferModuleAdapter {
  String get module;
  String get schemaVersion;
  Set<int> get supportedRecordVersions;

  Future<OperationSyncRecordInspection> inspect(OperationTransferRecord record);

  Future<void> applyForTesting(List<OperationTransferRecord> records);

  Future<bool> verifyForTesting(List<OperationTransferRecord> records);
}

class OperationTransferAdapterRegistry {
  final Map<String, OperationTransferModuleAdapter> _adapters;

  OperationTransferAdapterRegistry({
    Iterable<OperationTransferModuleAdapter> adapters = const [],
  }) : _adapters = Map.unmodifiable({
         for (final adapter in adapters) adapter.module: adapter,
       });

  OperationTransferModuleAdapter? adapterFor(String module) {
    return _adapters[module];
  }

  bool get isEmpty => _adapters.isEmpty;
}

class OperationSyncValidator {
  final OperationTransferAdapterRegistry registry;

  const OperationSyncValidator(this.registry);

  Future<OperationSyncPreview> preview(OperationTransferPackage package) async {
    final issues = <OperationSyncIssue>[];
    var creates = 0;
    var noChanges = 0;
    var conflicts = 0;
    for (final section in package.sections) {
      final adapter = registry.adapterFor(section.module);
      if (adapter == null) {
        issues.add(
          OperationSyncIssue(
            level: OperationSyncIssueLevel.blocking,
            code: OperationSyncIssueCode.adapterUnavailable,
            message: 'No production adapter is registered for the module.',
            module: section.module,
          ),
        );
        conflicts += section.records.length;
        continue;
      }
      if (adapter.schemaVersion != section.schemaVersion) {
        issues.add(
          OperationSyncIssue(
            level: OperationSyncIssueLevel.blocking,
            code: OperationSyncIssueCode.versionUnsupported,
            message: 'Module schema version is unsupported.',
            module: section.module,
          ),
        );
        conflicts += section.records.length;
        continue;
      }
      for (final record in section.records) {
        if (!adapter.supportedRecordVersions.contains(record.recordVersion)) {
          conflicts++;
          issues.add(
            OperationSyncIssue(
              level: OperationSyncIssueLevel.blocking,
              code: OperationSyncIssueCode.versionUnsupported,
              message: 'Module record version is unsupported.',
              module: section.module,
              recordId: record.recordId,
            ),
          );
          continue;
        }
        final inspection = await adapter.inspect(record);
        issues.addAll(inspection.issues);
        switch (inspection.disposition) {
          case OperationSyncRecordDisposition.create:
            creates++;
          case OperationSyncRecordDisposition.noChange:
            noChanges++;
            issues.add(
              OperationSyncIssue(
                level: OperationSyncIssueLevel.information,
                code: OperationSyncIssueCode.duplicateNoChange,
                message: 'Record already exists without changes.',
                module: section.module,
                recordId: record.recordId,
              ),
            );
          case OperationSyncRecordDisposition.conflict:
            conflicts++;
            if (!inspection.issues.any(
              (issue) => issue.level == OperationSyncIssueLevel.blocking,
            )) {
              issues.add(
                OperationSyncIssue(
                  level: OperationSyncIssueLevel.blocking,
                  code: OperationSyncIssueCode.canonicalConflict,
                  message: 'Record conflicts with target state.',
                  module: section.module,
                  recordId: record.recordId,
                ),
              );
            }
        }
      }
    }
    return OperationSyncPreview(
      packageId: package.packageId,
      sourceType: package.sourceType,
      transferMode: package.transferMode,
      schemaVersion: package.schemaVersion,
      createdAt: package.createdAt,
      moduleCount: package.sections.length,
      recordCount: package.manifest.recordCount,
      createCount: creates,
      noChangeCount: noChanges,
      conflictCount: conflicts,
      issues: issues,
      packageDigest: package.packageDigest,
    );
  }
}
