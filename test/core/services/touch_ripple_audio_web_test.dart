@TestOn('browser')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/services/device_settings_controller.dart';
import 'package:or_app/core/services/touch_ripple_audio.dart';
import 'package:or_app/core/services/touch_ripple_audio_web.dart';
import 'package:web/web.dart';

void main() {
  test('production player sends continuous gain to browser output', () async {
    final controller = DeviceSettingsController.instance;
    final original = controller.value;
    controller.resetForTesting(const DeviceSettings());
    final outputs = <TouchFeedbackSound, _RecordingAudioOutput>{};
    final audio = createPlatformTouchRippleAudio(
      audioFactory: (_) => HTMLAudioElement(),
      outputFactory: (sound, element) {
        final output = _RecordingAudioOutput(element);
        outputs[sound] = output;
        return output;
      },
    );
    try {
      audio.prepare();
      expect(outputs[TouchFeedbackSound.water]!.gain, .28);
      expect(outputs[TouchFeedbackSound.success]!.gain, .34);
      expect(outputs[TouchFeedbackSound.failure]!.gain, .34);
      expect(outputs[TouchFeedbackSound.exit]!.gain, .34);
      for (final master in [1.0, .75, .5, .25, .1, .01]) {
        controller.update(
          controller.value.copyWith(masterVolume: master, commandVolume: 1),
        );
        audio.playFromUserGesture(TouchFeedbackSound.success);
        expect(
          outputs[TouchFeedbackSound.success]!.gain,
          closeTo(touchRippleSemanticBaseVolume * master, .000001),
          reason: 'MASTER $master must reach the output as continuous gain',
        );
      }

      controller.update(
        controller.value.copyWith(masterVolume: .5, commandVolume: .5),
      );
      audio.playFromUserGesture(TouchFeedbackSound.success);
      expect(outputs[TouchFeedbackSound.success]!.gain, closeTo(.085, .000001));
      controller.update(controller.value.copyWith(commandVolume: .4));
      expect(outputs[TouchFeedbackSound.success]!.gain, closeTo(.068, .000001));
      controller.update(
        controller.value.copyWith(masterVolume: .25, commandVolume: .2),
      );
      expect(outputs[TouchFeedbackSound.success]!.gain, closeTo(.017, .000001));

      controller.update(
        controller.value.copyWith(masterVolume: .5, ambientVolume: 1),
      );
      audio.playFromUserGesture(TouchFeedbackSound.water);
      controller.update(controller.value.copyWith(ambientVolume: .5));
      // A rejected passive request was never added to the active pool.
      expect(outputs[TouchFeedbackSound.water]!.gain, .14);
      audio.playFromUserGesture(TouchFeedbackSound.exit);
      controller.update(
        controller.value.copyWith(exitVolume: .5, commandVolume: .2),
      );
      expect(outputs[TouchFeedbackSound.exit]!.gain, closeTo(.085, .000001));
      // The replaced COMMAND is no longer updated as an active sound.
      expect(outputs[TouchFeedbackSound.success]!.gain, closeTo(.017, .000001));
      controller.update(controller.value.copyWith(muted: true));
      expect(outputs[TouchFeedbackSound.exit]!.gain, 0);
      controller.update(controller.value.copyWith(muted: false));
      audio.playFromUserGesture(TouchFeedbackSound.exit);
      expect(outputs[TouchFeedbackSound.exit]!.gain, closeTo(.085, .000001));
      // Empty sources reject playback. After cleanup the pool accepts ambient.
      await Future<void>.delayed(const Duration(milliseconds: 100));
      audio.playFromUserGesture(TouchFeedbackSound.water);
      expect(outputs[TouchFeedbackSound.water]!.gain, closeTo(.07, .000001));

      controller.update(controller.value.copyWith(ambientVolume: 0));
      expect(outputs[TouchFeedbackSound.water]!.gain, 0);
      controller.update(
        controller.value.copyWith(masterVolume: .5, ambientVolume: .5),
      );
      audio.playFromUserGesture(TouchFeedbackSound.water);
      controller.update(controller.value.copyWith(masterVolume: 0));
      expect(outputs[TouchFeedbackSound.water]!.gain, 0);
    } finally {
      audio.dispose();
      expect(outputs.values.every((output) => output.disposed), isTrue);
      controller.resetForTesting(original);
    }
  });
}

class _RecordingAudioOutput implements TouchFeedbackAudioOutput {
  _RecordingAudioOutput(this.audio);

  @override
  final HTMLAudioElement audio;
  double gain = 0;
  bool disposed = false;

  @override
  void setGain(double gain) => this.gain = gain;

  @override
  void dispose() => disposed = true;
}
