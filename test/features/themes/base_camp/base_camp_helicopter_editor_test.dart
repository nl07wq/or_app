import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/themes/base_camp/base_camp_map_configuration.dart';
import 'package:or_app/features/themes/base_camp/base_camp_map_editor_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
      await tester.tap(find.text('HELICOPTER'));
      await tester.pump();
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
    await tester.tap(find.text('HELICOPTER'));
    await tester.pump();
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
    await tester.tap(find.text('HELICOPTER'));
    await tester.pump();
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
    await tester.tap(find.text('HELICOPTER'));
    await tester.pump();
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
      await tester.tap(find.text('HELICOPTER'));
      await tester.pump();
      final run = find.byKey(const ValueKey('helicopter-run-flight'));
      await tester.ensureVisible(run);
      await tester.pump();
      await tester.tap(run);
      await tester.pump(const Duration(milliseconds: 100));
      var transform = tester.widget<Transform>(
        find.byKey(const ValueKey('base-camp-helicopter-direction-transform')),
      );
      expect(transform.transform.entry(0, 0), -1);
      await tester.tap(find.byKey(const ValueKey('helicopter-stop-flight')));
      final reverse = find.byKey(
        const ValueKey('helicopter-direction-right-to-left'),
      );
      await tester.ensureVisible(reverse);
      await tester.tap(reverse);
      await tester.ensureVisible(run);
      await tester.pump();
      await tester.tap(run);
      await tester.pump(const Duration(milliseconds: 100));
      transform = tester.widget<Transform>(
        find.byKey(const ValueKey('base-camp-helicopter-direction-transform')),
      );
      expect(transform.transform.entry(0, 0), 1);
    },
  );
}
