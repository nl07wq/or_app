import 'package:flutter/material.dart';

import '../../../core/widgets/operation_button.dart';
import '../../../core/widgets/operation_card.dart';
import '../../../core/state/app_initialization_state.dart';

class TrainingSyncCard extends StatelessWidget {
  const TrainingSyncCard({super.key});

  @override
  Widget build(BuildContext context) {
    return OperationCard(
      child: OperationButton(
        icon: Icons.sync,
        text: 'SYNC TRAINING',
        onPressed: appInitializationController.value.isReadOnly
            ? null
            : () {
                // Phase5 Argo Engineで実装
              },
      ),
    );
  }
}
