import '../../operation_date/models/operation_state.dart';
import '../../operation_date/repository/operation_state_repository.dart';
import '../models/operation_sync_issue.dart';
import '../models/operation_transfer_package.dart';
import 'operation_sync_validator.dart';
import 'operation_transfer_canonical_service.dart';

class OperationTransferExportService {
  final OperationTransferAdapterRegistry registry;
  final OperationStateRepository operationStateRepository;
  final DateTime Function() _clock;

  OperationTransferExportService({
    required this.registry,
    required this.operationStateRepository,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  Future<OperationTransferPackage> createPackage({
    required String packageId,
    required String sourceApplicationVersion,
  }) async {
    final state = await operationStateRepository.requireCurrent();
    if (state.phase != OperationPhase.open) {
      throw const OperationSyncException(
        OperationSyncIssueCode.processingStateConflict,
        'Operation State requires recovery before export.',
      );
    }
    final createdAt = _clock().toUtc();
    final sections = <OperationTransferSection>[];
    for (final adapter in registry.adapters) {
      final records = await adapter.exportRecords();
      final unsigned = OperationTransferSection(
        module: adapter.module,
        schemaVersion: adapter.schemaVersion,
        records: records,
        sectionDigest: '',
      );
      sections.add(
        OperationTransferSection(
          module: adapter.module,
          schemaVersion: adapter.schemaVersion,
          records: records,
          sectionDigest: OperationTransferCanonicalService.sectionDigest(
            unsigned,
          ),
        ),
      );
    }
    final recordCount = sections.fold<int>(
      0,
      (count, section) => count + section.records.length,
    );
    final manifest = OperationTransferManifest(
      sectionCount: sections.length,
      recordCount: recordCount,
      sectionSummaries: [
        for (final section in sections)
          OperationTransferSectionSummary(
            module: section.module,
            recordVersionSet:
                section.records
                    .map((record) => record.recordVersion)
                    .toSet()
                    .toList()
                  ..sort(),
            recordCount: section.records.length,
            sectionDigest: section.sectionDigest,
          ),
      ],
      sourceCheckpoint: OperationTransferCanonicalService.digest({
        'operationDate': state.operationDate.value,
        'lastFinalizedDate': state.lastFinalizedDate?.value,
        'revision': state.revision,
      }),
      sourceLastFinalizedDate: state.lastFinalizedDate?.value,
      sourceOperationDate: state.operationDate.value,
      packageCreatedAt: createdAt,
    );
    final unsigned = OperationTransferPackage(
      packageId: packageId,
      createdAt: createdAt,
      sourceApplicationVersion: sourceApplicationVersion,
      manifest: manifest,
      sections: sections,
      packageDigest: '',
    );
    return OperationTransferPackage(
      packageId: packageId,
      createdAt: createdAt,
      sourceApplicationVersion: sourceApplicationVersion,
      manifest: manifest,
      sections: sections,
      packageDigest: OperationTransferCanonicalService.packageDigest(unsigned),
    );
  }
}
