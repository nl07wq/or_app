import 'package:flutter/material.dart';

import '../../../core/widgets/operation_card.dart';
import '../../../core/widgets/operation_dropdown.dart';
import '../../../core/widgets/section_header.dart';

class FootCard extends StatelessWidget {
  final int footPain;
  final ValueChanged<int> onChanged;

  const FootCard({super.key, required this.footPain, required this.onChanged});

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

          const SizedBox(height: 16),

          OperationDropdown<int>(
            label: "Pain Level",
            value: footPain,
            items: List.generate(
              11,
              (index) =>
                  DropdownMenuItem(value: index, child: Text(index.toString())),
            ),
            onChanged: (value) {
              if (value != null) {
                onChanged(value);
              }
            },
          ),
        ],
      ),
    );
  }
}
