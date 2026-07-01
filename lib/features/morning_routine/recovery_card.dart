import 'package:flutter/material.dart';

import '../../core/widgets/operation_card.dart';
import '../../core/widgets/section_header.dart';
import '../../core/widgets/operation_text_field.dart';

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

          OperationTextField(
            controller: sleepController,
            label: "睡眠時間",
            hint: "例）7:30",
          ),
          const SizedBox(height: 16),

          OperationTextField(
            controller: sleepScoreController,
            label: "睡眠スコア",
            hint: "0〜100",
            keyboardType: TextInputType.number,
          ),
        ],
      ),
    );
  }
}
