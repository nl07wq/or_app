import 'package:flutter/material.dart';

import '../../../core/widgets/operation_button.dart';
import '../../../core/state/app_initialization_state.dart';

import '../training_entry_page.dart';

class TrainingManualCard extends StatelessWidget {
  const TrainingManualCard({super.key});

  @override
  Widget build(BuildContext context) {
    return OperationButton(
      icon: Icons.fitness_center,
      text: 'TRAINING ENTRY',
      dashboardGlass: true,
      onPressed: appInitializationController.value.isReadOnly
          ? null
          : () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TrainingEntryPage()),
              );
            },
    );
  }
}
