import 'package:flutter/material.dart';

import '../../../core/widgets/operation_button.dart';
import '../../../core/state/app_initialization_state.dart';
import '../morning_fact_page.dart';

class MorningManualCard extends StatelessWidget {
  const MorningManualCard({super.key});

  @override
  Widget build(BuildContext context) {
    return OperationButton(
      icon: Icons.edit_note,
      text: "STATUS ENTRY",
      onPressed: appInitializationController.value.isReadOnly
          ? null
          : () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const MorningFactPage(),
                ),
              );
            },
    );
  }
}
