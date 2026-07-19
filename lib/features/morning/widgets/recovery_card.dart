import 'package:flutter/material.dart';

import '../../../core/widgets/operation_card.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/inputs/time/time_input_card.dart';
import '../../../core/widgets/inputs/wheel/wheel_input_card.dart';

class RecoveryCard extends StatelessWidget {
  final TextEditingController sleepController;
  final TextEditingController sleepScoreController;

  const RecoveryCard({
    super.key,
    required this.sleepController,
    required this.sleepScoreController,
  });

  @override
  Widget build(BuildContext context) {
    return OperationCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(icon: Icons.hotel, title: "RECOVERY"),

          const SizedBox(height: 20),

          TimeInputCard(
            title: "Sleep Time",
            controller: sleepController,
            initialHour: 8,
            initialMinute: 0,
          ),

          const SizedBox(height: 20),

          WheelInputCard(
            title: "Sleep Score",
            unit: "",
            controller: sleepScoreController,
            min: 0,
            max: 100,
            step: 1,
            initialValue: 80,
          ),
        ],
      ),
    );
  }
}
