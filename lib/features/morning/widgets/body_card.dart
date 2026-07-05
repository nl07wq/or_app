import 'package:flutter/material.dart';

import '../../../core/widgets/operation_card.dart';
import '../../../core/widgets/operation_field_label.dart';
import '../../../core/widgets/operation_text_field.dart';
import '../../../core/widgets/section_header.dart';

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

          OperationTextField(
            controller: weightController,
            hint: "kg",
            keyboardType: TextInputType.number,
          ),

          const SizedBox(height: 20),

          const OperationFieldLabel("Body Fat"),

          const SizedBox(height: 8),

          OperationTextField(
            controller: bodyFatController,
            hint: "%",
            keyboardType: TextInputType.number,
          ),
        ],
      ),
    );
  }
}
