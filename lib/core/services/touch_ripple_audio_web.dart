// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:js_interop';
import 'dart:math' show sqrt;
import 'dart:typed_data' as typed_data;

import 'package:flutter/foundation.dart';
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

class _WebTouchRippleAudio
    implements TouchRippleAudio, TouchRippleAudioDiagnosticPlayer {
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
  final Map<TouchFeedbackAudioOutput, int> _outputIds = {};
  final Map<HTMLAudioElement, int> _audioOutputIds = {};
  final List<_BufferDiagnosticPlayback> _bufferDiagnostics = [];
  AudioContext? _audioContext;
  Future<_DiagnosticAudioBuffer?>? _rejectedDiagnosticBuffer;
  bool _listening = false;
  int _nextOutputId = 1;

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
  void playFromUserGesture(TouchFeedbackSound sound) => _play(sound);

  @override
  void playDiagnosticFromUserGesture(
    TouchFeedbackSound sound,
    TouchFeedbackDiagnosticRoute route,
    double effectiveVolume,
  ) {
    if (!TouchRippleAudioDiagnostics.enabled) return;
    TouchRippleAudioDiagnostics.record('DIAGNOSTIC_ROUTE_SELECTED', {
      'sound': sound.name,
      'route': route.name,
      'asset': _assetUrl(sound),
      'comparisonVolume': effectiveVolume.toStringAsFixed(3),
    });
    _play(
      sound,
      diagnosticRoute: route,
      diagnosticVolumeOverride: effectiveVolume,
    );
  }

  void _play(
    TouchFeedbackSound sound, {
    TouchFeedbackDiagnosticRoute? diagnosticRoute,
    double? diagnosticVolumeOverride,
  }) {
    final volume =
        diagnosticVolumeOverride ??
        touchFeedbackEffectiveVolume(
          sound,
          DeviceSettingsController.instance.value,
        );
    if (diagnosticRoute == TouchFeedbackDiagnosticRoute.audioBuffer) {
      _playAudioBufferDiagnostic(sound, volume);
      return;
    }
    TouchRippleAudioDiagnostics.record('PLAY_REQUESTED', {
      'sound': sound.name,
      'volume': volume.toStringAsFixed(3),
      'active': _active.length,
      'context': _audioContext?.state ?? 'none',
    });
    final decodedSignal = TouchRippleAudioDiagnostics.enabled
        ? _inspectSignal(sound)
        : null;
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
    final output = _outputForUserGesture(sound, diagnosticRoute);
    final entry = _ActiveSound(
      sound,
      output,
      _outputIdFor(output),
      decodedSignal: decodedSignal,
    );
    _active.add(entry);
    final audio = output.audio;
    audio.currentTime = 0;
    output.setGain(volume);
    _recordOutputState(sound, output, diagnosticRoute, entry.outputId);
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
        'outputId': entry.outputId,
        'time': audio.currentTime.toStringAsFixed(3),
      }),
      onError: (Object error, StackTrace stackTrace) {
        TouchRippleAudioDiagnostics.record('PLAY_PROMISE_REJECTED', {
          'sound': sound.name,
          'outputId': entry.outputId,
          'errorType': error.runtimeType,
          'error': error,
        });
        _recoverFromPlaybackFailure(entry);
      },
    );
    if (TouchRippleAudioDiagnostics.enabled) {
      _scheduleMediaTimeSamples(entry);
    }
  }

  /// A comparison-only Web Audio route which deliberately bypasses
  /// MediaElementAudioSourceNode. It never participates in normal feedback.
  void _playAudioBufferDiagnostic(TouchFeedbackSound sound, double volume) {
    if (sound != TouchFeedbackSound.failure) {
      TouchRippleAudioDiagnostics.record('BUFFER_ROUTE_UNSUPPORTED_SOUND', {
        'sound': sound.name,
      });
      return;
    }
    if (volume <= 0) {
      TouchRippleAudioDiagnostics.record('BUFFER_ROUTE_SKIPPED_MUTED_OR_ZERO', {
        'sound': sound.name,
      });
      return;
    }
    final context = _audioContext ??= AudioContext();
    TouchRippleAudioDiagnostics.record('BUFFER_ROUTE_REQUESTED', {
      'sound': sound.name,
      'asset': _assetUrl(sound),
      'requestedVolume': volume.toStringAsFixed(3),
      'context': context.state,
      'topology': 'audioBufferSource>gain>destination',
    });
    _resumeAudioContext();
    unawaited(_startAudioBufferDiagnostic(context, sound, volume));
  }

  Future<void> _startAudioBufferDiagnostic(
    AudioContext context,
    TouchFeedbackSound sound,
    double volume,
  ) async {
    final decoded = await _loadRejectedDiagnosticBuffer(context);
    if (decoded == null) return;
    if (!identical(context, _audioContext)) {
      TouchRippleAudioDiagnostics.record('BUFFER_ROUTE_CONTEXT_RETIRED', {
        'sound': sound.name,
      });
      return;
    }
    try {
      final gain = context.createGain()..gain.value = volume.clamp(0, 1);
      final signalDiagnostics = TouchRippleAudioDiagnostics.enabled;
      final preGain = signalDiagnostics ? context.createAnalyser() : null;
      final postGain = signalDiagnostics ? context.createAnalyser() : null;
      preGain?.fftSize = 256;
      postGain?.fftSize = 256;
      final source = createAudioBufferDiagnosticSource(
        context: context,
        buffer: decoded.buffer,
        gain: gain,
        preGainAnalyser: preGain,
        postGainAnalyser: postGain,
      );
      final playback = _BufferDiagnosticPlayback(
        context: context,
        source: source,
        gain: gain,
        preGainAnalyser: preGain,
        postGainAnalyser: postGain,
        sound: sound,
        sourceDescription: decoded.description,
      );
      _bufferDiagnostics.add(playback);
      playback.ended = ((Event _) {
        TouchRippleAudioDiagnostics.record('BUFFER_SOURCE_ENDED', {
          'sound': sound.name,
          'context': context.state,
          'startedAt': playback.startedAt.toStringAsFixed(4),
        });
        _removeBufferDiagnostic(playback);
      }).toJS;
      source.addEventListener('ended', playback.ended);
      TouchRippleAudioDiagnostics.record('BUFFER_OUTPUT_READY', {
        'sound': sound.name,
        'asset': _assetUrl(sound),
        'context': context.state,
        'gain': gain.gain.value.toStringAsFixed(3),
        'topology': playback.outputTopology,
        ...decoded.description,
      });
      source.start();
      playback.startedAt = context.currentTime;
      TouchRippleAudioDiagnostics.record('BUFFER_SOURCE_STARTED', {
        'sound': sound.name,
        'context': context.state,
        'startedAt': playback.startedAt.toStringAsFixed(4),
      });
      _scheduleBufferSamples(playback);
    } catch (error) {
      TouchRippleAudioDiagnostics.record('BUFFER_SOURCE_FAILED', {
        'sound': sound.name,
        'errorType': error.runtimeType,
        'error': error,
      });
    }
  }

  Future<_DiagnosticAudioBuffer?> _loadRejectedDiagnosticBuffer(
    AudioContext context,
  ) => _rejectedDiagnosticBuffer ??= _decodeRejectedDiagnosticBuffer(context);

  Future<_DiagnosticAudioBuffer?> _decodeRejectedDiagnosticBuffer(
    AudioContext context,
  ) async {
    try {
      final response = await _fetchAudio(
        Uri.base.resolve(_assetUrl(TouchFeedbackSound.failure)).toString().toJS,
      ).toDart;
      if (!response.ok.toDart) {
        TouchRippleAudioDiagnostics.record('BUFFER_FETCH_FAILED', {
          'sound': TouchFeedbackSound.failure.name,
          'status': response.status.toDartInt,
        });
        return null;
      }
      final bytes = await response.arrayBuffer().toDart;
      final buffer = await context.decodeAudioData(bytes).toDart;
      final description = _describeAudioBuffer(buffer);
      TouchRippleAudioDiagnostics.record('BUFFER_DECODED', {
        'sound': TouchFeedbackSound.failure.name,
        ...description,
      });
      return _DiagnosticAudioBuffer(buffer, description);
    } catch (error) {
      TouchRippleAudioDiagnostics.record('BUFFER_DECODE_FAILED', {
        'sound': TouchFeedbackSound.failure.name,
        'errorType': error.runtimeType,
        'error': error,
      });
      return null;
    }
  }

  Map<String, String> _describeAudioBuffer(AudioBuffer buffer) {
    var peak = 0.0;
    var squared = 0.0;
    for (var channel = 0; channel < buffer.numberOfChannels; channel++) {
      final samples = typed_data.Float32List(buffer.length);
      buffer.copyFromChannel(samples.toJS, channel);
      for (final sample in samples) {
        final amplitude = sample.abs();
        if (amplitude > peak) peak = amplitude;
        squared += sample * sample;
      }
    }
    return {
      'duration': buffer.duration.toStringAsFixed(3),
      'channels': buffer.numberOfChannels.toString(),
      'sampleRate': buffer.sampleRate.toStringAsFixed(0),
      'peak': peak.toStringAsFixed(4),
      'rms': sqrt(
        squared / (buffer.length * buffer.numberOfChannels),
      ).toStringAsFixed(4),
    };
  }

  void _scheduleBufferSamples(
    _BufferDiagnosticPlayback playback, [
    int index = 0,
  ]) {
    const interval = Duration(milliseconds: 40);
    const maximumSamples = 24;
    Future<void>.delayed(index == 0 ? Duration.zero : interval).then((_) {
      if (!_bufferDiagnostics.contains(playback) || index >= maximumSamples) {
        return;
      }
      final elapsed = (playback.context.currentTime - playback.startedAt)
          .clamp(0, double.infinity)
          .toDouble();
      TouchRippleAudioDiagnostics.record('BUFFER_SIGNAL_SAMPLE', {
        'sound': playback.sound.name,
        'sampleIndex': index,
        'bufferTime': elapsed.toStringAsFixed(4),
        'context': playback.context.state,
        'gain': playback.gain.gain.value.toStringAsFixed(4),
        'topology': playback.outputTopology,
        'preGain': _signalLevel(playback.preGainAnalyser),
        'postGain': _signalLevel(playback.postGainAnalyser),
      });
      _scheduleBufferSamples(playback, index + 1);
    });
  }

  Map<String, String> _signalLevel(AnalyserNode? analyser) {
    if (analyser == null) return const {'available': 'false'};
    final samples = typed_data.Uint8List(analyser.fftSize);
    analyser.getByteTimeDomainData(samples.toJS);
    var peak = 0.0;
    var squared = 0.0;
    for (final byte in samples) {
      final amplitude = (byte - 128).abs() / 128;
      if (amplitude > peak) peak = amplitude;
      squared += amplitude * amplitude;
    }
    return {
      'available': 'true',
      'peak': peak.toStringAsFixed(4),
      'rms': sqrt(squared / samples.length).toStringAsFixed(4),
    };
  }

  void _removeBufferDiagnostic(_BufferDiagnosticPlayback playback) {
    if (!_bufferDiagnostics.remove(playback)) return;
    playback.dispose();
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
      'outputId': entry.outputId,
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
  TouchFeedbackAudioOutput _outputForUserGesture(
    TouchFeedbackSound sound,
    TouchFeedbackDiagnosticRoute? diagnosticRoute,
  ) {
    if (diagnosticRoute == TouchFeedbackDiagnosticRoute.directHtml) {
      return _newDirectHtmlOutput(sound);
    }
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

  TouchFeedbackAudioOutput _newDirectHtmlOutput(TouchFeedbackSound sound) {
    final audio =
        audioFactory?.call(sound) ??
        (HTMLAudioElement()
          ..src = Uri.base.resolve(_assetUrl(sound)).toString());
    audio
      ..preload = 'auto'
      ..muted = false;
    _observeMedia(sound, audio);
    return _HtmlAudioGainOutput(audio);
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
      return _WebAudioGainOutput(
        audio,
        context,
        enableSignalDiagnostics: TouchRippleAudioDiagnostics.enabled,
      );
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

  void _recordOutputState(
    TouchFeedbackSound sound,
    TouchFeedbackAudioOutput output,
    TouchFeedbackDiagnosticRoute? diagnosticRoute,
    int outputId,
  ) {
    if (!TouchRippleAudioDiagnostics.enabled) return;
    final webAudio = output is _WebAudioGainOutput;
    TouchRippleAudioDiagnostics.record('OUTPUT_READY', {
      'sound': sound.name,
      'asset': _assetUrl(sound),
      'outputId': outputId,
      'outputType': output.runtimeType,
      'requestedRoute': diagnosticRoute?.name ?? 'normal',
      'actualRoute': webAudio ? 'webAudio' : 'directHtml',
      'audioSrc': output.audio.currentSrc.isEmpty
          ? output.audio.src
          : output.audio.currentSrc,
      'audioVolume': output.audio.volume.toStringAsFixed(3),
      'audioMuted': output.audio.muted,
      'context': webAudio ? output.context.state : 'none',
      'gain': webAudio
          ? output.gainValue.toStringAsFixed(3)
          : output.audio.volume.toStringAsFixed(3),
      'topology': webAudio
          ? output.outputTopology
          : 'htmlAudioElement>browserMediaOutput',
      'sourceToGain': webAudio,
      'gainToDestination': webAudio,
    });
  }

  void _scheduleMediaTimeSamples(_ActiveSound entry, [int index = 0]) {
    // The analyser snapshot must be correlated with media time, not request
    // time. A short bounded sequence captures attack, peak, and decay without
    // changing or replaying the diagnostic sound.
    const interval = Duration(milliseconds: 40);
    const maximumSamples = 24;
    Future<void>.delayed(index == 0 ? Duration.zero : interval).then((_) {
      if (!_active.contains(entry) || index >= maximumSamples) return;
      unawaited(_recordPlaybackSample(entry, index));
      if (!entry.output.audio.ended) {
        _scheduleMediaTimeSamples(entry, index + 1);
      }
    });
  }

  Future<void> _recordPlaybackSample(
    _ActiveSound entry,
    int sampleIndex,
  ) async {
    final audio = entry.output.audio;
    final output = entry.output;
    const windowSeconds = .024;
    final mediaTime = audio.currentTime;
    final signalLevels = output is _WebAudioGainOutput
        ? output.signalLevels()
        : const <String, Object>{'signalDiagnostics': false};
    final decodedFuture = entry.decodedSignal;
    final decoded = decodedFuture == null ? null : await decodedFuture;
    final sourceWindow = decoded?.windowAt(mediaTime, windowSeconds);
    final gain = output is _WebAudioGainOutput
        ? output.gainValue
        : audio.volume;
    final gainComparison = _gainComparison(
      signalLevels['preGain'],
      signalLevels['postGain'],
      gain,
    );
    final common = <String, Object>{
      'sound': entry.sound.name,
      'outputId': entry.outputId,
      'sampleIndex': sampleIndex,
      'measuredAtUtc': DateTime.now().toUtc().toIso8601String(),
      'mediaTime': mediaTime.toStringAsFixed(4),
      'measurementWindowMs': (windowSeconds * 1000).round(),
      'sourceWindow': sourceWindow ?? const {'available': 'pendingOrFailed'},
      'paused': audio.paused,
      'ended': audio.ended,
      'readyState': audio.readyState,
      'effectiveGain': gain.toStringAsFixed(4),
      'context': output is _WebAudioGainOutput ? output.context.state : 'none',
      'topology': output is _WebAudioGainOutput
          ? output.outputTopology
          : 'htmlAudioElement>browserMediaOutput',
      ...signalLevels,
      'gainComparison': gainComparison,
    };
    TouchRippleAudioDiagnostics.record('MEDIA_TIME_SIGNAL_SAMPLE', common);
  }

  Map<String, String> _gainComparison(
    Object? preGain,
    Object? postGain,
    double gain,
  ) {
    if (preGain is! Map<String, String> || postGain is! Map<String, String>) {
      return const {'status': 'notWebAudio'};
    }
    final preRms = double.tryParse(preGain['rms'] ?? '');
    final postRms = double.tryParse(postGain['rms'] ?? '');
    if (preRms == null || postRms == null || preRms < .01) {
      return const {
        'status': 'insufficientPreGainSignal',
        'note': 'byte analyser quantization or a quiet source window',
      };
    }
    final observed = postRms / preRms;
    return {
      'status': 'comparable',
      'expectedLinearRatio': gain.toStringAsFixed(4),
      'observedRmsRatio': observed.toStringAsFixed(4),
      'difference': (observed - gain).toStringAsFixed(4),
    };
  }

  int _outputIdFor(TouchFeedbackAudioOutput output) {
    final outputId = _outputIds.putIfAbsent(output, () => _nextOutputId++);
    _audioOutputIds[output.audio] = outputId;
    return outputId;
  }

  Future<_DecodedSignalDiagnostics?> _inspectSignal(
    TouchFeedbackSound sound,
  ) async {
    AudioContext? decoder;
    try {
      final response = await _fetchAudio(
        Uri.base.resolve(_assetUrl(sound)).toString().toJS,
      ).toDart;
      if (!response.ok.toDart) {
        TouchRippleAudioDiagnostics.record('SIGNAL_FETCH_FAILED', {
          'sound': sound.name,
          'status': response.status.toDartInt,
        });
        return null;
      }
      final bytes = await response.arrayBuffer().toDart;
      decoder = AudioContext();
      final decoded = await decoder.decodeAudioData(bytes).toDart;
      final channels = <typed_data.Float32List>[];
      var peak = 0.0;
      var squared = 0.0;
      var firstAudible = decoded.length;
      for (var channel = 0; channel < decoded.numberOfChannels; channel++) {
        final samples = typed_data.Float32List(decoded.length);
        decoded.copyFromChannel(samples.toJS, channel);
        channels.add(samples);
        for (var index = 0; index < samples.length; index++) {
          final value = samples[index].abs();
          if (value > peak) peak = value;
          squared += value * value;
          if (firstAudible == decoded.length && value >= .002) {
            firstAudible = index;
          }
        }
      }
      TouchRippleAudioDiagnostics.record('SIGNAL_DECODED', {
        'sound': sound.name,
        'channels': decoded.numberOfChannels,
        'sampleRate': decoded.sampleRate.toStringAsFixed(0),
        'duration': decoded.duration.toStringAsFixed(3),
        'peak': peak.toStringAsFixed(4),
        'rms': sqrt(
          squared / (decoded.length * channels.length),
        ).toStringAsFixed(4),
        'leadingSignal': firstAudible == decoded.length
            ? 'none'
            : (firstAudible / decoded.sampleRate).toStringAsFixed(3),
      });
      return _DecodedSignalDiagnostics(
        channels: channels,
        sampleRate: decoded.sampleRate,
        duration: decoded.duration,
      );
    } catch (error) {
      TouchRippleAudioDiagnostics.record('SIGNAL_DECODE_FAILED', {
        'sound': sound.name,
        'errorType': error.runtimeType,
        'error': error,
      });
      return null;
    } finally {
      final context = decoder;
      if (context != null) {
        unawaited(
          context.close().toDart.then<void>((_) {}, onError: (_, _) {}),
        );
      }
    }
  }

  void _observeMedia(TouchFeedbackSound sound, HTMLAudioElement audio) {
    if (!TouchRippleAudioDiagnostics.enabled) return;
    void record(String event) => TouchRippleAudioDiagnostics.record(event, {
      'sound': sound.name,
      'outputId': _audioOutputIds[audio] ?? 'unassigned',
      'asset': _assetUrl(sound),
      'audioSrc': audio.currentSrc.isEmpty ? audio.src : audio.currentSrc,
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
    for (final playback in List<_BufferDiagnosticPlayback>.of(
      _bufferDiagnostics,
    )) {
      _removeBufferDiagnostic(playback);
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

/// Builds the one-shot source used solely by the opt-in diagnostic route.
/// Exposed for the browser regression test; normal semantic playback never
/// calls this helper.
@visibleForTesting
AudioBufferSourceNode createAudioBufferDiagnosticSource({
  required AudioContext context,
  required AudioBuffer buffer,
  required GainNode gain,
  AnalyserNode? preGainAnalyser,
  AnalyserNode? postGainAnalyser,
}) {
  final source = context.createBufferSource()..buffer = buffer;
  if (preGainAnalyser != null && postGainAnalyser != null) {
    source.connect(preGainAnalyser);
    preGainAnalyser.connect(gain);
    gain.connect(postGainAnalyser);
    postGainAnalyser.connect(context.destination);
  } else {
    source.connect(gain);
    gain.connect(context.destination);
  }
  return source;
}

class _DecodedSignalDiagnostics {
  const _DecodedSignalDiagnostics({
    required this.channels,
    required this.sampleRate,
    required this.duration,
  });

  final List<typed_data.Float32List> channels;
  final double sampleRate;
  final double duration;

  Map<String, String> windowAt(double mediaTime, double windowSeconds) {
    final center = mediaTime.clamp(0, duration).toDouble();
    final frameCount = (windowSeconds * sampleRate).round().clamp(
      1,
      channels.first.length,
    );
    final centerFrame = (center * sampleRate).round();
    final start = (centerFrame - frameCount ~/ 2).clamp(
      0,
      channels.first.length - frameCount,
    );
    var peak = 0.0;
    var squared = 0.0;
    for (final channel in channels) {
      for (var index = start; index < start + frameCount; index++) {
        final value = channel[index];
        final amplitude = value.abs();
        if (amplitude > peak) peak = amplitude;
        squared += value * value;
      }
    }
    final sampleCount = frameCount * channels.length;
    return {
      'available': 'true',
      'windowStart': (start / sampleRate).toStringAsFixed(4),
      'windowEnd': ((start + frameCount) / sampleRate).toStringAsFixed(4),
      'peak': peak.toStringAsFixed(5),
      'rms': sqrt(squared / sampleCount).toStringAsFixed(5),
      'channels': channels.length.toString(),
    };
  }
}

class _DiagnosticAudioBuffer {
  const _DiagnosticAudioBuffer(this.buffer, this.description);

  final AudioBuffer buffer;
  final Map<String, String> description;
}

class _BufferDiagnosticPlayback {
  _BufferDiagnosticPlayback({
    required this.context,
    required this.source,
    required this.gain,
    required this.preGainAnalyser,
    required this.postGainAnalyser,
    required this.sound,
    required this.sourceDescription,
  });

  final AudioContext context;
  final AudioBufferSourceNode source;
  final GainNode gain;
  final AnalyserNode? preGainAnalyser;
  final AnalyserNode? postGainAnalyser;
  final TouchFeedbackSound sound;
  final Map<String, String> sourceDescription;
  JSFunction? ended;
  double startedAt = 0;

  String get outputTopology => preGainAnalyser == null
      ? 'audioBufferSource>gain>destination'
      : 'audioBufferSource>preGainAnalyser>gain>postGainAnalyser>destination';

  void dispose() {
    final listener = ended;
    if (listener != null) source.removeEventListener('ended', listener);
    try {
      source.stop();
    } catch (_) {
      // A one-shot source that already ended cannot be stopped again.
    }
    source.disconnect();
    gain.disconnect();
    preGainAnalyser?.disconnect();
    postGainAnalyser?.disconnect();
  }
}

class _ActiveSound {
  _ActiveSound(this.sound, this.output, this.outputId, {this.decodedSignal});

  final TouchFeedbackSound sound;
  final TouchFeedbackAudioOutput output;
  final int outputId;
  final Future<_DecodedSignalDiagnostics?>? decodedSignal;
  JSFunction? ended;
  JSFunction? error;
}

class _WebAudioGainOutput implements TouchFeedbackAudioOutput {
  _WebAudioGainOutput(
    this.audio,
    this.context, {
    required bool enableSignalDiagnostics,
  }) : _source = context.createMediaElementSource(audio),
       _gain = context.createGain(),
       _preGainAnalyser = enableSignalDiagnostics
           ? context.createAnalyser()
           : null,
       _postGainAnalyser = enableSignalDiagnostics
           ? context.createAnalyser()
           : null {
    // MediaElement volume is not continuously controllable on mobile WebKit.
    // Keep it neutral and route the released asset level through Web Audio.
    audio.volume = 1;
    _preGainAnalyser?.fftSize = 256;
    _postGainAnalyser?.fftSize = 256;
    final preGainAnalyser = _preGainAnalyser;
    final postGainAnalyser = _postGainAnalyser;
    if (preGainAnalyser != null && postGainAnalyser != null) {
      _source.connect(preGainAnalyser);
      preGainAnalyser.connect(_gain);
      _gain.connect(postGainAnalyser);
      postGainAnalyser.connect(context.destination);
    } else {
      _source.connect(_gain);
      _gain.connect(context.destination);
    }
  }

  @override
  final HTMLAudioElement audio;
  final AudioContext context;
  final MediaElementAudioSourceNode _source;
  final GainNode _gain;
  final AnalyserNode? _preGainAnalyser;
  final AnalyserNode? _postGainAnalyser;

  double get gainValue => _gain.gain.value;

  String get outputTopology => _preGainAnalyser == null
      ? 'mediaElementSource>gain>destination'
      : 'mediaElementSource>preGainAnalyser>gain>postGainAnalyser>destination';

  Map<String, Object> signalLevels() => {
    'signalDiagnostics': _preGainAnalyser != null,
    'preGain': _signalLevel(_preGainAnalyser),
    'postGain': _signalLevel(_postGainAnalyser),
  };

  Map<String, String> _signalLevel(AnalyserNode? analyser) {
    if (analyser == null) return const {'available': 'false'};
    final samples = typed_data.Uint8List(analyser.fftSize);
    analyser.getByteTimeDomainData(samples.toJS);
    var peak = 0.0;
    var squared = 0.0;
    for (final byte in samples) {
      final amplitude = (byte - 128).abs() / 128;
      if (amplitude > peak) peak = amplitude;
      squared += amplitude * amplitude;
    }
    return {
      'available': 'true',
      'peak': peak.toStringAsFixed(4),
      'rms': sqrt(squared / samples.length).toStringAsFixed(4),
    };
  }

  @override
  void setGain(double gain) => _gain.gain.value = gain.clamp(0, 1);

  @override
  void dispose() {
    _source.disconnect();
    _gain.disconnect();
    _preGainAnalyser?.disconnect();
    _postGainAnalyser?.disconnect();
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

@JS('fetch')
external JSPromise<_AudioDiagnosticResponse> _fetchAudio(JSString url);

extension type _AudioDiagnosticResponse._(JSObject _) implements JSObject {
  external JSBoolean get ok;
  external JSNumber get status;
  external JSPromise<JSArrayBuffer> arrayBuffer();
}
