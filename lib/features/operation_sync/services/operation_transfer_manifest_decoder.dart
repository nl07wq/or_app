import '../models/operation_sync_issue.dart';
import '../models/operation_transfer_package.dart';
import 'operation_transfer_decode_support.dart';

abstract final class OperationTransferManifestDecoder {
  static OperationTransferManifest decode(Map<String, Object?> json) {
    OperationTransferDecodeSupport.expectKeys(json, const {
      'sectionCount',
      'recordCount',
      'sectionSummaries',
      'sourceCheckpoint',
      'sourceLastFinalizedDate',
      'sourceOperationDate',
      'packageCreatedAt',
    });
    final summaries = [
      for (final value in OperationTransferDecodeSupport.list(
        json,
        'sectionSummaries',
      ))
        _decodeSummary(
          OperationTransferDecodeSupport.object(value, 'sectionSummary'),
        ),
    ];
    return OperationTransferManifest(
      sectionCount: OperationTransferDecodeSupport.nonNegativeInt(
        json,
        'sectionCount',
      ),
      recordCount: OperationTransferDecodeSupport.nonNegativeInt(
        json,
        'recordCount',
      ),
      sectionSummaries: summaries,
      sourceCheckpoint: OperationTransferDecodeSupport.string(
        json,
        'sourceCheckpoint',
      ),
      sourceLastFinalizedDate: json['sourceLastFinalizedDate'] == null
          ? null
          : OperationTransferDecodeSupport.localDate(
              json,
              'sourceLastFinalizedDate',
            ),
      sourceOperationDate: OperationTransferDecodeSupport.localDate(
        json,
        'sourceOperationDate',
      ),
      packageCreatedAt: OperationTransferDecodeSupport.timestamp(
        json,
        'packageCreatedAt',
      ),
    );
  }

  static void validate(
    OperationTransferManifest manifest,
    List<OperationTransferSection> sections,
    int totalRecords,
  ) {
    if (manifest.sectionCount != sections.length ||
        manifest.recordCount != totalRecords ||
        manifest.sectionSummaries.length != sections.length) {
      throw const OperationSyncException(
        OperationSyncIssueCode.integrityFailure,
        'Operation Transfer manifest counts do not match.',
      );
    }
    for (var index = 0; index < sections.length; index++) {
      final section = sections[index];
      final summary = manifest.sectionSummaries[index];
      final versions =
          section.records.map((record) => record.recordVersion).toSet().toList()
            ..sort();
      if (summary.module != section.module ||
          summary.recordCount != section.records.length ||
          summary.sectionDigest != section.sectionDigest ||
          !_listsEqual(summary.recordVersionSet, versions)) {
        throw const OperationSyncException(
          OperationSyncIssueCode.integrityFailure,
          'Operation Transfer manifest section summary does not match.',
        );
      }
    }
  }

  static OperationTransferSectionSummary _decodeSummary(
    Map<String, Object?> json,
  ) {
    OperationTransferDecodeSupport.expectKeys(json, const {
      'module',
      'recordVersionSet',
      'recordCount',
      'sectionDigest',
    });
    final rawVersions = OperationTransferDecodeSupport.list(
      json,
      'recordVersionSet',
    );
    if (rawVersions.any((value) => value is! int || value < 1)) {
      throw const OperationSyncException(
        OperationSyncIssueCode.versionUnsupported,
        'Manifest record version set is invalid.',
      );
    }
    final versions = rawVersions.cast<int>();
    if (versions.toSet().length != versions.length || !_isAscending(versions)) {
      throw const OperationSyncException(
        OperationSyncIssueCode.integrityFailure,
        'Manifest record version set must be sorted and unique.',
      );
    }
    return OperationTransferSectionSummary(
      module: OperationTransferDecodeSupport.string(json, 'module'),
      recordVersionSet: versions,
      recordCount: OperationTransferDecodeSupport.nonNegativeInt(
        json,
        'recordCount',
      ),
      sectionDigest: OperationTransferDecodeSupport.digest(
        json,
        'sectionDigest',
      ),
    );
  }

  static bool _isAscending(List<int> values) {
    for (var index = 1; index < values.length; index++) {
      if (values[index - 1] >= values[index]) return false;
    }
    return true;
  }

  static bool _listsEqual(List<int> first, List<int> second) {
    if (first.length != second.length) return false;
    for (var index = 0; index < first.length; index++) {
      if (first[index] != second[index]) return false;
    }
    return true;
  }
}
