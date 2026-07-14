import 'package:flutter/material.dart';

import '../../../core/widgets/operation_card.dart';
import '../../../core/widgets/operation_field_label.dart';
import '../../../core/widgets/section_header.dart';

import '../../../core/widgets/operation_input_container.dart';

import '../../../core/widgets/inputs/weight_input.dart';
import '../../../core/widgets/inputs/operation_picker.dart';
import '../../../core/widgets/operation_input_container.dart';

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

          OperationInputContainer(
            title: "Weight",
            suffix: "kg",
            controller: weightController,
            autoCollapse: true,

            onCompleted: () {
              FocusScope.of(context).unfocus();
            },

            child: WeightInput(controller: weightController),
          ),

          const SizedBox(height: 20),

          OperationInputContainer(
            title: "Body Fat",
            suffix: "%",
            controller: bodyFatController,
            autoCollapse: true,

            onCompleted: () {
              FocusScope.of(context).unfocus();
            },

            child: OperationPicker(
              controller: bodyFatController,
              min: 0,
              max: 60,
              step: 0.1,
              unit: "%",
            ),
          ),
        ],
      ),
    );
  }
}
