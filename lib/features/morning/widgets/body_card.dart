import 'package:flutter/material.dart';

import '../../../core/widgets/operation_card.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/operation_text_field.dart';

class BodyCard extends StatelessWidget {
  final TextEditingController weightController;
  final TextEditingController bodyFatController;

  const BodyCard({
    super.key,
    required this.weightController,
    required this.bodyFatController,
  });

  @override
  Widget build(BuildContext context) {
    return OperationCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(icon: Icons.monitor_weight, title: "BODY"),

          const SizedBox(height: 20),

          OperationTextField(
            controller: weightController,
            label: "体重 (kg)",
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 20),

          OperationTextField(
            controller: bodyFatController,
            label: "体脂肪率 (%)",
            keyboardType: TextInputType.number,
          ),
        ],
      ),
    );
  }
}
