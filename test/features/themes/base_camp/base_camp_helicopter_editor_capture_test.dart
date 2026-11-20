import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/themes/base_camp/base_camp_map_configuration.dart';
import 'package:or_app/features/themes/base_camp/base_camp_map_editor_page.dart';
import 'package:or_app/features/themes/base_camp/widgets/base_camp_helicopter.dart';
import 'package:or_app/features/themes/base_camp/widgets/base_camp_map.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _captureDirectory = String.fromEnvironment(
  'HELICOPTER_EDITOR_CAPTURE_DIR',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('captures helicopter editor assembly and previews', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = BaseCampMapConfigurationController()
      ..resetForTesting(BaseCampMapConfiguration.defaults());
    final boundaryKey = GlobalKey();
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
    await tester.pumpWidget(
      MaterialApp(
        home: RepaintBoundary(
          key: boundaryKey,
          child: BaseCampMapEditorPage(configurationController: controller),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 250));
    await _capture(tester, boundaryKey, 'layout_route_default_390');
    await tester.ensureVisible(find.text('HELICOPTER'));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(find.text('HELICOPTER'));
    await tester.pump();
    await _capture(tester, boundaryKey, 'layout_helicopter_default_390');
    final resizeHandle = find.byKey(
      const ValueKey('base-camp-editor-resize-handle'),
    );
    await tester.drag(resizeHandle, const Offset(0, 100));
    await tester.pump();
    await _capture(tester, boundaryKey, 'layout_map_enlarged_390');
    await tester.drag(resizeHandle, const Offset(0, -180));
    await tester.pump();
    await _capture(tester, boundaryKey, 'layout_controls_enlarged_390');
    await tester.drag(resizeHandle, const Offset(0, 80));
    await tester.pump();
    await _capture(tester, boundaryKey, 'editor_body_selected');

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

    await setSlider('helicopter-global-scale', 1.5);
    await setSlider('helicopter-main-speed', 20);
    await setSlider('helicopter-tail-speed', 5);
    await setSlider('helicopter-flight-speed', 400);
    await setSlider('helicopter-forward-pitch', 12);
    await tester.ensureVisible(
      find.byKey(const ValueKey('helicopter-copy-json')),
    );
    await tester.tap(find.byKey(const ValueKey('helicopter-copy-json')));
    await tester.pump();
    await _capture(tester, boundaryKey, 'speed_scale_json_controls');
    if (_captureDirectory.isNotEmpty && clipboardText != null) {
      File(
        '$_captureDirectory/helicopter_working_copy.json',
      ).writeAsStringSync(clipboardText!);
    }

    var part = find.byKey(const ValueKey('helicopter-part-mainRotor'));
    await tester.ensureVisible(part);
    await tester.pump();
    await tester.tap(part);
    await tester.pump();
    await _capture(tester, boundaryKey, 'editor_main_selected');
    var x = find.byKey(const ValueKey('helicopter-mainRotor-X-772.000'));
    await tester.ensureVisible(x);
    await tester.enterText(x, '805');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await _capture(tester, boundaryKey, 'editor_main_adjusted');

    part = find.byKey(const ValueKey('helicopter-part-tailRotor'));
    await tester.ensureVisible(part);
    await tester.pump();
    await tester.tap(part);
    await tester.pump();
    x = find.byKey(const ValueKey('helicopter-tailRotor-X-1250.000'));
    await tester.ensureVisible(x);
    await tester.enterText(x, '1225');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await _capture(tester, boundaryKey, 'editor_tail_adjusted');

    await tester.ensureVisible(
      find.byKey(const ValueKey('helicopter-rotors-on')),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('helicopter-rotors-on')));
    await tester.pump(const Duration(milliseconds: 220));
    await _capture(tester, boundaryKey, 'stationary_rotors_on');

    await tester.ensureVisible(
      find.byKey(const ValueKey('helicopter-run-flight')),
    );
    var direction = find.byKey(
      const ValueKey('helicopter-direction-left-to-right'),
    );
    await tester.ensureVisible(direction);
    await tester.pump();
    tester.widget<ChoiceChip>(direction).onSelected?.call(true);
    tester
        .widget<FilledButton>(
          find.byKey(const ValueKey('helicopter-run-flight')),
        )
        .onPressed
        ?.call();
    await tester.pump();
    await tester.pump(const Duration(seconds: 4));
    await _capture(tester, boundaryKey, 'flight_left_to_right');
    await tester.pump(const Duration(milliseconds: 900));
    await _capture(tester, boundaryKey, 'flight_left_to_right_near_exit');
    tester
        .widget<OutlinedButton>(
          find.byKey(const ValueKey('helicopter-stop-flight')),
        )
        .onPressed
        ?.call();
    await tester.pump();

    direction = find.byKey(
      const ValueKey('helicopter-direction-right-to-left'),
    );
    await tester.ensureVisible(direction);
    await tester.pump();
    tester.widget<ChoiceChip>(direction).onSelected?.call(true);
    tester
        .widget<FilledButton>(
          find.byKey(const ValueKey('helicopter-run-flight')),
        )
        .onPressed
        ?.call();
    await tester.pump();
    await tester.pump(const Duration(seconds: 4));
    await _capture(tester, boundaryKey, 'flight_right_to_left');
    tester
        .widget<OutlinedButton>(
          find.byKey(const ValueKey('helicopter-stop-flight')),
        )
        .onPressed
        ?.call();
    await tester.ensureVisible(find.text('ROUTE EDITOR'));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(find.text('ROUTE EDITOR'));
    await tester.pump();
    await _capture(tester, boundaryKey, 'layout_route_after_resize_390');
    await tester.tap(find.byKey(const ValueKey('base-camp-editor-save')));
    await tester.pump(const Duration(milliseconds: 150));
    await tester.binding.setSurfaceSize(const Size(320, 480));
    await tester.pump();
    await tester.pump();
    await _capture(tester, boundaryKey, 'layout_short_viewport_320');
    await tester.binding.setSurfaceSize(const Size(430, 900));
    await tester.pump();
    await tester.pump();

    final productionBoundary = GlobalKey();
    final interactive = ValueNotifier<bool>(false);
    addTearDown(interactive.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: RepaintBoundary(
          key: productionBoundary,
          child: SizedBox.square(
            dimension: 430,
            child: Stack(
              fit: StackFit.expand,
              children: [
                const Image(image: baseCampMapImageProvider, fit: BoxFit.cover),
                BaseCampHelicopterFlybyLayer(
                  dashboardInteractive: interactive,
                  assembly: controller.value.helicopterAssembly,
                  debugFlight: const BaseCampHelicopterDebugFlight(
                    progress: .5,
                    direction: BaseCampHelicopterDirection.leftToRight,
                    mainRotorFrame: 3,
                    tailRotorFrame: 9,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await _capture(tester, productionBoundary, 'production_saved_assembly');
    expect(tester.takeException(), isNull);
  });
}

Future<void> _capture(
  WidgetTester tester,
  GlobalKey boundaryKey,
  String name,
) async {
  if (_captureDirectory.isEmpty) return;
  final directory = Directory(_captureDirectory)..createSync(recursive: true);
  await tester.runAsync(() async {
    final boundary =
        boundaryKey.currentContext!.findRenderObject()!
            as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    await File(
      '${directory.path}/helicopter_$name.png',
    ).writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
  });
}
