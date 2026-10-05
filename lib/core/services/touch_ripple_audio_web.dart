// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html';

import 'touch_ripple_audio.dart';

const _touchRippleAudioVolume = .28;
const _semanticAudioVolume = .34;
const _maximumConcurrentTouchRippleSounds = 2;

TouchRippleAudio createPlatformTouchRippleAudio() => _WebTouchRippleAudio();

class _WebTouchRippleAudio implements TouchRippleAudio {
  final List<AudioElement> _active = [];
  final Map<TouchFeedbackSound, AudioElement> _prepared = {};

  @override
  void prepare() {
    for (final sound in TouchFeedbackSound.values) {
      _prepared.putIfAbsent(sound, () => _newAudio(sound));
    }
  }

  @override
  void playFromUserGesture(TouchFeedbackSound sound) {
    if (_active.length >= _maximumConcurrentTouchRippleSounds) return;
    final prepared = _prepared[sound];
    final audio = prepared != null && !_active.contains(prepared)
        ? prepared
        : _newAudio(sound);
    audio
      ..currentTime = 0
      ..play();
    _active.add(audio);
    audio.onEnded.first.then((_) => _active.remove(audio));
    audio.onError.first.then((_) => _active.remove(audio));
  }

  AudioElement _newAudio(TouchFeedbackSound sound) =>
      AudioElement(Uri.base.resolve(_assetUrl(sound)).toString())
        ..preload = 'auto'
        ..volume = sound == TouchFeedbackSound.water
            ? _touchRippleAudioVolume
            : _semanticAudioVolume;

  String _assetUrl(TouchFeedbackSound sound) => switch (sound) {
    TouchFeedbackSound.water => touchRippleAudioAssetUrl,
    TouchFeedbackSound.success => touchRippleSuccessAudioAssetUrl,
    TouchFeedbackSound.failure => touchRippleFailureAudioAssetUrl,
  };

  @override
  void dispose() {
    for (final audio in _active) {
      audio.pause();
    }
    _active.clear();
    for (final audio in _prepared.values) {
      audio.pause();
    }
    _prepared.clear();
  }
}
