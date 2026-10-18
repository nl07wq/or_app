import 'package:flutter/material.dart';

import '../../../core/widgets/operation_button.dart';

import '../training_history_page.dart';

class TrainingHistoryButton extends StatelessWidget {
  const TrainingHistoryButton({super.key});

  @override
  Widget build(BuildContext context) {
    return OperationButton(
      icon: Icons.history,
      text: 'RECORD',
      frostedGlass: true,
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const TrainingHistoryPage()),
        );
      },
    );
  }
}
