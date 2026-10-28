import 'package:flutter/foundation.dart';

import 'touch_ripple_audio_stub.dart'
    if (dart.library.html) 'touch_ripple_audio_web.dart';
import 'device_settings_controller.dart';

const touchRippleAudioAssetUrl =
    'assets/assets/audio/touch/Water_Drop02-1(Low-Reverb).mp3';
const touchRippleSuccessAudioAssetUrl =
    'assets/assets/audio/touch/Cyber03-1.mp3';
// GitHub Pages does not serve the original Japanese filenames reliably from
// direct HTML audio URLs. These aliases are byte-for-byte copies of the
// credited source assets and keep semantic delivery independent of URL
// encoding.
const touchRippleFailureAudioAssetUrl =
    'assets/assets/audio/touch/cancel-1.mp3';
const touchRippleExitAudioAssetUrl = 'assets/assets/audio/touch/button-09.mp3';
const touchRipplePageFlipAudioAssetUrl =
    'assets/assets/audio/touch/Book01-1(Flip).mp3';
const touchRippleCursorAudioAssetUrl =
    'assets/assets/audio/touch/Cursor_sound.mp3';
const touchRippleEnterAudioAssetUrl =
    'assets/assets/audio/touch/Enter_sound.mp3';

enum TouchFeedbackSound {
  water,
  success,
  failure,
  exit,
  pageFlip,
  cursor,
  enter,
}

@immutable
class TouchFeedbackSoundInventoryEntry {
  const TouchFeedbackSoundInventoryEntry({
    required this.semanticName,
    required this.sound,
    required this.setting,
    required this.asset,
    required this.channel,
  });

  final String semanticName;
  final TouchFeedbackSound sound;
  final DeviceFeedbackSound setting;
  final String asset;
  final DeviceFeedbackChannel channel;
}

/// The complete user-facing semantic SE inventory. Multiple interaction
/// families may map to one item; entries intentionally describe sound assets,
/// not fabricated per-screen audio variants.
const touchFeedbackSoundInventory = <TouchFeedbackSoundInventoryEntry>[
  TouchFeedbackSoundInventoryEntry(
    semanticName: 'WATER',
    sound: TouchFeedbackSound.water,
    setting: DeviceFeedbackSound.water,
    asset: touchRippleAudioAssetUrl,
    channel: DeviceFeedbackChannel.ambient,
  ),
  TouchFeedbackSoundInventoryEntry(
    semanticName: 'COMMAND / ACCEPTED',
    sound: TouchFeedbackSound.success,
    setting: DeviceFeedbackSound.accepted,
    asset: touchRippleSuccessAudioAssetUrl,
    channel: DeviceFeedbackChannel.command,
  ),
  TouchFeedbackSoundInventoryEntry(
    semanticName: 'REJECTED',
    sound: TouchFeedbackSound.failure,
    setting: DeviceFeedbackSound.rejected,
    asset: touchRippleFailureAudioAssetUrl,
    channel: DeviceFeedbackChannel.rejected,
  ),
  TouchFeedbackSoundInventoryEntry(
    semanticName: 'EXIT',
    sound: TouchFeedbackSound.exit,
    setting: DeviceFeedbackSound.exit,
    asset: touchRippleExitAudioAssetUrl,
    channel: DeviceFeedbackChannel.exit,
  ),
  TouchFeedbackSoundInventoryEntry(
    semanticName: 'PAGE FLIP',
    sound: TouchFeedbackSound.pageFlip,
    setting: DeviceFeedbackSound.pageFlip,
    asset: touchRipplePageFlipAudioAssetUrl,
    channel: DeviceFeedbackChannel.command,
  ),
  TouchFeedbackSoundInventoryEntry(
    semanticName: 'CURSOR / SELECTION',
    sound: TouchFeedbackSound.cursor,
    setting: DeviceFeedbackSound.cursor,
    asset: touchRippleCursorAudioAssetUrl,
    channel: DeviceFeedbackChannel.command,
  ),
  TouchFeedbackSoundInventoryEntry(
    semanticName: 'ENTER / BOOT',
    sound: TouchFeedbackSound.enter,
    setting: DeviceFeedbackSound.enter,
    asset: touchRippleEnterAudioAssetUrl,
    channel: DeviceFeedbackChannel.command,
  ),
];

