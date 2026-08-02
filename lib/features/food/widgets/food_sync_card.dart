import 'package:flutter/material.dart';

import '../../../core/widgets/operation_button.dart';
import '../../../core/widgets/operation_card.dart';
import '../../../core/state/app_initialization_state.dart';

class FoodSyncCard extends StatelessWidget {
  const FoodSyncCard({super.key});

  @override
  Widget build(BuildContext context) {
    return OperationCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('FOOD SYNC'),
          const SizedBox(height: 8),
          const Text('COMING LATER'),
          const SizedBox(height: 12),
          OperationButton(
            icon: Icons.sync,
            text: 'SYNC FOOD',
            onPressed: appInitializationController.value.isReadOnly
                ? null
                : () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('FOOD SYNC COMING LATER')),
                    );
                  },
          ),
        ],
      ),
    );
  }
}
