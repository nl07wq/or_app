// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html';

import 'touch_ripple_audio.dart';

const _touchRippleAudioVolume = .28;
const _maximumConcurrentTouchRippleSounds = 2;

TouchRippleAudio createPlatformTouchRippleAudio() => _WebTouchRippleAudio();

class _WebTouchRippleAudio implements TouchRippleAudio {
  final List<AudioElement> _active = [];
  AudioElement? _prepared;

  @override
  void prepare() {
    _prepared ??= _newAudio();
  }

  @override
  void playFromUserGesture() {
    if (_active.length >= _maximumConcurrentTouchRippleSounds) return;
    final audio = _prepared != null && !_active.contains(_prepared)
        ? _prepared!
        : _newAudio();
    audio
      ..currentTime = 0
      ..play();
    _active.add(audio);
    audio.onEnded.first.then((_) => _active.remove(audio));
    audio.onError.first.then((_) => _active.remove(audio));
  }

  AudioElement _newAudio() =>
      AudioElement(Uri.base.resolve(touchRippleAudioAssetUrl).toString())
        ..preload = 'auto'
        ..volume = _touchRippleAudioVolume;

  @override
  void dispose() {
    for (final audio in _active) {
      audio.pause();
    }
    _active.clear();
    _prepared?.pause();
    _prepared = null;
  }
}
