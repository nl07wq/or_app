import 'package:flutter/material.dart';

import '../../../core/widgets/operation_button.dart';
import '../../../core/widgets/operation_card.dart';

import '../training_history_page.dart';

class TrainingHistoryButton extends StatelessWidget {
  const TrainingHistoryButton({super.key});

  @override
  Widget build(BuildContext context) {
    return OperationCard(
      child: OperationButton(
        icon: Icons.history,
        text: 'History',
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const TrainingHistoryPage()),
          );
        },
      ),
    );
  }
}
