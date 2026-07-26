import 'package:flutter/material.dart';

import '../../../core/widgets/operation_button.dart';
import '../../../core/widgets/operation_card.dart';
import '../../../core/state/app_initialization_state.dart';

class FoodSyncCard extends StatelessWidget {
  const FoodSyncCard({super.key});

  @override
  Widget build(BuildContext context) {
    return OperationCard(
      child: OperationButton(
        icon: Icons.sync,
        text: 'SYNC FOOD',
        onPressed: appInitializationController.value.isReadOnly
            ? null
            : () {
                // 次回実装
              },
      ),
    );
  }
}
