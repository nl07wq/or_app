@TestOn('browser')
library;

import 'dart:js_interop';

import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/services/device_settings_controller.dart';
import 'package:or_app/core/services/touch_ripple_audio.dart';
import 'package:or_app/core/services/touch_ripple_audio_web.dart';
import 'package:web/web.dart';

void main() {
  test(
    'AudioBuffer diagnostics use a distinct, one-shot source route',
    () async {
      final context = AudioContext();
      final buffer = AudioBuffer(
        AudioBufferOptions(numberOfChannels: 1, length: 128, sampleRate: 44100),
      );
      final gain = context.createGain()..gain.value = .17;
      final source = createAudioBufferDiagnosticSource(
        context: context,
        buffer: buffer,
        gain: gain,
      );
      final secondGain = context.createGain()..gain.value = .17;
      final secondSource = createAudioBufferDiagnosticSource(
        context: context,
        buffer: buffer,
        gain: secondGain,
      );
      try {
        expect(
          TouchFeedbackDiagnosticRoute.values,
          contains(TouchFeedbackDiagnosticRoute.audioBuffer),
        );
        expect(source.buffer, isNotNull);
        expect(source.buffer!.length, 128);
        expect(identical(source, secondSource), isFalse);
        expect(identical(source.buffer, secondSource.buffer), isTrue);
        expect(gain.gain.value, closeTo(.17, .000001));
      } finally {
        source.disconnect();
        secondSource.disconnect();
        gain.disconnect();
        secondGain.disconnect();
        await context.close().toDart;
      }
    },
  );

  test('production player sends continuous gain to browser output', () async {
    final controller = DeviceSettingsController.instance;
    final original = controller.value;
    controller.resetForTesting(const DeviceSettings());
    final outputs = <TouchFeedbackSound, _RecordingAudioOutput>{};
    final audio = createPlatformTouchRippleAudio(
      audioFactory: (_) => HTMLAudioElement(),
      outputFactory: (sound, element) {
        final output = _RecordingAudioOutput(element);
        outputs[sound] = output;
        return output;
      },
    );
    try {
      audio.prepare();
      // Preparing retains preloaded media without creating production Web
      // Audio output. Injected outputs remain observable for gain assertions.
      expect(outputs[TouchFeedbackSound.water]!.gain, .28);
      expect(outputs[TouchFeedbackSound.success]!.gain, .34);
      expect(outputs[TouchFeedbackSound.failure]!.gain, .34);
      expect(outputs[TouchFeedbackSound.exit]!.gain, .34);
      for (final master in [1.0, .75, .5, .25, .1, .01]) {
        controller.update(
          controller.value.copyWith(masterVolume: master, commandVolume: 1),
        );
        audio.playFromUserGesture(TouchFeedbackSound.success);
        expect(
          outputs[TouchFeedbackSound.success]!.gain,
          closeTo(touchRippleSemanticBaseVolume * master, .000001),
          reason: 'MASTER $master must reach the output as continuous gain',
        );
      }

      controller.update(
        controller.value.copyWith(masterVolume: .5, commandVolume: .5),
      );
      audio.playFromUserGesture(TouchFeedbackSound.success);
      expect(outputs[TouchFeedbackSound.success]!.gain, closeTo(.085, .000001));
      controller.update(controller.value.copyWith(commandVolume: .4));
      expect(outputs[TouchFeedbackSound.success]!.gain, closeTo(.068, .000001));
      controller.update(
        controller.value.copyWith(masterVolume: .25, commandVolume: .2),
      );
      expect(outputs[TouchFeedbackSound.success]!.gain, closeTo(.017, .000001));

      controller.update(
        controller.value.copyWith(masterVolume: .5, ambientVolume: 1),
      );
      audio.playFromUserGesture(TouchFeedbackSound.water);
      controller.update(controller.value.copyWith(ambientVolume: .5));
      // A rejected passive request was never added to the active pool.
      expect(outputs[TouchFeedbackSound.water]!.gain, .14);
      audio.playFromUserGesture(TouchFeedbackSound.exit);
      controller.update(
        controller.value.copyWith(exitVolume: .5, commandVolume: .2),
      );
      expect(outputs[TouchFeedbackSound.exit]!.gain, closeTo(.085, .000001));
      // The replaced COMMAND is no longer updated as an active sound.
      expect(outputs[TouchFeedbackSound.success]!.gain, closeTo(.017, .000001));
      controller.update(controller.value.copyWith(muted: true));
      expect(outputs[TouchFeedbackSound.exit]!.gain, 0);
      controller.update(controller.value.copyWith(muted: false));
      audio.playFromUserGesture(TouchFeedbackSound.exit);
      expect(outputs[TouchFeedbackSound.exit]!.gain, closeTo(.085, .000001));
      // Empty sources reject playback. After cleanup the pool accepts ambient.
      await Future<void>.delayed(const Duration(milliseconds: 100));
      audio.playFromUserGesture(TouchFeedbackSound.water);
      expect(outputs[TouchFeedbackSound.water]!.gain, closeTo(.07, .000001));

      controller.update(controller.value.copyWith(ambientVolume: 0));
      expect(outputs[TouchFeedbackSound.water]!.gain, 0);
      controller.update(
        controller.value.copyWith(masterVolume: .5, ambientVolume: .5),
      );
      audio.playFromUserGesture(TouchFeedbackSound.water);
      controller.update(controller.value.copyWith(masterVolume: 0));
      expect(outputs[TouchFeedbackSound.water]!.gain, 0);
    } finally {
      audio.dispose();
      expect(outputs.values.every((output) => output.disposed), isTrue);
      controller.resetForTesting(original);
    }
  });

  test(
    'failed REJECTED media is discarded before the next user gesture',
    () async {
      final controller = DeviceSettingsController.instance;
      final original = controller.value;
      controller.resetForTesting(const DeviceSettings());
      final outputs = <TouchFeedbackSound, List<_RecordingAudioOutput>>{};
      final audio = createPlatformTouchRippleAudio(
        audioFactory: (_) => HTMLAudioElement(),
        outputFactory: (sound, element) {
          final output = _RecordingAudioOutput(element);
          outputs.putIfAbsent(sound, () => []).add(output);
          return output;
        },
      );
      try {
        audio.prepare();
        final first = outputs[TouchFeedbackSound.failure]!.single;
        audio.playFromUserGesture(TouchFeedbackSound.failure);
        first.audio.dispatchEvent(Event('error'));
        audio.playFromUserGesture(TouchFeedbackSound.failure);

        expect(outputs[TouchFeedbackSound.failure], hasLength(2));
        expect(first.disposed, isTrue);
      } finally {
        audio.dispose();
        controller.resetForTesting(original);
      }
    },
  );

  test('COMMAND retains its MediaElement Web Audio production route', () {
    final controller = DeviceSettingsController.instance;
    final original = controller.value;
    controller.resetForTesting(const DeviceSettings());
    var browserOutputCreations = 0;
    final audio = createPlatformTouchRippleAudio(
      audioFactory: (_) => HTMLAudioElement(),
      browserOutputFactory: (element) {
        browserOutputCreations++;
        return _RecordingAudioOutput(element);
      },
    );
    try {
      audio.prepare();
      expect(browserOutputCreations, 0);

      audio.playFromUserGesture(TouchFeedbackSound.success);

      expect(browserOutputCreations, 1);
    } finally {
      audio.dispose();
      controller.resetForTesting(original);
    }
  });

  test(
    'production REJECTED selects the cached one-shot buffer route',
    () async {
      final controller = DeviceSettingsController.instance;
      final original = controller.value;
      controller.resetForTesting(const DeviceSettings());
      TouchRippleAudioDiagnostics.enabledForTesting = true;
      var mediaOutputCreations = 0;
      final audio = createPlatformTouchRippleAudio(
        audioFactory: (_) => HTMLAudioElement(),
        browserOutputFactory: (element) {
          mediaOutputCreations++;
          return _RecordingAudioOutput(element);
        },
      );
      try {
        audio.prepare();
        audio.playFromUserGesture(TouchFeedbackSound.failure);

        expect(
          TouchRippleAudioDiagnostics.report,
          contains('AUDIO_BUFFER_ROUTE_REQUESTED sound=failure'),
        );
        expect(
          mediaOutputCreations,
          0,
          reason: 'REJECTED must not create a MediaElement Web Audio output',
        );
        await Future<void>.delayed(const Duration(milliseconds: 10));
      } finally {
        audio.dispose();
        TouchRippleAudioDiagnostics.enabledForTesting = null;
        TouchRippleAudioDiagnostics.clear();
        controller.resetForTesting(original);
      }
    },
  );

  test(
    'COMMAND AudioBuffer is available only through the diagnostic route',
    () {
      final controller = DeviceSettingsController.instance;
      final original = controller.value;
      controller.resetForTesting(const DeviceSettings());
      TouchRippleAudioDiagnostics.enabledForTesting = true;
      final audio = createPlatformTouchRippleAudio(
        audioFactory: (_) => HTMLAudioElement(),
        browserOutputFactory: _RecordingAudioOutput.new,
      );
      try {
        audio.prepare();
        (audio as TouchRippleAudioDiagnosticPlayer)
            .playDiagnosticFromUserGesture(
              TouchFeedbackSound.success,
              TouchFeedbackDiagnosticRoute.audioBuffer,
              .34,
            );
        expect(
          TouchRippleAudioDiagnostics.report,
          contains('AUDIO_BUFFER_ROUTE_REQUESTED sound=success'),
        );
      } finally {
        audio.dispose();
        TouchRippleAudioDiagnostics.enabledForTesting = null;
        TouchRippleAudioDiagnostics.clear();
        controller.resetForTesting(original);
      }
    },
  );

  test('diagnostic comparison keeps COMMAND and REJECTED at one gain', () {
    final controller = DeviceSettingsController.instance;
    final original = controller.value;
    controller.resetForTesting(const DeviceSettings());
    final outputs = <TouchFeedbackSound, _RecordingAudioOutput>{};
    final elements = <TouchFeedbackSound, List<HTMLAudioElement>>{};
    final audio = createPlatformTouchRippleAudio(
      audioFactory: (sound) {
        final element = HTMLAudioElement();
        elements.putIfAbsent(sound, () => []).add(element);
        return element;
      },
      outputFactory: (sound, element) {
        final output = _RecordingAudioOutput(element);
        outputs[sound] = output;
        return output;
      },
    );
    try {
      TouchRippleAudioDiagnostics.enabledForTesting = true;
      audio.prepare();
      final diagnostic = audio as TouchRippleAudioDiagnosticPlayer;
      const comparisonGain = .17;

      diagnostic.playDiagnosticFromUserGesture(
        TouchFeedbackSound.success,
        TouchFeedbackDiagnosticRoute.webAudio,
        comparisonGain,
      );
      diagnostic.playDiagnosticFromUserGesture(
        TouchFeedbackSound.failure,
        TouchFeedbackDiagnosticRoute.webAudio,
        comparisonGain,
      );
      expect(outputs[TouchFeedbackSound.success]!.gain, comparisonGain);
      expect(outputs[TouchFeedbackSound.failure]!.gain, comparisonGain);

      diagnostic.playDiagnosticFromUserGesture(
        TouchFeedbackSound.success,
        TouchFeedbackDiagnosticRoute.directHtml,
        comparisonGain,
      );
      diagnostic.playDiagnosticFromUserGesture(
        TouchFeedbackSound.failure,
        TouchFeedbackDiagnosticRoute.directHtml,
        comparisonGain,
      );
      expect(elements[TouchFeedbackSound.success]!.last.volume, comparisonGain);
      expect(elements[TouchFeedbackSound.failure]!.last.volume, comparisonGain);
    } finally {
      audio.dispose();
      TouchRippleAudioDiagnostics.enabledForTesting = null;
      TouchRippleAudioDiagnostics.clear();
      controller.resetForTesting(original);
    }
  });
}

class _RecordingAudioOutput implements TouchFeedbackAudioOutput {
  _RecordingAudioOutput(this.audio);

  @override
  final HTMLAudioElement audio;
  double gain = 0;
  bool disposed = false;

  @override
  void setGain(double gain) => this.gain = gain;

  @override
  void dispose() => disposed = true;
}
