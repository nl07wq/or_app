// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html';

import 'touch_ripple_audio.dart';

const _touchRippleAudioVolume = .28;
const _semanticAudioVolume = .34;
const _maximumConcurrentTouchRippleSounds = 2;

TouchRippleAudio createPlatformTouchRippleAudio() => _WebTouchRippleAudio();

class _WebTouchRippleAudio implements TouchRippleAudio {
  final List<_ActiveSound> _active = [];
  final Map<TouchFeedbackSound, AudioElement> _prepared = {};

  @override
  void prepare() {
    for (final sound in TouchFeedbackSound.values) {
      _prepared.putIfAbsent(sound, () => _newAudio(sound));
    }
  }

  @override
  void playFromUserGesture(TouchFeedbackSound sound) {
    if (_active.length >= _maximumConcurrentTouchRippleSounds) {
      final genericIndex = _active.indexWhere(
        (entry) => entry.sound == TouchFeedbackSound.water,
      );
      // Semantic feedback is never silently discarded behind a lower-priority
      // environmental droplet. If the bounded pool is full of semantic sound,
      // replace the oldest entry so repeated accepted taps still get feedback.
      final index = genericIndex >= 0 ? genericIndex : 0;
      final displaced = _active.removeAt(index);
      displaced.audio.pause();
    }
    final prepared = _prepared[sound];
    final audio =
        prepared != null &&
            !_active.any((entry) => identical(entry.audio, prepared))
        ? prepared
        : _newAudio(sound);
    final entry = _ActiveSound(sound, audio);
    _active.add(entry);
    audio.currentTime = 0;
    audio.play().then<void>((_) {}, onError: (_) => _remove(entry));
    audio.onEnded.first.then((_) => _remove(entry));
    audio.onError.first.then((_) => _remove(entry));
  }

  void _remove(_ActiveSound entry) => _active.remove(entry);

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
    TouchFeedbackSound.exit => touchRippleExitAudioAssetUrl,
  };

  @override
  void dispose() {
    for (final audio in _active) {
      audio.audio.pause();
    }
    _active.clear();
    for (final audio in _prepared.values) {
      audio.pause();
    }
    _prepared.clear();
  }
}

class _ActiveSound {
  const _ActiveSound(this.sound, this.audio);

  final TouchFeedbackSound sound;
  final AudioElement audio;
}
