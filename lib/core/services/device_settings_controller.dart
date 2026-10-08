import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/notifications/models/notification_configuration.dart';

/// The explicit application preference for motion. [system] follows the
/// platform, while [on] and [off] are explicit application overrides.
enum ReducedMotionPreference { system, on, off }

/// MID-REAR is the only user-adjustable Command Center Data Rain layer.
/// The exact 390px allocations are deliberately part of the preference
/// contract so backup/restore preserves the requested visual comparison.
enum CommandCenterMidRearDensity {
  low(12),
  medium(21),
  high(31);

  const CommandCenterMidRearDensity(this.streamsAt390);

  final int streamsAt390;
}

enum DeviceFeedbackChannel { command, exit, rejected, ambient }

/// OR-APP-local presentation and feedback preferences.
///
/// The defaults intentionally multiply the released feedback levels by 1.0
/// and leave every existing visual effect enabled.
@immutable
class DeviceSettings {
  const DeviceSettings({
    this.masterVolume = 1,
    this.muted = false,
    this.commandVolume = 1,
    this.exitVolume = 1,
    this.rejectedVolume = 1,
    this.ambientVolume = 1,
    this.brightness = 1,
    this.rippleEnabled = true,
    this.ambientCircuitEnabled = true,
    this.ambientProcessingEnabled = true,
    this.commandCenterMidRearDensity = CommandCenterMidRearDensity.low,
    this.ambientKineticFieldEnabled = true,
    this.ambientWildlifeEnabled = true,
    this.reducedMotion = ReducedMotionPreference.system,
    this.notificationPrivacyMode = NotificationPrivacyMode.contentHidden,
  });

  static const minimumBrightness = .35;

  final double masterVolume;
  final bool muted;
  final double commandVolume;
  final double exitVolume;
  final double rejectedVolume;
  final double ambientVolume;
  final double brightness;
  final bool rippleEnabled;
  final bool ambientCircuitEnabled;
  final bool ambientProcessingEnabled;
  final CommandCenterMidRearDensity commandCenterMidRearDensity;
  final bool ambientKineticFieldEnabled;
  final bool ambientWildlifeEnabled;
  final ReducedMotionPreference reducedMotion;
  final NotificationPrivacyMode notificationPrivacyMode;

  double volumeMultiplierFor(DeviceFeedbackChannel channel) {
    if (muted) return 0;
    final roleVolume = switch (channel) {
      DeviceFeedbackChannel.ambient => ambientVolume,
      DeviceFeedbackChannel.command => commandVolume,
      DeviceFeedbackChannel.exit => exitVolume,
      DeviceFeedbackChannel.rejected => rejectedVolume,
    };
    return masterVolume * roleVolume;
  }

  /// Resolves the tri-state preference used by every OR-APP visual effect.
  bool resolvesReducedMotion(bool platformReducedMotion) =>
      switch (reducedMotion) {
        ReducedMotionPreference.system => platformReducedMotion,
        ReducedMotionPreference.on => true,
        ReducedMotionPreference.off => false,
      };

  DeviceSettings copyWith({
    double? masterVolume,
    bool? muted,
    double? commandVolume,
    double? exitVolume,
    double? rejectedVolume,
    double? ambientVolume,
    double? brightness,
    bool? rippleEnabled,
    bool? ambientCircuitEnabled,
    bool? ambientProcessingEnabled,
    CommandCenterMidRearDensity? commandCenterMidRearDensity,
    bool? ambientKineticFieldEnabled,
    bool? ambientWildlifeEnabled,
    ReducedMotionPreference? reducedMotion,
    NotificationPrivacyMode? notificationPrivacyMode,
  }) => DeviceSettings(
    masterVolume: masterVolume ?? this.masterVolume,
    muted: muted ?? this.muted,
    commandVolume: commandVolume ?? this.commandVolume,
    exitVolume: exitVolume ?? this.exitVolume,
    rejectedVolume: rejectedVolume ?? this.rejectedVolume,
    ambientVolume: ambientVolume ?? this.ambientVolume,
    brightness: brightness ?? this.brightness,
    rippleEnabled: rippleEnabled ?? this.rippleEnabled,
    ambientCircuitEnabled: ambientCircuitEnabled ?? this.ambientCircuitEnabled,
    ambientProcessingEnabled:
        ambientProcessingEnabled ?? this.ambientProcessingEnabled,
    commandCenterMidRearDensity:
        commandCenterMidRearDensity ?? this.commandCenterMidRearDensity,
    ambientKineticFieldEnabled:
        ambientKineticFieldEnabled ?? this.ambientKineticFieldEnabled,
    ambientWildlifeEnabled:
        ambientWildlifeEnabled ?? this.ambientWildlifeEnabled,
    reducedMotion: reducedMotion ?? this.reducedMotion,
    notificationPrivacyMode:
        notificationPrivacyMode ?? this.notificationPrivacyMode,
  ).normalized();

  DeviceSettings normalized() => DeviceSettings(
    masterVolume: _unit(masterVolume),
    muted: muted,
    commandVolume: _unit(commandVolume),
    exitVolume: _unit(exitVolume),
    rejectedVolume: _unit(rejectedVolume),
    ambientVolume: _unit(ambientVolume),
    brightness: _brightness(brightness),
    rippleEnabled: rippleEnabled,
    ambientCircuitEnabled: ambientCircuitEnabled,
    ambientProcessingEnabled: ambientProcessingEnabled,
    commandCenterMidRearDensity: commandCenterMidRearDensity,
    ambientKineticFieldEnabled: ambientKineticFieldEnabled,
    ambientWildlifeEnabled: ambientWildlifeEnabled,
    reducedMotion: reducedMotion,
    notificationPrivacyMode: notificationPrivacyMode,
  );

