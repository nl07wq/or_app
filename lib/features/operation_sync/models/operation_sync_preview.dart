import 'operation_sync_issue.dart';
import 'operation_transfer_package.dart';

class OperationSyncPreview {
  final String packageId;
  final OperationTransferSourceType sourceType;
  final OperationTransferMode transferMode;
  final String schemaVersion;
  final DateTime createdAt;
  final int moduleCount;
  final int recordCount;
  final int createCount;
  final int noChangeCount;
  final int conflictCount;
  final int blockingIssueCount;
  final int warningCount;
  final int informationCount;
  final List<OperationSyncIssue> issues;
  final String packageDigest;

  OperationSyncPreview({
    required this.packageId,
    required this.sourceType,
    required this.transferMode,
    required this.schemaVersion,
    required this.createdAt,
    required this.moduleCount,
    required this.recordCount,
    required this.createCount,
    required this.noChangeCount,
    required this.conflictCount,
    required Iterable<OperationSyncIssue> issues,
    required this.packageDigest,
  }) : issues = List.unmodifiable(issues),
       blockingIssueCount = issues
           .where((issue) => issue.level == OperationSyncIssueLevel.blocking)
           .length,
       warningCount = issues
           .where((issue) => issue.level == OperationSyncIssueLevel.warning)
           .length,
       informationCount = issues
           .where((issue) => issue.level == OperationSyncIssueLevel.information)
           .length;

  bool get canApply => blockingIssueCount == 0;
}
