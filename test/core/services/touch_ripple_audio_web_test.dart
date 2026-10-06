@TestOn('browser')
library;

// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html';

import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/services/device_settings_controller.dart';
import 'package:or_app/core/services/touch_ripple_audio.dart';
import 'package:or_app/core/services/touch_ripple_audio_web.dart';

void main() {
  test('live levels, mute, latest semantic and ambient priority', () async {
    final controller = DeviceSettingsController.instance;
    final original = controller.value;
    controller.resetForTesting(const DeviceSettings());
    final elements = <TouchFeedbackSound, AudioElement>{};
    final audio = createPlatformTouchRippleAudio(
      audioFactory: (sound) {
        final element = AudioElement();
        elements[sound] = element;
        return element;
      },
    );
    try {
      audio.prepare();
      audio.playFromUserGesture(TouchFeedbackSound.success);
      expect(elements[TouchFeedbackSound.success]!.volume, .34);
      controller.update(controller.value.copyWith(masterVolume: .5));
      expect(
        elements[TouchFeedbackSound.success]!.volume,
        closeTo(.17, .000001),
      );
      audio.playFromUserGesture(TouchFeedbackSound.water);
      controller.update(controller.value.copyWith(ambientVolume: .5));
      // A rejected passive request was never added to the active pool.
      expect(elements[TouchFeedbackSound.water]!.volume, .28);
      audio.playFromUserGesture(TouchFeedbackSound.exit);
      controller.update(
        controller.value.copyWith(exitVolume: .5, commandVolume: .2),
      );
      expect(elements[TouchFeedbackSound.exit]!.volume, closeTo(.085, .000001));
      // The replaced COMMAND is no longer updated as an active sound.
      expect(
        elements[TouchFeedbackSound.success]!.volume,
        closeTo(.17, .000001),
      );
      controller.update(controller.value.copyWith(muted: true));
      expect(elements[TouchFeedbackSound.exit]!.volume, 0);
      controller.update(controller.value.copyWith(muted: false));
      audio.playFromUserGesture(TouchFeedbackSound.exit);
      expect(elements[TouchFeedbackSound.exit]!.volume, closeTo(.085, .000001));
      // Empty sources reject playback. After cleanup the pool accepts ambient.
      await Future<void>.delayed(const Duration(milliseconds: 100));
      audio.playFromUserGesture(TouchFeedbackSound.water);
      expect(elements[TouchFeedbackSound.water]!.volume, closeTo(.07, .000001));
    } finally {
      audio.dispose();
      controller.resetForTesting(original);
    }
  });
}