/// Diagnostic-only output routes for comparing the same REJECTED asset on a
/// physical browser. These are never selected by normal application feedback.
enum TouchFeedbackDiagnosticRoute { webAudio, audioBuffer, directHtml }

/// Opt-in, copyable event trace for investigating browser media behavior on a
/// physical device. It is inert unless the public URL includes
/// `?audioDiagnostics=true`.
class TouchRippleAudioDiagnostics {
  TouchRippleAudioDiagnostics._();

  // Four independently-run route tests each emit media, output, signal, and
  // promise events. Keep a complete comparison available for copying.
  static const _maximumEntries = 192;
  static final entries = ValueNotifier<List<String>>(const []);

  @visibleForTesting
  static bool? enabledForTesting;

  static bool get enabled =>
      enabledForTesting ??
      Uri.base.queryParameters['audioDiagnostics'] == 'true';

  static void record(String event, [Map<String, Object?> fields = const {}]) {
    if (!enabled) return;
    final detail = fields.entries
        .map((entry) => '${entry.key}=${entry.value}')
        .join(' ');
    final next = [
      ...entries.value,
      '${DateTime.now().toUtc().toIso8601String()} $event${detail.isEmpty ? '' : ' $detail'}',
    ];
    entries.value = List.unmodifiable(
      next.length > _maximumEntries
          ? next.sublist(next.length - _maximumEntries)
          : next,
    );
  }

  static String get report => entries.value.join('\n');

  static void clear() => entries.value = const [];
}

const touchRippleWaterBaseVolume = .28;
const touchRippleSemanticBaseVolume = .34;

double touchFeedbackBaseVolume(TouchFeedbackSound sound) =>
    sound == TouchFeedbackSound.water
    ? touchRippleWaterBaseVolume
    : touchRippleSemanticBaseVolume;

double touchFeedbackEffectiveVolume(
  TouchFeedbackSound sound,
  DeviceSettings settings,
) =>
    touchFeedbackBaseVolume(sound) *
    settings.normalized().volumeMultiplierFor(switch (sound) {
      TouchFeedbackSound.water => DeviceFeedbackChannel.ambient,
      TouchFeedbackSound.success => DeviceFeedbackChannel.command,
      TouchFeedbackSound.failure => DeviceFeedbackChannel.rejected,
      TouchFeedbackSound.exit => DeviceFeedbackChannel.exit,
      // Report navigation remains a semantic COMMAND event while retaining a
      // separate per-sound multiplier in Device Settings.
      TouchFeedbackSound.pageFlip => DeviceFeedbackChannel.command,
      // Selection and boot-enter remain COMMAND events while retaining their
      // own per-sound multipliers in Device Settings.
      TouchFeedbackSound.cursor => DeviceFeedbackChannel.command,
      TouchFeedbackSound.enter => DeviceFeedbackChannel.command,
    }) *
    settings.soundVolumeMultiplierFor(switch (sound) {
      TouchFeedbackSound.water => DeviceFeedbackSound.water,
      TouchFeedbackSound.success => DeviceFeedbackSound.accepted,
      TouchFeedbackSound.failure => DeviceFeedbackSound.rejected,
      TouchFeedbackSound.exit => DeviceFeedbackSound.exit,
      TouchFeedbackSound.pageFlip => DeviceFeedbackSound.pageFlip,
      TouchFeedbackSound.cursor => DeviceFeedbackSound.cursor,
      TouchFeedbackSound.enter => DeviceFeedbackSound.enter,
    });

abstract interface class TouchRippleAudio {
  void prepare();
  void playFromUserGesture(TouchFeedbackSound sound);
  void dispose();
}

/// Implemented only by the web player. Keeping this separate ensures the
/// diagnostic route is unavailable to normal feedback and test doubles.
abstract interface class TouchRippleAudioDiagnosticPlayer {
  /// Plays one explicitly selected comparison route. [effectiveVolume] is
  /// resolved by the diagnostics UI once so every cross-test uses precisely
  /// the same gain without changing normal production sound settings.
  void playDiagnosticFromUserGesture(
    TouchFeedbackSound sound,
    TouchFeedbackDiagnosticRoute route,
    double effectiveVolume,
  );
}

TouchRippleAudio createTouchRippleAudio() => createPlatformTouchRippleAudio();
