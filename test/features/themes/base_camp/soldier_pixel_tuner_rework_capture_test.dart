import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/services/device_settings_controller.dart';
import 'package:or_app/core/widgets/operation_button.dart';
import 'package:or_app/features/themes/base_camp/base_camp_dashboard_page.dart';
import 'package:or_app/features/themes/base_camp/base_camp_retro_theme.dart';
import 'package:or_app/features/themes/base_camp/base_camp_soldier_pixelation.dart';
import 'package:or_app/features/themes/base_camp/soldier_live_motion_preview_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _captureDirectory = String.fromEnvironment(
  'SOLDIER_TUNER_REWORK_CAPTURE_DIR',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await Future.wait(<Future<void>>[
      _loadFont(
        baseCampPixelFontFamily,
        'assets/fonts/PressStart2P-Regular.ttf',
      ),
      _loadFont(
        baseCampJapaneseFontFallback,
        'assets/fonts/DotGothic16-Regular.ttf',
      ),
    ]);
  });

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    DeviceSettingsController.instance.resetForTesting(const DeviceSettings());
    BaseCampSoldierPixelCache.instance.resetForTesting();
    baseCampRifleGlobalAlignment.resetForTesting();
  });

  tearDown(BaseCampSoldierPixelCache.instance.resetForTesting);

  for (final level in SoldierPixelationLevel.values) {
    testWidgets('captures live preview ${level.name}', (tester) async {
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.binding.setSurfaceSize(const Size(430, 932));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.runAsync(() => _selectAndPrepare(level));
      final boundaryKey = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          theme: BaseCampRetroTheme.apply(ThemeData.light()),
          home: RepaintBoundary(
            key: boundaryKey,
            child: const SoldierLiveMotionPreviewPage(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      if (level == SoldierPixelationLevel.original) {
        final context = tester.element(find.byType(Scaffold));
        await tester.runAsync(
          () => Future.wait(<Future<void>>[
            precacheImage(
              const AssetImage(baseCampBreathingSoldierLowerAsset),
              context,
            ),
            precacheImage(
              const AssetImage(baseCampBreathingSoldierUpperAsset),
              context,
            ),
          ]),
        );
        await tester.pump();
      }
      expect(tester.takeException(), isNull);
      await _capture(tester, boundaryKey, 'preview_${level.name}.png');
    });
  }

  testWidgets('captures non-zero regrip preview', (tester) async {
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.runAsync(
      () => _selectAndPrepare(SoldierPixelationLevel.coarse),
    );
    final boundaryKey = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        theme: BaseCampRetroTheme.apply(ThemeData.light()),
        home: RepaintBoundary(
          key: boundaryKey,
          child: const SoldierLiveMotionPreviewPage(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    final trigger = find.byKey(const ValueKey('soldier-live-trigger-regrip'));
    tester.widget<OperationButton>(trigger).onPressed!();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1200));
    expect(find.text('PHASE: RIFLEREGRIP'), findsOneWidget);
    await _capture(tester, boundaryKey, 'preview_coarse_regrip.png');
  });

  testWidgets('captures selected level on the real Dashboard', (tester) async {
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    DeviceSettingsController.instance.resetForTesting(
      const DeviceSettings(
        soldierPixelationLevel: SoldierPixelationLevel.coarse,
      ),
    );
    final boundaryKey = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        theme: BaseCampRetroTheme.apply(ThemeData.light()),
        home: RepaintBoundary(
          key: boundaryKey,
          child: const BaseCampDashboardPage(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    final window = tester.renderObject<RenderBox>(
      find.byKey(const ValueKey('base-camp-soldier-display-window')),
    );
    final viewport = Size(window.size.width - 8, window.size.height - 8);
    await tester.runAsync(
      () => BaseCampSoldierPixelCache.instance.prepareRequests(
        baseCampSoldierPixelProfile(
          viewport: viewport,
          devicePixelRatio: 3,
        ).requests,
        SoldierPixelationLevel.coarse,
      ),
    );
    await tester.pump();
    expect(
      find.byKey(
        ValueKey<String>(
          'soldier-pixelated-${SoldierPixelationLevel.coarse.name}-'
          '$baseCampBreathingSoldierLowerAsset',
        ),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await _capture(tester, boundaryKey, 'dashboard_coarse.png');
  });
}

Future<void> _selectAndPrepare(SoldierPixelationLevel level) async {
  DeviceSettingsController.instance.resetForTesting(
    DeviceSettings(soldierPixelationLevel: level),
  );
  if (level == SoldierPixelationLevel.original) return;
  const width = 430.0 - 32;
  final profile = baseCampSoldierPixelProfile(
    viewport: const Size(width, width / 1.35),
    devicePixelRatio: 3,
  );
  await BaseCampSoldierPixelCache.instance.prepareRequests(
    profile.requests,
    level,
  );
}

Future<void> _loadFont(String family, String asset) async {
  final bytes = File(asset).readAsBytesSync();
  final loader = FontLoader(family)
    ..addFont(Future<ByteData>.value(ByteData.sublistView(bytes)));
  await loader.load();
}

Future<void> _capture(
  WidgetTester tester,
  GlobalKey boundaryKey,
  String name,
) async {
  if (_captureDirectory.isEmpty) return;
  await tester.runAsync(() async {
    final directory = Directory(_captureDirectory)..createSync(recursive: true);
    final boundary =
        boundaryKey.currentContext!.findRenderObject()!
            as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    await File('${directory.path}/$name').writeAsBytes(
      data!.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    );
    image.dispose();
  });
}
