import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/app.dart';
import 'package:or_app/core/services/device_settings_controller.dart';
import 'package:or_app/core/services/startup_initialization_service.dart';
import 'package:or_app/core/state/app_initialization_state.dart';
import 'package:or_app/core/widgets/holographic_ambient_background.dart';
import 'package:or_app/core/widgets/global_touch_ripple.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('production brightness layer preserves input and geometry', (
    tester,
  ) async {
    final settings = DeviceSettingsController.instance;
    final original = settings.value;
    addTearDown(() => settings.resetForTesting(original));
    settings.resetForTesting(const DeviceSettings());
    final controller = AppInitializationController();
    final service = StartupInitializationService(
      controller: controller,
      isWeb: false,
      restore: () async {},
    );
    await tester.pumpWidget(OperationRebootApp(initializationService: service));
    final productionBuilder = tester
        .widget<MaterialApp>(find.byType(MaterialApp))
        .builder;
    await tester.pumpWidget(const SizedBox.shrink());
    controller.markReady();
    var taps = 0;
    const targetKey = ValueKey('brightness-input-target');
    await tester.pumpWidget(
      MaterialApp(
        builder: productionBuilder,
        home: Center(
          child: GestureDetector(
            key: targetKey,
            onTap: () => taps++,
            child: const SizedBox(
              width: 120,
              height: 80,
              child: ColoredBox(color: Colors.white),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    final baseline = tester.getRect(find.byKey(targetKey));
    final media = MediaQuery.of(tester.element(find.byKey(targetKey)));
    expect(
      find.byWidgetPredicate(
        (w) => w is ColoredBox && w.color.a > 0 && w.color.a < 1,
      ),
      findsNothing,
    );
    settings.update(settings.value.copyWith(brightness: .5));
    await tester.pump();
    expect(tester.getRect(find.byKey(targetKey)), baseline);
    final dimmedMedia = MediaQuery.of(tester.element(find.byKey(targetKey)));
    expect(dimmedMedia.size, media.size);
    expect(dimmedMedia.textScaler, media.textScaler);
    final brightnessLayer = find.byWidgetPredicate(
      (w) => w is ColoredBox && w.color.a > 0 && w.color.a < 1,
    );
    expect(brightnessLayer, findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(GlobalTouchRipple),
        matching: brightnessLayer,
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(targetKey));
    await tester.pump(const Duration(milliseconds: 40));
    expect(taps, 1);
    settings.update(
      settings.value.copyWith(reducedMotion: ReducedMotionPreference.on),
    );
    await tester.pump();
    expect(
      MediaQuery.of(tester.element(find.byKey(targetKey))).disableAnimations,
      isTrue,
    );
    settings.update(const DeviceSettings());
    await tester.pump();
    expect(tester.getRect(find.byKey(targetKey)), baseline);
    expect(
      MediaQuery.of(tester.element(find.byKey(targetKey))).disableAnimations,
      media.disableAnimations,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('ambient circuit disabled removes painter and can restart', (
    tester,
  ) async {
    Widget circuit(bool enabled) =>
        MaterialApp(home: HolographicAmbientBackground(enabled: enabled));
    await tester.pumpWidget(circuit(true));
    expect(find.byType(CustomPaint), findsWidgets);
    await tester.pumpWidget(circuit(false));
    expect(
      find.descendant(
        of: find.byType(HolographicAmbientBackground),
        matching: find.byType(CustomPaint),
      ),
      findsNothing,
    );
    await tester.pumpWidget(circuit(true));
    expect(
      find.descendant(
        of: find.byType(HolographicAmbientBackground),
        matching: find.byType(CustomPaint),
      ),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
