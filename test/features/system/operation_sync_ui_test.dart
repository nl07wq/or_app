import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/import_export/services/backup_file_gateway.dart';
import 'package:or_app/features/operation_sync/models/operation_sync_history.dart';
import 'package:or_app/features/operation_sync/models/operation_sync_issue.dart';
import 'package:or_app/features/operation_sync/models/operation_sync_preview.dart';
import 'package:or_app/features/operation_sync/models/operation_sync_state.dart';
import 'package:or_app/features/operation_sync/services/operation_sync_transfer_coordinator.dart';
import 'package:or_app/features/system/pages/operation_sync_page.dart';

import '../operation_sync/operation_transfer_test_fixture.dart';

void main() {
  testWidgets('formal transfer flow exports, previews, applies, and verifies', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final workflow = _FakeWorkflow();

    await tester.pumpWidget(
      MaterialApp(home: OperationSyncPage(workflow: workflow)),
    );
    await tester.pumpAndSettle();

    expect(find.text('AVAILABLE'), findsNothing);
    expect(find.text('ARCHIVE'), findsNothing);
    expect(find.text('COMING LATER'), findsNothing);
    expect(find.text('OPERATION SYNC'), findsOneWidget);
    expect(find.text('TRANSFER PACKAGE'), findsOneWidget);
    expect(find.text('TRANSFER STEP'), findsOneWidget);
    for (final stage in [
      'SELECT TRANSFER PACKAGE',
      'VALIDATION',
      'PREVIEW',
      'APPLY',
      'VERIFY',
      'COMPLETE',
    ]) {
      expect(
        find.text(stage),
        stage == 'SELECT TRANSFER PACKAGE' ? findsNWidgets(2) : findsOneWidget,
      );
    }

    await tester.tap(find.text('EXPORT TRANSFER PACKAGE'));
    await tester.pumpAndSettle();
    expect(workflow.exportCalls, 1);
    expect(find.textContaining('TRANSFER PACKAGE READY'), findsOneWidget);

    await tester.tap(find.text('SELECT TRANSFER PACKAGE').last);
    await tester.pumpAndSettle();
    expect(
      find.text('PACKAGE VALIDATED · 適用前に内容を確認してください'),
      findsOneWidget,
    );
    expect(find.text('CREATE: 1'), findsOneWidget);
    expect(find.text('NO CHANGES: 0'), findsOneWidget);
    expect(find.text('CONFLICT: 0'), findsOneWidget);

    await tester.ensureVisible(find.text('APPLY TRANSFER'));
    await tester.tap(find.text('APPLY TRANSFER'));
    await tester.pumpAndSettle();
    expect(find.text('APPLY TRANSFER?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'APPLY'));
    await tester.pumpAndSettle();

    expect(workflow.applyCalls, 1);
    expect(find.text('READ-BACK VERIFIED · TRANSFER COMPLETE'), findsOneWidget);
    expect(find.text('SUCCESS'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('OPERATION SYNC RECORD'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('OPERATION SYNC RECORD'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('view-all-operation-sync-records')),
      findsOneWidget,
    );
    await tester.tap(find.text('SUCCESS').last);
    await tester.pumpAndSettle();
    expect(find.text('OPERATION ID'), findsOneWidget);
    expect(find.text('operation-sync:test'), findsOneWidget);
  });

  testWidgets('blocking conflicts are explicit and cannot be applied', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final issue = const OperationSyncIssue(
      level: OperationSyncIssueLevel.blocking,
      code: OperationSyncIssueCode.recordIdConflict,
      message: 'Record conflicts with target state.',
      module: 'status',
      recordId: 'status-1',
    );
    final workflow = _FakeWorkflow(issues: [issue], conflictCount: 1);

    await tester.pumpWidget(
      MaterialApp(home: OperationSyncPage(workflow: workflow)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('SELECT TRANSFER PACKAGE').last);
    await tester.pumpAndSettle();

    expect(find.textContaining('VALIDATION BLOCKED'), findsOneWidget);
    expect(find.textContaining('recordIdConflict'), findsOneWidget);
    final apply = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'APPLY TRANSFER'),
    );
    expect(apply.onPressed, isNull);
  });

  testWidgets('recovery requires the locked package and offers resume', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final workflow = _FakeWorkflow(recoveryRequired: true);

    await tester.pumpWidget(
      MaterialApp(home: OperationSyncPage(workflow: workflow)),
    );
    await tester.pumpAndSettle();

    expect(find.text('RECOVERY REQUIRED'), findsOneWidget);
    expect(find.text('RESELECT PACKAGE TO RESUME'), findsOneWidget);
    expect(find.textContaining('Checkpoint: applying'), findsOneWidget);
    await tester.tap(find.text('RESELECT PACKAGE TO RESUME'));
    await tester.pumpAndSettle();
    expect(find.text('RESUME TRANSFER'), findsOneWidget);
  });

  testWidgets('Historical Import pages do not expose Operation Sync records', (
    tester,
  ) async {
    for (final page in const [
      HistoricalTrainingImportPage(),
      HistoricalDnsImportPage(),
    ]) {
      await tester.pumpWidget(MaterialApp(home: page));
      await tester.pump();
      expect(find.text('OPERATION SYNC RECORD'), findsNothing);
    }
  });

  for (final width in [320.0, 390.0, 900.0, 1280.0]) {
    testWidgets('Operation Sync is overflow-free at ${width.toInt()}px', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      for (final theme in [ThemeData.light(), ThemeData.dark()]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: OperationSyncPage(workflow: _FakeWorkflow()),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    });
  }
}

