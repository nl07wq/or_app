import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/services/device_settings_controller.dart';
import 'package:or_app/core/services/touch_ripple_audio.dart';
import 'package:or_app/core/widgets/global_touch_ripple.dart';
import 'package:or_app/features/system/pages/device_settings_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final width in [320.0, 390.0, 900.0]) {
    testWidgets('settings are usable at width $width', (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = DeviceSettingsController();
      await controller.initialize();
      await tester.pumpWidget(
        MaterialApp(home: DeviceSettingsPage(controller: controller)),
      );
      final master = find.byKey(
        const ValueKey('device-settings-master se-slider'),
      );
      expect(tester.getSize(master).width, greaterThan(150));
      await tester.drag(master, const Offset(-40, 0));
      await tester.pump();
      expect(controller.value.masterVolume, lessThan(1));
      final reduced = find.byKey(
        const ValueKey('device-settings-reduced-motion'),
      );
      await tester.scrollUntilVisible(reduced, 200);
      await tester.ensureVisible(reduced);
      await tester.pumpAndSettle();
      await tester.tap(reduced);
      await tester.pumpAndSettle();
      await tester.tap(find.text('ON').last);
      await tester.pumpAndSettle();
      expect(controller.value.reducedMotion, ReducedMotionPreference.on);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('muted previews are silent and sliders preview only at release', (
    tester,
  ) async {
    final original = DeviceSettingsController.instance.value;
    addTearDown(
      () => DeviceSettingsController.instance.resetForTesting(original),
    );
    DeviceSettingsController.instance.resetForTesting(const DeviceSettings());
    final audio = _RecordingAudio();
    await tester.pumpWidget(
      MaterialApp(
        home: GlobalTouchRipple(
          audio: audio,
          child: const DeviceSettingsPage(),
        ),
      ),
    );
    final slider = find.byKey(const ValueKey('device-settings-command-slider'));
    final gesture = await tester.startGesture(tester.getCenter(slider));
    await gesture.moveBy(const Offset(-20, 0));
    await tester.pump();
    expect(audio.played, isEmpty);
    await gesture.up();
    await tester.pump();
    expect(audio.played, [TouchFeedbackSound.success]);
    audio.played.clear();
    DeviceSettingsController.instance.update(
      DeviceSettingsController.instance.value.copyWith(muted: true),
    );
    await tester.pump();
    await tester.drag(slider, const Offset(-30, 0));
    await tester.pump(const Duration(milliseconds: 150));
    expect(audio.played, isEmpty);
  });

  testWidgets('settings controls remain input-silent while applying changes', (
    tester,
  ) async {
    final controller = DeviceSettingsController();
    await controller.initialize();
    final audio = _RecordingAudio();
    await tester.pumpWidget(
      MaterialApp(
        home: GlobalTouchRipple(
          audio: audio,
          child: DeviceSettingsPage(controller: controller),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('device-settings-mute')));
    await tester.pump();

    expect(controller.value.muted, isTrue);
    expect(audio.played, isEmpty);
    expect(find.text('MASTER SE'), findsOneWidget);
  });

  testWidgets('ripple preference hides only the passive visual effect', (
    tester,
  ) async {
    final original = DeviceSettingsController.instance.value;
    DeviceSettingsController.instance.resetForTesting(
      original.copyWith(rippleEnabled: false),
    );
    final audio = _RecordingAudio();
    var ripples = 0;
    try {
      await tester.pumpWidget(
        MaterialApp(
          home: GlobalTouchRipple(
            audio: audio,
            onRippleEventCreated: (_) => ripples++,
            child: const SizedBox.expand(),
          ),
        ),
      );

      await tester.tapAt(const Offset(20, 20));
      await tester.pump(const Duration(milliseconds: 40));

      expect(ripples, 0);
      expect(audio.played, [TouchFeedbackSound.water]);
    } finally {
      DeviceSettingsController.instance.resetForTesting(original);
    }
  });

  testWidgets('Ambient Wildlife preference applies immediately', (
    tester,
  ) async {
    final controller = DeviceSettingsController();
    await controller.initialize();
    await tester.pumpWidget(
      MaterialApp(home: DeviceSettingsPage(controller: controller)),
    );

    final wildlife = find.byKey(
      const ValueKey('device-settings-ambient-wildlife'),
    );
    await tester.scrollUntilVisible(wildlife, 300);
    await tester.ensureVisible(wildlife);
    await tester.pumpAndSettle();
    await tester.tap(wildlife);
    await tester.pump();
    expect(controller.value.ambientWildlifeEnabled, isFalse);

    await tester.tap(wildlife);
    await tester.pump();
    expect(controller.value.ambientWildlifeEnabled, isTrue);
  });
}

class _RecordingAudio implements TouchRippleAudio {
  final played = <TouchFeedbackSound>[];

  @override
  void dispose() {}

  @override
  void playFromUserGesture(TouchFeedbackSound sound) => played.add(sound);

  @override
  void prepare() {}
}
