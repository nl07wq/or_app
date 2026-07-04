import 'package:flutter/material.dart';

import '../../../core/widgets/operation_button.dart';

class MorningSubmitButton extends StatelessWidget {
  final VoidCallback onPressed;

  const MorningSubmitButton({super.key, required this.onPressed});
  @override
  Widget build(BuildContext context) {
    return OperationButton(text: "▶ Morning Routine 開始", onPressed: onPressed);
  }
}
