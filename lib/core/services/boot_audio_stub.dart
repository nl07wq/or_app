import 'boot_audio.dart';

BootAudio createPlatformBootAudio() => _SilentBootAudio();

class _SilentBootAudio implements BootAudio {
  @override
  void playOnce() {}
}
