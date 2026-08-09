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

  const RecoveryCard({
    super.key,
    required this.sleepController,
    required this.sleepScoreController,
    required this.sleepType,
    required this.onSleepTypeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return OperationCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(icon: Icons.hotel, title: "RECOVERY"),

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

          TimeInputCard(
            title: "Sleep Time",
            controller: sleepController,
            initialHour: 8,
            initialMinute: 0,
          ),

          const SizedBox(height: 20),

          if (sleepType == SleepType.sleep) ...[
            WheelInputCard(
              key: ValueKey('sleep-score-${sleepType.name}'),
              title: "Sleep Score",
              unit: "",
              controller: sleepScoreController,
              min: 0,
              max: 100,
              step: 1,
              initialValue: 80,
            ),
          ] else ...[
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
