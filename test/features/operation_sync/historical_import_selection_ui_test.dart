import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/operation_sync/models/historical_import_difference.dart';
import 'package:or_app/features/operation_sync/models/operation_sync_history.dart';
import 'package:or_app/features/operation_sync/services/historical_dns_workflow.dart';
import 'package:or_app/features/operation_sync/services/historical_training_workflow.dart';
import 'package:or_app/features/operation_sync/widgets/historical_dns_import_panel.dart';
import 'package:or_app/features/operation_sync/widgets/historical_training_import_panel.dart';

void main() {
  testWidgets('DNS selection supports individual, all, clear, and zero state', (
    tester,
  ) async {
    await _pumpPanel(
      tester,
      HistoricalDnsImportPanel(workflow: _DnsWorkflow()),
      width: 900,
    );
    await _selectRangeAndValidate(tester);

    tester.view.physicalSize = const Size(390, 1800);
    await tester.pump();

    expect(find.text('SELECTED 2 / 2'), findsOneWidget);
    final checkboxes = find.byType(Checkbox);
    expect(checkboxes, findsNWidgets(4));
    expect(tester.widget<Checkbox>(checkboxes.at(1)).onChanged, isNotNull);
    expect(tester.widget<Checkbox>(checkboxes.at(2)).onChanged, isNull);
    expect(tester.widget<Checkbox>(checkboxes.at(3)).onChanged, isNull);
    tester.widget<Checkbox>(checkboxes.first).onChanged!(false);
    await tester.pump();
    expect(find.text('SELECTED 1 / 2'), findsOneWidget);
    tester.widget<Checkbox>(checkboxes.first).onChanged!(true);
    await tester.pump();
    expect(find.text('SELECTED 2 / 2'), findsOneWidget);

    _textButton(tester, 'CLEAR ALL').onPressed!();
    await tester.pump();
    expect(find.text('SELECTED 0 / 2'), findsOneWidget);
    expect(_importButton(tester).onPressed, isNull);
    _textButton(tester, 'SELECT ALL').onPressed!();
    await tester.pump();
    expect(find.text('SELECTED 2 / 2'), findsOneWidget);
    expect(_importButton(tester).onPressed, isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Training selection has the same controls and no overflow', (
    tester,
  ) async {
    await _pumpPanel(
      tester,
      HistoricalTrainingImportPanel(workflow: _TrainingWorkflow()),
      width: 900,
    );
    await _selectRangeAndValidate(tester);

    expect(find.text('SELECTED 2 / 2'), findsOneWidget);
    expect(find.text('DIFFERENT 1'), findsOneWidget);
    expect(find.text('DIFFERENCE PREVIEW'), findsOneWidget);
    final checkboxes = find.byType(Checkbox);
    expect(checkboxes, findsNWidgets(4));
    expect(tester.widget<Checkbox>(checkboxes.at(0)).onChanged, isNotNull);
    expect(tester.widget<Checkbox>(checkboxes.at(1)).onChanged, isNotNull);
    expect(tester.widget<Checkbox>(checkboxes.at(2)).onChanged, isNull);
    expect(tester.widget<Checkbox>(checkboxes.at(3)).onChanged, isNull);
    _textButton(tester, 'CLEAR ALL').onPressed!();
    await tester.pump();
    expect(find.text('SELECTED 0 / 2'), findsOneWidget);
    expect(_importButton(tester).onPressed, isNull);
    _textButton(tester, 'SELECT ALL').onPressed!();
    await tester.pump();
    expect(find.text('SELECTED 2 / 2'), findsOneWidget);
    expect(_importButton(tester).onPressed, isNotNull);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpPanel(
  WidgetTester tester,
  Widget panel, {
  required double width,
}) async {
  tester.view.physicalSize = Size(width, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: panel)),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _selectRangeAndValidate(WidgetTester tester) async {
  await tester.tap(find.text('SELECT DATE RANGE'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('1').last);
  await tester.pump();
  await tester.tap(find.text('2').last);
  await tester.pump();
  final useRange = find.widgetWithText(TextButton, 'USE RANGE');
  expect(tester.widget<TextButton>(useRange).onPressed, isNotNull);
  await tester.tap(useRange);
  await tester.pumpAndSettle();
  expect(find.text('SELECT DATE RANGE'), findsNothing);
  await tester.enterText(find.byType(TextField), 'fixture');
  tester.testTextInput.hide();
  await tester.pumpAndSettle();
  final validate = find.widgetWithText(FilledButton, 'VALIDATE');
  await tester.scrollUntilVisible(
    validate,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pump();
  await tester.tap(validate);
  await tester.pumpAndSettle();
}

ElevatedButton _importButton(WidgetTester tester) =>
    tester.widget<ElevatedButton>(find.byType(ElevatedButton).last);

TextButton _textButton(WidgetTester tester, String label) =>
    tester.widget<TextButton>(find.widgetWithText(TextButton, label));

class _DnsWorkflow implements HistoricalDnsWorkflow {
  final previewValue = HistoricalDnsPreview(
    exchangeId: 'dns',
    createdAt: DateTime.utc(2026, 8, 9),
    responseDigest: 'a' * 64,
    packageDigest: 'b' * 64,
    requestedStartDate: '2026-08-01',
    requestedEndDate: '2026-08-02',
    envelope: const {},
    records: const [
      HistoricalDnsPreviewItem(
        index: 0,
        operationDate: '2026-08-01',
        sourceDigest: 'a',
        aggregate: null,
        disposition: OperationSyncRecordDisposition.newRecord,
        issues: [],
      ),
      HistoricalDnsPreviewItem(
        index: 1,
        operationDate: '2026-08-02',
        sourceDigest: 'b',
        aggregate: null,
        disposition: OperationSyncRecordDisposition.conflict,
        issues: [],
      ),
      HistoricalDnsPreviewItem(
        index: 2,
        operationDate: '2026-08-03',
        sourceDigest: 'c',
        aggregate: null,
        disposition: OperationSyncRecordDisposition.identical,
        issues: [],
      ),
      HistoricalDnsPreviewItem(
        index: 3,
        operationDate: '2026-08-04',
        sourceDigest: 'd',
        aggregate: null,
        disposition: OperationSyncRecordDisposition.blocked,
        issues: [],
      ),
    ],
  );

  @override
  String buildPrompt({required String startDate, required String endDate}) =>
      '';

  @override
  Future<HistoricalDnsPreview> preview(
    String responseJson, {
    required String startDate,
    required String endDate,
  }) async => previewValue;

  @override
  Future<HistoricalDnsApplyResult> apply(
    HistoricalDnsPreview preview, {
    Set<int>? selectedIndexes,
  }) => throw UnimplementedError();

  @override
  Future<List<OperationSyncRecord>> listRecords() async => const [];
}

class _TrainingWorkflow implements HistoricalTrainingWorkflow {
  final previewValue = HistoricalTrainingPreview(
    exchangeId: 'training',
    createdAt: DateTime.utc(2026, 8, 9),
    responseDigest: 'a' * 64,
    packageDigest: 'b' * 64,
    requestedStartDate: '2026-08-01',
    requestedEndDate: '2026-08-02',
    envelope: const {},
    records: const [
      HistoricalTrainingPreviewItem(
        index: 0,
        sourceRecordId: 'one',
        operationDate: '2026-08-01',
        sourceDigest: 'a',
        targetRecordId: 'one',
        domainDigest: 'a',
        persistedRecord: null,
        disposition: OperationSyncRecordDisposition.newRecord,
        issues: [],
      ),
      HistoricalTrainingPreviewItem(
        index: 1,
        sourceRecordId: 'two',
        operationDate: '2026-08-02',
        sourceDigest: 'b',
        targetRecordId: 'two',
        domainDigest: 'b',
        persistedRecord: null,
        disposition: OperationSyncRecordDisposition.conflict,
        differences: [
          HistoricalImportDifference(
            field: 'session.session.memo',
            current: null,
            incoming: 'corrected',
          ),
        ],
        issues: [],
      ),
      HistoricalTrainingPreviewItem(
        index: 2,
        sourceRecordId: 'same',
        operationDate: '2026-08-03',
        sourceDigest: 'c',
        targetRecordId: 'same',
        domainDigest: 'c',
        persistedRecord: null,
        disposition: OperationSyncRecordDisposition.identical,
        issues: [],
      ),
      HistoricalTrainingPreviewItem(
        index: 3,
        sourceRecordId: 'blocked',
        operationDate: '2026-08-04',
        sourceDigest: 'd',
        targetRecordId: 'blocked',
        domainDigest: 'd',
        persistedRecord: null,
        disposition: OperationSyncRecordDisposition.blocked,
        issues: [],
      ),
    ],
  );

  @override
  String buildPrompt({required String startDate, required String endDate}) =>
      '';

  @override
  Future<HistoricalTrainingPreview> preview(
    String responseJson, {
    required String startDate,
    required String endDate,
  }) async => previewValue;

  @override
  Future<HistoricalTrainingApplyResult> apply(
    HistoricalTrainingPreview preview, {
    Set<int>? selectedIndexes,
  }) => throw UnimplementedError();

  @override
  Future<List<OperationSyncRecord>> listRecords() async => const [];
}
