import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/import_export/services/backup_file_gateway.dart';
import 'package:or_app/features/sync/models/orlo_sync_models.dart';
import 'package:or_app/features/sync/pages/orlo_sync_page.dart';
import 'package:or_app/features/sync/services/orlo_sync_adapter.dart';
import 'package:or_app/features/sync/services/orlo_sync_gateway.dart';
import 'package:or_app/features/sync/services/orlo_sync_registry.dart';

void main() {
  testWidgets(
    'shows idle, file, copy, invalid, and unavailable preview states',
    (tester) async {
      String? copied;
      await tester.pumpWidget(
        MaterialApp(
          home: OrloSyncPage(
            fileSelector: () async => BackupSelectedFile(
              name: 'sync.json',
              bytes: utf8.encode(_validRaw()),
            ),
            clipboardWriter: (value) async => copied = value,
          ),
        ),
      );
      expect(find.text('ORLO SYNC'), findsOneWidget);
      expect(find.text('PASTE SYNC DATA'), findsOneWidget);
      expect(find.text('IMPORT'), findsNothing);

      await tester.tap(find.text('COPY CHATGPT INSTRUCTION'));
      await tester.pump();
      expect(copied, contains('orlo-sync'));
      expect(find.text('Instructionをコピーしました。'), findsOneWidget);

      await tester.ensureVisible(find.text('PARSE'));
      await tester.tap(find.text('PARSE'));
      await tester.pumpAndSettle();
      expect(find.text('VALIDATION'), findsOneWidget);
      await tester.drag(
        find.byKey(const ValueKey('orlo-sync-content')),
        const Offset(0, -300),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('入力が空です'), findsOneWidget);
      expect(find.text('PREVIEW'), findsNothing);

      await tester.ensureVisible(find.text('SELECT FILE'));
      await tester.tap(find.text('SELECT FILE'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('PARSE'));
      await tester.tap(find.text('PARSE'));
      await tester.pumpAndSettle();
      await tester.drag(
        find.byKey(const ValueKey('orlo-sync-content')),
        const Offset(0, -500),
      );
      await tester.pumpAndSettle();
      expect(find.text('PREVIEW'), findsOneWidget);
      expect(find.textContaining('COMING LATER'), findsOneWidget);
      expect(find.text('Importできません。'), findsOneWidget);
      expect(find.text('IMPORT'), findsNothing);
    },
  );

  testWidgets('requires confirmation and shows success after verified apply', (
    tester,
  ) async {
    final gateway = OrloSyncGateway(
      registry: OrloSyncTypeRegistry(
        definitions: [
          OrloSyncTypeDefinition(
            id: 'training',
            displayName: 'TRAINING SYNC',
            schemaVersion: '1.0',
            adapter: _UiAdapter(),
          ),
        ],
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: OrloSyncPage(
          gateway: gateway,
          fileSelector: () async => BackupSelectedFile(
            name: 'sync.json',
            bytes: utf8.encode(_validRaw()),
          ),
          clipboardWriter: (_) async {},
        ),
      ),
    );
    await tester.tap(find.text('SELECT FILE'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('PARSE'));
    await tester.tap(find.text('PARSE'));
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const ValueKey('orlo-sync-content')),
      const Offset(0, -700),
    );
    await tester.pumpAndSettle();
    expect(find.text('IMPORT'), findsOneWidget);
    await tester.tap(find.text('IMPORT'));
    await tester.pumpAndSettle();
    expect(find.text('CONFIRM IMPORT'), findsOneWidget);
    await tester.tap(find.text('CONFIRM IMPORT'));
    await tester.pumpAndSettle();
    expect(find.text('ImportとRead-back Verificationが完了しました。'), findsOneWidget);
  });

  for (final width in [320.0, 390.0, 900.0, 1280.0]) {
    testWidgets('is overflow-free at ${width.toInt()}px in light and dark', (
      tester,
    ) async {
      for (final theme in [ThemeData.light(), ThemeData.dark()]) {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: OrloSyncPage(
              fileSelector: () async => null,
              clipboardWriter: (_) async {},
            ),
          ),
        );
        expect(tester.takeException(), isNull);
      }
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    });
  }
}

String _validRaw() => jsonEncode({
  'format': 'orlo-sync',
  'envelopeVersion': 1,
  'schemaVersion': '1.0',
  'dataType': 'training',
  'packageId': 'pkg',
  'idempotencyKey': 'key',
  'source': {
    'type': 'test',
    'generatedAt': '2026-08-01T00:00:00.000Z',
    'producer': 'test',
    'producerVersion': null,
  },
  'operationDate': '2026-08-01',
  'payload': <String, Object?>{},
});

class _UiAdapter implements OrloSyncAdapter {
  @override
  String get dataType => 'training';
  @override
  String get schemaVersion => '1.0';
  @override
  String buildChatGptPayloadInstruction() => '';
  @override
  Future<SyncPreviewCounts> buildPreview(OrloSyncEnvelope envelope) async =>
      const SyncPreviewCounts(records: 1, create: 1);
  @override
  Future<List<SyncIssue>> detectConflicts(OrloSyncEnvelope envelope) async =>
      const [];
  @override
  Future<List<SyncIssue>> validatePayload(OrloSyncEnvelope envelope) async =>
      const [];
  @override
  Future<SyncImportResult> applyAndVerify({
    required OrloSyncEnvelope envelope,
    required String expectedPayloadDigest,
  }) async => SyncImportResult(
    success: true,
    packageId: envelope.packageId,
    payloadDigest: expectedPayloadDigest,
    issues: const [],
  );
}
