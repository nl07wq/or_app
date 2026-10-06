import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/services/device_settings_controller.dart';
import 'package:or_app/core/services/touch_ripple_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('defaults preserve the released base feedback volumes', () {
    const settings = DeviceSettings();

    expect(
      touchFeedbackBaseVolume(TouchFeedbackSound.water) *
          settings.volumeMultiplierFor(DeviceFeedbackChannel.ambient),
      .28,
    );
    expect(
      touchFeedbackBaseVolume(TouchFeedbackSound.success) *
          settings.volumeMultiplierFor(DeviceFeedbackChannel.command),
      .34,
    );
    expect(settings.resolvesReducedMotion(false), isFalse);
    expect(
      const DeviceSettings(
        reducedMotion: ReducedMotionPreference.on,
      ).resolvesReducedMotion(false),
      isTrue,
    );
    expect(
      const DeviceSettings(
        reducedMotion: ReducedMotionPreference.off,
      ).resolvesReducedMotion(true),
      isTrue,
    );
    expect(settings.rippleEnabled, isTrue);
    expect(settings.ambientCircuitEnabled, isTrue);
  });

  test(
    'persists every setting and restores it on a fresh controller',
    () async {
      final first = DeviceSettingsController();
      await first.initialize();
      await first.restore({
        'masterVolume': .5,
        'muted': true,
        'commandVolume': .4,
        'exitVolume': .3,
        'rejectedVolume': .2,
        'ambientVolume': .1,
        'brightness': .6,
        'rippleEnabled': false,
        'ambientCircuitEnabled': false,
        'reducedMotion': 'on',
      });

      final restored = DeviceSettingsController();
      await restored.initialize();

      expect(restored.value.masterVolume, .5);
      expect(restored.value.muted, isTrue);
      expect(restored.value.commandVolume, .4);
      expect(restored.value.exitVolume, .3);
      expect(restored.value.rejectedVolume, .2);
      expect(restored.value.ambientVolume, .1);
      expect(restored.value.brightness, .6);
      expect(restored.value.rippleEnabled, isFalse);
      expect(restored.value.ambientCircuitEnabled, isFalse);
      expect(restored.value.reducedMotion, ReducedMotionPreference.on);
    },
  );

  test('missing and invalid stored values normalize safely', () async {
    SharedPreferences.setMockInitialValues({
      DeviceSettingsController.storageKey: jsonEncode({
        'masterVolume': 4,
        'commandVolume': -1,
        'brightness': 0,
        'reducedMotion': 'invalid',
      }),
    });
    final controller = DeviceSettingsController();
    await controller.initialize();

    expect(controller.value.masterVolume, 1);
    expect(controller.value.commandVolume, 0);
    expect(controller.value.brightness, DeviceSettings.minimumBrightness);
    expect(controller.value.reducedMotion, ReducedMotionPreference.system);
  });

  test('mute suppresses every channel without erasing channel values', () {
    const settings = DeviceSettings(
      muted: true,
      masterVolume: .6,
      commandVolume: .4,
      exitVolume: .3,
      rejectedVolume: .2,
      ambientVolume: .1,
    );

    for (final channel in DeviceFeedbackChannel.values) {
      expect(settings.volumeMultiplierFor(channel), 0);
    }
    expect(settings.commandVolume, .4);
    expect(settings.ambientVolume, .1);
  });
}
