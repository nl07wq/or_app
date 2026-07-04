import 'package:flutter/material.dart';

import '../../../core/widgets/operation_button.dart';

import '../morning_history_page.dart';

class MorningHistoryButton extends StatelessWidget {
  const MorningHistoryButton({super.key});

  @override
  Widget build(BuildContext context) {
    return OperationButton(
      icon: Icons.history,
      text: "History",
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MorningHistoryPage()),
        );
      },
    );
  }
}
