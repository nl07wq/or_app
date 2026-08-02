import '../models/operation_sync_issue.dart';
import '../models/operation_transfer_package.dart';
import 'operation_transfer_canonical_service.dart';
import 'operation_transfer_decode_support.dart';
import 'operation_transfer_manifest_decoder.dart';

abstract final class OperationTransferJsonDecoder {
  static OperationTransferPackage decode(Map<String, Object?> json) {
    OperationTransferDecodeSupport.expectKeys(json, const {
      'format',
      'envelopeVersion',
      'schemaVersion',
      'packageId',
      'createdAt',
      'sourceApplication',
      'sourceApplicationVersion',
      'sourceType',
      'transferMode',
      'manifest',
      'sections',
      'packageDigest',
    });
    _validateEnvelope(json);
    final rawSections = OperationTransferDecodeSupport.list(json, 'sections');
    if (rawSections.length > OperationTransferDecodeSupport.maxSectionCount) {
      throw const OperationSyncException(
        OperationSyncIssueCode.recordLimitExceeded,
        'Operation Transfer section limit exceeded.',
      );
    }
    var declaredRecordCount = 0;
    for (final rawSection in rawSections) {
      final sectionJson = OperationTransferDecodeSupport.object(
        rawSection,
        'section',
      );
      declaredRecordCount += OperationTransferDecodeSupport.list(
        sectionJson,
        'records',
      ).length;
      if (declaredRecordCount >
          OperationTransferDecodeSupport.maxPackageRecords) {
        throw const OperationSyncException(
          OperationSyncIssueCode.recordLimitExceeded,
          'Operation Transfer package record limit exceeded.',
        );
      }
    }
    final sections = <OperationTransferSection>[];
    final modules = <String>{};
    var totalRecords = 0;
    for (final rawSection in rawSections) {
      final section = _decodeSection(
        OperationTransferDecodeSupport.object(rawSection, 'section'),
      );
      if (!modules.add(section.module)) {
        throw const OperationSyncException(
          OperationSyncIssueCode.integrityFailure,
          'Operation Transfer contains a duplicate module section.',
        );
      }
      totalRecords += section.records.length;
      if (totalRecords > OperationTransferDecodeSupport.maxPackageRecords) {
        throw const OperationSyncException(
          OperationSyncIssueCode.recordLimitExceeded,
          'Operation Transfer package record limit exceeded.',
        );
      }
      sections.add(section);
    }
    final manifest = OperationTransferManifestDecoder.decode(
      OperationTransferDecodeSupport.map(json, 'manifest'),
    );
    OperationTransferManifestDecoder.validate(manifest, sections, totalRecords);
    final createdAt = OperationTransferDecodeSupport.timestamp(
      json,
      'createdAt',
    );
    if (manifest.packageCreatedAt != createdAt) {
      throw const OperationSyncException(
        OperationSyncIssueCode.integrityFailure,
        'Manifest packageCreatedAt does not match the envelope.',
      );
    }
    final package = OperationTransferPackage(
      packageId: OperationTransferDecodeSupport.uuid(json, 'packageId'),
      createdAt: createdAt,
      sourceApplicationVersion: OperationTransferDecodeSupport.string(
        json,
        'sourceApplicationVersion',
      ),
      sourceType: OperationTransferDecodeSupport.stableEnum(
        OperationTransferSourceType.values,
        json['sourceType'],
        (value) => value.stableId,
        'sourceType',
      ),
      transferMode: OperationTransferDecodeSupport.stableEnum(
        OperationTransferMode.values,
        json['transferMode'],
        (value) => value.stableId,
        'transferMode',
      ),
      manifest: manifest,
      sections: sections,
      packageDigest: OperationTransferDecodeSupport.digest(
        json,
        'packageDigest',
      ),
    );
    if (OperationTransferCanonicalService.packageDigest(package) !=
        package.packageDigest) {
      throw const OperationSyncException(
        OperationSyncIssueCode.packageDigestMismatch,
        'Operation Transfer package digest does not match.',
      );
    }
    return package;
  }

  static void _validateEnvelope(Map<String, Object?> json) {
    if (json['format'] != OperationTransferPackage.formatName ||
        json['envelopeVersion'] !=
            OperationTransferPackage.currentEnvelopeVersion ||
        json['schemaVersion'] !=
            OperationTransferPackage.currentSchemaVersion ||
        json['sourceApplication'] !=
            OperationTransferPackage.sourceApplicationName) {
      throw const OperationSyncException(
        OperationSyncIssueCode.versionUnsupported,
        'Operation Transfer envelope version is unsupported.',
      );
    }
  }

  static OperationTransferSection _decodeSection(Map<String, Object?> json) {
    OperationTransferDecodeSupport.expectKeys(json, const {
      'module',
      'schemaVersion',
      'records',
      'sectionDigest',
    });
    final rawRecords = OperationTransferDecodeSupport.list(json, 'records');
    if (rawRecords.length >
        OperationTransferDecodeSupport.maxRecordsPerSection) {
      throw const OperationSyncException(
        OperationSyncIssueCode.recordLimitExceeded,
        'Operation Transfer section record limit exceeded.',
      );
    }
    final records = <OperationTransferRecord>[];
    final ids = <String>{};
    for (final rawRecord in rawRecords) {
      final record = _decodeRecord(
        OperationTransferDecodeSupport.object(rawRecord, 'record'),
      );
      if (!ids.add(record.recordId)) {
        throw const OperationSyncException(
          OperationSyncIssueCode.integrityFailure,
          'Operation Transfer section contains a duplicate record ID.',
        );
      }
      records.add(record);
    }
    final section = OperationTransferSection(
      module: OperationTransferDecodeSupport.string(json, 'module'),
      schemaVersion: OperationTransferDecodeSupport.string(
        json,
        'schemaVersion',
      ),
      records: records,
      sectionDigest: OperationTransferDecodeSupport.digest(
        json,
        'sectionDigest',
      ),
    );
    if (OperationTransferCanonicalService.sectionDigest(section) !=
        section.sectionDigest) {
      throw const OperationSyncException(
        OperationSyncIssueCode.sectionDigestMismatch,
        'Operation Transfer section digest does not match.',
      );
    }
    return section;
  }

  static OperationTransferRecord _decodeRecord(Map<String, Object?> json) {
    OperationTransferDecodeSupport.expectKeys(json, const {
      'recordId',
      'recordVersion',
      'localDate',
      'canonicalPayload',
      'recordDigest',
    });
    final version = json['recordVersion'];
    if (version is! int || version < 1) {
      throw const OperationSyncException(
        OperationSyncIssueCode.versionUnsupported,
        'Operation Transfer record version is unsupported.',
      );
    }
    final record = OperationTransferRecord(
      recordId: OperationTransferDecodeSupport.string(json, 'recordId'),
      recordVersion: version,
      localDate: OperationTransferDecodeSupport.localDate(json, 'localDate'),
      canonicalPayload: OperationTransferDecodeSupport.map(
        json,
        'canonicalPayload',
      ),
      recordDigest: OperationTransferDecodeSupport.digest(json, 'recordDigest'),
    );
    if (OperationTransferCanonicalService.recordDigest(record) !=
        record.recordDigest) {
      throw const OperationSyncException(
        OperationSyncIssueCode.recordDigestMismatch,
        'Operation Transfer record digest does not match.',
      );
    }
    return record;
  }
}
