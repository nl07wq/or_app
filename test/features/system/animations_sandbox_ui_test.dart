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
      find.byKey(const ValueKey('open-assembly-calibration')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('open-motion-calibration')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('open-effect-lab')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('effect lab exposes three empty slots at supported widths', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final width in [320.0, 390.0, 1280.0]) {
      tester.view.physicalSize = Size(width, 1800);
      tester.view.devicePixelRatio = 1;

      await tester.pumpWidget(
        MaterialApp(
          key: ValueKey('effect-lab-$width'),
          home: const BootSequenceCalibrationPage(),
        ),
      );
      await tester.ensureVisible(find.byKey(const ValueKey('open-effect-lab')));
      await tester.tap(find.byKey(const ValueKey('open-effect-lab')));
      await tester.pumpAndSettle();

      expect(find.text('EFFECT LAB'), findsOneWidget);
      expect(find.text('HEADLIGHT TEST'), findsOneWidget);
      expect(find.text('DUST TEST'), findsOneWidget);
      expect(find.text('SUSPENSION TEST'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('effect-lab-headlight-slot')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('effect-lab-dust-slot')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('effect-lab-suspension-slot')),
        findsOneWidget,
      );
      expect(find.text('DEVELOPMENT TEST SLOT'), findsNWidgets(3));
      expect(find.byKey(const ValueKey('jeep-headlight')), findsNothing);
      expect(find.byKey(const ValueKey('jeep-dust')), findsNothing);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets(
    'assembly calibration uses three shared wheels and local values',
    (tester) async {
      tester.view.physicalSize = const Size(390, 4200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
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

      await tester.pumpWidget(
        const MaterialApp(home: BootSequenceCalibrationPage()),
      );
      await tester.tap(find.byKey(const ValueKey('open-assembly-calibration')));
      await tester.pumpAndSettle();

      expect(find.text('ASSEMBLY CALIBRATION'), findsWidgets);
      expect(
        find.byKey(const ValueKey('calibration-front-wheel-far')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('calibration-rear-wheel')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('calibration-front-wheel-near')),
        findsOneWidget,
      );
      for (final key in const [
        ValueKey('calibration-front-wheel-far'),
        ValueKey('calibration-rear-wheel'),
        ValueKey('calibration-front-wheel-near'),
      ]) {
        expect(
          _assetName(tester, key),
          'assets/animations/sandbox/boot_sequence/phase_01/jeep/wheel.png',
        );
      }

      final initial = _jsonFromSelectable(
        tester,
        const ValueKey('assembly-parameters-json'),
      );
      expect(initial['coordinateSystem'], 'jeep_local_normalized');
      expect((initial['frontWheelFar'] as Map)['localX'], 0.108);
      expect((initial['frontWheelFar'] as Map)['localY'], 0.618);
      expect((initial['frontWheelFar'] as Map)['scale'], 0.2);
      expect((initial['rearWheel'] as Map)['localX'], 0.779);
      expect((initial['rearWheel'] as Map)['localY'], 0.587);
      expect((initial['rearWheel'] as Map)['scale'], 0.185);
      expect((initial['frontWheelNear'] as Map)['localX'], 0.330);
      expect((initial['frontWheelNear'] as Map)['localY'], 0.593);
      expect((initial['frontWheelNear'] as Map)['scale'], 0.245);
      expect(initial['layerOrder'], [
        'frontWheelFar',
        'jeepBody',
        'rearWheel',
        'frontWheelNear',
      ]);
      await tester.ensureVisible(
        find.byKey(const ValueKey('copy-assembly-parameters')),
      );
      await tester.tap(find.byKey(const ValueKey('copy-assembly-parameters')));
      await tester.pump();
      expect(
        jsonDecode(copiedText!)['calibrationType'],
        'boot_sequence_assembly',
      );

      final initialFar = Map<String, dynamic>.from(
        initial['frontWheelFar'] as Map,
      );
      await _dragByKey(
        tester,
        const ValueKey('assembly-canvas-drag-target'),
        const Offset(-80, 50),
      );
      await tester.drag(
        find.descendant(
          of: find.byKey(const ValueKey('assembly-wheel-scale-slider')),
          matching: find.byType(Slider),
        ),
        const Offset(35, 0),
      );
      await tester.pump();
      final far =
          _jsonFromSelectable(
                tester,
                const ValueKey('assembly-parameters-json'),
              )['frontWheelFar']
              as Map;
      expect(far['localX'], isNot(initialFar['localX']));
      expect(far['localY'], isNot(initialFar['localY']));
      expect(far['scale'], isNot(initialFar['scale']));

      for (final target in const ['rearWheel', 'frontWheelNear']) {
        final targetSelector = find.byKey(ValueKey('assembly-target-$target'));
        await tester.ensureVisible(targetSelector);
        await tester.pump();
        await tester.tap(targetSelector);
        await tester.pump();
        final before =
            _jsonFromSelectable(
                  tester,
                  const ValueKey('assembly-parameters-json'),
                )[target]
                as Map;
        await _dragByKey(
          tester,
          const ValueKey('assembly-canvas-drag-target'),
          const Offset(95, -65),
        );
        await tester.pump();
        final after =
            _jsonFromSelectable(
                  tester,
                  const ValueKey('assembly-parameters-json'),
                )[target]
                as Map;
        expect(after['localX'], isNot(before['localX']));
        expect(after['localY'], isNot(before['localY']));
      }
      expect(tester.takeException(), isNull);
    },
  );

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
    await tester.tap(find.byKey(const ValueKey('open-motion-calibration')));
    await tester.pumpAndSettle();

    final initialJson = _calibrationJson(tester);
    expect(initialJson['coordinateSystem'], 'alignment_normalized');
    final initialJeep = initialJson['jeepAssembly'] as Map<String, dynamic>;
    expect(initialJeep['start'], {'x': 0.971, 'y': 0.322, 'scale': 0.1});
    expect(initialJeep['end'], {'x': -0.232, 'y': 0.603, 'scale': 1.31});
    expect((initialJson['motion'] as Map)['travelDurationMs'], 6000);
    expect((initialJson['motion'] as Map)['holdDurationMs'], 750);
    expect((initialJson['motion'] as Map)['curve'], 'linear');

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
    expect((configuredJson['motion'] as Map)['curve'], 'easeInOutCubic');
    expect(
      find.byKey(const ValueKey('motion-playback-controls')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('motion positioning reaches every canvas edge at any scale', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: BootSequenceCalibrationPage()),
    );
    await tester.tap(find.byKey(const ValueKey('open-motion-calibration')));
    await tester.pumpAndSettle();

    await _dragCalibrationCanvas(tester, const Offset(-1000, -1000));
    _expectAlignmentNear(_calibrationAlignment(tester), -1, -1);
    await _dragCalibrationCanvas(tester, const Offset(1000, 1000));
    _expectAlignmentNear(_calibrationAlignment(tester), 1, 1);

    final scaleSlider = find.descendant(
      of: find.byKey(const ValueKey('jeep-scale-slider')),
      matching: find.byType(Slider),
    );
    await tester.drag(scaleSlider, const Offset(-1000, 0));
    await _dragCalibrationCanvas(tester, const Offset(-1000, -1000));
    _expectAlignmentNear(_calibrationAlignment(tester), -1, -1);
    await tester.drag(scaleSlider, const Offset(1000, 0));
    await _dragCalibrationCanvas(tester, const Offset(1000, 1000));
    _expectAlignmentNear(_calibrationAlignment(tester), 1, 1);
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
          MaterialApp(
            key: ValueKey('calibration-width-$width'),
            home: const BootSequenceCalibrationPage(),
          ),
        );
        await tester.tap(find.byKey(const ValueKey('open-motion-calibration')));
        await tester.pumpAndSettle();

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
        find.byKey(const ValueKey('copy-motion-parameters')),
      );
      await tester.tap(find.byKey(const ValueKey('copy-motion-parameters')));
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
    expect(find.byKey(const ValueKey('jeep-front-wheel-far')), findsOneWidget);
    expect(find.byKey(const ValueKey('jeep-rear-wheel')), findsOneWidget);
    expect(find.byKey(const ValueKey('jeep-front-wheel-near')), findsOneWidget);
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
      _assetName(tester, const ValueKey('jeep-front-wheel-far')),
      'assets/animations/sandbox/boot_sequence/phase_01/jeep/wheel.png',
    );
    expect(
      _assetName(tester, const ValueKey('jeep-rear-wheel')),
      'assets/animations/sandbox/boot_sequence/phase_01/jeep/wheel.png',
    );
    expect(
      _assetName(tester, const ValueKey('jeep-front-wheel-near')),
      'assets/animations/sandbox/boot_sequence/phase_01/jeep/wheel.png',
    );
    _expectSceneWheelCalibration(
      tester,
      const ValueKey('jeep-front-wheel-far-layer'),
      x: 0.108,
      y: 0.618,
      scale: 0.200,
    );
    _expectSceneWheelCalibration(
      tester,
      const ValueKey('jeep-rear-wheel-layer'),
      x: 0.779,
      y: 0.587,
      scale: 0.185,
    );
    _expectSceneWheelCalibration(
      tester,
      const ValueKey('jeep-front-wheel-near-layer'),
      x: 0.330,
      y: 0.593,
      scale: 0.245,
    );
    expect(_jeepLayerKeys(tester), [
      const ValueKey('jeep-front-wheel-far-layer'),
      const ValueKey('jeep-body-layer'),
      const ValueKey('jeep-rear-wheel-layer'),
      const ValueKey('jeep-front-wheel-near-layer'),
    ]);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('jeep-assembly')),
        matching: find.byType(RotationTransition),
      ),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('jeep-dust')), findsNothing);
    expect(find.byKey(const ValueKey('jeep-headlight')), findsNothing);
    expect(find.byKey(const ValueKey('jeep-bounce-offset')), findsNothing);
    expect(find.byKey(const ValueKey('jeep-micro-offset')), findsNothing);
    expect(find.byKey(const ValueKey('preview-play')), findsOneWidget);
    expect(find.byKey(const ValueKey('preview-pause')), findsOneWidget);
    expect(find.byKey(const ValueKey('preview-stop')), findsOneWidget);
    expect(find.byKey(const ValueKey('preview-replay')), findsOneWidget);

    final startAlignment = _jeepAlignment(tester);
    final startScale = _jeepScale(tester);
    _expectAlignmentNear(startAlignment, 0.971, 0.322);
    expect(startScale, closeTo(0.100, 0.000001));

    await tester.ensureVisible(find.byKey(const ValueKey('preview-play')));
    await tester.tap(find.byKey(const ValueKey('preview-play')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1100));
    expect(find.text('00:01 / 00:06'), findsOneWidget);
    expect(_jeepAlignment(tester).x, lessThan(startAlignment.x));
    expect(_jeepAlignment(tester).y, greaterThan(startAlignment.y));
    expect(_jeepScale(tester), greaterThan(startScale));
    expect(find.byKey(const ValueKey('jeep-dust')), findsNothing);
    expect(find.byKey(const ValueKey('jeep-headlight')), findsNothing);
    expect(find.byKey(const ValueKey('jeep-bounce-offset')), findsNothing);
    expect(find.byKey(const ValueKey('jeep-micro-offset')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('preview-pause')));
    final pausedAlignment = _jeepAlignment(tester);
    final pausedScale = _jeepScale(tester);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('00:01 / 00:06'), findsOneWidget);
    expect(_jeepAlignment(tester), pausedAlignment);
    expect(_jeepScale(tester), pausedScale);

    await tester.tap(find.byKey(const ValueKey('preview-play')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(_jeepScale(tester), greaterThan(pausedScale));

    await tester.tap(find.byKey(const ValueKey('preview-stop')));
    await tester.pump();
    expect(find.text('00:00 / 00:06'), findsOneWidget);
    expect(_jeepAlignment(tester), startAlignment);
    expect(_jeepScale(tester), startScale);
    expect(find.byKey(const ValueKey('jeep-dust')), findsNothing);
    expect(find.byKey(const ValueKey('jeep-headlight')), findsNothing);

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
    expect(find.byKey(const ValueKey('jeep-dust')), findsNothing);
    expect(find.byKey(const ValueKey('jeep-headlight')), findsNothing);
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
    _expectAlignmentNear(_jeepAlignment(tester), 0.971, 0.322);
    expect(_jeepScale(tester), closeTo(0.100, 0.000001));
    expect(find.byKey(const ValueKey('jeep-dust')), findsNothing);
    expect(find.byKey(const ValueKey('jeep-headlight')), findsNothing);
    expect(find.text('00:00 / 00:06'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('baseline jeep reaches calibrated end and holds', (tester) async {
    tester.view.physicalSize = const Size(390, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: BootSequencePreviewPage()));
    await tester.ensureVisible(find.byKey(const ValueKey('preview-play')));
    await tester.tap(find.byKey(const ValueKey('preview-play')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 6000));
    final stoppedAlignment = _jeepAlignment(tester);
    final stoppedScale = _jeepScale(tester);
    _expectAlignmentNear(stoppedAlignment, -0.232, 0.603);
    expect(stoppedScale, closeTo(1.310, 0.000001));
    expect(find.byKey(const ValueKey('jeep-bounce-offset')), findsNothing);
    expect(find.byKey(const ValueKey('jeep-micro-offset')), findsNothing);
    expect(find.byKey(const ValueKey('jeep-dust')), findsNothing);
    expect(find.byKey(const ValueKey('jeep-headlight')), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('jeep-assembly')),
        matching: find.byType(RotationTransition),
      ),
      findsNothing,
    );

    await tester.pump(const Duration(milliseconds: 749));
    expect(_jeepAlignment(tester), stoppedAlignment);
    expect(_jeepScale(tester), stoppedScale);
    expect(find.byKey(const ValueKey('jeep-dust')), findsNothing);
    await tester.pump(const Duration(milliseconds: 1));
    expect(_jeepAlignment(tester), stoppedAlignment);
    expect(_jeepScale(tester), stoppedScale);
    expect(find.byKey(const ValueKey('jeep-dust')), findsNothing);
    expect(find.byKey(const ValueKey('jeep-headlight')), findsNothing);
    expect(find.text('00:06 / 00:06'), findsOneWidget);
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
    expect(find.text('USAGE  USED ×3'), findsOneWidget);
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
  await _dragByKey(
    tester,
    const ValueKey('calibration-canvas-drag-target'),
    delta,
  );
}

Future<void> _dragByKey(
  WidgetTester tester,
  ValueKey<String> key,
  Offset delta,
) async {
  final target = find.byKey(key);
  await tester.ensureVisible(target);
  await tester.pump();
  final gesture = await tester.startGesture(tester.getCenter(target));
  await gesture.moveBy(Offset(delta.dx, 0));
  await gesture.moveBy(Offset(0, delta.dy));
  await gesture.up();
  await tester.pump();
}

String _assetName(WidgetTester tester, ValueKey<String> key) =>
    (tester.widget<Image>(find.byKey(key)).image as AssetImage).assetName;

Alignment _jeepAlignment(WidgetTester tester) {
  final position = tester.widget<Positioned>(
    find.byKey(const ValueKey('jeep-assembly-position')),
  );
  final canvasSize = tester.getSize(
    find.byKey(const ValueKey('jeep-scene-canvas')),
  );
  final centerX = position.left! + (position.width! / 2);
  final centerY = position.top! + (position.height! / 2);
  return Alignment(
    ((centerX / canvasSize.width) * 2) - 1,
    ((centerY / canvasSize.height) * 2) - 1,
  );
}

double _jeepScale(WidgetTester tester) => tester
    .widget<Transform>(find.byKey(const ValueKey('jeep-assembly-scale')))
    .transform
    .entry(0, 0);

void _expectSceneWheelCalibration(
  WidgetTester tester,
  ValueKey<String> layerKey, {
  required double x,
  required double y,
  required double scale,
}) {
  final position = tester.widget<Positioned>(
    find.descendant(
      of: find.byKey(layerKey),
      matching: find.byType(Positioned),
    ),
  );
  final assemblySize = tester.getSize(
    find.byKey(const ValueKey('jeep-assembly')),
  );
  expect(position.left! / assemblySize.width, closeTo(x, 0.000001));
  expect(position.top! / assemblySize.height, closeTo(y, 0.000001));
  expect(position.width! / assemblySize.width, closeTo(scale, 0.000001));
  expect(position.height, position.width);
}

List<Key?> _jeepLayerKeys(WidgetTester tester) {
  final stack = tester.widget<Stack>(
    find
        .descendant(
          of: find.byKey(const ValueKey('jeep-assembly')),
          matching: find.byType(Stack),
        )
        .first,
  );
  return stack.children.map((child) => child.key).toList();
}

Alignment _calibrationAlignment(WidgetTester tester) {
  final position = tester.widget<Positioned>(
    find.byKey(const ValueKey('calibration-jeep-position')),
  );
  final canvasSize = tester.getSize(
    find.byKey(const ValueKey('calibration-canvas-drag-target')),
  );
  final centerX = position.left! + (position.width! / 2);
  final centerY = position.top! + (position.height! / 2);
  return Alignment(
    ((centerX / canvasSize.width) * 2) - 1,
    ((centerY / canvasSize.height) * 2) - 1,
  );
}

double _calibrationScale(WidgetTester tester) => tester
    .widget<Transform>(find.byKey(const ValueKey('calibration-jeep-scale')))
    .transform
    .getMaxScaleOnAxis();

String _calibrationJsonText(WidgetTester tester) => tester
    .widget<SelectableText>(
      find.byKey(const ValueKey('motion-parameters-json')),
    )
    .data!;

Map<String, dynamic> _calibrationJson(WidgetTester tester) =>
    jsonDecode(_calibrationJsonText(tester)) as Map<String, dynamic>;

Map<String, dynamic> _jsonFromSelectable(
  WidgetTester tester,
  ValueKey<String> key,
) =>
    jsonDecode(tester.widget<SelectableText>(find.byKey(key)).data!)
        as Map<String, dynamic>;

void _expectAlignmentNear(Alignment actual, double x, double y) {
  expect(actual.x, closeTo(x, 0.000001));
  expect(actual.y, closeTo(y, 0.000001));
}

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
