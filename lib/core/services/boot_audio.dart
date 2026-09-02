import 'boot_audio_stub.dart' if (dart.library.html) 'boot_audio_web.dart';

const bootAudioAssetUrl = 'assets/assets/audio/boot/ORLO_Boot_v17.wav';

abstract interface class BootAudio {
  void playOnce();
}

BootAudio createBootAudio() => createPlatformBootAudio();
