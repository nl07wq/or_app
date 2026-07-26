import 'package:flutter/material.dart';

import '../../../core/widgets/operation_button.dart';
import '../../../core/state/app_initialization_state.dart';
import '../../../core/navigation/app_routes.dart';

class MorningSyncCard extends StatelessWidget {
  const MorningSyncCard({super.key});

  @override
  Widget build(BuildContext context) {
    return OperationButton(
      icon: Icons.sync,
      text: "SYNC STATUS",
      onPressed: appInitializationController.value.isReadOnly
          ? null
          : () => Navigator.pushNamed(context, AppRoutes.backupRestore),
    );
  }
}
