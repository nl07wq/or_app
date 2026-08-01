import '../models/orlo_sync_models.dart';
import 'orlo_sync_adapter.dart';
import 'orlo_sync_canonical_codec.dart';
import 'orlo_sync_parser.dart';
import 'orlo_sync_registry.dart';
import 'orlo_sync_validator.dart';

class OrloSyncGateway {
  OrloSyncGateway({
    this.parser = const OrloSyncParser(),
    OrloSyncTypeRegistry? registry,
    this.idempotencyChecker,
  }) : registry = registry ?? OrloSyncTypeRegistry();

  final OrloSyncParser parser;
  final OrloSyncTypeRegistry registry;
  final OrloSyncIdempotencyChecker? idempotencyChecker;

  factory OrloSyncGateway.production() =>
      OrloSyncGateway(registry: OrloSyncTypeRegistry.production());

  Future<SyncPreview> prepare(String rawText) async {
    final json = parser.parse(rawText);
    final output = OrloSyncValidator(registry).validate(json);
    final envelope = output.envelope;
    if (envelope == null) {
      throw OrloSyncValidationException(output.issues);
    }
    final digest = OrloSyncCanonicalCodec.digest(envelope.payload);
    final issues = [...output.issues];
    final adapter = registry.find(envelope.dataType)?.adapter;
    var counts = const SyncPreviewCounts();
    if (adapter != null) {
      issues.addAll(await adapter.validatePayload(envelope));
      issues.addAll(await adapter.detectConflicts(envelope));
      final checker = idempotencyChecker;
      if (checker != null) {
        issues.addAll(
          await checker.check(
            packageId: envelope.packageId,
            idempotencyKey: envelope.idempotencyKey,
            payloadDigest: digest,
          ),
        );
      }
      counts = await adapter.buildPreview(envelope);
    }
    return SyncPreview(
      envelope: envelope,
      payloadDigest: digest,
      validation: SyncValidationResult(List.unmodifiable(issues)),
      counts: counts,
    );
  }

  Future<SyncImportResult> apply({
    required SyncPreview preview,
    required String confirmedPayloadDigest,
  }) async {
    if (!preview.canImport || confirmedPayloadDigest != preview.payloadDigest) {
      throw StateError('Preview confirmation is invalid.');
    }
    final adapter = registry.find(preview.envelope.dataType)?.adapter;
    if (adapter == null) throw StateError('Sync adapter is unavailable.');
    final result = await adapter.applyAndVerify(
      envelope: preview.envelope,
      expectedPayloadDigest: preview.payloadDigest,
    );
    if (!result.success || result.payloadDigest != preview.payloadDigest) {
      return SyncImportResult(
        success: false,
        packageId: preview.envelope.packageId,
        payloadDigest: preview.payloadDigest,
        issues: [
          ...result.issues,
          const SyncIssue(
            code: 'readbackMismatch',
            path: r'$.payload',
            message: '保存後の読込検証に失敗しました。',
            severity: SyncIssueSeverity.blockingError,
          ),
        ],
      );
    }
    return result;
  }

  SyncQuarantineCandidate buildQuarantineCandidate({
    required String rawText,
    required List<SyncIssue> issues,
    OrloSyncEnvelope? envelope,
  }) => SyncQuarantineCandidate(
    packageId: envelope?.packageId,
    dataType: envelope?.dataType,
    schemaVersion: envelope?.schemaVersion,
    receivedAt: DateTime.now().toUtc(),
    issueCodes: List.unmodifiable(issues.map((issue) => issue.code).toSet()),
    rawDigest: OrloSyncCanonicalCodec.digest(rawText),
    summary: 'ORLO Sync validation failed (${issues.length} issues).',
  );
}

class OrloSyncValidationException implements Exception {
  const OrloSyncValidationException(this.issues);
  final List<SyncIssue> issues;
}
