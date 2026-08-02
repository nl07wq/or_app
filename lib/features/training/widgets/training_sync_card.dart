import 'package:flutter/material.dart';

import '../../../core/widgets/operation_button.dart';
import '../../../core/widgets/operation_card.dart';
import '../../../core/state/app_initialization_state.dart';
import '../../sync/pages/orlo_sync_page.dart';

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
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => OrloSyncPage(
                      initialDataType: 'training',
                      lockDataType: true,
                      title: 'TRAINING SYNC',
                    ),
                  ),
                );
              },
      ),
    );
  }
}
