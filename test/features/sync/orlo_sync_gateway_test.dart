import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/sync/models/orlo_sync_models.dart';
import 'package:or_app/features/sync/services/orlo_sync_adapter.dart';
import 'package:or_app/features/sync/services/orlo_sync_gateway.dart';
import 'package:or_app/features/sync/services/orlo_sync_canonical_codec.dart';
import 'package:or_app/features/sync/services/orlo_sync_registry.dart';

void main() {
  test('canonical payload digest is stable across map key order', () {
    expect(
      OrloSyncCanonicalCodec.digest({'a': 1, 'b': 2}),
      OrloSyncCanonicalCodec.digest({'b': 2, 'a': 1}),
    );
  });

  test('classifies duplicate and conflicting import identities', () {
    const prior = OrloSyncImportIdentity(
      packageId: 'package-a',
      idempotencyKey: 'key-a',
      payloadDigest: 'digest-a',
    );
    List<String> codes(OrloSyncImportIdentity incoming) =>
        OrloSyncIdempotencyEvaluator.evaluate(
          existing: const [prior],
          incoming: incoming,
        ).map((issue) => issue.code).toList();

    expect(codes(prior), ['duplicatePackage']);
    expect(
      codes(
        const OrloSyncImportIdentity(
          packageId: 'package-b',
          idempotencyKey: 'key-a',
          payloadDigest: 'digest-b',
        ),
      ),
      ['idempotencyConflict'],
    );
    expect(
      codes(
        const OrloSyncImportIdentity(
          packageId: 'package-b',
          idempotencyKey: 'key-b',
          payloadDigest: 'digest-a',
        ),
      ),
      ['duplicatePayload'],
    );
  });
  test(
    'builds preview with adapter, conflict, warning, and information issues',
    () async {
      final adapter = _Adapter();
      final gateway = OrloSyncGateway(
        registry: _registry(adapter),
        idempotencyChecker: const _IdempotencyChecker(),
      );
      final preview = await gateway.prepare(_raw());

      expect(preview.counts.records, 2);
      expect(preview.counts.create, 1);
      expect(preview.counts.noOp, 1);
      expect(
        preview.validation.issues.map((issue) => issue.severity),
        containsAll([SyncIssueSeverity.warning, SyncIssueSeverity.information]),
      );
      expect(preview.canImport, isTrue);
    },
  );

  test(
    'requires the exact preview digest and verifies read-back result',
    () async {
      final adapter = _Adapter();
      final gateway = OrloSyncGateway(registry: _registry(adapter));
      final preview = await gateway.prepare(_raw());
      expect(
        () => gateway.apply(preview: preview, confirmedPayloadDigest: 'other'),
        throwsStateError,
      );
      final result = await gateway.apply(
        preview: preview,
        confirmedPayloadDigest: preview.payloadDigest,
      );
      expect(result.success, isTrue);
      expect(adapter.applyCalls, 1);
    },
  );

  test(
    'turns read-back mismatch into failure and quarantine candidate',
    () async {
      final adapter = _Adapter(mismatch: true);
      final gateway = OrloSyncGateway(registry: _registry(adapter));
      final preview = await gateway.prepare(_raw());
      final result = await gateway.apply(
        preview: preview,
        confirmedPayloadDigest: preview.payloadDigest,
      );
      expect(result.success, isFalse);
      expect(
        result.issues.map((issue) => issue.code),
        contains('readbackMismatch'),
      );
      final candidate = gateway.buildQuarantineCandidate(
        rawText: _raw(),
        issues: result.issues,
        envelope: preview.envelope,
      );
      expect(candidate.packageId, 'pkg-1');
      expect(candidate.rawDigest, hasLength(8));
    },
  );
}

OrloSyncTypeRegistry _registry(OrloSyncAdapter adapter) => OrloSyncTypeRegistry(
  definitions: [
    OrloSyncTypeDefinition(
      id: 'training',
      displayName: 'TRAINING SYNC',
      schemaVersion: '1.0',
      adapter: adapter,
    ),
  ],
);

String _raw() => jsonEncode({
  'format': 'orlo-sync',
  'envelopeVersion': 1,
  'schemaVersion': '1.0',
  'dataType': 'training',
  'packageId': 'pkg-1',
  'idempotencyKey': 'key-1',
  'source': {
    'type': 'test',
    'generatedAt': '2026-08-01T00:00:00.000Z',
    'producer': 'test',
    'producerVersion': null,
  },
  'operationDate': '2026-08-01',
  'payload': {'records': []},
});

class _Adapter implements OrloSyncAdapter {
  _Adapter({this.mismatch = false});
  final bool mismatch;
  int applyCalls = 0;

  @override
  String get dataType => 'training';
  @override
  String get schemaVersion => '1.0';
  @override
  String buildChatGptPayloadInstruction() => 'payload';
  @override
  Future<SyncPreviewCounts> buildPreview(OrloSyncEnvelope envelope) async =>
      const SyncPreviewCounts(records: 2, create: 1, noOp: 1);
  @override
  Future<List<SyncIssue>> detectConflicts(OrloSyncEnvelope envelope) async => [
    const SyncIssue(
      code: 'recordCount',
      path: r'$.payload',
      message: '2 records',
      severity: SyncIssueSeverity.information,
    ),
  ];
  @override
  Future<List<SyncIssue>> validatePayload(OrloSyncEnvelope envelope) async => [
    const SyncIssue(
      code: 'reviewRequired',
      path: r'$.payload',
      message: '確認してください。',
      severity: SyncIssueSeverity.warning,
    ),
  ];
  @override
  Future<SyncImportResult> applyAndVerify({
    required OrloSyncEnvelope envelope,
    required String expectedPayloadDigest,
  }) async {
    applyCalls++;
    return SyncImportResult(
      success: true,
      packageId: envelope.packageId,
      payloadDigest: mismatch ? 'mismatch' : expectedPayloadDigest,
      issues: const [],
    );
  }
}

class _IdempotencyChecker implements OrloSyncIdempotencyChecker {
  const _IdempotencyChecker();
  @override
  Future<List<SyncIssue>> check({
    required String packageId,
    required String idempotencyKey,
    required String payloadDigest,
  }) async => const [];
}
