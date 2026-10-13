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
  TouchFeedbackAudioOutput Function(HTMLAudioElement audio)?
  browserOutputFactory,
}) => _WebTouchRippleAudio(
  audioFactory: audioFactory,
  outputFactory: outputFactory,
  browserOutputFactory: browserOutputFactory,
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
  _WebTouchRippleAudio({
    this.audioFactory,
    this.outputFactory,
    this.browserOutputFactory,
  });

  final HTMLAudioElement Function(TouchFeedbackSound)? audioFactory;
  final TouchFeedbackAudioOutput Function(
    TouchFeedbackSound sound,
    HTMLAudioElement audio,
  )?
  outputFactory;
  final TouchFeedbackAudioOutput Function(HTMLAudioElement audio)?
  browserOutputFactory;
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
    // Do not create an AudioContext or media-element source here.  `prepare`
    // runs while the app tree is mounted, outside a user activation.  Mobile
    // WebKit can keep such a context suspended through the first semantic
    // feedback request, making that request silent until a later tap happens
    // to resume it.  The selected output is instead created synchronously by
    // [playFromUserGesture], inside the originating pointer/slider gesture.
    // The plain media elements are still preloaded so the first permitted
    // gesture does not have to wait for an uncached source request.
    for (final sound in TouchFeedbackSound.values) {
      _prepared.putIfAbsent(sound, () => _newPreloadedOutput(sound));
    }
  }

  @override
  void playFromUserGesture(TouchFeedbackSound sound) {
    final volume = touchFeedbackEffectiveVolume(
      sound,
      DeviceSettingsController.instance.value,
    );
    TouchRippleAudioDiagnostics.record('PLAY_REQUESTED', {
      'sound': sound.name,
      'volume': volume.toStringAsFixed(3),
      'active': _active.length,
      'context': _audioContext?.state ?? 'none',
    });
    if (volume <= 0) {
      TouchRippleAudioDiagnostics.record('PLAY_SKIPPED_MUTED_OR_ZERO', {
        'sound': sound.name,
      });
      return;
    }
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
    final output = _outputForUserGesture(sound);
    final entry = _ActiveSound(sound, output);
    _active.add(entry);
    final audio = output.audio;
    audio.currentTime = 0;
    output.setGain(volume);
    entry.ended = ((Event _) => _remove(entry)).toJS;
    // A media element can enter an error state after an interrupted or
    // rejected play request on mobile WebKit.  Keeping that prepared element
    // would make every later REJECTED attempt silently reuse the same failed
    // decoder.  Retire it so the next explicit user gesture starts with a
    // fresh element and decoder.
    entry.error = ((Event _) => _recoverFromPlaybackFailure(entry)).toJS;
    audio.addEventListener('ended', entry.ended);
    audio.addEventListener('error', entry.error);
    _resumeAudioContext();
    audio.play().toDart.then<void>(
      (_) => TouchRippleAudioDiagnostics.record('PLAY_PROMISE_RESOLVED', {
        'sound': sound.name,
        'time': audio.currentTime.toStringAsFixed(3),
      }),
      onError: (Object error, StackTrace stackTrace) {
        TouchRippleAudioDiagnostics.record('PLAY_PROMISE_REJECTED', {
          'sound': sound.name,
          'errorType': error.runtimeType,
          'error': error,
        });
        _recoverFromPlaybackFailure(entry);
      },
    );
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

  void _recoverFromPlaybackFailure(_ActiveSound entry) {
    // Ignore delayed rejections from a source which has already been replaced
    // by a newer semantic response.
    if (!_active.contains(entry)) return;
    final output = entry.output;
    final error = output.audio.error;
    TouchRippleAudioDiagnostics.record('MEDIA_FAILURE', {
      'sound': entry.sound.name,
      'mediaCode': error?.code ?? 'none',
      'mediaMessage': error?.message ?? 'none',
    });
    _remove(entry);
    if (identical(_prepared[entry.sound], output)) {
      _prepared.remove(entry.sound);
      output.dispose();
    }
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

  /// Obtains a preloaded output without creating Web Audio until a real user
  /// gesture asks for it.  A currently playing prepared source is never
  /// reused: overlapping semantic requests retain their own media element.
  TouchFeedbackAudioOutput _outputForUserGesture(TouchFeedbackSound sound) {
    final prepared = _prepared[sound];
    if (prepared != null &&
        !_active.any((entry) => identical(entry.output, prepared))) {
      if (_usesBrowserOutput && prepared is _HtmlAudioGainOutput) {
        // Upgrade the preloaded media element only while a user gesture is
        // active.  That is the point at which iPhone Safari permits the
        // AudioContext to become an audible output.
        final output = _browserOutput(prepared.audio);
        _prepared[sound] = output;
        prepared.dispose();
        return output;
      }
      return prepared;
    }
    final output = _newOutput(sound);
    _prepared.putIfAbsent(sound, () => output);
    return output;
  }

  TouchFeedbackAudioOutput _newOutput(TouchFeedbackSound sound) {
    final audio =
        audioFactory?.call(sound) ??
        (HTMLAudioElement()
          ..src = Uri.base.resolve(_assetUrl(sound)).toString());
    audio.preload = 'auto';
    _observeMedia(sound, audio);
    final output = outputFactory?.call(sound, audio) ?? _browserOutput(audio);
    output.setGain(
      touchFeedbackEffectiveVolume(
        sound,
        DeviceSettingsController.instance.value,
      ),
    );
    return output;
  }

  bool get _usesBrowserOutput => outputFactory == null;

  TouchFeedbackAudioOutput _newPreloadedOutput(TouchFeedbackSound sound) {
    final audio =
        audioFactory?.call(sound) ??
        (HTMLAudioElement()
          ..src = Uri.base.resolve(_assetUrl(sound)).toString());
    audio.preload = 'auto';
    _observeMedia(sound, audio);
    // Keep startup preparation independent of Web Audio.  Tests that inject
    // the output boundary retain their normal deterministic recording path.
    if (outputFactory != null) return outputFactory!(sound, audio);
    final output = _HtmlAudioGainOutput(audio);
    output.setGain(
      touchFeedbackEffectiveVolume(
        sound,
        DeviceSettingsController.instance.value,
      ),
    );
    return output;
  }

  TouchFeedbackAudioOutput _browserOutput(HTMLAudioElement audio) {
    final injected = browserOutputFactory;
    if (injected != null) return injected(audio);
    try {
      final context = _audioContext ??= AudioContext();
      TouchRippleAudioDiagnostics.record('WEB_AUDIO_OUTPUT_CONNECTED', {
        'context': context.state,
      });
      return _WebAudioGainOutput(audio, context);
    } catch (error) {
      TouchRippleAudioDiagnostics.record('WEB_AUDIO_OUTPUT_FALLBACK', {
        'errorType': error.runtimeType,
        'error': error,
      });
      // Older embedded browsers can advertise Web Audio but reject media
      // element routing. Keep the existing HTML audio fallback available.
    }
    return _HtmlAudioGainOutput(audio);
  }

  void _resumeAudioContext() {
    final context = _audioContext;
    if (context == null) return;
    TouchRippleAudioDiagnostics.record('AUDIO_CONTEXT_RESUME_REQUESTED', {
      'before': context.state,
    });
    context.resume().toDart.then<void>(
      (_) => TouchRippleAudioDiagnostics.record('AUDIO_CONTEXT_RESUMED', {
        'after': context.state,
      }),
      onError: (Object error, StackTrace stackTrace) =>
          TouchRippleAudioDiagnostics.record('AUDIO_CONTEXT_RESUME_REJECTED', {
            'errorType': error.runtimeType,
            'error': error,
          }),
    );
  }

  void _observeMedia(TouchFeedbackSound sound, HTMLAudioElement audio) {
    if (!TouchRippleAudioDiagnostics.enabled) return;
    void record(String event) => TouchRippleAudioDiagnostics.record(event, {
      'sound': sound.name,
      'readyState': audio.readyState,
      'networkState': audio.networkState,
      'duration': audio.duration,
    });
    audio.addEventListener(
      'loadstart',
      ((Event _) => record('MEDIA_LOAD_START')).toJS,
    );
    audio.addEventListener(
      'loadedmetadata',
      ((Event _) => record('MEDIA_METADATA')).toJS,
    );
    audio.addEventListener(
      'canplay',
      ((Event _) => record('MEDIA_CAN_PLAY')).toJS,
    );
    audio.addEventListener(
      'playing',
      ((Event _) => record('MEDIA_PLAYING')).toJS,
    );
    audio.addEventListener('error', ((Event _) => record('MEDIA_ERROR')).toJS);
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
