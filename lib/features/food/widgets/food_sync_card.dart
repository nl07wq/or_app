import 'package:flutter/material.dart';

import '../../../core/widgets/operation_button.dart';
import '../../../core/widgets/operation_card.dart';

class FoodSyncCard extends StatelessWidget {
  const FoodSyncCard({super.key});

  @override
  Widget build(BuildContext context) {
    return OperationCard(
      child: OperationButton(
        icon: Icons.sync,
        text: 'Sync Report',
        onPressed: () {
          // 次回実装
        },
      ),
    );
  }
}