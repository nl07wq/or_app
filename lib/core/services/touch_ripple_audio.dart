import 'touch_ripple_audio_stub.dart'
    if (dart.library.html) 'touch_ripple_audio_web.dart';

const touchRippleAudioAssetUrl =
    'assets/assets/audio/touch/Water_Drop02-1(Low-Reverb).mp3';

abstract interface class TouchRippleAudio {
  void prepare();
  void playFromUserGesture();
  void dispose();
}

TouchRippleAudio createTouchRippleAudio() => createPlatformTouchRippleAudio();
