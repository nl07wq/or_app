// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html';

import 'touch_ripple_audio.dart';
import 'device_settings_controller.dart';

const _maximumConcurrentTouchRippleSounds = 2;

TouchRippleAudio createPlatformTouchRippleAudio({
  AudioElement Function(TouchFeedbackSound)? audioFactory,
}) => _WebTouchRippleAudio(audioFactory: audioFactory);

class _WebTouchRippleAudio implements TouchRippleAudio {
  _WebTouchRippleAudio({this.audioFactory});

  final AudioElement Function(TouchFeedbackSound)? audioFactory;
  final List<_ActiveSound> _active = [];
  final Map<TouchFeedbackSound, AudioElement> _prepared = {};
  bool _listening = false;

  @override
  void prepare() {
    if (!_listening) {
      DeviceSettingsController.instance.addListener(_applySettings);
      _listening = true;
    }
    for (final sound in TouchFeedbackSound.values) {
      _prepared.putIfAbsent(sound, () => _newAudio(sound));
    }
  }

  @override
  void playFromUserGesture(TouchFeedbackSound sound) {
    final volume = touchFeedbackEffectiveVolume(
      sound,
      DeviceSettingsController.instance.value,
    );
    if (volume <= 0) return;
    // Passive audio never displaces an in-progress semantic response.
    if (sound == TouchFeedbackSound.water &&
        _active.any((entry) => entry.sound != TouchFeedbackSound.water)) {
      return;
    }
    if (sound != TouchFeedbackSound.water) {
      for (final entry in List<_ActiveSound>.of(_active)) {
        _stop(entry);
      }
    }
    if (_active.length >= _maximumConcurrentTouchRippleSounds) {
      // Only ambient sounds can coexist; replace the oldest bounded droplet.
      _stop(_active.first);
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
    audio.volume = volume;
    entry.ended = audio.onEnded.listen((_) => _remove(entry));
    entry.error = audio.onError.listen((_) => _stop(entry));
    audio.play().then<void>((_) {}, onError: (_) => _stop(entry));
  }

  void _remove(_ActiveSound entry) {
    _active.remove(entry);
    entry.ended?.cancel();
    entry.error?.cancel();
  }

  void _stop(_ActiveSound entry) {
    // A displaced play() can reject after its prepared element was reused.
    // Its stale callback must not pause the newer response.
    if (!_active.contains(entry)) return;
    entry.audio.pause();
    _remove(entry);
  }

  void _applySettings() {
    final settings = DeviceSettingsController.instance.value;
    for (final entry in List<_ActiveSound>.of(_active)) {
      final volume = touchFeedbackEffectiveVolume(entry.sound, settings);
      entry.audio.volume = volume;
      if (volume <= 0) {
        _stop(entry);
      }
    }
  }

  AudioElement _newAudio(TouchFeedbackSound sound) =>
      (audioFactory?.call(sound) ??
            AudioElement(Uri.base.resolve(_assetUrl(sound)).toString()))
        ..preload = 'auto'
        ..volume = touchFeedbackEffectiveVolume(
          sound,
          DeviceSettingsController.instance.value,
        );

  String _assetUrl(TouchFeedbackSound sound) => switch (sound) {
    TouchFeedbackSound.water => touchRippleAudioAssetUrl,
    TouchFeedbackSound.success => touchRippleSuccessAudioAssetUrl,
    TouchFeedbackSound.failure => touchRippleFailureAudioAssetUrl,
    TouchFeedbackSound.exit => touchRippleExitAudioAssetUrl,
  };

  @override
  void dispose() {
    if (_listening) {
      DeviceSettingsController.instance.removeListener(_applySettings);
      _listening = false;
    }
    for (final entry in List<_ActiveSound>.of(_active)) {
      _stop(entry);
    }
    for (final audio in _prepared.values) {
      audio.pause();
    }
    _prepared.clear();
  }
}

class _ActiveSound {
  _ActiveSound(this.sound, this.audio);

  final TouchFeedbackSound sound;
  final AudioElement audio;
  StreamSubscription<Event>? ended;
  StreamSubscription<Event>? error;
}
