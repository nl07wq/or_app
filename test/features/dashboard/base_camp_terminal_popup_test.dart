import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/engine/activity_summary.dart';
import 'package:or_app/core/services/device_settings_controller.dart';
import 'package:or_app/core/state/app_initialization_state.dart';
import 'package:or_app/data/indexed_db/indexed_db_store_names.dart';
import 'package:or_app/features/dashboard/widgets/backup_prompt_dialog.dart';
import 'package:or_app/features/dashboard/widgets/base_camp_finalize_day_dialog.dart';
import 'package:or_app/features/dashboard/widgets/daily_log_card.dart';
import 'package:or_app/features/import_export/services/backup_export_service.dart';
import 'package:or_app/features/import_export/services/backup_file_export_service.dart';
import 'package:or_app/features/import_export/services/backup_file_gateway.dart';
import 'package:or_app/features/operation_date/models/operation_local_date.dart';
import 'package:or_app/features/operation_date/models/operation_state.dart';
import 'package:or_app/features/themes/base_camp/base_camp_presentation.dart';
import 'package:or_app/features/themes/base_camp/widgets/base_camp_communication_motion.dart';
import 'package:or_app/features/themes/base_camp/widgets/base_camp_operation_panel.dart';
import 'package:or_app/features/themes/base_camp/widgets/base_camp_terminal_popup.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../repositories/indexed_db/fake_indexed_db_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await _loadFont('PressStart2P', 'assets/fonts/PressStart2P-Regular.ttf');
    await _loadFont('DotGothic16', 'assets/fonts/DotGothic16-Regular.ttf');
  });

  setUp(() {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    DeviceSettingsController.instance.resetForTesting(const DeviceSettings());
  });

  testWidgets(
    'FINALIZE confirmation stays open, blocks duplicates, and success holds 1.5 seconds',
    (tester) async {
      final operation = Completer<void>();
      var calls = 0;
      await _pumpBaseCampHost(
        tester,
        width: 320,
        child: Builder(
          builder: (context) => FilledButton(
            onPressed: () => showDialog<bool>(
              context: context,
              barrierDismissible: false,
              builder: (_) => BaseCampFinalizeDayDialog(
                onFinalize: () {
                  calls++;
                  return operation.future;
                },
              ),
            ),
            child: const Text('OPEN'),
          ),
        ),
      );

      await tester.tap(find.text('OPEN'));
      await tester.pumpAndSettle();
      expect(find.text('CONFIRM'), findsOneWidget);
      expect(find.text('本日の記録を確定します。'), findsOneWidget);

      await tester.tap(find.text('FINALIZE'));
      await tester.pump();
      expect(calls, 1);
      expect(find.text('PROCESSING'), findsOneWidget);
      expect(find.text('FINALIZE'), findsNothing);

      operation.complete();
      await tester.pump();
      expect(find.text('COMPLETE'), findsOneWidget);
      expect(find.text('本日の記録を確定しました。'), findsOneWidget);
      await tester.pump(
        baseCampTerminalSuccessHold - const Duration(milliseconds: 1),
      );
      expect(find.text('COMPLETE'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pumpAndSettle();
      expect(find.byType(BaseCampFinalizeDayDialog), findsNothing);
      expect(calls, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('FINALIZE failure remains until explicit close', (tester) async {
    await _pumpBaseCampHost(
      tester,
      child: Builder(
        builder: (context) => FilledButton(
          onPressed: () => showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (_) => BaseCampFinalizeDayDialog(
              onFinalize: () => Future<void>.error(StateError('disk failed')),
            ),
          ),
          child: const Text('OPEN'),
        ),
      ),
    );
    await tester.tap(find.text('OPEN'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('FINALIZE'));
    await tester.pumpAndSettle();
    expect(find.text('FAILED'), findsOneWidget);
    expect(find.textContaining('disk failed'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    expect(find.text('FAILED'), findsOneWidget);
    await tester.tap(find.text('CLOSE'));
    await tester.pumpAndSettle();
    expect(find.byType(BaseCampFinalizeDayDialog), findsNothing);
  });

  testWidgets('operation panel renders explicit lifecycle states', (
    tester,
  ) async {
    await _pumpBaseCampHost(
      tester,
      child: const BaseCampOperationPanel(
        title: 'SAVE STATUS',
        state: BaseCampOperationPanelState.confirmation,
        message: 'STATUSを保存しますか？',
      ),
    );
    expect(find.text('CONFIRM'), findsOneWidget);
    expect(find.text('STATUSを保存しますか？'), findsOneWidget);

    await _pumpBaseCampHost(
      tester,
      child: const BaseCampOperationPanel(
        title: 'SAVE STATUS',
        state: BaseCampOperationPanelState.processing,
        message: 'STATUSを保存しています。',
      ),
    );
    expect(find.text('PROCESSING'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('base-camp-terminal-popup-progress')),
      findsOneWidget,
    );

    await _pumpBaseCampHost(
      tester,
      child: const BaseCampOperationPanel(
        title: 'SAVE STATUS',
        state: BaseCampOperationPanelState.result,
        result: BaseCampOperationPanelResult.failure,
        message: 'STATUSの保存に失敗しました。',
      ),
    );
    expect(find.text('FAILED'), findsOneWidget);
    expect(find.text('STATUSの保存に失敗しました。'), findsOneWidget);
  });

  testWidgets(
    'BACKUP required and exporting persist until actual delivery succeeds',
    (tester) async {
      final delivery = Completer<BackupFileDelivery>();
      final gateway = _RecordingBackupGateway(pendingDelivery: delivery);
      await _pumpBackup(tester, gateway: gateway);
      expect(find.text('REQUIRED'), findsOneWidget);
      expect(find.text('最新のBACKUPを保存してください。'), findsOneWidget);

      await tester.tap(find.text('EXPORT BACKUP'));
      await tester.pump();
      expect(gateway.exportCount, 1);
      expect(find.text('EXPORTING'), findsOneWidget);
      expect(find.text('BACKUPを出力しています。'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      expect(find.text('EXPORTING'), findsOneWidget);
      expect(gateway.exportCount, 1);

      delivery.complete(BackupFileDelivery.shared);
      await _pumpUntil(tester, find.text('CONNECTING...'));
      await tester.pump(
        baseCampCommunicationConnectingDuration +
            baseCampCommunicationTransferDuration,
      );
      expect(find.text('COMPLETE'), findsOneWidget);
      await tester.pump(baseCampCommunicationCompletionHold);
      await tester.pump();
      expect(find.text('BACKUPを出力しました。'), findsOneWidget);
      await tester.pump(
        baseCampTerminalSuccessHold - const Duration(milliseconds: 1),
      );
      expect(find.text('BACKUPを出力しました。'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pumpAndSettle();
      expect(find.byType(BackupPromptDialog), findsNothing);
      expect(gateway.exportCount, 1);
    },
  );

  testWidgets('BACKUP failure shows actual error and never auto-dismisses', (
    tester,
  ) async {
    final gateway = _RecordingBackupGateway(
      failure: StateError('share failed'),
    );
    await _pumpBackup(tester, gateway: gateway, width: 320, negative: true);
    await tester.tap(find.text('EXPORT BACKUP'));
    await tester.pumpAndSettle();
    expect(find.text('FAILED'), findsOneWidget);
    expect(find.textContaining('share failed'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    expect(find.text('FAILED'), findsOneWidget);
    expect(find.text('RETRY'), findsOneWidget);
  });

  for (final width in <double>[320, 375, 390, 430]) {
    for (final negative in <bool>[false, true]) {
      testWidgets(
        'terminal popup is overflow-free at ${width.toInt()}dp ${negative ? 'INV' : 'LIGHT'}',
        (tester) async {
          await _pumpBaseCampHost(
            tester,
            width: width,
            negative: negative,
            child: const BaseCampTerminalPopup(
              title: 'FINALIZE DAY',
              stateLabel: 'FAILED',
              message: 'FINALIZE DAYに失敗しました。\n保存データを確認してから再度実行してください。',
              actions: <Widget>[
                BaseCampTerminalPopupButton(label: 'CLOSE', onPressed: null),
                BaseCampTerminalPopupButton(
                  label: 'COPY DIAGNOSTICS',
                  onPressed: null,
                  primary: true,
                ),
              ],
            ),
          );
          expect(tester.takeException(), isNull);
          expect(
            find.byKey(const ValueKey('base-camp-terminal-lcd-grid')),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('base-camp-terminal-popup')),
            findsOneWidget,
          );
        },
      );
    }
  }

  testWidgets('STANDARD keeps the existing AlertDialog presentation', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => FilledButton(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => BackupPromptDialog(
                exportService: _backupService(_RecordingBackupGateway()),
              ),
            ),
            child: const Text('OPEN'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('OPEN'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(
      find.byKey(const ValueKey('base-camp-terminal-popup')),
      findsNothing,
    );
  });

  testWidgets('operation panel remains reachable in a short landscape view', (
    tester,
  ) async {
    await _pumpBaseCampHost(
      tester,
      width: 568,
      height: 280,
      child: BaseCampOperationPanel(
        title: 'FINALIZE DAY',
        state: BaseCampOperationPanelState.result,
        result: BaseCampOperationPanelResult.failure,
        message:
            'FINALIZE DAYに失敗しました。\n'
            '保存データを確認してから安全に再度実行してください。',
        actions: <Widget>[
          BaseCampOperationPanelButton(label: 'CLOSE', onPressed: () {}),
          BaseCampOperationPanelButton(
            label: 'COPY DIAGNOSTICS',
            primary: true,
            onPressed: () {},
          ),
        ],
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('CLOSE'), findsOneWidget);
    expect(find.text('COPY DIAGNOSTICS'), findsOneWidget);
  });

  testWidgets('renders popup and communication screenshot evidence', (
    tester,
  ) async {
    final output = Platform.environment['OR_APP_POPUP_SCREENSHOT_DIR'];
    if (output == null || output.isEmpty) return;
    final directory = Directory(output)..createSync(recursive: true);
    final captureKey = GlobalKey();

    Future<void> capture(String name) => _capture(
      tester,
      captureKey,
      '${directory.path}${Platform.pathSeparator}$name.png',
    );

    final finalizePending = Completer<void>();
    await _pumpEvidenceSurface(
      tester,
      captureKey: captureKey,
      width: 320,
      background: const Padding(
        padding: EdgeInsets.all(12),
        child: Align(
          alignment: Alignment.topCenter,
          child: DailyLogCard(
            morningFact: null,
            foodSummary: null,
            activitySummary: ActivitySummary.empty(),
            trainingSummary: null,
            phase: OperationPhase.awaitingDebrief,
            finalizeReady: true,
            onPrimaryAction: null,
          ),
        ),
      ),
      child: BaseCampFinalizeDayDialog(
        key: const ValueKey('evidence-finalize-confirm'),
        onFinalize: () => finalizePending.future,
        successHold: const Duration(hours: 1),
      ),
    );
    await capture('finalize_confirm_320_light');
    await tester.tap(find.text('FINALIZE'));
    await tester.pump();
    expect(find.text('PROCESSING'), findsOneWidget);
    await capture('finalize_processing_320_light');
    finalizePending.complete();
    await tester.pump();
    expect(find.text('COMPLETE'), findsOneWidget);
    await capture('finalize_complete_320_light');

    await _pumpEvidenceSurface(
      tester,
      captureKey: captureKey,
      width: 390,
      negative: true,
      child: BaseCampFinalizeDayDialog(
        key: const ValueKey('evidence-finalize-failed'),
        onFinalize: () => Future<void>.error(StateError('保存処理に失敗しました')),
      ),
    );
    await tester.tap(find.text('FINALIZE'));
    await tester.pumpAndSettle();
    await capture('finalize_failed_390_inv');

    await _pumpEvidenceSurface(
      tester,
      captureKey: captureKey,
      width: 375,
      child: BackupPromptDialog(
        exportService: _backupService(_RecordingBackupGateway()),
      ),
    );
    await capture('backup_required_375_light');

    final pending = Completer<BackupFileDelivery>();
    await _pumpEvidenceSurface(
      tester,
      captureKey: captureKey,
      width: 390,
      negative: true,
      child: BackupPromptDialog(
        exportService: _backupService(
          _RecordingBackupGateway(pendingDelivery: pending),
        ),
      ),
    );
    await tester.tap(find.text('EXPORT BACKUP'));
    await tester.pump();
    await capture('backup_exporting_390_inv');

    await _pumpEvidenceSurface(
      tester,
      captureKey: captureKey,
      width: 430,
      child: BackupPromptDialog(
        key: const ValueKey('evidence-backup-complete'),
        exportService: _backupService(_RecordingBackupGateway()),
        successHold: const Duration(hours: 1),
      ),
    );
    await tester.tap(find.text('EXPORT BACKUP'));
    await _pumpUntil(tester, find.text('CONNECTING...'));
    await tester.pump(
      baseCampCommunicationConnectingDuration +
          baseCampCommunicationTransferDuration +
          baseCampCommunicationCompletionHold,
    );
    await tester.pump();
    expect(find.text('BACKUPを出力しました。'), findsOneWidget);
    await capture('backup_complete_430_light');

    await _pumpEvidenceSurface(
      tester,
      captureKey: captureKey,
      width: 320,
      negative: true,
      child: BackupPromptDialog(
        key: const ValueKey('evidence-backup-failed'),
        exportService: _backupService(
          _RecordingBackupGateway(failure: StateError('share failed')),
        ),
      ),
    );
    await tester.tap(find.text('EXPORT BACKUP'));
    await tester.pumpAndSettle();
    expect(find.text('FAILED'), findsOneWidget);
    await capture('backup_failed_320_inv');

    await _pumpEvidenceSurface(
      tester,
      captureKey: captureKey,
      width: 390,
      child: BaseCampOperationPanel(
        title: 'DAILY BRIEF',
        state: BaseCampOperationPanelState.confirmation,
        message: 'DAILY BRIEFを作成できます。\n今すぐ作成しますか？',
        actions: <Widget>[
          BaseCampOperationPanelButton(label: 'CANCEL', onPressed: () {}),
          BaseCampOperationPanelButton(
            label: 'CREATE',
            primary: true,
            onPressed: () {},
          ),
        ],
      ),
    );
    await capture('daily_brief_confirm_390_light');

    await _pumpEvidenceSurface(
      tester,
      captureKey: captureKey,
      width: 390,
      child: const BaseCampCommunicationMotion(
        kind: BaseCampCommunicationKind.dailyBrief,
        phase: BaseCampCommunicationPhase.success,
      ),
    );
    await _pumpUntil(tester, find.text('RECEIVED'));
    await capture('morning_brief_complete_390_light');

    await _pumpEvidenceSurface(
      tester,
      captureKey: captureKey,
      width: 390,
      negative: true,
      child: const BaseCampCommunicationMotion(
        kind: BaseCampCommunicationKind.dailyDebrief,
        phase: BaseCampCommunicationPhase.success,
      ),
    );
    await _pumpUntil(tester, find.text('RECEIVED'));
    await capture('daily_debrief_complete_390_inv');
  });
}

Future<void> _pumpBaseCampHost(
  WidgetTester tester, {
  required Widget child,
  double width = 390,
  double height = 800,
  bool negative = false,
}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  DeviceSettingsController.instance.update(
    DeviceSettingsController.instance.value.copyWith(
      baseCampLcdNegative: negative,
    ),
  );
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, appChild) => BaseCampScreenEntry(
        screen: BaseCampScreen.dashboard,
        child: appChild!,
      ),
      home: Scaffold(body: Center(child: child)),
    ),
  );
  await tester.pump();
}

Future<void> _pumpBackup(
  WidgetTester tester, {
  required _RecordingBackupGateway gateway,
  double width = 390,
  bool negative = false,
}) async {
  await _pumpBaseCampHost(
    tester,
    width: width,
    negative: negative,
    child: Builder(
      builder: (context) => FilledButton(
        onPressed: () => showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (_) =>
              BackupPromptDialog(exportService: _backupService(gateway)),
        ),
        child: const Text('OPEN'),
      ),
    ),
  );
  await tester.tap(find.text('OPEN'));
  await tester.pumpAndSettle();
}

Future<void> _pumpUntil(
  WidgetTester tester,
  Finder finder, {
  int limit = 30,
}) async {
  for (var index = 0; index < limit && finder.evaluate().isEmpty; index++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  expect(finder, findsOneWidget);
}

Future<void> _pumpEvidenceSurface(
  WidgetTester tester, {
  required GlobalKey captureKey,
  required double width,
  required Widget child,
  bool negative = false,
  Widget? background,
}) async {
  tester.view.physicalSize = Size(width, 800);
  tester.view.devicePixelRatio = 1;
  DeviceSettingsController.instance.update(
    DeviceSettingsController.instance.value.copyWith(
      baseCampLcdNegative: negative,
    ),
  );
  await tester.pumpWidget(
    RepaintBoundary(
      key: captureKey,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        builder: (context, appChild) => BaseCampScreenEntry(
          screen: BaseCampScreen.dashboard,
          child: appChild!,
        ),
        home: Scaffold(
          body: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              const ColoredBox(color: Color(0xff11170f)),
              background ??
                  const Center(
                    child: Text(
                      'BASE CAMP // OPERATIONS',
                      style: TextStyle(color: Color(0xff788a66)),
                    ),
                  ),
              Center(child: child),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _capture(
  WidgetTester tester,
  GlobalKey key,
  String outputPath,
) async {
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    await File(outputPath).writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
  });
}

BackupFileExportService _backupService(_RecordingBackupGateway gateway) {
  final database = FakeIndexedDbDatabase();
  final timestamp = DateTime.utc(2026, 11, 16);
  final state = OperationState(
    operationDate: OperationLocalDate.parse('2026-11-16'),
    createdAt: timestamp,
    updatedAt: timestamp,
  );
  database.seed(
    IndexedDbStoreNames.operationState,
    OperationState.canonicalId,
    state.toRecord(),
  );
  return BackupFileExportService(
    exportService: BackupExportService(
      database: database,
      controller: AppInitializationController()..markReady(),
      clock: () => DateTime(2026, 11, 16, 21, 35),
    ),
    fileGateway: gateway,
  );
}

class _RecordingBackupGateway implements BackupFileGateway {
  _RecordingBackupGateway({this.failure, this.pendingDelivery});

  Object? failure;
  final Completer<BackupFileDelivery>? pendingDelivery;
  int exportCount = 0;

  @override
  String get origin => 'https://example.test';

  @override
  Future<BackupFileDelivery> shareOrSave({
    required String fileName,
    required String content,
  }) async {
    exportCount++;
    if (failure case final failure?) throw failure;
    if (pendingDelivery case final delivery?) return delivery.future;
    return BackupFileDelivery.shared;
  }

  @override
  Future<BackupSelectedFile?> selectJson() async => null;
}

Future<void> _loadFont(String family, String asset) async {
  final bytes = File(asset).readAsBytesSync();
  final loader = FontLoader(family)
    ..addFont(Future<ByteData>.value(ByteData.sublistView(bytes)));
  await loader.load();
}
