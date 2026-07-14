import 'package:flutter/material.dart';

import '../../../core/widgets/operation_button.dart';
import '../morning_fact_page.dart';

class MorningManualCard extends StatelessWidget {
  const MorningManualCard({super.key});

  @override
  Widget build(BuildContext context) {
    return OperationButton(
      icon: Icons.edit_note,
      text: "Morning Fact",
      onPressed: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => const MorningFactPage()),
        );
      },
    );
  }
}
