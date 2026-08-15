import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/navigation/app_routes.dart';
import 'package:or_app/features/repositories/app_repository_container.dart';
import 'package:or_app/features/system/pages/animations_sandbox_page.dart';
import 'package:or_app/features/system/pages/system_page.dart';
import 'package:or_app/features/system/services/storage_status_gateway.dart';

import '../../repositories/indexed_db/fake_indexed_db_database.dart';

void main() {
  setUp(() {
    AppRepositoryRegistry.install(
      AppRepositoryContainer.indexedDb(FakeIndexedDbDatabase()),
    );
  });

  tearDown(AppRepositoryRegistry.resetForTesting);

  testWidgets('SYSTEM opens the sandbox below INITIALIZE APP DATA', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: SystemPage(
          dataHealthLoader: () async => const SystemDataHealthSnapshot(
            integrity: 'READABLE',
            recoveryStatus: 'NO RECOVERY REQUIRED',
            healthStatus: 'HEALTHY',
          ),
          storageGateway: const _FakeStorageGateway(),
        ),
        routes: {
          AppRoutes.animationsSandbox: (_) => const AnimationsSandboxPage(),
          AppRoutes.bootSequencePreview: (_) => const BootSequencePreviewPage(),
        },
      ),
    );
    await tester.pump();
    await tester.scrollUntilVisible(find.text('OPEN ANIMATIONS SANDBOX'), 300);

    expect(find.text('INITIALIZE APP DATA'), findsWidgets);
    expect(find.text('ANIMATIONS SANDBOX'), findsOneWidget);
    final initializeTop = tester.getTopLeft(
      find.text('INITIALIZE APP DATA').last,
    );
    final sandboxTop = tester.getTopLeft(find.text('ANIMATIONS SANDBOX'));
    expect(sandboxTop.dy, greaterThan(initializeTop.dy));

    await tester.tap(find.text('OPEN ANIMATIONS SANDBOX'));
    await tester.pumpAndSettle();
    expect(find.byType(AnimationsSandboxPage), findsOneWidget);
    expect(find.text('BOOT SEQUENCE'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('BOOT SEQUENCE opens the transient calibration test', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: const AnimationsSandboxPage(),
        routes: {
          AppRoutes.bootSequencePreview: (_) => const BootSequencePreviewPage(),
          AppRoutes.bootSequenceCalibration: (_) =>
              const BootSequenceCalibrationPage(),
        },
      ),
    );
    await tester.tap(find.byKey(const ValueKey('open-boot-sequence-preview')));
    await tester.pumpAndSettle();
    expect(find.byType(BootSequencePreviewPage), findsOneWidget);
    expect(find.text('CALIBRATION TEST'), findsWidgets);

    await tester.tap(
      find.byKey(const ValueKey('open-boot-sequence-calibration')),
    );
    await tester.pumpAndSettle();

    expect(find.byType(BootSequenceCalibrationPage), findsOneWidget);
    expect(
      find.byKey(const ValueKey('calibration-background')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('calibration-jeep-body')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('calibration-front-wheel')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('calibration-rear-wheel')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('calibration-grid')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('calibration-vertical-center-line')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('calibration-horizontal-center-line')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('calibration-center-marker')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('calibration updates targets, snapshots, motion, and JSON', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 5200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: BootSequenceCalibrationPage()),
    );

    final initialJson = _calibrationJson(tester);
    expect(initialJson['coordinateSystem'], 'alignment_normalized');
    final initialJeep = initialJson['jeepAssembly'] as Map<String, dynamic>;
    expect(initialJeep['start'], isNull);
    expect(initialJeep['end'], isNull);

    final initialAlignment = _calibrationAlignment(tester);
    await _dragCalibrationCanvas(tester, const Offset(-24, 18));
    await tester.pump();
    final movedAlignment = _calibrationAlignment(tester);
    expect(movedAlignment.x, lessThan(initialAlignment.x));
    expect(movedAlignment.y, greaterThan(initialAlignment.y));

    final initialScale = _calibrationScale(tester);
    await tester.drag(
      find.descendant(
        of: find.byKey(const ValueKey('jeep-scale-slider')),
        matching: find.byType(Slider),
      ),
      const Offset(70, 0),
    );
    await tester.pump();
    expect(_calibrationScale(tester), greaterThan(initialScale));

    await tester.tap(find.byKey(const ValueKey('set-calibration-start')));
    await tester.pump();
    expect(find.textContaining('START  X'), findsOneWidget);
    final startAlignment = _calibrationAlignment(tester);
    final startScale = _calibrationScale(tester);

    await _dragCalibrationCanvas(tester, const Offset(-50, 25));
    await tester.drag(
      find.descendant(
        of: find.byKey(const ValueKey('jeep-scale-slider')),
        matching: find.byType(Slider),
      ),
      const Offset(45, 0),
    );
    await tester.tap(find.byKey(const ValueKey('set-calibration-end')));
    await tester.pump();
    expect(find.textContaining('END  X'), findsOneWidget);
    final endAlignment = _calibrationAlignment(tester);
    final endScale = _calibrationScale(tester);

    await tester.tap(
      find.byKey(const ValueKey('calibration-target-frontWheel')),
    );
    await tester.pump();
    final frontBefore =
        _calibrationJson(tester)['frontWheel'] as Map<String, dynamic>;
    await _dragCalibrationCanvas(tester, const Offset(15, -8));
    await tester.drag(
      find.descendant(
        of: find.byKey(const ValueKey('front-wheel-scale-slider')),
        matching: find.byType(Slider),
      ),
      const Offset(30, 0),
    );
    await tester.pump();
    final frontAfter =
        _calibrationJson(tester)['frontWheel'] as Map<String, dynamic>;
    expect(frontAfter['localX'], isNot(frontBefore['localX']));
    expect(frontAfter['localY'], isNot(frontBefore['localY']));
    expect(frontAfter['scale'], isNot(frontBefore['scale']));

    await tester.tap(
      find.byKey(const ValueKey('calibration-target-rearWheel')),
    );
    await tester.pump();
    final rearBefore =
        _calibrationJson(tester)['rearWheel'] as Map<String, dynamic>;
    await _dragCalibrationCanvas(tester, const Offset(-12, 9));
    await tester.drag(
      find.descendant(
        of: find.byKey(const ValueKey('rear-wheel-scale-slider')),
        matching: find.byType(Slider),
      ),
      const Offset(25, 0),
    );
    await tester.pump();
    final rearAfter =
        _calibrationJson(tester)['rearWheel'] as Map<String, dynamic>;
    expect(rearAfter['localX'], isNot(rearBefore['localX']));
    expect(rearAfter['localY'], isNot(rearBefore['localY']));
    expect(rearAfter['scale'], isNot(rearBefore['scale']));

    await tester.drag(
      find.descendant(
        of: find.byKey(const ValueKey('travel-duration-slider')),
        matching: find.byType(Slider),
      ),
      const Offset(45, 0),
    );
    await tester.drag(
      find.descendant(
        of: find.byKey(const ValueKey('hold-duration-slider')),
        matching: find.byType(Slider),
      ),
      const Offset(35, 0),
    );
    await tester.tap(find.byKey(const ValueKey('calibration-curve-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('EASE IN/OUT').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('calibration-test-play')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    expect(_calibrationAlignment(tester), isNot(startAlignment));
    expect(_calibrationScale(tester), isNot(startScale));

    await tester.tap(find.byKey(const ValueKey('calibration-test-stop')));
    await tester.pump();
    expect(_calibrationAlignment(tester), startAlignment);
    expect(_calibrationScale(tester), startScale);

    await tester.tap(find.byKey(const ValueKey('calibration-test-replay')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 20));
    expect(_calibrationAlignment(tester), endAlignment);
    expect(_calibrationScale(tester), endScale);

    final configuredJson = _calibrationJson(tester);
    expect((configuredJson['jeepAssembly'] as Map)['start'], isNotNull);
    expect((configuredJson['jeepAssembly'] as Map)['end'], isNotNull);
    expect(configuredJson['layerOrder'], [
      'background',
      'jeepBody',
      'rearWheel',
      'frontWheel',
    ]);
    expect((configuredJson['motion'] as Map)['curve'], 'easeInOutCubic');
    expect(
      (configuredJson['frontWheel'] as Map)['asset'],
      (configuredJson['rearWheel'] as Map)['asset'],
    );
    expect(
      find.byKey(const ValueKey('calibration-layer-order')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'calibration supports clipboard, touch, mouse, and three widths',
    (tester) async {
      String? copiedText;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'Clipboard.setData') {
              copiedText = (call.arguments as Map)['text'] as String?;
            }
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null),
      );

      for (final width in [320.0, 390.0, 1280.0]) {
        tester.view.physicalSize = Size(width, 5200);
        tester.view.devicePixelRatio = 1;
        await tester.pumpWidget(
          const MaterialApp(home: BootSequenceCalibrationPage()),
        );

        await _dragCalibrationCanvas(tester, const Offset(-10, 8));
        await tester.pump();
        expect(tester.takeException(), isNull, reason: 'width $width');
      }
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final mouseGesture = await tester.startGesture(
        tester.getCenter(
          find.byKey(const ValueKey('calibration-canvas-drag-target')),
        ),
        kind: PointerDeviceKind.mouse,
      );
      final dragTarget = find.byKey(
        const ValueKey('calibration-canvas-drag-target'),
      );
      final beforeMouse = _calibrationAlignment(tester);
      expect(dragTarget, findsOneWidget);
      await mouseGesture.moveBy(const Offset(-16, 10));
      await mouseGesture.up();
      await tester.pump();
      expect(_calibrationAlignment(tester), isNot(beforeMouse));

      await tester.ensureVisible(
        find.byKey(const ValueKey('copy-calibration-parameters')),
      );
      await tester.tap(
        find.byKey(const ValueKey('copy-calibration-parameters')),
      );
      await tester.pump();
      expect(copiedText, _calibrationJsonText(tester));
      expect(find.text('CODEX PARAMETERSをコピーしました'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('boot preview controls transient timeline and all scene slots', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: const AnimationsSandboxPage(),
        routes: {
          AppRoutes.bootSequencePreview: (_) => const BootSequencePreviewPage(),
        },
      ),
    );
    await tester.tap(find.byKey(const ValueKey('open-boot-sequence-preview')));
    await tester.pumpAndSettle();

    expect(find.text('00:00 / 00:06'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('boot-sequence-background')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('jeep-body')), findsOneWidget);
    expect(find.byKey(const ValueKey('jeep-front-wheel')), findsOneWidget);
    expect(find.byKey(const ValueKey('jeep-rear-wheel')), findsOneWidget);
    expect(
      _assetName(tester, const ValueKey('boot-sequence-background')),
      'assets/animations/sandbox/boot_sequence/phase_01/background/'
      'base_camp_background.png',
    );
    expect(
      _assetName(tester, const ValueKey('jeep-body')),
      'assets/animations/sandbox/boot_sequence/phase_01/jeep/jeep_body.png',
    );
    expect(
      _assetName(tester, const ValueKey('jeep-front-wheel')),
      'assets/animations/sandbox/boot_sequence/phase_01/jeep/wheel.png',
    );
    expect(
      _assetName(tester, const ValueKey('jeep-rear-wheel')),
      'assets/animations/sandbox/boot_sequence/phase_01/jeep/wheel.png',
    );
    expect(find.byKey(const ValueKey('preview-play')), findsOneWidget);
    expect(find.byKey(const ValueKey('preview-pause')), findsOneWidget);
    expect(find.byKey(const ValueKey('preview-stop')), findsOneWidget);
    expect(find.byKey(const ValueKey('preview-replay')), findsOneWidget);

    final startAlignment = _jeepAlignment(tester);
    final startScale = _jeepScale(tester);
    final startWheelTurns = _frontWheelTurns(tester);

    await tester.ensureVisible(find.byKey(const ValueKey('preview-play')));
    await tester.tap(find.byKey(const ValueKey('preview-play')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1100));
    expect(find.text('00:01 / 00:06'), findsOneWidget);
    expect(_jeepAlignment(tester).x, lessThan(startAlignment.x));
    expect(_jeepAlignment(tester).y, greaterThan(startAlignment.y));
    expect(_jeepScale(tester), greaterThan(startScale));
    expect(_frontWheelTurns(tester), lessThan(startWheelTurns));
    expect(_rearWheelTurns(tester), _frontWheelTurns(tester));

    await tester.tap(find.byKey(const ValueKey('preview-pause')));
    final pausedAlignment = _jeepAlignment(tester);
    final pausedScale = _jeepScale(tester);
    final pausedWheelTurns = _frontWheelTurns(tester);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('00:01 / 00:06'), findsOneWidget);
    expect(_jeepAlignment(tester), pausedAlignment);
    expect(_jeepScale(tester), pausedScale);
    expect(_frontWheelTurns(tester), pausedWheelTurns);

    await tester.tap(find.byKey(const ValueKey('preview-play')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(_jeepScale(tester), greaterThan(pausedScale));

    await tester.tap(find.byKey(const ValueKey('preview-stop')));
    await tester.pump();
    expect(find.text('00:00 / 00:06'), findsOneWidget);
    expect(_jeepAlignment(tester), startAlignment);
    expect(_jeepScale(tester), startScale);
    expect(_frontWheelTurns(tester), startWheelTurns);

    await tester.ensureVisible(find.byKey(const ValueKey('preview-replay')));
    await tester.tap(find.byKey(const ValueKey('preview-replay')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1100));
    expect(_jeepScale(tester), greaterThan(startScale));

    await tester.ensureVisible(find.byKey(const ValueKey('preview-scene-1')));
    await tester.tap(find.byKey(const ValueKey('preview-scene-1')));
    await tester.pump();
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('current-scene'))).data,
      'SCENE 2',
    );
    expect(
      find.byKey(const ValueKey('scene-placeholder-content')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('jeep-body')), findsNothing);
    expect(find.text('00:00 / 00:08'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const ValueKey('preview-scene-7')));
    await tester.tap(find.byKey(const ValueKey('preview-scene-7')));
    await tester.pump();
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('current-scene'))).data,
      'FINAL',
    );
    expect(
      find.byKey(const ValueKey('scene-placeholder-content')),
      findsOneWidget,
    );
    for (var index = 0; index < 8; index++) {
      expect(find.byKey(ValueKey('preview-scene-$index')), findsOneWidget);
    }

    await tester.tap(find.byKey(const ValueKey('preview-scene-0')));
    await tester.pump();
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('current-scene'))).data,
      'SCENE 1',
    );
    expect(find.byKey(const ValueKey('jeep-body')), findsOneWidget);
    expect(find.text('00:00 / 00:06'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('jeep stops with both wheels after the approach interval', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: BootSequencePreviewPage()));
    await tester.ensureVisible(find.byKey(const ValueKey('preview-play')));
    await tester.tap(find.byKey(const ValueKey('preview-play')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 4600));
    final stoppedAlignment = _jeepAlignment(tester);
    final stoppedScale = _jeepScale(tester);
    final stoppedWheelTurns = _frontWheelTurns(tester);

    await tester.pump(const Duration(milliseconds: 1200));
    expect(_jeepAlignment(tester), stoppedAlignment);
    expect(_jeepScale(tester), stoppedScale);
    expect(_frontWheelTurns(tester), stoppedWheelTurns);
    expect(_rearWheelTurns(tester), stoppedWheelTurns);
    expect(find.text('00:05 / 00:06'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('boot-asset-list')),
      300,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('asset viewer lists exactly three read-only source assets', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: BootSequencePreviewPage()));
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('boot-asset-list')),
      300,
    );

    expect(find.byKey(const ValueKey('boot-asset-card-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('boot-asset-card-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('boot-asset-card-2')), findsOneWidget);
    expect(find.byKey(const ValueKey('boot-asset-card-3')), findsNothing);
    expect(find.text('BACKGROUND'), findsOneWidget);
    expect(find.text('JEEP BODY'), findsOneWidget);
    expect(find.text('WHEEL'), findsOneWidget);
    expect(find.textContaining('base_camp_background.png'), findsWidgets);
    expect(find.textContaining('jeep_body.png'), findsWidgets);
    expect(find.textContaining('wheel.png'), findsWidgets);
    expect(find.text('USAGE  USED ×2'), findsOneWidget);
    expect(find.textContaining('front_wheel.png'), findsNothing);
    expect(find.textContaining('rear_wheel.png'), findsNothing);
    expect(find.text('UPLOAD'), findsNothing);
    expect(find.text('DELETE'), findsNothing);
    expect(find.text('REPLACE'), findsNothing);

    await _openAndCloseAssetPreview(
      tester,
      fileName: 'base_camp_background.png',
      assetName: 'BACKGROUND',
      path:
          'assets/animations/sandbox/boot_sequence/phase_01/background/'
          'base_camp_background.png',
      transparent: false,
    );
    await _openAndCloseAssetPreview(
      tester,
      fileName: 'jeep_body.png',
      assetName: 'JEEP BODY',
      path:
          'assets/animations/sandbox/boot_sequence/phase_01/jeep/'
          'jeep_body.png',
      transparent: true,
    );
    await _openAndCloseAssetPreview(
      tester,
      fileName: 'wheel.png',
      assetName: 'WHEEL',
      path: 'assets/animations/sandbox/boot_sequence/phase_01/jeep/wheel.png',
      transparent: true,
    );

    expect(find.byType(BootSequencePreviewPage), findsOneWidget);
    expect(
      find.byKey(const ValueKey('boot-asset-preview-dialog')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('boot preview has no overflow at desktop width', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: BootSequencePreviewPage()));
    await tester.pump();

    expect(
      find.byKey(const ValueKey('boot-sequence-placeholder')),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('boot-asset-list')),
      300,
    );
    expect(find.byKey(const ValueKey('boot-asset-card-2')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _openAndCloseAssetPreview(
  WidgetTester tester, {
  required String fileName,
  required String assetName,
  required String path,
  required bool transparent,
}) async {
  final thumbnail = find.byKey(ValueKey('boot-asset-thumbnail-$fileName'));
  await tester.ensureVisible(thumbnail);
  await tester.tap(thumbnail);
  await tester.pumpAndSettle();

  final dialog = find.byKey(const ValueKey('boot-asset-preview-dialog'));
  expect(dialog, findsOneWidget);
  expect(
    find.descendant(of: dialog, matching: find.text(assetName)),
    findsWidgets,
  );
  expect(
    find.descendant(of: dialog, matching: find.text('FILE NAME  $fileName')),
    findsOneWidget,
  );
  expect(
    find.descendant(of: dialog, matching: find.text('ASSET PATH  $path')),
    findsOneWidget,
  );
  expect(
    find.byKey(ValueKey('boot-asset-preview-source-$fileName')),
    findsOneWidget,
  );
  expect(
    find.byKey(ValueKey('transparent-asset-backdrop-preview-$fileName')),
    transparent ? findsOneWidget : findsNothing,
  );

  await tester.tap(find.byKey(const ValueKey('close-boot-asset-preview')));
  await tester.pumpAndSettle();
  expect(dialog, findsNothing);
}

Future<void> _dragCalibrationCanvas(WidgetTester tester, Offset delta) async {
  final target = find.byKey(const ValueKey('calibration-canvas-drag-target'));
  final gesture = await tester.startGesture(tester.getCenter(target));
  await gesture.moveBy(Offset(delta.dx, 0));
  await gesture.moveBy(Offset(0, delta.dy));
  await gesture.up();
  await tester.pump();
}

String _assetName(WidgetTester tester, ValueKey<String> key) =>
    (tester.widget<Image>(find.byKey(key)).image as AssetImage).assetName;

Alignment _jeepAlignment(WidgetTester tester) =>
    tester
            .widget<Align>(find.byKey(const ValueKey('jeep-assembly-position')))
            .alignment
        as Alignment;

double _jeepScale(WidgetTester tester) => tester
    .widget<Transform>(find.byKey(const ValueKey('jeep-assembly-scale')))
    .transform
    .entry(0, 0);

double _frontWheelTurns(WidgetTester tester) => tester
    .widget<RotationTransition>(
      find.byKey(const ValueKey('jeep-front-wheel-rotation')),
    )
    .turns
    .value;

double _rearWheelTurns(WidgetTester tester) => tester
    .widget<RotationTransition>(
      find.byKey(const ValueKey('jeep-rear-wheel-rotation')),
    )
    .turns
    .value;

Alignment _calibrationAlignment(WidgetTester tester) =>
    tester
            .widget<Align>(
              find.byKey(const ValueKey('calibration-jeep-alignment')),
            )
            .alignment
        as Alignment;

double _calibrationScale(WidgetTester tester) => tester
    .widget<Transform>(find.byKey(const ValueKey('calibration-jeep-scale')))
    .transform
    .getMaxScaleOnAxis();

String _calibrationJsonText(WidgetTester tester) => tester
    .widget<SelectableText>(find.byKey(const ValueKey('codex-parameters-json')))
    .data!;

Map<String, dynamic> _calibrationJson(WidgetTester tester) =>
    jsonDecode(_calibrationJsonText(tester)) as Map<String, dynamic>;

class _FakeStorageGateway implements StorageStatusGateway {
  const _FakeStorageGateway();

  @override
  Future<StorageStatusSnapshot> load() async => const StorageStatusSnapshot(
    estimateState: StorageEstimateState.available,
    usageBytes: 1024,
    quotaBytes: 2048,
    persistence: StoragePersistence.persistent,
  );
}
