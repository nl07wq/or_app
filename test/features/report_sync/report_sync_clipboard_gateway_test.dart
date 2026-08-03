import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/report_sync/services/report_sync_clipboard_gateway.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Flutter clipboard gateway reads and writes plain text', () async {
    String? written;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          switch (call.method) {
            case 'Clipboard.getData':
              expect(call.arguments, Clipboard.kTextPlain);
              return <String, Object?>{'text': '{"response":true}'};
            case 'Clipboard.setData':
              written = (call.arguments as Map)['text'] as String;
              return null;
          }
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );

    const gateway = FlutterReportSyncClipboardGateway();
    expect(await gateway.readText(), '{"response":true}');
    await gateway.writeText('plain prompt');
    expect(written, 'plain prompt');
  });
}
