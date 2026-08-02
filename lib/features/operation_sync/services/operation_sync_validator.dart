import '../../../data/indexed_db/indexed_db_database_contract.dart';
import '../../operation_date/models/operation_state.dart';
import '../../operation_date/repository/operation_state_repository.dart';
import '../models/operation_sync_issue.dart';
import '../models/operation_sync_preview.dart';
import '../models/operation_transfer_package.dart';
import 'operation_sync_record_envelope.dart';

abstract interface class OperationTransferModuleAdapter {
  String get module;
  String get schemaVersion;
  Set<int> get supportedRecordVersions;
  Set<String> get storeNames;

  Future<List<OperationTransferRecord>> exportRecords();

  Future<OperationSyncRecordInspection> inspect(
    OperationTransferRecord record,
    OperationSyncInspectionContext context,
  );

  bool isDateBound(OperationTransferRecord record);

  Future<bool> hasTargetRecords();

  Future<OperationSyncApplyCounts> apply(
    IndexedDbTransaction transaction,
    List<OperationTransferRecord> records,
    OperationSyncInspectionContext context,
  );

  Future<bool> verify(
    IndexedDbTransaction transaction,
    List<OperationTransferRecord> records,
  );
}

class OperationSyncApplyCounts {
  final int created;
  final int noChanges;

  const OperationSyncApplyCounts({
    required this.created,
    required this.noChanges,
  });
}

class OperationTransferAdapterRegistry {
  final Map<String, OperationTransferModuleAdapter> _adapters;

  OperationTransferAdapterRegistry({
    Iterable<OperationTransferModuleAdapter> adapters = const [],
  }) : _adapters = _build(adapters);

  OperationTransferModuleAdapter? adapterFor(String module) {
    return _adapters[module];
  }

  bool get isEmpty => _adapters.isEmpty;

  List<OperationTransferModuleAdapter> get adapters =>
      List.unmodifiable(_adapters.values);

  Set<String> get storeNames => {
    for (final adapter in _adapters.values) ...adapter.storeNames,
  };

  Future<bool> hasAnyTargetRecords() async {
    for (final adapter in _adapters.values) {
      if (await adapter.hasTargetRecords()) return true;
    }
    return false;
  }

  static Map<String, OperationTransferModuleAdapter> _build(
    Iterable<OperationTransferModuleAdapter> adapters,
  ) {
    final result = <String, OperationTransferModuleAdapter>{};
    for (final adapter in adapters) {
      if (result.containsKey(adapter.module)) {
        throw ArgumentError.value(adapter.module, 'adapters');
      }
      result[adapter.module] = adapter;
    }
    return Map.unmodifiable(result);
  }
}

class OperationSyncValidator {
  final OperationTransferAdapterRegistry registry;
  final OperationStateRepository? operationStateRepository;

  const OperationSyncValidator(this.registry, {this.operationStateRepository});

  Future<OperationSyncPreview> preview(OperationTransferPackage package) async {
    final issues = <OperationSyncIssue>[];
    var creates = 0;
    var noChanges = 0;
    var conflicts = 0;
    final state = await operationStateRepository?.requireCurrent();
    final targetHasRecords = await registry.hasAnyTargetRecords();
    final pristine =
        state != null &&
        state.phase == OperationPhase.open &&
        state.revision == 0 &&
        state.lastFinalizedDate == null &&
        !targetHasRecords;
    final stateIssue = _stateIssue(package, state, pristine);
    if (stateIssue != null) {
      issues.add(stateIssue);
      conflicts = package.manifest.recordCount;
      return _preview(
        package,
        creates: creates,
        noChanges: noChanges,
        conflicts: conflicts,
        issues: issues,
      );
    }
    final context = OperationSyncInspectionContext(
      package: package,
      targetOperationState: state,
      pristineTarget: pristine,
    );
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
        final inspection = await adapter.inspect(record, context);
        issues.addAll(inspection.issues);
        switch (inspection.disposition) {
          case OperationSyncRecordDisposition.create:
            final lastFinalized = state?.lastFinalizedDate?.value;
            if (!pristine &&
                lastFinalized != null &&
                adapter.isDateBound(record) &&
                record.localDate.compareTo(lastFinalized) <= 0) {
              conflicts++;
              issues.add(
                OperationSyncIssue(
                  level: OperationSyncIssueLevel.blocking,
                  code: OperationSyncIssueCode.historicalFinalizedConflict,
                  message: 'A finalized historical date cannot be created.',
                  module: section.module,
                  recordId: record.recordId,
                ),
              );
            } else {
              creates++;
            }
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
    return _preview(
      package,
      creates: creates,
      noChanges: noChanges,
      conflicts: conflicts,
      issues: issues,
    );
  }

  static OperationSyncPreview _preview(
    OperationTransferPackage package, {
    required int creates,
    required int noChanges,
    required int conflicts,
    required List<OperationSyncIssue> issues,
  }) {
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

  static OperationSyncIssue? _stateIssue(
    OperationTransferPackage package,
    OperationState? state,
    bool pristine,
  ) {
    final sourceLastFinalized = package.manifest.sourceLastFinalizedDate;
    if (sourceLastFinalized != null &&
        sourceLastFinalized.compareTo(package.manifest.sourceOperationDate) >=
            0) {
      return const OperationSyncIssue(
        level: OperationSyncIssueLevel.blocking,
        code: OperationSyncIssueCode.integrityFailure,
        message: 'Source Operation State checkpoint is invalid.',
      );
    }
    if (state == null) return null;
    if (state.phase != OperationPhase.open) {
      return const OperationSyncIssue(
        level: OperationSyncIssueLevel.blocking,
        code: OperationSyncIssueCode.processingStateConflict,
        message: 'Operation State requires recovery before transfer.',
      );
    }
    if (pristine) return null;
    if (state.operationDate.value != package.manifest.sourceOperationDate ||
        state.lastFinalizedDate?.value !=
            package.manifest.sourceLastFinalizedDate) {
      return const OperationSyncIssue(
        level: OperationSyncIssueLevel.blocking,
        code: OperationSyncIssueCode.operationStateConflict,
        message: 'Source and target Operation State checkpoints differ.',
      );
    }
    return null;
  }
}

class OperationSyncInspectionContext {
  final OperationTransferPackage package;
  final OperationState? targetOperationState;
  final bool pristineTarget;

  const OperationSyncInspectionContext({
    required this.package,
    required this.targetOperationState,
    required this.pristineTarget,
  });

  Iterable<OperationTransferRecord> recordsFor(String module) => package
      .sections
      .where((section) => section.module == module)
      .expand((section) => section.records);

  bool containsRecord({
    required String module,
    required String recordType,
    required String recordId,
  }) {
    return recordsFor(module).any((record) {
      if (record.recordId != recordId) return false;
      try {
        return OperationSyncRecordEnvelope.fromTransfer(record).recordType ==
            recordType;
      } on OperationSyncException {
        return false;
      }
    });
  }
}
