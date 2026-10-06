import 'package:flutter/material.dart';

import '../../../core/widgets/operation_button.dart';
import '../../../core/state/app_initialization_state.dart';
import '../morning_fact_page.dart';

class MorningManualCard extends StatelessWidget {
  const MorningManualCard({
    super.key,
    this.enabled = true,
    this.reportUnavailableTap = false,
  });

  final bool enabled;
  final bool reportUnavailableTap;

  @override
  Widget build(BuildContext context) {
    return OperationButton(
      key: const ValueKey('status-entry-button'),
      icon: Icons.edit_note,
      text: "STATUS ENTRY",
      reportUnavailableTap: reportUnavailableTap,
      onPressed: appInitializationController.value.isReadOnly || !enabled
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
