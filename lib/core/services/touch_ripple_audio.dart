import 'touch_ripple_audio_stub.dart'
    if (dart.library.html) 'touch_ripple_audio_web.dart';

const touchRippleAudioAssetUrl =
    'assets/assets/audio/touch/Water_Drop02-1(Low-Reverb).mp3';
const touchRippleSuccessAudioAssetUrl =
    'assets/assets/audio/touch/Cyber03-1.mp3';
const touchRippleFailureAudioAssetUrl = 'assets/assets/audio/touch/キャンセル1.mp3';
const touchRippleExitAudioAssetUrl = 'assets/assets/audio/touch/ボタン音09.mp3';

enum TouchFeedbackSound { water, success, failure, exit }

abstract interface class TouchRippleAudio {
  void prepare();
  void playFromUserGesture(TouchFeedbackSound sound);
  void dispose();
}

TouchRippleAudio createTouchRippleAudio() => createPlatformTouchRippleAudio();
