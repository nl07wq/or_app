// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:js_interop';

import 'package:web/web.dart';

import 'touch_ripple_audio.dart';
import 'device_settings_controller.dart';

const _maximumConcurrentTouchRippleSounds = 2;

TouchRippleAudio createPlatformTouchRippleAudio({
  HTMLAudioElement Function(TouchFeedbackSound)? audioFactory,
  TouchFeedbackAudioOutput Function(
    TouchFeedbackSound sound,
    HTMLAudioElement audio,
  )?
  outputFactory,
}) => _WebTouchRippleAudio(
  audioFactory: audioFactory,
  outputFactory: outputFactory,
);

/// The final browser output stage used by the production touch-audio player.
///
/// Tests inject this boundary so that they verify the value delivered to the
/// actual output adapter, rather than stopping at the settings calculation.
abstract interface class TouchFeedbackAudioOutput {
  HTMLAudioElement get audio;
  void setGain(double gain);
  void dispose();
}

class _WebTouchRippleAudio implements TouchRippleAudio {
  _WebTouchRippleAudio({this.audioFactory, this.outputFactory});

  final HTMLAudioElement Function(TouchFeedbackSound)? audioFactory;
  final TouchFeedbackAudioOutput Function(
    TouchFeedbackSound sound,
    HTMLAudioElement audio,
  )?
  outputFactory;
  final List<_ActiveSound> _active = [];
  final Map<TouchFeedbackSound, TouchFeedbackAudioOutput> _prepared = {};
  AudioContext? _audioContext;
  bool _listening = false;

  @override
  void prepare() {
    if (!_listening) {
      DeviceSettingsController.instance.addListener(_applySettings);
      _listening = true;
    }
    for (final sound in TouchFeedbackSound.values) {
      _prepared.putIfAbsent(sound, () => _newOutput(sound));
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
    final output =
        prepared != null &&
            !_active.any((entry) => identical(entry.output, prepared))
        ? prepared
        : _newOutput(sound);
    final entry = _ActiveSound(sound, output);
    _active.add(entry);
    final audio = output.audio;
    audio.currentTime = 0;
    output.setGain(volume);
    entry.ended = ((Event _) => _remove(entry)).toJS;
    entry.error = ((Event _) => _stop(entry)).toJS;
    audio.addEventListener('ended', entry.ended);
    audio.addEventListener('error', entry.error);
    _resumeAudioContext();
    audio.play().toDart.then<void>((_) {}, onError: (_) => _stop(entry));
  }

  void _remove(_ActiveSound entry) {
    _active.remove(entry);
    entry.output.audio.removeEventListener('ended', entry.ended);
    entry.output.audio.removeEventListener('error', entry.error);
    if (!identical(_prepared[entry.sound], entry.output)) {
      entry.output.dispose();
    }
  }

  void _stop(_ActiveSound entry) {
    // A displaced play() can reject after its prepared element was reused.
    // Its stale callback must not pause the newer response.
    if (!_active.contains(entry)) return;
    entry.output.audio.pause();
    _remove(entry);
  }

  void _applySettings() {
    final settings = DeviceSettingsController.instance.value;
    for (final entry in List<_ActiveSound>.of(_active)) {
      final volume = touchFeedbackEffectiveVolume(entry.sound, settings);
      entry.output.setGain(volume);
      if (volume <= 0) {
        _stop(entry);
      }
    }
  }

  TouchFeedbackAudioOutput _newOutput(TouchFeedbackSound sound) {
    final audio =
        audioFactory?.call(sound) ??
        (HTMLAudioElement()
          ..src = Uri.base.resolve(_assetUrl(sound)).toString());
    audio.preload = 'auto';
    final output = outputFactory?.call(sound, audio) ?? _browserOutput(audio);
    output.setGain(
      touchFeedbackEffectiveVolume(
        sound,
        DeviceSettingsController.instance.value,
      ),
    );
    return output;
  }

  TouchFeedbackAudioOutput _browserOutput(HTMLAudioElement audio) {
    try {
      final context = _audioContext ??= AudioContext();
      return _WebAudioGainOutput(audio, context);
    } catch (_) {
      // Older embedded browsers can advertise Web Audio but reject media
      // element routing. Keep the existing HTML audio fallback available.
    }
    return _HtmlAudioGainOutput(audio);
  }

  void _resumeAudioContext() {
    final context = _audioContext;
    if (context == null) return;
    context.resume().toDart.then<void>((_) {}, onError: (_) {});
  }

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
    for (final output in _prepared.values) {
      output.audio.pause();
      output.dispose();
    }
    _prepared.clear();
    final context = _audioContext;
    _audioContext = null;
    context?.close().toDart.then<void>((_) {}, onError: (_) {});
  }
}

class _ActiveSound {
  _ActiveSound(this.sound, this.output);

  final TouchFeedbackSound sound;
  final TouchFeedbackAudioOutput output;
  JSFunction? ended;
  JSFunction? error;
}

class _WebAudioGainOutput implements TouchFeedbackAudioOutput {
  _WebAudioGainOutput(this.audio, AudioContext context)
    : _source = context.createMediaElementSource(audio),
      _gain = context.createGain() {
    // MediaElement volume is not continuously controllable on mobile WebKit.
    // Keep it neutral and route the released asset level through Web Audio.
    audio.volume = 1;
    _source.connect(_gain);
    _gain.connect(context.destination);
  }

  @override
  final HTMLAudioElement audio;
  final MediaElementAudioSourceNode _source;
  final GainNode _gain;

  @override
  void setGain(double gain) => _gain.gain.value = gain.clamp(0, 1);

  @override
  void dispose() {
    _source.disconnect();
    _gain.disconnect();
  }
}

class _HtmlAudioGainOutput implements TouchFeedbackAudioOutput {
  _HtmlAudioGainOutput(this.audio);

  @override
  final HTMLAudioElement audio;

  @override
  void setGain(double gain) => audio.volume = gain.clamp(0, 1).toDouble();

  @override
  void dispose() {}
}
