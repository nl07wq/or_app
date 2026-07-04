import 'package:flutter/material.dart';

import '../../../core/widgets/operation_button.dart';
import '../../../core/widgets/operation_card.dart';

class TrainingSyncCard extends StatelessWidget {
  const TrainingSyncCard({super.key});

  @override
  Widget build(BuildContext context) {
    return OperationCard(
      child: OperationButton(
        icon: Icons.sync,
        text: 'Sync Training',
        onPressed: () {
          // Phase5 Argo Engineで実装
        },
      ),
    );
  }
}
