import 'package:flutter/material.dart';

import 'package:or_app/core/services/device_settings_controller.dart';
import 'package:or_app/core/services/touch_ripple_audio.dart';
import 'package:or_app/core/theme/app_spacing.dart';
import 'package:or_app/core/widgets/global_touch_ripple.dart';
import 'package:or_app/core/widgets/operation_card.dart';
import 'package:or_app/core/widgets/section_header.dart';

class DeviceSettingsPage extends StatelessWidget {
  const DeviceSettingsPage({super.key, this.controller});

  final DeviceSettingsController? controller;

  DeviceSettingsController get _controller =>
      controller ?? DeviceSettingsController.instance;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: const ActionableBackButton(),
      title: const Text('DEVICE SETTINGS'),
    ),
    body: ValueListenableBuilder<DeviceSettings>(
      valueListenable: _controller,
      builder: (context, settings, _) => ListView(
        key: const ValueKey('device-settings-content'),
        padding: AppSpacing.cardPadding,
        children: [
          const SectionHeader(icon: Icons.volume_up_outlined, title: 'AUDIO'),
          AppSpacing.gapSM,
          OperationCard(
            child: Column(
              children: [
                _SettingsSlider(
                  label: 'MASTER SE',
                  value: settings.masterVolume,
                  onChanged: (value) => _controller.update(
                    settings.copyWith(masterVolume: value),
                  ),
                  onChangeEnd: (_) => GlobalTouchRipple.previewFeedback(
                    TouchFeedbackSound.success,
                  ),
                ),
                const Divider(),
                SwitchListTile.adaptive(
                  key: const ValueKey('device-settings-mute'),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('MUTE'),
                  subtitle: const Text('OR-APPのフィードバック音を消音します。'),
                  value: settings.muted,
                  onChanged: (value) =>
                      _controller.update(settings.copyWith(muted: value)),
                ).inputFeedback(),
                const Divider(),
                _SettingsSlider(
                  label: 'COMMAND',
                  value: settings.commandVolume,
                  onChanged: (value) => _controller.update(
                    settings.copyWith(commandVolume: value),
                  ),
                  onChangeEnd: (_) => GlobalTouchRipple.previewFeedback(
                    TouchFeedbackSound.success,
                  ),
                ),
                _SettingsSlider(
                  label: 'EXIT',
                  value: settings.exitVolume,
                  onChanged: (value) =>
                      _controller.update(settings.copyWith(exitVolume: value)),
                  onChangeEnd: (_) => GlobalTouchRipple.previewFeedback(
                    TouchFeedbackSound.exit,
                  ),
                ),
                _SettingsSlider(
                  label: 'REJECTED',
                  value: settings.rejectedVolume,
                  onChanged: (value) => _controller.update(
                    settings.copyWith(rejectedVolume: value),
                  ),
                  onChangeEnd: (_) => GlobalTouchRipple.previewFeedback(
                    TouchFeedbackSound.failure,
                  ),
                ),
                _SettingsSlider(
                  label: 'AMBIENT',
                  value: settings.ambientVolume,
                  onChanged: (value) => _controller.update(
                    settings.copyWith(ambientVolume: value),
                  ),
                  onChangeEnd: (_) => GlobalTouchRipple.previewFeedback(
                    TouchFeedbackSound.water,
                  ),
                ),
              ],
            ),
          ),
          AppSpacing.gapXL,
          const SectionHeader(
            icon: Icons.brightness_6_outlined,
            title: 'DISPLAY',
          ),
          AppSpacing.gapSM,
          OperationCard(
            child: _SettingsSlider(
              label: 'APP BRIGHTNESS',
              value: settings.brightness,
              min: DeviceSettings.minimumBrightness,
              onChanged: (value) =>
                  _controller.update(settings.copyWith(brightness: value)),
            ),
          ),
          AppSpacing.gapXL,
          const SectionHeader(
            icon: Icons.auto_awesome_outlined,
            title: 'EFFECTS',
          ),
          AppSpacing.gapSM,
          OperationCard(
            child: Column(
              children: [
                SwitchListTile.adaptive(
                  key: const ValueKey('device-settings-ripple'),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('RIPPLE'),
                  subtitle: const Text('受動タップ時のガラスリップルを表示します。'),
                  value: settings.rippleEnabled,
                  onChanged: (value) => _controller.update(
                    settings.copyWith(rippleEnabled: value),
                  ),
                ).inputFeedback(),
                const Divider(),
                SwitchListTile.adaptive(
                  key: const ValueKey('device-settings-ambient-circuit'),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('AMBIENT CIRCUIT'),
                  subtitle: const Text('DashboardのAmbient Circuitを表示します。'),
                  value: settings.ambientCircuitEnabled,
                  onChanged: (value) => _controller.update(
                    settings.copyWith(ambientCircuitEnabled: value),
                  ),
                ).inputFeedback(),
                const Divider(),
                _ReducedMotionSelector(
                  value: settings.reducedMotion,
                  onChanged: (value) => _controller.update(
                    settings.copyWith(reducedMotion: value),
                  ),
                ),
              ],
            ),
          ),
          AppSpacing.gapLG,
        ],
      ),
    ),
  );
}

class _SettingsSlider extends StatelessWidget {
  const _SettingsSlider({
    required this.label,
    required this.value,
    required this.onChanged,
    this.onChangeEnd,
    this.min = 0,
  });

  final String label;
  final double value;
  final ValueChanged<double> onChanged;
  final ValueChanged<double>? onChangeEnd;
  final double min;

  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    value: '${(value * 100).round()}%',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text(label)),
            Text('${(value * 100).round()}%'),
          ],
        ),
        Slider(
          key: ValueKey('device-settings-${label.toLowerCase()}-slider'),
          min: min,
          max: 1,
          value: value,
          onChanged: onChanged,
          onChangeEnd: onChangeEnd,
        ).inputFeedback(),
      ],
    ),
  );
}

class _ReducedMotionSelector extends StatelessWidget {
  const _ReducedMotionSelector({required this.value, required this.onChanged});

  final ReducedMotionPreference value;
  final ValueChanged<ReducedMotionPreference> onChanged;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      const Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('REDUCED MOTION'),
            Text('SYSTEMは端末のアクセシビリティ設定に従います。'),
          ],
        ),
      ),
      AppSpacing.gapSM,
      DropdownButton<ReducedMotionPreference>(
        key: const ValueKey('device-settings-reduced-motion'),
        value: value,
        onChanged: (next) {
          if (next != null) onChanged(next);
        },
        items: const [
          DropdownMenuItem(
            value: ReducedMotionPreference.system,
            child: Text('SYSTEM'),
          ),
          DropdownMenuItem(
            value: ReducedMotionPreference.on,
            child: Text('ON'),
          ),
          DropdownMenuItem(
            value: ReducedMotionPreference.off,
            child: Text('OFF'),
          ),
        ],
      ).inputFeedback(),
    ],
  );
}
