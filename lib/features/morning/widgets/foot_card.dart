import 'package:flutter/material.dart';

import '../../../core/widgets/operation_card.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/inputs/wheel/wheel_input_card.dart';

class FootCard extends StatelessWidget {
  final TextEditingController controller;

  const FootCard({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return OperationCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            icon: Icons.accessibility_new,
            title: "FOOT HEALTH",
          ),

          const SizedBox(height: 20),

          WheelInputCard(
            title: "Pain Level",
            unit: "",
            controller: controller,
            min: 0,
            max: 10,
            step: 1,
            initialValue: 3,
          ),
        ],
      ),
    );
  }
}
