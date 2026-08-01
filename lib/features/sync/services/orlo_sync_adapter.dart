import '../models/orlo_sync_models.dart';

abstract interface class OrloSyncAdapter {
  String get dataType;
  String get schemaVersion;

  Future<List<SyncIssue>> validatePayload(OrloSyncEnvelope envelope);
  Future<SyncPreviewCounts> buildPreview(OrloSyncEnvelope envelope);
  Future<List<SyncIssue>> detectConflicts(OrloSyncEnvelope envelope);

  /// Implementations must write atomically, read back from the formal
  /// repository, compare canonical content, and roll back on mismatch.
  Future<SyncImportResult> applyAndVerify({
    required OrloSyncEnvelope envelope,
    required String expectedPayloadDigest,
  });

  String buildChatGptPayloadInstruction();
}

abstract interface class OrloSyncIdempotencyChecker {
  Future<List<SyncIssue>> check({
    required String packageId,
    required String idempotencyKey,
    required String payloadDigest,
  });
}

class OrloSyncImportIdentity {
  const OrloSyncImportIdentity({
    required this.packageId,
    required this.idempotencyKey,
    required this.payloadDigest,
  });

  final String packageId;
  final String idempotencyKey;
  final String payloadDigest;
}

abstract final class OrloSyncIdempotencyEvaluator {
  static List<SyncIssue> evaluate({
    required Iterable<OrloSyncImportIdentity> existing,
    required OrloSyncImportIdentity incoming,
  }) {
    final issues = <SyncIssue>[];
    for (final value in existing) {
      if (value.packageId == incoming.packageId &&
          value.idempotencyKey == incoming.idempotencyKey &&
          value.payloadDigest == incoming.payloadDigest) {
        return const [
          SyncIssue(
            code: 'duplicatePackage',
            path: r'$.packageId',
            message: '同一PackageはImport済みです。',
            severity: SyncIssueSeverity.blockingError,
          ),
        ];
      }
      if (value.packageId == incoming.packageId) {
        issues.add(
          const SyncIssue(
            code: 'packageIdConflict',
            path: r'$.packageId',
            message: 'Package IDが既存Importと競合します。',
            severity: SyncIssueSeverity.conflict,
          ),
        );
      } else if (value.idempotencyKey == incoming.idempotencyKey &&
          value.payloadDigest != incoming.payloadDigest) {
        issues.add(
          const SyncIssue(
            code: 'idempotencyConflict',
            path: r'$.idempotencyKey',
            message: '同じIdempotency Keyに異なるPayloadがあります。',
            severity: SyncIssueSeverity.conflict,
          ),
        );
      } else if (value.idempotencyKey != incoming.idempotencyKey &&
          value.payloadDigest == incoming.payloadDigest) {
        issues.add(
          const SyncIssue(
            code: 'duplicatePayload',
            path: r'$.payload',
            message: '同一Payloadが別KeyでImport済みです。',
            severity: SyncIssueSeverity.warning,
          ),
        );
      }
    }
    return List.unmodifiable(issues);
  }
}
