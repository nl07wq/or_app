import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/services/device_settings_controller.dart';
import 'package:or_app/core/services/touch_ripple_audio.dart';
import 'package:or_app/core/widgets/global_touch_ripple.dart';
import 'package:or_app/features/system/pages/device_settings_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

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
