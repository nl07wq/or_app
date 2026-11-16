import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/services/navigation_diagnostic_binding.dart';
import 'package:or_app/core/services/system_diagnostics.dart';

void main() {
  const malformed = 'http://or-app.invalid:bad/path?probe=%25#uri-evidence-v2';

  test('same platform-message boundary captures exact malformed URI', () async {
    final diagnostics = SystemDiagnostics.testing()..beginSession();
    final messenger = NavigationDiagnosticBinaryMessenger(
      _ParsingNavigationMessenger(),
      diagnostics: diagnostics,
    );
    final message = const JSONMethodCodec().encodeMethodCall(
      const MethodCall('routeInformationUpdated', <String, Object?>{
        'uri': malformed,
        'state': <String, Object?>{'probe': true},
        'replace': true,
      }),
    );

    await expectLater(
      messenger.send(SystemChannels.navigation.name, message),
      throwsFormatException,
    );

    final exported = jsonDecode(diagnostics.copyUriEvidenceText()) as Map;
    final incidents = exported['incidents'] as List;
    expect(incidents, hasLength(1));
    final incident = incidents.single as Map;
    expect(incident['captureCompleteness'], 'engine_input_captured');
    final related = incident['relatedPlatformMessage'] as Map;
    expect(related['method'], 'routeInformationUpdated');
    expect(related['rawUri'], malformed);
    expect(_decodeUtf16Le(related['rawUriUtf16LeBase64'] as String), malformed);
    expect(related['collectorParseResult'], 'format_exception');
  });

  test(
    'successful navigation remains unchanged and creates no incident',
    () async {
      final diagnostics = SystemDiagnostics.testing()..beginSession();
      final messenger = NavigationDiagnosticBinaryMessenger(
        _ParsingNavigationMessenger(),
        diagnostics: diagnostics,
      );
      final message = const JSONMethodCodec().encodeMethodCall(
        const MethodCall('routeInformationUpdated', <String, Object?>{
          'uri': '/system#diagnostics',
          'replace': false,
        }),
      );

      await messenger.send(SystemChannels.navigation.name, message);

      expect(diagnostics.uriIncidentCount, 0);
      expect(diagnostics.copyText(), contains('PLATFORM_MESSAGE_SENT'));
    },
  );

  test('incident survives a reconstructed diagnostics instance', () async {
    final diagnostics = SystemDiagnostics.testing()..beginSession();
    final messenger = NavigationDiagnosticBinaryMessenger(
      _ParsingNavigationMessenger(),
      diagnostics: diagnostics,
    );
    final message = const JSONMethodCodec().encodeMethodCall(
      const MethodCall('routeInformationUpdated', <String, Object?>{
        'uri': malformed,
        'replace': true,
      }),
    );
    await expectLater(
      messenger.send(SystemChannels.navigation.name, message),
      throwsFormatException,
    );
    final firstExport = jsonDecode(diagnostics.copyUriEvidenceText()) as Map;

    final restored = SystemDiagnostics.testing(
      initialUriIncidents: (firstExport['incidents'] as List)
          .cast<Map>()
          .map((value) => Map<String, Object?>.from(value))
          .toList(),
    )..beginSession();

    expect(restored.uriIncidentCount, 1);
    final secondExport = jsonDecode(restored.copyUriEvidenceText()) as Map;
    final related =
        ((secondExport['incidents'] as List).single
                as Map)['relatedPlatformMessage']
            as Map;
    expect(_decodeUtf16Le(related['rawUriUtf16LeBase64'] as String), malformed);
  });

  test('deduplicates one failure and bounds retained incidents', () async {
    final diagnostics = SystemDiagnostics.testing()..beginSession();
    for (var index = 0; index < 7; index++) {
      final messenger = NavigationDiagnosticBinaryMessenger(
        _ParsingNavigationMessenger(),
        diagnostics: diagnostics,
      );
      final message = const JSONMethodCodec().encodeMethodCall(
        MethodCall('routeInformationUpdated', <String, Object?>{
          'uri': malformed,
          'replace': true,
        }),
      );
      await expectLater(
        messenger.send(SystemChannels.navigation.name, message),
        throwsFormatException,
      );
    }
    expect(diagnostics.uriIncidentCount, 5);
  });
}

class _ParsingNavigationMessenger extends BinaryMessenger {
  @override
  Future<ByteData?> send(String channel, ByteData? message) async {
    if (channel == SystemChannels.navigation.name) {
      final call = const JSONMethodCodec().decodeMethodCall(message);
      if (call.method == 'routeInformationUpdated') {
        final arguments = call.arguments! as Map;
        Uri.parse(arguments['uri']! as String);
      }
    }
    return null;
  }

  @override
  Future<void> handlePlatformMessage(
    String channel,
    ByteData? data,
    ui.PlatformMessageResponseCallback? callback,
  ) async {
    callback?.call(null);
  }

  @override
  void setMessageHandler(String channel, MessageHandler? handler) {}
}

String _decodeUtf16Le(String encoded) {
  final bytes = base64Decode(encoded);
  final units = <int>[];
  for (var index = 0; index < bytes.length; index += 2) {
    units.add(bytes[index] | (bytes[index + 1] << 8));
  }
  return String.fromCharCodes(units);
}
