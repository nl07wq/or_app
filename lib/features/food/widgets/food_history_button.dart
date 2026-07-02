import 'package:flutter/material.dart';

import '../../../core/widgets/operation_button.dart';
import '../../../core/widgets/operation_card.dart';
import '../../../core/widgets/section_header.dart';

class FoodHistoryButton extends StatelessWidget {
  const FoodHistoryButton({super.key});

  @override
  Widget build(BuildContext context) {
    return OperationCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(icon: Icons.history, title: "HISTORY"),

          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            child: OperationButton(
              icon: Icons.history,
              text: "History",
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
