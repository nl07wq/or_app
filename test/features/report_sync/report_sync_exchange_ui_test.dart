import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/import_export/services/backup_file_gateway.dart';
import 'package:or_app/features/report_sync/models/report_sync_envelope.dart';
import 'package:or_app/features/report_sync/models/report_sync_history.dart';
import 'package:or_app/features/report_sync/pages/report_sync_exchange_page.dart';
import 'package:or_app/features/report_sync/services/report_sync_canonical_service.dart';
import 'package:or_app/features/report_sync/services/report_sync_codec.dart';
import 'package:or_app/features/report_sync/services/report_sync_exchange_gateway.dart';

void main() {
  testWidgets(
    'common exchange UI exports, validates, confirms, and clears raw input',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final gateway = _FakeExchangeGateway();
      final files = _FakeFileGateway(
        selected: BackupSelectedFile(
          name: 'food-report-response-2026-08-02.json',
          bytes: utf8.encode('{"fromFile":true}'),
        ),
      );
      final copied = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: ReportSyncExchangePage(
            exchangeType: ReportSyncExchangeType.food,
            gateway: gateway,
            fileGateway: files,
            clipboardWriter: (text) async => copied.add(text),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('FOOD REPORT SYNC'), findsWidgets);
      expect(find.text('REQUEST READY'), findsOneWidget);
      expect(find.text('HOW TO USE'), findsOneWidget);
      for (final step in const [
        '1. COPY CHATGPT PROMPT',
        '2. COPY REQUEST DATA',
        '3. Paste both into ChatGPT',
        '4. Copy the JSON response',
        '5. Paste or select the response',
        '6. Validate and review',
        '7. Import',
      ]) {
        expect(find.text(step), findsOneWidget);
      }
      expect(find.text('COPY CHATGPT PROMPT'), findsWidgets);
      expect(find.text('COPY REQUEST DATA'), findsWidgets);
      expect(find.text('EXPORT REQUEST FILE'), findsOneWidget);

      await tester.tap(find.text('COPY CHATGPT PROMPT').last);
      await tester.pump();
      await tester.tap(find.text('COPY REQUEST DATA').last);
      await tester.pump();
      expect(copied, hasLength(2));
      expect(gateway.recordRequestCalls, 1);

      await tester.scrollUntilVisible(
        find.text('EXPORT REQUEST FILE'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('EXPORT REQUEST FILE'));
      await tester.pump();
      expect(files.savedName, 'food-report-request-2026-08-02.json');
      expect(gateway.recordRequestCalls, 1);

      await tester.scrollUntilVisible(
        find.text('SELECT RESPONSE FILE'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('SELECT RESPONSE FILE'));
      await tester.pumpAndSettle();
      expect(find.text('RESPONSE FILE LOADED'), findsOneWidget);
      expect(find.text('{"fromFile":true}'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('PASTE RESPONSE JSON'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.textContaining('Markdown code fences'), findsOneWidget);

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
      expect(find.text('CREATE  1'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('IMPORT FOOD'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('IMPORT FOOD'), findsOneWidget);

      await tester.tap(find.text('IMPORT FOOD'));
      await tester.pumpAndSettle();
      expect(find.text('CONFIRM IMPORT'), findsOneWidget);
      await tester.tap(find.text('CONFIRM IMPORT'));
      await tester.pumpAndSettle();
      expect(gateway.applyCalls, 1);
      expect(find.text('COMPLETE · READ-BACK VERIFIED'), findsOneWidget);
      expect(find.text('{"response":true}'), findsNothing);
      expect(find.text('REPORT SYNC HISTORY'), findsOneWidget);
      expect(find.textContaining('food · request'), findsOneWidget);
    },
  );

  testWidgets('not ready state explains why and disables request data', (
    tester,
  ) async {
    const reason = 'No food data is available for this operation date.';
    await tester.pumpWidget(
      MaterialApp(
        home: ReportSyncExchangePage(
          exchangeType: ReportSyncExchangeType.food,
          gateway: _FakeExchangeGateway(
            preparation: const ReportSyncRequestPreparation(
              blockingReason: reason,
            ),
          ),
          fileGateway: _FakeFileGateway(),
          clipboardWriter: (_) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('REQUEST NOT READY'), findsOneWidget);
    expect(find.text(reason), findsOneWidget);
    final prompt = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'COPY CHATGPT PROMPT'),
    );
    final request = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'COPY REQUEST DATA'),
    );
    final export = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'EXPORT REQUEST FILE'),
    );
    expect(prompt.onPressed, isNotNull);
    expect(request.onPressed, isNull);
    expect(export.onPressed, isNull);
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
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: ReportSyncExchangePage(
              exchangeType: ReportSyncExchangeType.food,
              gateway: _FakeExchangeGateway(),
              fileGateway: _FakeFileGateway(),
              clipboardWriter: (_) async {},
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    });
  }
}

class _FakeExchangeGateway implements ReportSyncExchangeGateway {
  _FakeExchangeGateway({
    this.disposition = ReportSyncDisposition.create,
    this.preparation,
  });

  static const digest =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  final ReportSyncDisposition disposition;
  final ReportSyncRequestPreparation? preparation;
  int recordRequestCalls = 0;
  int applyCalls = 0;

  late final request = const ReportSyncCodec().create(
    direction: ReportSyncDirection.request,
    exchangeType: ReportSyncExchangeType.food,
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
    payload: const {
      'requestId': 'request-food',
      'requestDigest': digest,
      'operationDate': '2026-08-02',
      'meals': <Object?>[],
    },
  );

  @override
  Future<ReportSyncApplyResult> apply(ReportSyncResponsePreview preview) async {
    applyCalls++;
    return ReportSyncApplyResult(disposition, readBackVerified: true);
  }

  @override
  String encode(ReportSyncEnvelope envelope) => jsonEncode(envelope.toJson());

  @override
  Future<List<ReportSyncHistory>> history(ReportSyncExchangeType type) async =>
      [
        ReportSyncHistory(
          exchangeId: 'request-food',
          exchangeType: type,
          direction: ReportSyncDirection.request,
          operationDate: '2026-08-02',
          requestId: 'request-food',
          requestDigest: digest,
          startedAt: DateTime.utc(2026, 8, 2),
          completedAt: DateTime.utc(2026, 8, 2),
          result: ReportSyncHistoryResult.success,
          packageDigest: digest,
        ),
      ];

  @override
  Future<Object?> importedRecord(
    ReportSyncExchangeType type,
    String localDate,
  ) async => null;

  @override
  String instruction(ReportSyncExchangeType type) => 'JSON ONLY';

  @override
  Future<ReportSyncRequestPreparation> prepareRequest(
    ReportSyncExchangeType type,
  ) async => preparation ?? ReportSyncRequestPreparation(envelope: request);

  @override
  Future<ReportSyncResponsePreview> previewResponse(
    ReportSyncExchangeType type,
    String rawResponse,
  ) async => ReportSyncResponsePreview(
    envelope: response,
    disposition: disposition,
    createCount: disposition == ReportSyncDisposition.create ? 1 : 0,
    noChangeCount: disposition == ReportSyncDisposition.noChanges ? 1 : 0,
    conflictCount: disposition == ReportSyncDisposition.conflict ? 1 : 0,
  );

  @override
  Future<void> recordRequest(ReportSyncEnvelope request) async {
    recordRequestCalls++;
  }
}

class _FakeFileGateway implements BackupFileGateway {
  _FakeFileGateway({this.selected});

  final BackupSelectedFile? selected;
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
  Future<BackupSelectedFile?> selectJson() async => selected;
}
