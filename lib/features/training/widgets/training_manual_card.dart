import 'package:flutter/material.dart';

import '../../../core/widgets/operation_button.dart';
import '../../../core/widgets/operation_card.dart';

import '../training_entry_page.dart';

class TrainingManualCard extends StatelessWidget {
  const TrainingManualCard({super.key});

  @override
  Widget build(BuildContext context) {
    return OperationCard(
      child: OperationButton(
        icon: Icons.fitness_center,
        text: 'Training Entry',
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const TrainingEntryPage()),
          );
        },
      ),
    );
  }
}
