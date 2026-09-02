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
    final assetUrl = Uri.base.resolve(bootAudioAssetUrl).toString();
    final audio = AudioElement(assetUrl)
      ..preload = 'auto'
      ..muted = false
      ..volume = 1;
    _audio = audio;
    _log(
      'BOOT AUDIO request=ATTEMPTED asset=$assetUrl '
      'muted=${audio.muted} volume=${audio.volume}',
    );
    audio.onCanPlay.first.then((_) => _log('BOOT AUDIO decode=SUCCESS'));
    audio.onError.first.then(
      (_) => _log('BOOT AUDIO fetch/decode=FAILED code=${audio.error?.code}'),
    );
    // iOS autoplay can reject this promise; audio is strictly presentation.
    _requestPlayback();
  }

  void _requestPlayback() {
    final audio = _audio;
    if (audio == null) return;
    audio.play().then(
      (_) => _log('BOOT AUDIO play=SUCCESS'),
      onError: (Object error, StackTrace stackTrace) => _log(
        'BOOT AUDIO play=REJECTED '
        'errorName=${error.runtimeType} errorMessage=$error',
      ),
    );
  }

  void _log(String message) => window.console.info(message);
}
