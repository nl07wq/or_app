import 'package:flutter/material.dart';

import '../../../core/widgets/operation_card.dart';
import '../../../core/widgets/section_header.dart';

import '../../../core/widgets/inputs/hud/hud_input_card.dart';
import '../../../core/widgets/inputs/wheel/wheel_input_card.dart';

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

          HUDInputCard(
            title: "Weight",
            unit: "kg",
            controller: weightController,
            min: 40,
            max: 180,
            step: 0.1,
          ),
          const SizedBox(height: 32),

          WheelInputCard(
            title: "Body Fat",
            unit: "%",
            controller: bodyFatController,
            min: 0,
            max: 60,
            step: 0.1,
            initialValue: 20,
          ),
        ],
      ),
    );
  }
}
