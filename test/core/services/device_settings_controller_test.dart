import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/services/device_settings_controller.dart';
import 'package:or_app/core/services/touch_ripple_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('master and each role scale only the intended released levels', () {
    const defaults = DeviceSettings();
    final cases = <TouchFeedbackSound, DeviceSettings>{
      TouchFeedbackSound.success: defaults.copyWith(commandVolume: .5),
      TouchFeedbackSound.exit: defaults.copyWith(exitVolume: .5),
      TouchFeedbackSound.failure: defaults.copyWith(rejectedVolume: .5),
      TouchFeedbackSound.water: defaults.copyWith(ambientVolume: .5),
    };
    for (final sound in TouchFeedbackSound.values) {
      final base = sound == TouchFeedbackSound.water ? .28 : .34;
      expect(touchFeedbackEffectiveVolume(sound, defaults), base);
      expect(
        touchFeedbackEffectiveVolume(
          sound,
          defaults.copyWith(masterVolume: .5),
        ),
        base * .5,
      );
      for (final entry in cases.entries) {
        expect(
          touchFeedbackEffectiveVolume(sound, entry.value),
          base * (sound == entry.key ? .5 : 1),
        );
      }
      expect(
        touchFeedbackEffectiveVolume(sound, defaults.copyWith(masterVolume: 0)),
        0,
      );
      final selected = defaults.copyWith(masterVolume: .6, ambientVolume: .3);
      final muted = selected.copyWith(muted: true);
      expect(touchFeedbackEffectiveVolume(sound, muted), 0);
      expect(
        touchFeedbackEffectiveVolume(sound, muted.copyWith(muted: false)),
        touchFeedbackEffectiveVolume(sound, selected),
      );
    }
  });

  test('master and channel percentages remain continuously multiplicative', () {
    const cases = <(double, double, double)>[
      (1, 1, 1),
      (.75, 1, .75),
      (.5, 1, .5),
      (.25, 1, .25),
      (.1, 1, .1),
      (.01, 1, .01),
      (0, 1, 0),
      (.5, .5, .25),
      (.5, .4, .2),
      (.25, .2, .05),
    ];

    for (final (master, channel, expected) in cases) {
      final settings = DeviceSettings(
        masterVolume: master,
        commandVolume: channel,
      );
      expect(
        settings.volumeMultiplierFor(DeviceFeedbackChannel.command),
        closeTo(expected, .000001),
        reason: 'MASTER $master × COMMAND $channel',
      );
    }
  });

  test(
    'missing, corrupt and non-finite preferences preserve safe defaults',
    () async {
      final missing = DeviceSettingsController();
      await missing.initialize();
      expect(missing.snapshot(), const DeviceSettings().toJson());
      SharedPreferences.setMockInitialValues({
        DeviceSettingsController.storageKey: '{broken',
      });
      final corrupt = DeviceSettingsController();
      await corrupt.initialize();
      expect(corrupt.snapshot(), const DeviceSettings().toJson());
      expect(
        DeviceSettings.fromJson({
          'masterVolume': double.nan,
          'brightness': double.infinity,
          'muted': 'true',
        }).toJson(),
        const DeviceSettings().toJson(),
      );
    },
  );

  test('SYSTEM follows accessibility while ON and OFF are explicit', () {
    expect(const DeviceSettings().resolvesReducedMotion(false), isFalse);
    expect(const DeviceSettings().resolvesReducedMotion(true), isTrue);
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
      isFalse,
    );
  });

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
      isFalse,
    );
    expect(settings.rippleEnabled, isTrue);
    expect(settings.ambientCircuitEnabled, isTrue);
    expect(settings.ambientProcessingEnabled, isTrue);
    expect(settings.ambientWildlifeEnabled, isTrue);
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
        'ambientProcessingEnabled': false,
        'ambientWildlifeEnabled': false,
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
      expect(restored.value.ambientProcessingEnabled, isFalse);
      expect(restored.value.ambientWildlifeEnabled, isFalse);
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
    expect(controller.value.ambientProcessingEnabled, isTrue);
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
