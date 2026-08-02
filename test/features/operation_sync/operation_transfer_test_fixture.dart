import 'package:or_app/features/operation_sync/models/operation_transfer_package.dart';
import 'package:or_app/features/operation_sync/services/operation_transfer_canonical_service.dart';

OperationTransferRecord fixtureRecord({
  String recordId = 'record-1',
  int recordVersion = 1,
  String localDate = '2026-08-02',
  Map<String, Object?> canonicalPayload = const {'value': 1, 'optional': null},
}) {
  final draft = OperationTransferRecord(
    recordId: recordId,
    recordVersion: recordVersion,
    localDate: localDate,
    canonicalPayload: canonicalPayload,
    recordDigest: '0' * 64,
  );
  return OperationTransferRecord(
    recordId: recordId,
    recordVersion: recordVersion,
    localDate: localDate,
    canonicalPayload: canonicalPayload,
    recordDigest: OperationTransferCanonicalService.recordDigest(draft),
  );
}

OperationTransferSection fixtureSection({
  String module = 'fixture',
  String schemaVersion = '1.0',
  Iterable<OperationTransferRecord>? records,
}) {
  final values = List<OperationTransferRecord>.from(
    records ?? [fixtureRecord()],
  );
  final draft = OperationTransferSection(
    module: module,
    schemaVersion: schemaVersion,
    records: values,
    sectionDigest: '0' * 64,
  );
  return OperationTransferSection(
    module: module,
    schemaVersion: schemaVersion,
    records: values,
    sectionDigest: OperationTransferCanonicalService.sectionDigest(draft),
  );
}

OperationTransferPackage fixturePackage({
  Iterable<OperationTransferSection>? sections,
  DateTime? createdAt,
}) {
  final timestamp = createdAt ?? DateTime.utc(2026, 8, 2, 12);
  final values = List<OperationTransferSection>.from(
    sections ?? [fixtureSection()],
  );
  final manifest = OperationTransferManifest(
    sectionCount: values.length,
    recordCount: values.fold(
      0,
      (total, section) => total + section.records.length,
    ),
    sectionSummaries: [
      for (final section in values)
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
    sourceCheckpoint: 'checkpoint-1',
    sourceLastFinalizedDate: '2026-08-01',
    sourceOperationDate: '2026-08-02',
    packageCreatedAt: timestamp,
  );
  final draft = OperationTransferPackage(
    packageId: '11111111-1111-4111-8111-111111111111',
    createdAt: timestamp,
    sourceApplicationVersion: '1.0.0+1',
    manifest: manifest,
    sections: values,
    packageDigest: '0' * 64,
  );
  return OperationTransferPackage(
    packageId: draft.packageId,
    createdAt: timestamp,
    sourceApplicationVersion: draft.sourceApplicationVersion,
    manifest: manifest,
    sections: values,
    packageDigest: OperationTransferCanonicalService.packageDigest(draft),
  );
}
