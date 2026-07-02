import 'package:flutter/material.dart';

import '../../../core/widgets/operation_button.dart';
import '../../../core/widgets/operation_card.dart';
import '../../../core/widgets/section_header.dart';

class FoodSyncCard extends StatelessWidget {
  const FoodSyncCard({super.key});

  @override
  Widget build(BuildContext context) {
    return OperationCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(icon: Icons.sync, title: "REPORT SYNC"),

          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            child: OperationButton(
              icon: Icons.sync,
              text: "Sync Report",
              onPressed: () {
                // 次回実装
              },
            ),
          ),
        ],
      ),
    );
  }
}
