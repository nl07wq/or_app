import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/themes/base_camp/base_camp_map_configuration.dart';
import 'package:or_app/features/themes/base_camp/base_camp_map_editor_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _selectEditorSection(WidgetTester tester, String label) async {
  final tab = find.text(label);
  await tester.ensureVisible(tab);
  await tester.pump(const Duration(milliseconds: 250));
  await tester.tap(tab);
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final width in <double>[320, 375, 390, 430]) {
    testWidgets('helicopter editor remains usable at ${width.toInt()}dp', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final controller = BaseCampMapConfigurationController()
        ..resetForTesting(BaseCampMapConfiguration.defaults());
      await tester.binding.setSurfaceSize(Size(width, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: BaseCampMapEditorPage(configurationController: controller),
        ),
      );
      await tester.pump(const Duration(milliseconds: 250));
      await _selectEditorSection(tester, 'HELICOPTER');
      expect(
        find.byKey(const ValueKey('base-camp-helicopter-editor-preview')),
        findsOneWidget,
      );
      expect(find.text('BODY'), findsOneWidget);
      expect(find.text('RUN FLIGHT'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('part drag and pinch edit only the selected rotor', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final controller = BaseCampMapConfigurationController()
      ..resetForTesting(BaseCampMapConfiguration.defaults());
    await tester.binding.setSurfaceSize(const Size(430, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: BaseCampMapEditorPage(configurationController: controller),
      ),
    );
    await tester.pump(const Duration(milliseconds: 250));
    await _selectEditorSection(tester, 'HELICOPTER');
    await tester.tap(find.text('MAIN ROTOR'));
    await tester.pump();

    final gestureTarget = find.byKey(
      const ValueKey('base-camp-helicopter-part-gesture'),
    );
    await tester.drag(gestureTarget, const Offset(12, -8));
    await tester.pump();
    expect(
      find.byKey(const ValueKey('helicopter-mainRotor-X-772.000')),
      findsNothing,
    );
    await tester.tap(find.text('TAIL ROTOR'));
    await tester.pump();
    expect(
      find.byKey(const ValueKey('helicopter-tailRotor-X-1250.000')),
      findsOneWidget,
    );
    await tester.tap(find.text('MAIN ROTOR'));
    await tester.pump();

    final center = tester.getCenter(gestureTarget);
    final first = await tester.startGesture(
      center - const Offset(12, 0),
      pointer: 1,
    );
    final second = await tester.startGesture(
      center + const Offset(12, 0),
      pointer: 2,
    );
    await first.moveTo(center - const Offset(28, 0));
    await second.moveTo(center + const Offset(28, 0));
    await tester.pump();
    await first.up();
    await second.up();
    await tester.pump();
    expect(
      find.byKey(const ValueKey('helicopter-mainRotor-SCALE-1.000')),
      findsNothing,
    );
    await tester.tap(find.byKey(const ValueKey('base-camp-editor-undo')));
    await tester.pump();
    expect(
      find.byKey(const ValueKey('helicopter-mainRotor-SCALE-1.000')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('base-camp-editor-undo')));
    await tester.pump();
    expect(
      find.byKey(const ValueKey('helicopter-mainRotor-X-772.000')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('MAP NAV preserves helicopter working values', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final controller = BaseCampMapConfigurationController()
      ..resetForTesting(BaseCampMapConfiguration.defaults());
    await tester.binding.setSurfaceSize(const Size(430, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: BaseCampMapEditorPage(configurationController: controller),
      ),
    );
    await tester.pump(const Duration(milliseconds: 250));
    await _selectEditorSection(tester, 'HELICOPTER');
    await tester.tap(find.text('MAIN ROTOR'));
    await tester.pump();
    final x = find.byKey(const ValueKey('helicopter-mainRotor-X-772.000'));
    await tester.ensureVisible(x);
    await tester.enterText(x, '790');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    final mapNav = find.byKey(const ValueKey('helicopter-map-nav'));
    await tester.ensureVisible(mapNav);
    await tester.pump();
    await tester.tap(mapNav);
    await tester.pump();
    await tester.drag(
      find.byKey(const ValueKey('base-camp-editor-map')),
      const Offset(40, 20),
    );
    await tester.pump();
    expect(
      find.byKey(const ValueKey('helicopter-mainRotor-X-790.000')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('DISCARD restores saved helicopter assembly', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final controller = BaseCampMapConfigurationController()
      ..resetForTesting(BaseCampMapConfiguration.defaults());
    await tester.binding.setSurfaceSize(const Size(430, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: BaseCampMapEditorPage(configurationController: controller),
      ),
    );
    await tester.pump(const Duration(milliseconds: 250));
    await _selectEditorSection(tester, 'HELICOPTER');
    await tester.tap(find.text('MAIN ROTOR'));
    await tester.pump();
    final x = find.byKey(const ValueKey('helicopter-mainRotor-X-772.000'));
    await tester.ensureVisible(x);
    await tester.enterText(x, '810');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.tap(find.byTooltip('Cancel unsaved changes'));
    await tester.pump();
    await tester.tap(find.text('DISCARD'));
    await tester.pump();
    expect(
      find.byKey(const ValueKey('helicopter-mainRotor-X-772.000')),
      findsOneWidget,
    );
    expect(controller.value.helicopterAssembly.mainHub.dx, 772);
  });

  testWidgets(
    'preview flight mirrors the complete assembly in both directions',
    (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final controller = BaseCampMapConfigurationController()
        ..resetForTesting(BaseCampMapConfiguration.defaults());
      await tester.binding.setSurfaceSize(const Size(430, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: BaseCampMapEditorPage(configurationController: controller),
        ),
      );
      await tester.pump(const Duration(milliseconds: 250));
      await _selectEditorSection(tester, 'HELICOPTER');
      final run = find.byKey(const ValueKey('helicopter-run-flight'));
      await tester.ensureVisible(run);
      await tester.pump();
      await tester.tap(run);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      var transform = tester.widget<Transform>(
        find.byKey(const ValueKey('base-camp-helicopter-direction-transform')),
      );
      expect(transform.transform.entry(0, 0), -1);
      var pitchTransform = tester.widget<Transform>(
        find.byKey(const ValueKey('base-camp-helicopter-pitch-transform')),
      );
      final leftToRightPitchEntry = pitchTransform.transform.entry(0, 1);
      expect(leftToRightPitchEntry.abs(), greaterThan(0));
      await tester.tap(find.byKey(const ValueKey('helicopter-stop-flight')));
      final reverse = find.byKey(
        const ValueKey('helicopter-direction-right-to-left'),
      );
      await tester.ensureVisible(reverse);
      await tester.tap(reverse);
      await tester.ensureVisible(run);
      await tester.pump();
      await tester.tap(run);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      transform = tester.widget<Transform>(
        find.byKey(const ValueKey('base-camp-helicopter-direction-transform')),
      );
      expect(transform.transform.entry(0, 0), 1);
      pitchTransform = tester.widget<Transform>(
        find.byKey(const ValueKey('base-camp-helicopter-pitch-transform')),
      );
      expect(
        pitchTransform.transform.entry(0, 1),
        closeTo(-leftToRightPitchEntry, .000001),
      );
    },
  );

  testWidgets('timing and scale sliders export the unsaved working copy', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final controller = BaseCampMapConfigurationController()
      ..resetForTesting(BaseCampMapConfiguration.defaults());
    String? clipboardText;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          clipboardText =
              (call.arguments as Map<Object?, Object?>)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tester.binding.setSurfaceSize(const Size(390, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: BaseCampMapEditorPage(configurationController: controller),
      ),
    );
    await tester.pump(const Duration(milliseconds: 250));
    await _selectEditorSection(tester, 'HELICOPTER');

    Future<void> setSlider(String key, double value) async {
      final finder = find.byKey(ValueKey(key));
      await tester.ensureVisible(finder);
      await tester.pump();
      final slider = tester.widget<Slider>(finder);
      slider.onChangeStart?.call(slider.value);
      slider.onChanged?.call(value);
      slider.onChangeEnd?.call(value);
      await tester.pump();
    }

    await setSlider('helicopter-global-scale', .75);
    await setSlider('helicopter-main-speed', 20);
    await setSlider('helicopter-tail-speed', 5);
    await setSlider('helicopter-flight-speed', 1200);
    await setSlider('helicopter-forward-pitch', 12);
    expect(find.text('0.75×'), findsOneWidget);
    expect(find.text('20ms/frame · 120ms loop'), findsOneWidget);
    expect(find.text('5ms/frame · 80ms loop'), findsOneWidget);
    expect(find.text('1200 MAP px/s'), findsOneWidget);
    expect(find.text('12°'), findsOneWidget);
    final stationaryPitch = tester.widget<Transform>(
      find.byKey(const ValueKey('base-camp-helicopter-pitch-transform')),
    );
    expect(stationaryPitch.transform.entry(0, 1), 0);
    expect(controller.value.helicopterAssembly.globalScale, 1);
    expect(controller.value.helicopterAssembly.mainFrameMs, 110);
    expect(controller.value.helicopterAssembly.tailFrameMs, 50);
    expect(controller.value.helicopterAssembly.flightSpeed, 190);
    expect(controller.value.helicopterAssembly.forwardPitchDegrees, 4);

    final copy = find.byKey(const ValueKey('helicopter-copy-json'));
    await tester.ensureVisible(copy);
    await tester.tap(copy);
    await tester.pump();
    expect(find.text('HELICOPTER JSON COPIED'), findsOneWidget);
    final decoded = jsonDecode(clipboardText!) as Map<String, Object?>;
    expect(decoded.keys, <String>['helicopterAssembly']);
    final assembly = decoded['helicopterAssembly'] as Map<String, Object?>;
    expect(assembly['globalScale'], .75);
    expect(assembly['mainFrameMs'], 20);
    expect(assembly['tailFrameMs'], 5);
    expect(assembly['flightSpeed'], 1200);
    expect(assembly['forwardPitchDegrees'], 12);
    expect(assembly.containsKey('routes'), isFalse);

    final resetFlight = find.byKey(
      const ValueKey('helicopter-reset-flight-settings'),
    );
    await tester.ensureVisible(resetFlight);
    await tester.tap(resetFlight);
    await tester.pump();
    expect(find.text('190 MAP px/s'), findsOneWidget);
    expect(find.text('4°'), findsOneWidget);
    expect(find.text('0.75×'), findsOneWidget);
    expect(find.text('20ms/frame · 120ms loop'), findsOneWidget);
    expect(find.text('5ms/frame · 80ms loop'), findsOneWidget);

    final undo = find.byKey(const ValueKey('base-camp-editor-undo'));
    await tester.ensureVisible(undo);
    await tester.tap(undo);
    await tester.pump();
    expect(find.text('1200 MAP px/s'), findsOneWidget);
    expect(find.text('12°'), findsOneWidget);
    final save = find.byKey(const ValueKey('base-camp-editor-save'));
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pump(const Duration(milliseconds: 100));
    expect(controller.value.helicopterAssembly.globalScale, .75);
    expect(controller.value.helicopterAssembly.mainFrameMs, 20);
    expect(controller.value.helicopterAssembly.tailFrameMs, 5);
    expect(controller.value.helicopterAssembly.flightSpeed, 1200);
    expect(controller.value.helicopterAssembly.forwardPitchDegrees, 12);
  });

  testWidgets('RUN FLIGHT visibly crosses the editor MAP on frame time', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final controller = BaseCampMapConfigurationController()
      ..resetForTesting(BaseCampMapConfiguration.defaults());
    await tester.binding.setSurfaceSize(const Size(430, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: BaseCampMapEditorPage(configurationController: controller),
      ),
    );
    await tester.pump(const Duration(milliseconds: 250));
    await _selectEditorSection(tester, 'HELICOPTER');
    final run = find.byKey(const ValueKey('helicopter-run-flight'));
    await tester.ensureVisible(run);
    await tester.tap(run);
    await tester.pump();
    final preview = find.byKey(
      const ValueKey('base-camp-helicopter-editor-preview'),
    );
    final initialLeft = tester.getTopLeft(preview).dx;
    await tester.pump(const Duration(seconds: 1));
    final firstLeft = tester.getTopLeft(preview).dx;
    await tester.pump(const Duration(seconds: 1));
    final secondLeft = tester.getTopLeft(preview).dx;
    await tester.pump(const Duration(seconds: 1));
    final thirdLeft = tester.getTopLeft(preview).dx;
    await tester.pump(const Duration(seconds: 1));
    final middleRect = tester.getRect(preview);
    final mapRect = tester.getRect(
      find.byKey(const ValueKey('base-camp-editor-map')),
    );
    expect(middleRect.left, isNot(initialLeft));
    expect(secondLeft - firstLeft, closeTo(thirdLeft - secondLeft, .01));
    expect(middleRect.overlaps(mapRect), isTrue);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const ValueKey('helicopter-stop-flight')));
    await tester.pump();
    await tester.tap(run);
    await tester.pump(const Duration(seconds: 4));
    expect(tester.getRect(preview).overlaps(mapRect), isTrue);
  });
}
