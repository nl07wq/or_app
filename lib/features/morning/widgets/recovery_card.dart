import 'package:flutter/material.dart';

import '../../../core/widgets/operation_card.dart';
import '../../../core/widgets/operation_field_label.dart';
import '../../../core/widgets/operation_text_field.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/inputs/sleep_input.dart';
import '../../../core/widgets/inputs/sleep_score_input.dart';

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

          const OperationFieldLabel("Sleep Time"),

          const SizedBox(height: 8),

          SleepInput(controller: sleepController),

          const SizedBox(height: 20),

          const OperationFieldLabel("Sleep Score"),

          const SizedBox(height: 8),

          SleepScoreInput(controller: sleepScoreController),
        ],
      ),
    );
  }
}
