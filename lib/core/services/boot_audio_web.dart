// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html';

import 'boot_audio.dart';

BootAudio createPlatformBootAudio() => _WebBootAudio();

class _WebBootAudio implements BootAudio {
  AudioElement? _audio;
  bool _requested = false;

  @override
  void playOnce() {
    if (_requested) return;
    _requested = true;
    final audio = AudioElement(
      Uri.base.resolve('assets/assets/audio/boot/ORLO_Boot_v17.wav').toString(),
    )..preload = 'auto';
    _audio = audio;
    // iOS autoplay can reject this promise; audio is strictly presentation.
    _requestPlayback();
  }

  void _requestPlayback() {
    final audio = _audio;
    if (audio == null) return;
    audio.play().catchError((_) {});
  }
}
