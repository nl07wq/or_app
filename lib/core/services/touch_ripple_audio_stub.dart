import 'touch_ripple_audio.dart';

TouchRippleAudio createPlatformTouchRippleAudio() => _SilentTouchRippleAudio();

class _SilentTouchRippleAudio implements TouchRippleAudio {
  @override
  void dispose() {}

  @override
  void playFromUserGesture(TouchFeedbackSound sound) {}

  @override
  void prepare() {}
}
