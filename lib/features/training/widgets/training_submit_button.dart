import 'package:flutter/material.dart';

import '../../../../core/widgets/operation_button.dart';

class TrainingSubmitButton extends StatelessWidget {
  final VoidCallback onPressed;

  const TrainingSubmitButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return OperationButton(
      icon: Icons.save,
      text: 'Save Training',
      onPressed: onPressed,
    );
  }
}
