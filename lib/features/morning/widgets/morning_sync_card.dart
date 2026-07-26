import 'package:flutter/material.dart';

import '../../../core/widgets/operation_button.dart';
import '../../../core/state/app_initialization_state.dart';

class MorningSyncCard extends StatelessWidget {
  const MorningSyncCard({super.key});

  @override
  Widget build(BuildContext context) {
    return OperationButton(
      icon: Icons.sync,
      text: "SYNC STATUS",
      onPressed: appInitializationController.value.isReadOnly
          ? null
          : () {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text("Coming Soon")));
            },
    );
  }
}
