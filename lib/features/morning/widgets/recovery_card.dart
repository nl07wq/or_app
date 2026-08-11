import 'package:flutter/material.dart';

import '../../../core/models/morning_data.dart';
import '../../../core/widgets/operation_card.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/inputs/time/time_input_card.dart';
import '../../../core/widgets/inputs/wheel/wheel_input_card.dart';

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
    return OperationCard(
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
                  ),
                )
                .toList(),
          ),

          const SizedBox(height: 20),

          if (sleepTimeUnmeasured)
            const _UnmeasuredValue(title: 'Sleep Time')
          else ...[
            TimeInputCard(
              title: "Sleep Time",
              controller: sleepController,
              initialHour: 8,
              initialMinute: 0,
            ),
          ],

          const SizedBox(height: 20),

          if (sleepTimeUnmeasured)
            const _UnmeasuredValue(title: 'Sleep Score')
          else if (sleepType == SleepType.sleep)
            WheelInputCard(
              key: ValueKey('sleep-score-${sleepType.name}'),
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
  );
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
