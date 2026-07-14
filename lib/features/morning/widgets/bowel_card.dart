import 'package:flutter/material.dart';

import '../../../core/widgets/operation_card.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/inputs/wheel/wheel_input_card.dart';

class BowelCard extends StatelessWidget {
  final TextEditingController amountController;
  final TextEditingController shapeController;

  const BowelCard({
    super.key,
    required this.amountController,
    required this.shapeController,
  });

  @override
  Widget build(BuildContext context) {
    return OperationCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(icon: Icons.monitor_heart, title: "BOWEL"),

          const SizedBox(height: 20),

          WheelInputCard(
            title: "Amount",
            unit: "",
            controller: amountController,
            min: 0,
            max: 3,
            step: 1,
            initialValue: 2,
          ),

          const SizedBox(height: 20),

          ValueListenableBuilder<TextEditingValue>(
            valueListenable: amountController,
            builder: (context, value, _) {
              final amount = int.tryParse(value.text) ?? 2;
              if (amount == 0 && shapeController.text.isNotEmpty) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  shapeController.clear();
                });
              }

              return Column(
                children: [
                  if (amount != 0) ...[
                    const SizedBox(height: 20),

                    WheelInputCard(
                      title: "Shape",
                      unit: "",
                      controller: shapeController,
                      min: 1,
                      max: 3,
                      step: 1,
                      initialValue: 2,
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
