import 'package:flutter/material.dart';

import '../../../core/widgets/operation_button.dart';
import '../../../core/widgets/operation_card.dart';

import '../food_history_page.dart';

class FoodHistoryButton extends StatelessWidget {
  const FoodHistoryButton({super.key});

  @override
  Widget build(BuildContext context) {
    return OperationCard(
      child: OperationButton(
        icon: Icons.history,
        text: "History",
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const FoodHistoryPage()),
          );
        },
      ),
    );
  }
}
