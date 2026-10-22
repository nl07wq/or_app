import 'package:flutter/material.dart';

import '../../../core/models/morning_data.dart';
import '../../../core/widgets/global_touch_ripple.dart';
import '../../../core/widgets/dashboard_glass_card.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/inputs/hud/hud_input_card.dart';
import '../../schedule/widgets/shared_time_picker.dart';

class RecoveryCard extends StatelessWidget {
  final TextEditingController sleepController;
  final TextEditingController sleepScoreController;
  final SleepType sleepType;
  final ValueChanged<SleepType> onSleepTypeChanged;
  final bool sleepTimeUnmeasured;
  final VoidCallback onSleepTimeUnmeasured;
  final VoidCallback onSleepTimeMeasured;

  const RecoveryCard({
    super.key,
    required this.sleepController,
    required this.sleepScoreController,
    required this.sleepType,
    required this.onSleepTypeChanged,
    required this.sleepTimeUnmeasured,
    required this.onSleepTimeUnmeasured,
    required this.onSleepTimeMeasured,
  });

  @override
  Widget build(BuildContext context) {
    return DashboardGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: SectionHeader(icon: Icons.hotel, title: "RECOVERY"),
              ),
              _UnmeasuredToggle(
                key: const ValueKey('Sleep Time-unmeasured-toggle'),
                selected: sleepTimeUnmeasured,
                onPressed: sleepTimeUnmeasured
                    ? onSleepTimeMeasured
                    : onSleepTimeUnmeasured,
              ),
            ],
          ),

          const SizedBox(height: 20),

          const Text('睡眠タイプ', style: TextStyle(fontWeight: FontWeight.bold)),

          const SizedBox(height: 12),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: SleepType.values
                .map(
                  (value) => ChoiceChip(
                    label: Text(value.displayLabel),
                    selected: sleepType == value,
                    onSelected: (selected) {
                      if (selected) onSleepTypeChanged(value);
                    },
                  ).inputFeedback(),
                )
                .toList(),
          ),

          const SizedBox(height: 20),

          if (sleepTimeUnmeasured)
            const _UnmeasuredValue(title: 'Sleep Time')
          else ...[
            _SleepDurationOrbitalInput(
              title: "Sleep Time",
              controller: sleepController,
            ),
          ],

          const SizedBox(height: 20),

          if (sleepTimeUnmeasured)
            const _UnmeasuredValue(title: 'Sleep Score')
          else if (sleepType == SleepType.sleep)
            HUDInputCard(
              key: ValueKey('status-sleep-score-hud-${sleepType.name}'),
              title: "Sleep Score",
              unit: "",
              controller: sleepScoreController,
              min: 0,
              max: 100,
              step: 1,
              initialValue: 80,
            )
          else ...[
            const Row(
              children: [
                Expanded(
                  child: Text(
                    'Sleep Score',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                TextButton(
                  onPressed: null,
                  child: Text(
                    '仮眠',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.lightBlueAccent,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _SleepDurationOrbitalInput extends StatefulWidget {
  const _SleepDurationOrbitalInput({
    required this.title,
    required this.controller,
  });

  final String title;
  final TextEditingController controller;

  @override
  State<_SleepDurationOrbitalInput> createState() =>
      _SleepDurationOrbitalInputState();
}

class _SleepDurationOrbitalInputState
    extends State<_SleepDurationOrbitalInput> {
  Duration get _duration {
    final parts = widget.controller.text.split(':');
    final hour = int.tryParse(parts.first) ?? 8;
    final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    return Duration(
      hours: hour.clamp(0, 23).toInt(),
      minutes: minute.clamp(0, 59).toInt(),
    );
  }

  @override
  void initState() {
    super.initState();
    if (widget.controller.text.isEmpty) {
      widget.controller.text = '8:00';
    }
    widget.controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _selectDuration() async {
    final result = await showSharedDurationPicker(
      context,
      initialDuration: _duration,
    );
    if (!mounted || result == null) return;
    widget.controller.text =
        '${result.inHours}:${result.inMinutes.remainder(60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: 'Sleep duration ${widget.controller.text}',
      child: InkWell(
        key: const ValueKey('status-sleep-duration-picker'),
        onTap: _selectDuration,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 112,
          decoration: BoxDecoration(
            color: colors.surfaceContainer.withValues(alpha: .28),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colors.primary.withValues(alpha: .38)),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned(
                left: 14,
                right: 14,
                top: 29,
                child: Container(
                  height: 1,
                  color: colors.primary.withValues(alpha: .24),
                ),
              ),
              Positioned(
                left: 14,
                right: 14,
                bottom: 29,
                child: Container(
                  height: 1,
                  color: colors.primary.withValues(alpha: .24),
                ),
              ),
              const Positioned(
                left: 16,
                top: 12,
                child: Icon(Icons.bedtime_outlined, size: 20),
              ),
              Positioned(
                right: 16,
                top: 12,
                child: Icon(
                  Icons.track_changes_outlined,
                  size: 20,
                  color: colors.primary,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.title,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    widget.controller.text,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: colors.onSurface,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'ShareTechMono',
                    ),
                  ),
                  Text(
                    'DURATION / ORBITAL SELECT',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colors.primary.withValues(alpha: .78),
                      letterSpacing: .7,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ).inputFeedback(),
    );
  }
}

class _UnmeasuredToggle extends StatelessWidget {
  const _UnmeasuredToggle({
    super.key,
    required this.selected,
    required this.onPressed,
  });

  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => ChoiceChip(
    label: const Text('未計測'),
    selected: selected,
    onSelected: (_) => onPressed(),
  ).inputFeedback();
}

class _UnmeasuredValue extends StatelessWidget {
  const _UnmeasuredValue({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(
          '未計測',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.lightBlueAccent,
          ),
        ),
      ),
    ],
  );
}
