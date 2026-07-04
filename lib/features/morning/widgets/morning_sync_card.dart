import 'package:flutter/material.dart';

import '../../../core/widgets/operation_button.dart';

class MorningSyncCard extends StatelessWidget {
  const MorningSyncCard({super.key});

  @override
  Widget build(BuildContext context) {
    return OperationButton(
      icon: Icons.sync,
      text: "Report Sync",
      onPressed: () {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Coming Soon")));
      },
    );
  }
}
