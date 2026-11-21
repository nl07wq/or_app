import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/services/device_settings_controller.dart';
import 'package:or_app/core/state/app_initialization_state.dart';
import 'package:or_app/features/themes/base_camp/widgets/base_camp_boot_sequence.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await _loadFont('PressStart2P', 'assets/fonts/PressStart2P-Regular.ttf');
    await _loadFont('DotGothic16', 'assets/fonts/DotGothic16-Regular.ttf');
  });

  testWidgets('captures all BASE CAMP boot phases from implemented widget', (
    tester,
  ) async {
    debugPaintBaselinesEnabled = false;
    debugPaintSizeEnabled = false;
    final output = Platform.environment['OR_APP_BOOT_SCREENSHOT_DIR'];
    if (output == null || output.isEmpty) return;
    final directory = Directory(output)..createSync(recursive: true);

    await _renderAndCapture(
      tester,
      directory: directory,
      name: 'power_on_initial_320_light',
      width: 320,
      negative: false,
      state: const AppInitializationState.initializing(),
    );
    await _renderAndCapture(
      tester,
      directory: directory,
      name: 'terminal_initializing_320_light',
      width: 320,
      negative: false,
      wakeElapsed: const Duration(milliseconds: 400),
      state: const AppInitializationState.initializing(),
    );
    await _renderAndCapture(
      tester,
      directory: directory,
      name: 'system_check_375_light',
      width: 375,
      negative: false,
      wakeElapsed: const Duration(milliseconds: 800),
      state: const AppInitializationState.initializing(
        currentStage: InitializationStage.migratingFood,
      ),
    );
    await _captureMotionFrames(tester, directory);
    await _renderAndCapture(
      tester,
      directory: directory,
      name: 'base_camp_link_390_inv',
      width: 390,
      negative: true,
      wakeElapsed: const Duration(milliseconds: 1200),
      state: const AppInitializationState.initializing(
        currentStage: InitializationStage.verifyingRepositories,
      ),
    );
    await _renderAndCapture(
      tester,
      directory: directory,
      name: 'system_ready_430_light',
      width: 430,
      negative: false,
      wakeElapsed: const Duration(milliseconds: 1550),
      state: const AppInitializationState(
        mode: PersistenceMode.indexedDbReadWrite,
        currentStage: InitializationStage.complete,
      ),
    );

    DeviceSettingsController.instance.resetForTesting(const DeviceSettings());
  });
}

Future<void> _captureMotionFrames(
  WidgetTester tester,
  Directory directory,
) async {
  tester.view.physicalSize = const Size(390, 640);
  tester.view.devicePixelRatio = 1;
  DeviceSettingsController.instance.resetForTesting(
    const DeviceSettings(presentationTheme: AppPresentationTheme.baseCamp),
  );
  final boundaryKey = GlobalKey();
  final initialization = ValueNotifier<AppInitializationState>(
    const AppInitializationState.initializing(
      currentStage: InitializationStage.migratingFood,
    ),
  );
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: RepaintBoundary(
        key: boundaryKey,
        child: BaseCampBootSequenceGate(
          initialization: initialization,
          fallbackBuilder: (_) => const SizedBox.shrink(),
          onPresentationReleased: () {},
        ),
      ),
    ),
  );
  final boundary =
      boundaryKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  for (var frame = 0; frame <= 11; frame++) {
    if (frame > 0) await tester.pump(const Duration(milliseconds: 150));
    await _writeBoundary(
      tester,
      boundary,
      '${directory.path}${Platform.pathSeparator}'
      'boot_motion_${frame.toString().padLeft(2, '0')}.png',
    );
  }
  initialization.dispose();
  tester.view.resetPhysicalSize();
  tester.view.resetDevicePixelRatio();
}

Future<void> _loadFont(String family, String asset) async {
  final bytes = File(asset).readAsBytesSync();
  final loader = FontLoader(family)
    ..addFont(Future<ByteData>.value(ByteData.sublistView(bytes)));
  await loader.load();
}

Future<void> _renderAndCapture(
  WidgetTester tester, {
  required Directory directory,
  required String name,
  required double width,
  required bool negative,
  required AppInitializationState state,
  Duration wakeElapsed = Duration.zero,
}) async {
  tester.view.physicalSize = Size(width, 640);
  tester.view.devicePixelRatio = 1;
  DeviceSettingsController.instance.resetForTesting(
    DeviceSettings(
      presentationTheme: AppPresentationTheme.baseCamp,
      baseCampLcdNegative: negative,
    ),
  );
  final boundaryKey = GlobalKey();
  final initialization = ValueNotifier<AppInitializationState>(state);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: RepaintBoundary(
        key: boundaryKey,
        child: BaseCampBootSequenceGate(
          initialization: initialization,
          fallbackBuilder: (_) => const SizedBox.shrink(),
          onPresentationReleased: () {},
        ),
      ),
    ),
  );
  if (wakeElapsed > Duration.zero) {
    await tester.pump(wakeElapsed);
  }
  // flutter_test may restore debug-paint globals while installing a new root.
  // Reassert production paint settings and force the capture frame to repaint.
  debugPaintBaselinesEnabled = false;
  debugPaintSizeEnabled = false;
  final boundary =
      boundaryKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  _markPaintTreeDirty(boundary);
  await tester.pump();
  expect(debugPaintBaselinesEnabled, isFalse);
  expect(tester.takeException(), isNull);

  await _writeBoundary(
    tester,
    boundary,
    '${directory.path}${Platform.pathSeparator}$name.png',
    pixelRatio: 2,
  );
  initialization.dispose();
  tester.view.resetPhysicalSize();
  tester.view.resetDevicePixelRatio();
}

Future<void> _writeBoundary(
  WidgetTester tester,
  RenderRepaintBoundary boundary,
  String path, {
  double pixelRatio = 1,
}) async {
  debugPaintBaselinesEnabled = false;
  debugPaintSizeEnabled = false;
  _markPaintTreeDirty(boundary);
  await tester.pump();
  await tester.runAsync(() async {
    // The capture-only test needs the marked boundary painted synchronously
    // before reading its layer outside the fake async zone.
    // ignore: invalid_use_of_protected_member
    RendererBinding.instance.drawFrame();
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    await File(path).writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
  });
}

void _markPaintTreeDirty(RenderObject object) {
  object.markNeedsPaint();
  object.visitChildren(_markPaintTreeDirty);
}
