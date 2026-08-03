import 'package:flutter/services.dart';

abstract interface class ReportSyncClipboardGateway {
  Future<String?> readText();

  Future<void> writeText(String text);

  factory ReportSyncClipboardGateway.platform() =>
      const FlutterReportSyncClipboardGateway();
}

class FlutterReportSyncClipboardGateway implements ReportSyncClipboardGateway {
  const FlutterReportSyncClipboardGateway();

  @override
  Future<String?> readText() async =>
      (await Clipboard.getData(Clipboard.kTextPlain))?.text;

  @override
  Future<void> writeText(String text) =>
      Clipboard.setData(ClipboardData(text: text));
}
