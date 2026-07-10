import 'package:flutter/material.dart';

import '../../../core/widgets/operation_card.dart';
import '../../../core/widgets/operation_field_label.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/inputs/weight_input.dart';
import '../../../core/widgets/inputs/body_fat_input.dart';

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

          const OperationFieldLabel("Weight"),

          const SizedBox(height: 8),

          WeightInput(controller: weightController),

          const SizedBox(height: 20),

          const OperationFieldLabel("Body Fat"),

          const SizedBox(height: 8),

          BodyFatInput(controller: bodyFatController),
        ],
      ),
    );
  }
}