class _FakeWorkflow implements OperationSyncWorkflow {
  _FakeWorkflow({
    this.issues = const [],
    this.conflictCount = 0,
    this.recoveryRequired = false,
  });

  final List<OperationSyncIssue> issues;
  final int conflictCount;
  final bool recoveryRequired;
  int exportCalls = 0;
  int applyCalls = 0;
  bool completed = false;

  late final package = fixturePackage();

  OperationSyncState get _state => OperationSyncState(
    revision: 1,
    phase: completed
        ? OperationSyncPhase.completed
        : recoveryRequired
        ? OperationSyncPhase.recoveryRequired
        : OperationSyncPhase.idle,
    operationId: recoveryRequired || completed ? 'operation-sync:test' : null,
    packageId: recoveryRequired || completed ? package.packageId : null,
    packageDigest: recoveryRequired || completed ? package.packageDigest : null,
    sourceType: recoveryRequired || completed ? 'currentAppTransfer' : null,
    transferMode: recoveryRequired || completed ? 'fullTransfer' : null,
    startedAt: recoveryRequired || completed
        ? DateTime.utc(2026, 8, 2, 9)
        : null,
    checkpoint: recoveryRequired
        ? OperationSyncCheckpoint(
            validatedPackageDigest: package.packageDigest,
            expectedSectionDigests: {
              for (final section in package.sections)
                section.module: section.sectionDigest,
            },
            expectedRecordDigests: [
              for (final section in package.sections)
                for (final record in section.records) record.recordDigest,
            ],
            appliedSectionIds: const [],
            verificationStatus: 'applying',
          )
        : null,
    updatedAt: DateTime.utc(2026, 8, 2, 10),
  );

  OperationSyncPreview get _preview => OperationSyncPreview(
    packageId: package.packageId,
    sourceType: package.sourceType,
    transferMode: package.transferMode,
    schemaVersion: package.schemaVersion,
    createdAt: package.createdAt,
    moduleCount: package.sections.length,
    recordCount: package.manifest.recordCount,
    createCount: conflictCount == 0 ? 1 : 0,
    noChangeCount: 0,
    conflictCount: conflictCount,
    issues: issues,
    packageDigest: package.packageDigest,
  );

  @override
  Future<OperationSyncExportOutcome> exportPackage() async {
    exportCalls++;
    return OperationSyncExportOutcome(
      package: package,
      fileName: 'operation_reboot_transfer.json',
      delivery: BackupFileDelivery.downloaded,
    );
  }

  @override
  Future<OperationSyncWorkspace> load() async => OperationSyncWorkspace(
    state: _state,
    history: completed
        ? [
            OperationSyncHistory(
              operationId: 'operation-sync:test',
              packageId: package.packageId,
              packageDigest: package.packageDigest,
              sourceType: 'currentAppTransfer',
              transferMode: 'fullTransfer',
              startedAt: DateTime.utc(2026, 8, 2, 9),
              completedAt: DateTime.utc(2026, 8, 2, 10),
              moduleIds: const ['fixture'],
              recordCount: 1,
              createCount: 1,
              noChangeCount: 0,
              conflictCount: 0,
              quarantineCount: 0,
              result: OperationSyncHistoryResult.success,
              isRecoveryExecution: recoveryRequired,
            ),
          ]
        : const [],
  );

  @override
  Future<OperationSyncSelection?> selectAndPreview() async =>
      OperationSyncSelection(
        fileName: 'transfer.json',
        fileSize: 2048,
        package: package,
        preview: _preview,
        isRecovery: recoveryRequired,
      );

  @override
  Future<void> apply(OperationSyncSelection selection) async {
    applyCalls++;
    completed = true;
  }
}
