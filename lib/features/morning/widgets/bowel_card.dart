import 'package:flutter/material.dart';

import '../../../core/widgets/operation_card.dart';
import '../../../core/widgets/operation_dropdown.dart';
import '../../../core/widgets/section_header.dart';

class BowelCard extends StatelessWidget {
  final int bowelAmount;
  final int bowelShape;

  final ValueChanged<int> onAmountChanged;
  final ValueChanged<int> onShapeChanged;

  const BowelCard({
    super.key,
    required this.bowelAmount,
    required this.bowelShape,
    required this.onAmountChanged,
    required this.onShapeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return OperationCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(icon: Icons.monitor_heart, title: "BOWEL"),

          const SizedBox(height: 16),

          OperationDropdown<int>(
            label: "Amount",
            value: bowelAmount,
            items: List.generate(
              4,
              (index) =>
                  DropdownMenuItem(value: index, child: Text(index.toString())),
            ),
            onChanged: (value) {
              if (value != null) {
                onAmountChanged(value);
              }
            },
          ),

          const SizedBox(height: 16),

          OperationDropdown<int>(
            label: "Shape",
            value: bowelShape,
            items: List.generate(
              3,
              (index) => DropdownMenuItem(
                value: index + 1,
                child: Text((index + 1).toString()),
              ),
            ),
            onChanged: (value) {
              if (value != null) {
                onShapeChanged(value);
              }
            },
          ),
        ],
      ),
    );
  }
}
