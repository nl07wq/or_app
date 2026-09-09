import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/services/finalize_backup_trace.dart';
import 'package:or_app/features/system/pages/finalize_backup_trace_page.dart';

void main() {
  setUp(FinalizeBackupTrace.instance.clear);
  tearDown(FinalizeBackupTrace.instance.clear);

  testWidgets('shows and copies the bounded Dashboard/CC parity trace', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    FinalizeBackupTrace.instance.record(
      'COMMAND_CENTER',
      'BACKUP_PROMPT_REQUESTED',
      operationDate: '2026-09-08',
    );
    String? copiedText;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            copiedText =
                (call.arguments as Map<Object?, Object?>)['text'] as String?;
          }
          return null;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    await tester.pumpWidget(const MaterialApp(home: FinalizeBackupTracePage()));

    expect(find.text('FINALIZE BACKUP PARITY TRACE'), findsOneWidget);
    expect(find.text('1 EVENTS'), findsOneWidget);
    final traceText = tester.widget<SelectableText>(
      find.byKey(const ValueKey('finalize-backup-trace')),
    );
    expect(traceText.data, contains('BACKUP_PROMPT_REQUESTED'));
    await tester.ensureVisible(find.text('COPY TRACE'));
    await tester.tap(find.text('COPY TRACE'));
    await tester.pump();
    expect(copiedText, contains('COMMAND_CENTER'));

    await tester.tap(find.byKey(const ValueKey('finalize-backup-trace-clear')));
    await tester.pump();
    expect(find.text('0 EVENTS'), findsOneWidget);
  });
}
