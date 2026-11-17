import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = BaseCampMapConfigurationController()
      ..resetForTesting(BaseCampMapConfiguration.defaults());
    final boundaryKey = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: RepaintBoundary(
          key: boundaryKey,
          child: BaseCampMapEditorPage(configurationController: controller),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(find.text('HELICOPTER'));
    await tester.pump();
    await _capture(tester, boundaryKey, 'editor_body_selected');

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
    await tester.tap(direction);
    await tester.tap(find.byKey(const ValueKey('helicopter-run-flight')));
    await tester.pump(const Duration(seconds: 3));
    await _capture(tester, boundaryKey, 'flight_left_to_right');
    await tester.tap(find.byKey(const ValueKey('helicopter-stop-flight')));
    await tester.pump();

    direction = find.byKey(
      const ValueKey('helicopter-direction-right-to-left'),
    );
    await tester.ensureVisible(direction);
    await tester.pump();
    await tester.tap(direction);
    await tester.tap(find.byKey(const ValueKey('helicopter-run-flight')));
    await tester.pump(const Duration(seconds: 3));
    await _capture(tester, boundaryKey, 'flight_right_to_left');
    await tester.tap(find.byKey(const ValueKey('helicopter-stop-flight')));
    await tester.tap(find.byKey(const ValueKey('base-camp-editor-save')));
    await tester.pump(const Duration(milliseconds: 150));

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