  Map<String, Object?> toJson() => {
    'masterVolume': masterVolume,
    'muted': muted,
    'commandVolume': commandVolume,
    'exitVolume': exitVolume,
    'rejectedVolume': rejectedVolume,
    'ambientVolume': ambientVolume,
    'brightness': brightness,
    'rippleEnabled': rippleEnabled,
    'ambientCircuitEnabled': ambientCircuitEnabled,
    'ambientProcessingEnabled': ambientProcessingEnabled,
    'commandCenterMidRearDensity': commandCenterMidRearDensity.name,
    'ambientKineticFieldEnabled': ambientKineticFieldEnabled,
    'ambientWildlifeEnabled': ambientWildlifeEnabled,
    'reducedMotion': reducedMotion.name,
    'notificationPrivacyMode': notificationPrivacyMode.name,
  };

  factory DeviceSettings.fromJson(Object? raw) {
    if (raw is! Map) return const DeviceSettings();
    final json = Map<Object?, Object?>.from(raw);
    double number(String key, double fallback) {
      final value = json[key];
      return value is num ? value.toDouble() : fallback;
    }

    bool flag(String key, bool fallback) {
      final value = json[key];
      return value is bool ? value : fallback;
    }

    final reducedName = json['reducedMotion'];
    ReducedMotionPreference? reducedMotion;
    for (final candidate in ReducedMotionPreference.values) {
      if (candidate.name == reducedName) {
        reducedMotion = candidate;
        break;
      }
    }
    final privacyName = json['notificationPrivacyMode'];
    NotificationPrivacyMode? notificationPrivacyMode;
    for (final candidate in NotificationPrivacyMode.values) {
      if (candidate.name == privacyName) {
        notificationPrivacyMode = candidate;
        break;
      }
    }
    final densityName = json['commandCenterMidRearDensity'];
    CommandCenterMidRearDensity? commandCenterMidRearDensity;
    for (final candidate in CommandCenterMidRearDensity.values) {
      if (candidate.name == densityName) {
        commandCenterMidRearDensity = candidate;
        break;
      }
    }
    return DeviceSettings(
      masterVolume: number('masterVolume', 1),
      muted: flag('muted', false),
      commandVolume: number('commandVolume', 1),
      exitVolume: number('exitVolume', 1),
      rejectedVolume: number('rejectedVolume', 1),
      ambientVolume: number('ambientVolume', 1),
      brightness: number('brightness', 1),
      rippleEnabled: flag('rippleEnabled', true),
      ambientCircuitEnabled: flag('ambientCircuitEnabled', true),
      ambientProcessingEnabled: flag('ambientProcessingEnabled', true),
      commandCenterMidRearDensity:
          commandCenterMidRearDensity ?? CommandCenterMidRearDensity.low,
      ambientKineticFieldEnabled: flag('ambientKineticFieldEnabled', true),
      ambientWildlifeEnabled: flag('ambientWildlifeEnabled', true),
      reducedMotion: reducedMotion ?? ReducedMotionPreference.system,
      notificationPrivacyMode:
          notificationPrivacyMode ?? NotificationPrivacyMode.contentHidden,
    ).normalized();
  }

  static double _unit(double value) =>
      value.isFinite ? value.clamp(0, 1).toDouble() : 1;
  static double _brightness(double value) =>
      value.isFinite ? value.clamp(minimumBrightness, 1).toDouble() : 1;
}

/// A small, local-only preference store.  It intentionally does not share
/// identity, health, schedule, or operation data stores.
class DeviceSettingsController extends ValueNotifier<DeviceSettings> {
  DeviceSettingsController({
    Future<SharedPreferences> Function()? preferencesLoader,
  }) : _preferencesLoader = preferencesLoader ?? SharedPreferences.getInstance,
       super(const DeviceSettings());

  static const storageKey = 'or_app_device_settings_v1';
  static final instance = DeviceSettingsController();

  final Future<SharedPreferences> Function() _preferencesLoader;
  bool _initialized = false;
  Future<void>? _initializing;
  Future<void> _writeQueue = Future.value();

  Future<void> initialize() {
    if (_initialized) return Future.value();
    return _initializing ??= _load();
  }

  Future<void> _load() async {
    try {
      final preferences = await _preferencesLoader();
      final encoded = preferences.getString(storageKey);
      if (encoded != null) value = DeviceSettings.fromJson(jsonDecode(encoded));
    } catch (_) {
      // Invalid or unavailable local preference storage must never block boot.
      value = const DeviceSettings();
    } finally {
      _initialized = true;
    }
  }

  void update(DeviceSettings next) {
    value = next.normalized();
    unawaited(_enqueuePersist(value));
  }

  Future<void> restore(Map<String, Object?> raw) async {
    value = DeviceSettings.fromJson(raw);
    await _enqueuePersist(value);
  }

  Map<String, Object?> snapshot() => value.toJson();

  Future<void> _enqueuePersist(DeviceSettings settings) {
    final write = _writeQueue.then((_) => _persist(settings));
    _writeQueue = write;
    return write;
  }

  Future<void> _persist(DeviceSettings settings) async {
    try {
      final preferences = await _preferencesLoader();
      await preferences.setString(storageKey, jsonEncode(settings.toJson()));
    } catch (_) {
      // Settings are convenience data; retain the live choice if persistence
      // is temporarily unavailable rather than failing the surrounding UI.
    }
  }

  @visibleForTesting
  void resetForTesting(DeviceSettings settings) {
    value = settings.normalized();
    _initialized = true;
  }
}
