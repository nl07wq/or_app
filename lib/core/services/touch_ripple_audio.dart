import 'touch_ripple_audio_stub.dart'
    if (dart.library.html) 'touch_ripple_audio_web.dart';
import 'device_settings_controller.dart';

const touchRippleAudioAssetUrl =
    'assets/assets/audio/touch/Water_Drop02-1(Low-Reverb).mp3';
const touchRippleSuccessAudioAssetUrl =
    'assets/assets/audio/touch/Cyber03-1.mp3';
// GitHub Pages does not serve the original Japanese filenames reliably from
// direct HTML audio URLs. These aliases are byte-for-byte copies of the
// credited source assets and keep semantic delivery independent of URL
// encoding.
const touchRippleFailureAudioAssetUrl =
    'assets/assets/audio/touch/cancel-1.mp3';
const touchRippleExitAudioAssetUrl = 'assets/assets/audio/touch/button-09.mp3';

enum TouchFeedbackSound { water, success, failure, exit }

const touchRippleWaterBaseVolume = .28;
const touchRippleSemanticBaseVolume = .34;

double touchFeedbackBaseVolume(TouchFeedbackSound sound) =>
    sound == TouchFeedbackSound.water
    ? touchRippleWaterBaseVolume
    : touchRippleSemanticBaseVolume;

double touchFeedbackEffectiveVolume(
  TouchFeedbackSound sound,
  DeviceSettings settings,
) =>
    touchFeedbackBaseVolume(sound) *
    settings.normalized().volumeMultiplierFor(switch (sound) {
      TouchFeedbackSound.water => DeviceFeedbackChannel.ambient,
      TouchFeedbackSound.success => DeviceFeedbackChannel.command,
      TouchFeedbackSound.failure => DeviceFeedbackChannel.rejected,
      TouchFeedbackSound.exit => DeviceFeedbackChannel.exit,
    });

abstract interface class TouchRippleAudio {
  void prepare();
  void playFromUserGesture(TouchFeedbackSound sound);
  void dispose();
}

TouchRippleAudio createTouchRippleAudio() => createPlatformTouchRippleAudio();
