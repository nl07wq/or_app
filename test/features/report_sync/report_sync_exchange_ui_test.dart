import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/models/food_item.dart';
import 'package:or_app/core/models/meal_data.dart';
import 'package:or_app/features/import_export/services/backup_file_gateway.dart';
import 'package:or_app/features/operation_sync/models/operation_sync_history.dart';
import 'package:or_app/features/operation_sync/services/historical_training_workflow.dart';
import 'package:or_app/features/report_sync/models/report_sync_envelope.dart';
import 'package:or_app/features/report_sync/models/report_sync_history.dart';
import 'package:or_app/features/report_sync/models/report_sync_issue.dart';
import 'package:or_app/features/report_sync/models/status_report_sync_source.dart';
import 'package:or_app/features/report_sync/pages/report_sync_exchange_page.dart';
import 'package:or_app/features/report_sync/services/report_sync_canonical_service.dart';
import 'package:or_app/features/report_sync/services/report_sync_clipboard_gateway.dart';
import 'package:or_app/features/report_sync/services/report_sync_codec.dart';
import 'package:or_app/features/report_sync/services/report_sync_exchange_gateway.dart';

void main() {
  testWidgets('daily debrief eligible date selection reports the new target', (
    tester,
  ) async {
    final selectedDates = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: ReportSyncExchangePage(
          exchangeType: ReportSyncExchangeType.dailyDebrief,
          gateway: _FakeExchangeGateway(
            eligibleDates: const ['2026-08-02', '2026-08-01'],
          ),
          fileGateway: _FakeFileGateway(),
          clipboardWriter: (_) async {},
          onTargetDateChanged: selectedDates.add,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final dateField = find.byKey(const ValueKey('report-sync-target-date'));
    await tester.tap(dateField);
    await tester.pumpAndSettle();
    await tester.tap(find.text('2026-08-01'));
    await tester.pumpAndSettle();

    expect(tester.widget<TextField>(dateField).controller?.text, '2026-08-01');
    expect(selectedDates, ['2026-08-01']);
  });

  testWidgets('successful DD import returns to the existing top page', (
    tester,
  ) async {
    final gateway = _FakeExchangeGateway(
      responseExchangeType: ReportSyncExchangeType.dailyDebrief,
    );
    var applied = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) => ReportSyncExchangePage(
                    exchangeType: ReportSyncExchangeType.dailyDebrief,
                    gateway: gateway,
                    fileGateway: _FakeFileGateway(),
                    clipboardWriter: (_) async {},
                    onApplied: () => applied++,
                  ),
                ),
              ),
              child: const Text('OPEN IMPORT'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('OPEN IMPORT'));
    await tester.pumpAndSettle();
    await _validateAndConfirmImport(tester, 'IMPORT DAILY DEBRIEF');

    expect(gateway.applyCalls, 1);
    expect(applied, 1);
    expect(find.text('OPEN IMPORT'), findsOneWidget);
    expect(find.byType(ReportSyncExchangePage), findsNothing);
  });

  testWidgets('daily debrief preview replaces holiday work prose', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ReportSyncExchangePage(
          exchangeType: ReportSyncExchangeType.dailyDebrief,
          gateway: _FakeExchangeGateway(
            responseExchangeType: ReportSyncExchangeType.dailyDebrief,
          ),
          fileGateway: _FakeFileGateway(),
          clipboardWriter: (_) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _validateOnly(tester);

    expect(find.text('WORK  公休日'), findsOneWidget);
    expect(find.textContaining('実働'), findsNothing);
  });

  testWidgets('successful database import returns to the existing top page', (
    tester,
  ) async {
    final gateway = _FakeExchangeGateway();
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) => ReportSyncExchangePage(
                    exchangeType: ReportSyncExchangeType.training,
                    gateway: gateway,
                    fileGateway: _FakeFileGateway(),
                    clipboardWriter: (_) async {},
                  ),
                ),
              ),
              child: const Text('OPEN IMPORT'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('OPEN IMPORT'));
    await tester.pumpAndSettle();
    await _validateAndConfirmImport(tester, 'IMPORT TRAINING');

    expect(gateway.applyCalls, 1);
    expect(find.text('OPEN IMPORT'), findsOneWidget);
    expect(find.byType(ReportSyncExchangePage), findsNothing);
  });

  testWidgets('failed import remains on the import page', (tester) async {
    final gateway = _FakeExchangeGateway(applyError: StateError('failed'));
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) => ReportSyncExchangePage(
                    exchangeType: ReportSyncExchangeType.training,
                    gateway: gateway,
                    fileGateway: _FakeFileGateway(),
                    clipboardWriter: (_) async {},
                  ),
                ),
              ),
              child: const Text('OPEN IMPORT'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('OPEN IMPORT'));
    await tester.pumpAndSettle();
    await _validateAndConfirmImport(tester, 'IMPORT TRAINING');

    expect(gateway.applyCalls, 1);
    expect(find.byType(ReportSyncExchangePage), findsOneWidget);
  });

  testWidgets('food exchange UI is import-only and supports meal selection', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final gateway = _FakeExchangeGateway();
    final copied = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: ReportSyncExchangePage(
          exchangeType: ReportSyncExchangeType.food,
          gateway: gateway,
          fileGateway: _FakeFileGateway(),
          clipboardWriter: (text) async => copied.add(text),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('FOOD REPORT SYNC'), findsWidgets);
    expect(find.text('IMPORT READY'), findsOneWidget);
    expect(find.text('使い方'), findsOneWidget);
    for (final step in const [
      '① 対象日を確認する',
      '② ChatGPT用プロンプトをコピーする',
      '③ ChatGPTへ貼り付ける',
      '④ ChatGPTが保持している対象日の記録からJSONを作成させる',
      '⑤ 返されたJSONだけをコピーする',
      '⑥ JSONを貼り付ける、またはJSONファイルを選択する',
      '⑦ 内容を確認してインポートする',
    ]) {
      expect(find.text(step), findsOneWidget);
    }
    expect(find.text('COPY CHATGPT PROMPT'), findsWidgets);
    expect(find.text('COPY REQUEST DATA'), findsNothing);
    expect(find.text('EXPORT REQUEST FILE'), findsNothing);
    expect(find.text('対象データ: Meal Data'), findsNothing);
    expect(find.text('EXPORT TO CHATGPT'), findsNothing);
    expect(find.text('IMPORT FROM CHATGPT'), findsOneWidget);
    expect(find.text('PASTE'), findsOneWidget);
    expect(find.text('COPY MEAL DATA'), findsNothing);
    expect(
      find.byKey(const ValueKey('report-sync-target-date')),
      findsOneWidget,
    );

    await tester.tap(find.text('COPY CHATGPT PROMPT').last);
    await tester.pump();
    expect(copied, ['JSON ONLY']);
    expect(gateway.recordRequestCalls, 0);

    await tester.scrollUntilVisible(
      find.text('PASTE RESPONSE JSON'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('SELECT RESPONSE FILE'), findsNothing);
    expect(find.text('CLEAR'), findsOneWidget);
    expect(find.textContaining('Markdown'), findsOneWidget);

    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('report-sync-response-input')),
        matching: find.byType(TextField),
      ),
      '{"response":true}',
    );
    await tester.scrollUntilVisible(
      find.text('VALIDATE'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('VALIDATE'));
    await tester.pumpAndSettle();
    expect(find.text('PREVIEW'), findsOneWidget);
    expect(find.text('受信：3件'), findsOneWidget);
    expect(find.text('選択：1件'), findsOneWidget);
    expect(find.text('競合：1件'), findsOneWidget);
    expect(find.text('除外：2件'), findsOneWidget);
    expect(find.text('Rice100g'), findsOneWidget);
    expect(find.text('Donut 1個×4'), findsOneWidget);
    expect(find.text('1点'), findsNothing);
    expect(find.textContaining('×1'), findsNothing);
    expect(find.text('CAL 200'), findsOneWidget);
    expect(find.byIcon(Icons.local_fire_department_outlined), findsWidgets);
    expect(find.byIcon(Icons.fitness_center), findsWidgets);
    expect(find.byIcon(Icons.opacity), findsWidgets);
    expect(find.byIcon(Icons.rice_bowl_outlined), findsWidgets);
    await tester.tap(find.text('すべて解除'));
    await tester.pump();
    expect(find.text('選択：0件'), findsOneWidget);
    expect(find.text('除外：3件'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('food-meal-meal-1')));
    await tester.pump();
    expect(find.text('選択：1件'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('選択したMEALを取り込む'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('選択したMEALを取り込む'), findsOneWidget);

    await tester.tap(find.text('選択したMEALを取り込む'));
    await tester.pumpAndSettle();
    expect(find.text('CONFIRM IMPORT'), findsOneWidget);
    await tester.tap(find.text('CONFIRM IMPORT'));
    await tester.pumpAndSettle();
    expect(gateway.applyCalls, 1);
    expect(gateway.lastPreviewTargetDate, '2026-08-02');
    expect(gateway.lastSelectedMealIds, const {'meal-1'});
    await tester.fling(find.byType(ListView), const Offset(0, -1000), 1000);
    await tester.pumpAndSettle();
    expect(find.text('1件のMEALを取り込みました'), findsOneWidget);
    expect(find.text('{"response":true}'), findsNothing);
    expect(find.text('REPORT SYNC RECORD'), findsOneWidget);
    expect(find.text('FOOD SYNC · SUCCESS'), findsOneWidget);
    expect(find.textContaining('受信Meal：4件'), findsOneWidget);
    expect(find.textContaining('取り込み成功：2件'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('report-sync-record-request-food-0')),
    );
    await tester.pumpAndSettle();
    expect(find.text('EXCHANGE ID'), findsNothing);
    expect(find.text('REQUEST ID'), findsNothing);
    expect(find.text('DIRECTION'), findsNothing);
    expect(find.text('History snack35g×4'), findsWidgets);
    expect(find.text('CAL 57.1'), findsWidgets);
    expect(find.textContaining('57.099999999999994'), findsNothing);
  });

  testWidgets('food preview fits supported widths with compact item labels', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;

    for (final width in [320.0, 390.0, 900.0]) {
      tester.view.physicalSize = Size(width, 1600);
      await tester.pumpWidget(
        MaterialApp(
          home: ReportSyncExchangePage(
            exchangeType: ReportSyncExchangeType.food,
            gateway: _FakeExchangeGateway(),
            fileGateway: _FakeFileGateway(),
            clipboardWriter: (_) async {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byKey(const ValueKey('report-sync-response-input')),
          matching: find.byType(TextField),
        ),
        '{"response":true}',
      );
      await tester.scrollUntilVisible(
        find.text('VALIDATE'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('VALIDATE'));
      await tester.pumpAndSettle();

      expect(find.text('Rice100g'), findsOneWidget, reason: '${width}px');
      expect(find.text('Donut 1個×4'), findsOneWidget, reason: '${width}px');
      expect(tester.takeException(), isNull, reason: '${width}px');
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('food V1 history shows that meal counts were not recorded', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: ReportSyncExchangePage(
          exchangeType: ReportSyncExchangeType.food,
          gateway: _FakeExchangeGateway(legacyHistory: true),
          fileGateway: _FakeFileGateway(),
          clipboardWriter: (_) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Meal件数の記録はありません'), findsOneWidget);
    expect(find.textContaining('受信Meal：'), findsNothing);
  });

  testWidgets('food sync shows three recent rows and all records', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: ReportSyncExchangePage(
          exchangeType: ReportSyncExchangeType.food,
          gateway: _FakeExchangeGateway(historyCount: 7),
          fileGateway: _FakeFileGateway(),
          clipboardWriter: (_) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('REPORT SYNC RECORD'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.byKey(const ValueKey('report-sync-record-request-food-0')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('report-sync-record-request-food-2')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('report-sync-record-request-food-3')),
      findsNothing,
    );

    await tester.tap(
      find.byKey(const ValueKey('report-sync-record-request-food-0')),
    );
    await tester.pumpAndSettle();
    expect(find.text('EXCHANGE ID'), findsNothing);
    expect(find.text('REQUEST ID'), findsNothing);
    expect(find.text('request-food-0'), findsNothing);
    Navigator.of(tester.element(find.byType(ListView))).pop();
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('view-all-report-sync-records')),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(
      find.byKey(const ValueKey('view-all-report-sync-records')),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('all-report-sync-record-request-food-6')),
      250,
    );
    expect(
      find.byKey(const ValueKey('all-report-sync-record-request-food-6')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  for (final type in const [
    ReportSyncExchangeType.food,
    ReportSyncExchangeType.training,
  ]) {
    testWidgets('${type.name} shows VIEW ALL only from four records', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      for (final count in [0, 1, 3, 4]) {
        await tester.pumpWidget(
          MaterialApp(
            home: ReportSyncExchangePage(
              key: ValueKey('${type.name}-$count'),
              exchangeType: type,
              gateway: _FakeExchangeGateway(
                historyCount: count,
                responseExchangeType: type,
              ),
              fileGateway: _FakeFileGateway(),
              clipboardWriter: (_) async {},
            ),
          ),
        );
        await tester.pumpAndSettle();
        if (count >= 4) {
          await tester.scrollUntilVisible(
            find.byKey(const ValueKey('view-all-report-sync-records')),
            300,
            scrollable: find.byType(Scrollable).first,
          );
        }
        expect(
          find.byKey(const ValueKey('view-all-report-sync-records')),
          count >= 4 ? findsOneWidget : findsNothing,
          reason: '${type.name} history count $count',
        );
        expect(
          find.byKey(const ValueKey('report-sync-record-request-food-3')),
          findsNothing,
        );
      }
    });
  }

  for (final type in const [
    ReportSyncExchangeType.morningBrief,
    ReportSyncExchangeType.dailyDebrief,
  ]) {
    testWidgets('${type.name} hides inline history and uses human labels', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: ReportSyncExchangePage(
            exchangeType: type,
            gateway: _FakeExchangeGateway(
              historyCount: 4,
              responseExchangeType: type,
            ),
            fileGateway: _FakeFileGateway(),
            clipboardWriter: (_) async {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('REPORT SYNC RECORD'), findsNothing);
      expect(
        find.byKey(const ValueKey('report-sync-record-request-food-0')),
        findsNothing,
      );
      final viewAll = find.byKey(
        const ValueKey('view-all-report-sync-records'),
      );
      await tester.scrollUntilVisible(
        viewAll,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(viewAll, findsOneWidget);
      await tester.tap(viewAll);
      await tester.pumpAndSettle();
      final humanLabel = type == ReportSyncExchangeType.morningBrief
          ? 'DAILY BRIEF · SUCCESS'
          : 'DAILY DEBRIEF · SUCCESS';
      expect(find.text(humanLabel), findsNWidgets(4));
      expect(find.textContaining(type.stableId), findsNothing);
      expect(find.textContaining('response'), findsNothing);
    });
  }

  testWidgets('invalid target date disables import-only actions', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ReportSyncExchangePage(
          exchangeType: ReportSyncExchangeType.food,
          gateway: _FakeExchangeGateway(
            preparation: const ReportSyncRequestPreparation(
              operationDate: '2026-02-30',
            ),
          ),
          fileGateway: _FakeFileGateway(),
          clipboardWriter: (_) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('YYYY-MM-DD形式'), findsOneWidget);
    final prompt = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'COPY CHATGPT PROMPT'),
    );
    expect(prompt.onPressed, isNull);
    expect(find.text('COPY REQUEST DATA'), findsNothing);
    expect(find.text('EXPORT REQUEST FILE'), findsNothing);
  });

  testWidgets('calendar selection updates prompt and validation target date', (
    tester,
  ) async {
    final gateway = _FakeExchangeGateway();
    await tester.pumpWidget(
      MaterialApp(
        home: ReportSyncExchangePage(
          exchangeType: ReportSyncExchangeType.training,
          gateway: gateway,
          fileGateway: _FakeFileGateway(),
          clipboardWriter: (_) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final dateField = find.byKey(const ValueKey('report-sync-target-date'));
    expect(tester.widget<TextField>(dateField).readOnly, isTrue);
    await tester.tap(dateField);
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);
    await tester.tap(find.text('1').last);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(dateField).controller?.text, '2026-08-01');

    await tester.tap(find.text('COPY CHATGPT PROMPT').last);
    await tester.pump();
    expect(gateway.lastInstructionDate, '2026-08-01');

    await tester.scrollUntilVisible(
      find.text('PASTE RESPONSE JSON'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('report-sync-response-input')),
        matching: find.byType(TextField),
      ),
      '{}',
    );
    await tester.scrollUntilVisible(
      find.text('VALIDATE'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('VALIDATE'));
    await tester.pumpAndSettle();
    expect(gateway.lastPreviewTargetDate, '2026-08-01');
  });

  testWidgets('PASTE replaces the full response and invalidates preview only', (
    tester,
  ) async {
    final gateway = _FakeExchangeGateway();
    final clipboard = _FakeClipboardGateway(text: '{"pasted":true}');
    await tester.pumpWidget(
      MaterialApp(
        home: ReportSyncExchangePage(
          exchangeType: ReportSyncExchangeType.food,
          gateway: gateway,
          fileGateway: _FakeFileGateway(),
          clipboardGateway: clipboard,
          clipboardWriter: (_) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('PASTE RESPONSE JSON'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    final responseField = find.descendant(
      of: find.byKey(const ValueKey('report-sync-response-input')),
      matching: find.byType(TextField),
    );
    await tester.enterText(responseField, '{"old":true}');
    await tester.scrollUntilVisible(
      find.text('VALIDATE'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('VALIDATE'));
    await tester.pumpAndSettle();
    expect(find.text('PREVIEW'), findsOneWidget);

    await tester.tap(find.text('PASTE'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(responseField).controller?.text,
      '{"pasted":true}',
    );
    expect(find.text('クリップボードの内容を貼り付けました'), findsOneWidget);
    expect(find.text('PREVIEW'), findsNothing);
    expect(gateway.previewCalls, 1);
    expect(gateway.applyCalls, 0);
  });

  testWidgets('PASTE failure preserves manual input and validation', (
    tester,
  ) async {
    final clipboard = _FakeClipboardGateway();
    await tester.pumpWidget(
      MaterialApp(
        home: ReportSyncExchangePage(
          exchangeType: ReportSyncExchangeType.food,
          gateway: _FakeExchangeGateway(),
          fileGateway: _FakeFileGateway(),
          clipboardGateway: clipboard,
          clipboardWriter: (_) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('PASTE RESPONSE JSON'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    final responseField = find.descendant(
      of: find.byKey(const ValueKey('report-sync-response-input')),
      matching: find.byType(TextField),
    );
    await tester.enterText(responseField, 'manual value');
    await tester.scrollUntilVisible(
      find.text('PASTE'),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('PASTE'));
    await tester.pumpAndSettle();
    expect(find.text('クリップボードに貼り付け可能なテキストがありません'), findsOneWidget);
    expect(
      tester.widget<TextField>(responseField).controller?.text,
      'manual value',
    );

    clipboard.fails = true;
    await tester.scrollUntilVisible(
      find.text('PASTE'),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('PASTE'));
    await tester.pumpAndSettle();
    expect(find.text('クリップボードから貼り付けできませんでした'), findsOneWidget);
    expect(
      tester.widget<TextField>(responseField).controller?.text,
      'manual value',
    );
    expect(find.text('SELECT RESPONSE FILE'), findsNothing);
    expect(find.text('CLEAR'), findsOneWidget);
    expect(find.text('VALIDATE'), findsOneWidget);
  });

  testWidgets('CLEAR resets only response-derived import state', (
    tester,
  ) async {
    final gateway = _FakeExchangeGateway();
    await tester.pumpWidget(
      MaterialApp(
        home: ReportSyncExchangePage(
          exchangeType: ReportSyncExchangeType.food,
          gateway: gateway,
          fileGateway: _FakeFileGateway(),
          clipboardWriter: (_) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    final responseField = find.descendant(
      of: find.byKey(const ValueKey('report-sync-response-input')),
      matching: find.byType(TextField),
    );
    await tester.scrollUntilVisible(
      responseField,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(responseField, '{"response":true}');
    await tester.tap(
      find.byKey(const ValueKey('report-sync-response-action-validate')),
    );
    await tester.pumpAndSettle();
    expect(find.text('PREVIEW'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('report-sync-response-action-clear')),
    );
    await tester.pump();

    expect(tester.widget<TextField>(responseField).controller?.text, isEmpty);
    expect(find.text('PREVIEW'), findsNothing);
    expect(find.text('RESPONSE READY'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('REPORT SYNC RECORD'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('REPORT SYNC RECORD'), findsOneWidget);
    expect(find.text('FOOD SYNC · SUCCESS'), findsOneWidget);
    expect(gateway.applyCalls, 0);

    await tester.scrollUntilVisible(
      responseField,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(responseField, '{"response":true}');
    await tester.tap(
      find.byKey(const ValueKey('report-sync-response-action-validate')),
    );
    await tester.pumpAndSettle();
    expect(find.text('PREVIEW'), findsOneWidget);
    expect(gateway.previewCalls, 2);
    expect(gateway.applyCalls, 0);
  });

  testWidgets('target exchanges share the compact response action row', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final type in const [
      ReportSyncExchangeType.food,
      ReportSyncExchangeType.training,
      ReportSyncExchangeType.morningBrief,
      ReportSyncExchangeType.dailyDebrief,
    ]) {
      await tester.pumpWidget(
        MaterialApp(
          home: ReportSyncExchangePage(
            exchangeType: type,
            gateway: _FakeExchangeGateway(
              responseExchangeType: type,
              eligibleDates: const ['2026-08-02'],
            ),
            fileGateway: _FakeFileGateway(),
            clipboardWriter: (_) async {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      final actionBar = find.byKey(
        const ValueKey('report-sync-response-action-bar'),
      );
      await tester.scrollUntilVisible(
        actionBar,
        300,
        scrollable: find.byType(Scrollable).first,
      );

      final paste = find.byKey(
        const ValueKey('report-sync-response-action-paste'),
      );
      final clear = find.byKey(
        const ValueKey('report-sync-response-action-clear'),
      );
      final validate = find.byKey(
        const ValueKey('report-sync-response-action-validate'),
      );
      expect(actionBar, findsOneWidget, reason: type.stableId);
      expect(find.text('SELECT RESPONSE FILE'), findsNothing);
      expect(find.text('PASTE'), findsOneWidget);
      expect(find.text('CLEAR'), findsOneWidget);
      expect(find.text('VALIDATE'), findsOneWidget);
      expect(find.byIcon(Icons.content_paste_outlined), findsOneWidget);
      expect(find.byIcon(Icons.backspace_outlined), findsOneWidget);
      expect(find.byIcon(Icons.fact_check_outlined), findsOneWidget);
      expect(tester.getTopLeft(paste).dy, tester.getTopLeft(clear).dy);
      expect(tester.getTopLeft(clear).dy, tester.getTopLeft(validate).dy);
      expect(tester.getSize(paste).width, tester.getSize(clear).width);
      expect(tester.getSize(clear).width, tester.getSize(validate).width);
      expect(tester.takeException(), isNull, reason: type.stableId);
    }
  });

  testWidgets('daily debrief omits the redundant source action', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ReportSyncExchangePage(
          exchangeType: ReportSyncExchangeType.dailyDebrief,
          gateway: _FakeExchangeGateway(
            responseExchangeType: ReportSyncExchangeType.dailyDebrief,
            eligibleDates: const ['2026-08-02'],
          ),
          fileGateway: _FakeFileGateway(),
          clipboardWriter: (_) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('COPY CHATGPT PROMPT'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('COPY CHATGPT PROMPT'), findsOneWidget);
    expect(find.text('DAILY DEBRIEF SOURCE'), findsNothing);
  });

  testWidgets('strict parse errors are explained in Japanese', (tester) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: ReportSyncExchangePage(
          exchangeType: ReportSyncExchangeType.food,
          gateway: _FakeExchangeGateway(
            previewError: const ReportSyncException(
              ReportSyncIssueCode.schemaMismatch,
              'invalid JSON',
            ),
          ),
          fileGateway: _FakeFileGateway(),
          clipboardWriter: (_) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('report-sync-response-input')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('report-sync-response-input')),
        matching: find.byType(TextField),
      ),
      '“invalid”',
    );
    await tester.scrollUntilVisible(
      find.text('VALIDATE'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('VALIDATE'));
    await tester.pumpAndSettle();
    expect(find.textContaining('JSONを読み取れませんでした'), findsOneWidget);
    expect(find.textContaining('スマートクォート'), findsOneWidget);
  });

  for (final module in const [
    (
      type: ReportSyncExchangeType.morningBrief,
      source: 'STATUS Source',
      button: 'COPY CHATGPT PROMPT',
    ),
  ]) {
    testWidgets('${module.type.name} exposes its formal plain-text export', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: ReportSyncExchangePage(
            exchangeType: module.type,
            gateway: _FakeExchangeGateway(
              preparation: ReportSyncRequestPreparation(
                operationDate: '2026-08-02',
                sourceText:
                    'OPERATION REBOOT\nSOURCE: ${module.source}\nOPERATION DATE: 2026-08-02',
              ),
            ),
            fileGateway: _FakeFileGateway(),
            clipboardWriter: (_) async {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(module.button), findsOneWidget);
      expect(
        find.text('対象データ: ${module.source}'),
        module.type == ReportSyncExchangeType.morningBrief
            ? findsNothing
            : findsOneWidget,
      );
      expect(find.text('COPY REQUEST DATA'), findsNothing);
      expect(find.text('EXPORT REQUEST FILE'), findsNothing);
    });
  }

  testWidgets('morning brief previews and copies the exact STATUS source', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final source = _statusSourceExport();
    final copied = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: ReportSyncExchangePage(
          exchangeType: ReportSyncExchangeType.morningBrief,
          gateway: _FakeExchangeGateway(
            preparation: ReportSyncRequestPreparation(
              operationDate: '2026-08-02',
              sourceText: source.plainText,
              statusSourceExport: source,
              statusLabel: 'READY',
            ),
          ),
          fileGateway: _FakeFileGateway(),
          clipboardWriter: (value) async => copied.add(value),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('DAILY BRIEF REPORT SYNC'), findsWidgets);
    expect(find.textContaining('MORNING BRIEF'), findsNothing);
    expect(find.text('STATUS SOURCE'), findsOneWidget);
    for (final step in const [
      '① 対象日を選択する',
      '② STATUS SOURCEを生成してPreviewを確認する',
      '③ COPY CHATGPT PROMPTを押す',
      '④ コピーした内容をChatGPTへ1回だけ貼り付ける',
      '⑤ ChatGPTの単一textコードブロック内のJSONだけをコピーする',
      '⑥ PASTEでJSONを貼り付ける',
      '⑦ VALIDATEを押す',
      '⑧ PREVIEWでSource Digestと内容を確認する',
      '⑨ IMPORT DAILY BRIEFを押す',
      '⑩ COMPLETE · READ-BACK VERIFIEDを確認する',
    ]) {
      expect(find.text(step), findsOneWidget);
    }
    expect(find.text('③ 指定されたデータを貼り付ける'), findsNothing);
    expect(
      find.text('プロンプトには正式なDAILY BRIEF SchemaとSTATUS SOURCEが1つに統合されています。'),
      findsOneWidget,
    );
    expect(find.text('現在の回答はアプリへインポートしません。'), findsNothing);
    expect(find.text('COPY STATUS SOURCE'), findsNothing);
    expect(find.text('状態  READY'), findsOneWidget);
    expect(find.text('前日比較  AVAILABLE'), findsOneWidget);
    var prompt = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'COPY CHATGPT PROMPT'),
    );
    expect(prompt.onPressed, isNull);

    await tester.tap(find.text('GENERATE STATUS SOURCE'));
    await tester.pumpAndSettle();
    expect(find.text('STATUS SOURCE PREVIEW'), findsOneWidget);
    final status = find.byKey(const ValueKey('status-source-preview-status'));
    final body = find.byKey(const ValueKey('status-source-preview-body'));
    final recovery = find.byKey(
      const ValueKey('status-source-preview-recovery'),
    );
    final condition = find.byKey(
      const ValueKey('status-source-preview-condition'),
    );
    final work = find.byKey(const ValueKey('status-source-preview-work'));
    final carryover = find.byKey(
      const ValueKey('status-source-preview-carryover'),
    );
    expect(tester.getTopLeft(status).dy, tester.getTopLeft(body).dy);
    expect(tester.getTopLeft(recovery).dy, tester.getTopLeft(condition).dy);
    expect(tester.getTopLeft(work).dy, tester.getTopLeft(carryover).dy);
    expect(tester.getTopLeft(status).dx, lessThan(tester.getTopLeft(body).dx));
    expect(
      tester.getTopLeft(recovery).dy,
      greaterThan(tester.getTopLeft(status).dy),
    );
    expect(
      tester.getTopLeft(work).dy,
      greaterThan(tester.getTopLeft(recovery).dy),
    );
    expect(find.text(source.plainText), findsNothing);
    expect(find.text('OPERATION DATE  2026-08-02'), findsOneWidget);
    expect(find.text('WEIGHT  80.0 kg'), findsOneWidget);
    expect(find.text('SLEEP  7:30'), findsOneWidget);
    expect(find.text('TIME  09:00 - 18:00'), findsOneWidget);
    expect(find.textContaining('SOURCE DIGEST'), findsNothing);
    expect(find.textContaining('SOURCE RECORD ID'), findsNothing);
    expect(
      find.text(
        'コピーした内容には、DAILY BRIEF生成指示と正式なSTATUS SOURCEが含まれています。'
        'そのままChatGPTへ1回貼り付けてください。',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('プロンプトを貼り付けた後'), findsNothing);
    prompt = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'COPY CHATGPT PROMPT'),
    );
    expect(prompt.onPressed, isNotNull);
    await tester.tap(find.text('COPY CHATGPT PROMPT'));
    await tester.pumpAndSettle();
    expect(copied, hasLength(1));
    expect(copied.single, contains('DAILY BRIEF SOURCE PROMPT'));
    expect(copied.single, isNot(contains('MORNING BRIEF')));
    expect(copied.single, contains(source.plainText));
    expect(copied.single.split(source.plainText), hasLength(2));
    expect(find.text('CHATGPT PROMPTをコピーしました'), findsOneWidget);
    expect(find.text('STATUS SOURCEをコピーしました'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('report-sync-target-date')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1').last);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('STATUS SOURCE PREVIEW'), findsNothing);
    expect(find.text('CHATGPT PROMPTをコピーしました'), findsNothing);
    prompt = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'COPY CHATGPT PROMPT'),
    );
    expect(prompt.onPressed, isNull);
  });

  testWidgets('morning brief import errors stay in the import action area', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final source = _statusSourceExport();
    await tester.pumpWidget(
      MaterialApp(
        home: ReportSyncExchangePage(
          exchangeType: ReportSyncExchangeType.morningBrief,
          gateway: _FakeExchangeGateway(
            preparation: ReportSyncRequestPreparation(
              operationDate: '2026-08-02',
              sourceText: source.plainText,
              statusSourceExport: source,
              statusLabel: 'READY',
            ),
            previewError: const ReportSyncException(
              ReportSyncIssueCode.integrityFailure,
              'invalid digest',
            ),
          ),
          fileGateway: _FakeFileGateway(),
          clipboardWriter: (_) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('GENERATE STATUS SOURCE'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('report-sync-response-input')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('report-sync-response-input')),
        matching: find.byType(TextField),
      ),
      '{}',
    );
    await tester.scrollUntilVisible(
      find.text('VALIDATE'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('VALIDATE'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('report-sync-import-action-error')),
      findsOneWidget,
    );
    expect(find.textContaining('JSONの整合性を確認できません'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('report-sync-export-generate-error')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('report-sync-export-prompt-error')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('report-sync-export-source-error')),
      findsNothing,
    );
  });

  testWidgets('morning brief preview replaces holiday work prose', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final source = _statusSourceExport();
    await tester.pumpWidget(
      MaterialApp(
        home: ReportSyncExchangePage(
          exchangeType: ReportSyncExchangeType.morningBrief,
          gateway: _FakeExchangeGateway(
            preparation: ReportSyncRequestPreparation(
              operationDate: '2026-08-02',
              sourceText: source.plainText,
              statusSourceExport: source,
              statusLabel: 'READY',
            ),
            responseOverride: _morningHolidayResponse(),
          ),
          fileGateway: _FakeFileGateway(),
          clipboardWriter: (_) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('GENERATE STATUS SOURCE'));
    await tester.pumpAndSettle();
    await _validateOnly(tester);

    expect(find.text('WORK  公休日'), findsOneWidget);
    expect(find.textContaining('実働'), findsNothing);
  });

  testWidgets('training preview hides a null session name from visible UI', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: ReportSyncExchangePage(
          exchangeType: ReportSyncExchangeType.training,
          gateway: _FakeExchangeGateway(
            trainingPreview: _nullNameTrainingPreview(),
          ),
          fileGateway: _FakeFileGateway(),
          clipboardWriter: (_) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('report-sync-response-input')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('report-sync-response-input')),
        matching: find.byType(TextField),
      ),
      '{}',
    );
    await tester.scrollUntilVisible(
      find.text('VALIDATE'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('VALIDATE'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Session  NOT RECORDED'), findsOneWidget);
    expect(find.textContaining('Session  null'), findsNothing);
    expect(find.text('Exercises  1  Cardio  0'), findsOneWidget);
    expect(find.text('IMPORT TRAINING'), findsOneWidget);
  });

  for (final disposition in const [
    ReportSyncDisposition.noChanges,
    ReportSyncDisposition.conflict,
    ReportSyncDisposition.blocked,
  ]) {
    testWidgets('${disposition.name} preview never exposes import', (
      tester,
    ) async {
      final gateway = _FakeExchangeGateway(disposition: disposition);
      await tester.pumpWidget(
        MaterialApp(
          home: ReportSyncExchangePage(
            exchangeType: ReportSyncExchangeType.food,
            gateway: gateway,
            fileGateway: _FakeFileGateway(),
            clipboardWriter: (_) async {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('PASTE RESPONSE JSON'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(
        find.descendant(
          of: find.byKey(const ValueKey('report-sync-response-input')),
          matching: find.byType(TextField),
        ),
        '{}',
      );
      await tester.scrollUntilVisible(
        find.text('VALIDATE'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('VALIDATE'));
      await tester.pumpAndSettle();
      expect(find.text(disposition.name.toUpperCase()), findsOneWidget);
      expect(find.text('IMPORT FOOD'), findsNothing);
    });
  }

  for (final width in [320.0, 390.0, 900.0, 1280.0]) {
    testWidgets('common exchange UI has no overflow at ${width.toInt()}px', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final theme in [ThemeData.light(), ThemeData.dark()]) {
        for (final type in ReportSyncExchangeType.values) {
          await tester.pumpWidget(
            MaterialApp(
              theme: theme,
              home: ReportSyncExchangePage(
                exchangeType: type,
                gateway: _FakeExchangeGateway(),
                fileGateway: _FakeFileGateway(),
                clipboardWriter: (_) async {},
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: type.stableId);
        }
      }
    });
  }
}

Future<void> _validateAndConfirmImport(
  WidgetTester tester,
  String importLabel,
) async {
  final scrollable = find.byType(Scrollable).first;
  await tester.scrollUntilVisible(
    find.byKey(const ValueKey('report-sync-response-input')),
    250,
    scrollable: scrollable,
  );
  await tester.enterText(
    find.descendant(
      of: find.byKey(const ValueKey('report-sync-response-input')),
      matching: find.byType(TextField),
    ),
    '{"response":true}',
  );
  await tester.scrollUntilVisible(
    find.text('VALIDATE'),
    250,
    scrollable: scrollable,
  );
  await tester.tap(find.text('VALIDATE'));
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(
    find.text(importLabel),
    250,
    scrollable: scrollable,
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text(importLabel));
  await tester.pumpAndSettle();
  await tester.tap(find.text('CONFIRM IMPORT'));
  await tester.pumpAndSettle();
}

Future<void> _validateOnly(WidgetTester tester) async {
  final scrollable = find.byType(Scrollable).first;
  await tester.scrollUntilVisible(
    find.byKey(const ValueKey('report-sync-response-input')),
    250,
    scrollable: scrollable,
  );
  await tester.enterText(
    find.descendant(
      of: find.byKey(const ValueKey('report-sync-response-input')),
      matching: find.byType(TextField),
    ),
    '{"response":true}',
  );
  await tester.scrollUntilVisible(
    find.text('VALIDATE'),
    250,
    scrollable: scrollable,
  );
  await tester.tap(find.text('VALIDATE'));
  await tester.pumpAndSettle();
}

StatusReportSyncSourceExport _statusSourceExport() {
  const digest =
      'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
  const canonicalText =
      'OPERATION REBOOT\nFORMAT: operation-reboot-status-source\n';
  const plainText =
      'OPERATION REBOOT\nFORMAT: operation-reboot-status-source\n'
      'EXPORTED AT: 2026-08-02T01:00:00.000Z\n'
      'SOURCE DIGEST: $digest\n';
  return StatusReportSyncSourceExport(
    source: const StatusReportSyncSource(
      operationDate: '2026-08-02',
      sourceRecordId: 'status:2026-08-02',
      sourceRecordVersion: 1,
      body: StatusReportSyncBodySource(weightKg: 80, bodyFatPercent: 20),
      recovery: StatusReportSyncRecoverySource(
        sleepDurationMinutes: 450,
        sleepScore: 80,
      ),
      condition: StatusReportSyncConditionSource(
        footPainLevel: 3,
        condition: 4,
        notes: null,
      ),
      work: StatusReportSyncWorkSource(
        workType: 'work',
        startTime: '09:00',
        endTime: '18:00',
        breakDurationMinutes: 60,
        workHours: 8,
      ),
      previousCarryoverConfirmed: true,
      previousDayComparison: StatusReportSyncPreviousDayComparison(
        previousOperationDate: '2026-08-01',
        previousStatusAvailable: true,
        weightDifferenceKg: '+0.1',
        bodyFatDifferencePoint: '-0.1',
      ),
    ),
    exportedAt: DateTime.utc(2026, 8, 2, 1),
    sourceDigest: digest,
    canonicalText: canonicalText,
    plainText: plainText,
  );
}

ReportSyncEnvelope _morningHolidayResponse() => const ReportSyncCodec().create(
  direction: ReportSyncDirection.response,
  exchangeType: ReportSyncExchangeType.morningBrief,
  exchangeId: 'morning-holiday-response',
  requestId: 'request-morning',
  operationDate: '2026-08-02',
  createdAt: DateTime.utc(2026, 8, 2),
  requestDigest: _FakeExchangeGateway.digest,
  payload: const {
    'source': {
      'sourceOperationDate': '2026-08-02',
      'sourceRecordId': 'status:2026-08-02',
    },
    'content': {
      'operationStatus': 'green',
      'situationAnalysis': {
        'body': 'BODY',
        'recovery': 'RECOVERY',
        'condition': 'CONDITION',
        'work': '公休日で実働だった。',
        'carryover': 'CARRYOVER',
        'overall': 'OVERALL',
      },
      'operatingPolicy': 'POLICY',
      'strategicResourceDecision': {
        'decision': 'DECISION',
        'targetResource': null,
        'rationale': 'RATIONALE',
        'execution': null,
      },
      'commanderIntent': 'INTENT',
      'actions': [
        {'text': 'ACTION', 'priority': 'high'},
      ],
    },
  },
);

HistoricalTrainingPreview _nullNameTrainingPreview() =>
    HistoricalTrainingPreview(
      exchangeId: 'training-null-name-preview',
      createdAt: DateTime.utc(2026, 8, 3),
      responseDigest: 'a' * 64,
      packageDigest: 'b' * 64,
      requestedStartDate: '2026-08-03',
      requestedEndDate: '2026-08-03',
      envelope: const {
        'payload': {
          'records': [
            {
              'operationDate': '2026-08-03',
              'sourceRecordId': null,
              'session': {
                'session': {'name': null, 'grade': 'sPlus'},
                'exercises': [
                  {'exerciseName': 'Bench Press'},
                ],
                'cardio': <Object?>[],
              },
            },
          ],
        },
      },
      records: const [
        HistoricalTrainingPreviewItem(
          index: 0,
          sourceRecordId: null,
          operationDate: '2026-08-03',
          sourceDigest: null,
          targetRecordId: null,
          domainDigest: null,
          persistedRecord: null,
          disposition: OperationSyncRecordDisposition.newRecord,
          issues: [],
        ),
      ],
    );

class _FakeExchangeGateway implements ReportSyncExchangeGateway {
  _FakeExchangeGateway({
    this.disposition = ReportSyncDisposition.create,
    this.preparation,
    this.previewError,
    this.legacyHistory = false,
    this.historyCount = 1,
    this.trainingPreview,
    this.eligibleDates = const [],
    this.applyError,
    this.responseExchangeType = ReportSyncExchangeType.food,
    this.responseOverride,
  });

  static const digest =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  final ReportSyncDisposition disposition;
  final ReportSyncRequestPreparation? preparation;
  final Object? previewError;
  final bool legacyHistory;
  final int historyCount;
  final HistoricalTrainingPreview? trainingPreview;
  final List<String> eligibleDates;
  final Object? applyError;
  final ReportSyncExchangeType responseExchangeType;
  final ReportSyncEnvelope? responseOverride;
  int recordRequestCalls = 0;
  int applyCalls = 0;
  int previewCalls = 0;
  String? lastPreviewTargetDate;
  String? lastInstructionDate;
  Set<String>? lastSelectedMealIds;

  late final request = const ReportSyncCodec().create(
    direction: ReportSyncDirection.request,
    exchangeType: responseExchangeType,
    exchangeId: 'request-food',
    requestId: 'request-food',
    operationDate: '2026-08-02',
    createdAt: DateTime.utc(2026, 8, 2),
    requestDigest: ReportSyncCanonicalService.digest(const {'request': true}),
    payload: const {'request': true},
  );

  late final response = const ReportSyncCodec().create(
    direction: ReportSyncDirection.response,
    exchangeType: ReportSyncExchangeType.food,
    exchangeId: 'response-food',
    requestId: 'request-food',
    operationDate: '2026-08-02',
    createdAt: DateTime.utc(2026, 8, 2),
    requestDigest: digest,
    payload: responseExchangeType == ReportSyncExchangeType.dailyDebrief
        ? const {
            'analysis': {
              'commanderIntentEvaluation': null,
              'domainEvaluations': {
                'body': '体調は安定しました',
                'recovery': null,
                'condition': null,
                'work': '公休日で実働だった。',
                'nutrition': null,
                'hydration': null,
                'activity': null,
                'training': null,
              },
              'crossAnalysis': {
                'keyFactors': <Object?>[],
                'interactions': <Object?>[],
                'constraints': <Object?>[],
                'resources': <Object?>[],
              },
              'executionEvaluation': {
                'successes': <Object?>[],
                'adjustments': <Object?>[],
              },
              'nextDayHandoff': {'watchPoints': <Object?>[]},
            },
          }
        : const {
            'requestId': 'request-food',
            'requestDigest': digest,
            'operationDate': '2026-08-02',
            'meals': <Object?>[],
          },
  );

  @override
  Future<ReportSyncApplyResult> apply(
    ReportSyncResponsePreview preview, {
    Set<String>? selectedMealIds,
  }) async {
    applyCalls++;
    if (applyError != null) throw applyError!;
    lastSelectedMealIds = selectedMealIds;
    return ReportSyncApplyResult(
      disposition,
      readBackVerified: true,
      mealCounts: selectedMealIds == null
          ? null
          : ReportSyncMealCounts(
              received: preview.foodMeals.length,
              selected: selectedMealIds.length,
              imported: selectedMealIds.length,
              conflict: preview.conflictCount,
            ),
    );
  }

  @override
  String encode(ReportSyncEnvelope envelope) => jsonEncode(envelope.toJson());

  @override
  Future<List<ReportSyncHistory>> history(
    ReportSyncExchangeType type,
  ) async => [
    for (var index = 0; index < historyCount; index++)
      ReportSyncHistory(
        recordVersion: legacyHistory ? 1 : 3,
        exchangeId: 'request-food-$index',
        exchangeType: type,
        direction: ReportSyncDirection.response,
        operationDate: '2026-08-02',
        requestId: 'request-food-$index',
        requestDigest: digest,
        startedAt: DateTime.utc(2026, 8, 2, index),
        completedAt: DateTime.utc(2026, 8, 2, index),
        result: ReportSyncHistoryResult.success,
        packageDigest: digest,
        receivedMealCount: type == ReportSyncExchangeType.food && !legacyHistory
            ? 4
            : null,
        selectedMealCount: type == ReportSyncExchangeType.food && !legacyHistory
            ? 2
            : null,
        importedMealCount: type == ReportSyncExchangeType.food && !legacyHistory
            ? 2
            : null,
        conflictMealCount: type == ReportSyncExchangeType.food && !legacyHistory
            ? 1
            : null,
        excludedMealCount: type == ReportSyncExchangeType.food && !legacyHistory
            ? 2
            : null,
        importedMealSnapshots:
            type == ReportSyncExchangeType.food && !legacyHistory
            ? const [
                MealData(
                  date: '2026-08-02',
                  mealType: 'Snack',
                  items: [
                    FoodItem(
                      name: 'History snack',
                      calories: 57.099999999999994,
                      protein: 1.9,
                      fat: 5.5,
                      carbohydrate: 24.2,
                      quantity: 4,
                      amount: 35,
                      baseAmount: 35,
                      baseUnit: FoodBaseUnit.g,
                      amountMode: FoodAmountMode.physicalAmount,
                    ),
                  ],
                  memo: '',
                  id: 'history-meal-1',
                ),
                MealData(
                  date: '2026-08-02',
                  mealType: 'Water',
                  items: [],
                  memo: '',
                  id: 'history-meal-2',
                  waterMl: 250,
                ),
              ]
            : const [],
      ),
  ];

  @override
  Future<Object?> importedRecord(
    ReportSyncExchangeType type,
    String localDate,
  ) async => null;

  @override
  String instruction(
    ReportSyncExchangeType type,
    ReportSyncRequestPreparation preparation,
  ) {
    lastInstructionDate = preparation.operationDate;
    if (type == ReportSyncExchangeType.morningBrief) {
      final source = preparation.sourceText;
      if (source == null) throw StateError('STATUS SOURCE READYが必要です。');
      return 'DAILY BRIEF SOURCE PROMPT\n'
          'SOURCE DATA START\n'
          '━━━━━━━━━━━━━━━━━━━━\n'
          '$source'
          '━━━━━━━━━━━━━━━━━━━━\n'
          'SOURCE DATA END';
    }
    return 'JSON ONLY';
  }

  @override
  Future<ReportSyncRequestPreparation> prepareRequest(
    ReportSyncExchangeType type, {
    String? targetDate,
  }) async =>
      preparation ??
      ReportSyncRequestPreparation(
        envelope: request,
        operationDate: targetDate ?? request.operationDate,
        sourceText: 'OPERATION REBOOT\nSOURCE: Meal Data',
        eligibleDates: eligibleDates,
      );

  @override
  Future<ReportSyncResponsePreview> previewResponse(
    ReportSyncExchangeType type,
    String rawResponse, {
    String? targetDate,
  }) async {
    if (previewError != null) throw previewError!;
    previewCalls++;
    lastPreviewTargetDate = targetDate;
    final historical = trainingPreview;
    if (historical != null) {
      return ReportSyncResponsePreview(
        envelope: null,
        disposition: ReportSyncDisposition.create,
        createCount: historical.newCount,
        noChangeCount: 0,
        conflictCount: 0,
        trainingPreview: historical,
      );
    }
    return ReportSyncResponsePreview(
      envelope: responseOverride ?? response,
      disposition: disposition,
      createCount: disposition == ReportSyncDisposition.create ? 1 : 0,
      noChangeCount:
          disposition == ReportSyncDisposition.create ||
              disposition == ReportSyncDisposition.noChanges
          ? 1
          : 0,
      conflictCount:
          disposition == ReportSyncDisposition.create ||
              disposition == ReportSyncDisposition.conflict
          ? 1
          : 0,
      foodMeals: disposition == ReportSyncDisposition.create
          ? const [
              FoodReportSyncMealPreview(
                meal: MealData(
                  date: '2026-08-02',
                  mealType: 'Lunch',
                  items: [
                    FoodItem(
                      name: 'Rice',
                      calories: 200,
                      protein: 4,
                      fat: 1,
                      carbohydrate: 44,
                      quantity: 1,
                      amount: 100,
                      baseAmount: 100,
                      baseUnit: FoodBaseUnit.g,
                      amountMode: FoodAmountMode.physicalAmount,
                    ),
                    FoodItem(
                      name: 'Donut 1個',
                      calories: 0,
                      protein: 0,
                      fat: 0,
                      carbohydrate: 0,
                      quantity: 4,
                    ),
                  ],
                  memo: '',
                  id: 'meal-1',
                ),
                disposition: FoodReportSyncMealDisposition.create,
              ),
              FoodReportSyncMealPreview(
                meal: MealData(
                  date: '2026-08-02',
                  mealType: 'Dinner',
                  items: [],
                  memo: '',
                  id: 'meal-conflict',
                  waterMl: 250,
                ),
                disposition: FoodReportSyncMealDisposition.conflict,
              ),
              FoodReportSyncMealPreview(
                meal: MealData(
                  date: '2026-08-02',
                  mealType: 'Snack',
                  items: [],
                  memo: '',
                  id: 'meal-no-change',
                  waterMl: 100,
                ),
                disposition: FoodReportSyncMealDisposition.noChanges,
              ),
            ]
          : const [],
    );
  }

  @override
  Future<void> recordRequest(ReportSyncEnvelope request) async {
    recordRequestCalls++;
  }
}

class _FakeClipboardGateway implements ReportSyncClipboardGateway {
  _FakeClipboardGateway({this.text});

  String? text;
  bool fails = false;
  final writes = <String>[];

  @override
  Future<String?> readText() async {
    if (fails) throw StateError('clipboard unavailable');
    return text;
  }

  @override
  Future<void> writeText(String text) async => writes.add(text);
}

class _FakeFileGateway implements BackupFileGateway {
  String? savedName;

  @override
  String? get origin => 'https://example.test';

  @override
  Future<BackupFileDelivery> shareOrSave({
    required String fileName,
    required String content,
  }) async {
    savedName = fileName;
    return BackupFileDelivery.downloaded;
  }

  @override
  Future<BackupSelectedFile?> selectJson() async => null;
}
