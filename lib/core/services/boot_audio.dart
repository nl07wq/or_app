import 'boot_audio_stub.dart' if (dart.library.html) 'boot_audio_web.dart';

abstract interface class BootAudio {
  void playOnce();
}

BootAudio createBootAudio() => createPlatformBootAudio();
