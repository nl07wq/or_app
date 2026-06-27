import 'package:flutter/material.dart';

import '../../core/widgets/operation_button.dart';

class MorningSubmitButton extends StatelessWidget {
  const MorningSubmitButton({super.key});

  @override
  Widget build(BuildContext context) {
    return OperationButton(
      text: "▶ Morning Routine 開始",
      onPressed: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Morning Routine Started"),
          ),
        );
      },
    );
  }
}