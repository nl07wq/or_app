import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/services/system_diagnostics.dart';
import 'package:or_app/core/widgets/operation_button.dart';
import 'package:or_app/features/themes/base_camp/base_camp_dashboard_page.dart';
import 'package:or_app/features/themes/base_camp/soldier_live_motion_preview_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('captures preview and Dashboard regrip frame timestamps', (
    tester,
  ) async {
    final output = Platform.environment['OR_APP_REGRIP_CAPTURE_DIR'];
    if (output == null || output.isEmpty) return;
    final directory = Directory(output)..createSync(recursive: true);
    final boundaryKey = GlobalKey();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    baseCampRifleGlobalAlignment.resetForTesting();
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: RepaintBoundary(
          key: boundaryKey,
          child: const SoldierLiveMotionPreviewPage(),
        ),
      ),
    );
    await tester.pump();
    final trigger = find.byKey(const ValueKey('soldier-live-trigger-regrip'));
    await tester.ensureVisible(trigger);
    tester.widget<OperationButton>(trigger).onPressed!();
    tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position
        .jumpTo(0);
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();
    await _capture(tester, boundaryKey, directory, 'preview_f0_t0000');
    await _captureFrames(tester, boundaryKey, directory, 'preview');

    SystemDiagnostics.instance.clear();
    await tester.pumpWidget(
      MaterialApp(
        home: RepaintBoundary(
          key: boundaryKey,
          child: const BaseCampDashboardPage(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const ValueKey('base-camp-soldier-panel')));
    for (var attempt = 0; attempt < 80; attempt++) {
      await tester.pump(const Duration(milliseconds: 50));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 1)),
      );
      if (SystemDiagnostics.instance.copyText().contains(
        'RIFLE_REGRIP_PLAYBACK_START',
      )) {
        break;
      }
    }
    expect(
      SystemDiagnostics.instance.copyText(),
      contains('RIFLE_REGRIP_PLAYBACK_START'),
    );
    await _capture(tester, boundaryKey, directory, 'dashboard_f0_t0000');
    await _captureFrames(tester, boundaryKey, directory, 'dashboard');
  });
}

Future<void> _captureFrames(
  WidgetTester tester,
  GlobalKey boundaryKey,
  Directory directory,
  String prefix,
) async {
  const boundaries = <int>[400, 750, 950, 1300, 1450];
  var previous = 0;
  for (var frame = 1; frame < 6; frame++) {
    final timestamp = boundaries[frame - 1];
    await tester.pump(Duration(milliseconds: timestamp - previous));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
    await _capture(
      tester,
      boundaryKey,
      directory,
      '${prefix}_f${frame}_t${timestamp.toString().padLeft(4, '0')}',
    );
    previous = timestamp;
  }
  await tester.pump(const Duration(milliseconds: 400));
  await _capture(tester, boundaryKey, directory, '${prefix}_breathing_t1850');
}

Future<void> _capture(
  WidgetTester tester,
  GlobalKey boundaryKey,
  Directory directory,
  String name,
) => tester.runAsync(() async {
  final boundary =
      boundaryKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await boundary.toImage(pixelRatio: 1);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  await File(
    '${directory.path}${Platform.pathSeparator}$name.png',
  ).writeAsBytes(data!.buffer.asUint8List());
  image.dispose();
});
