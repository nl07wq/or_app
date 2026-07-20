import 'package:flutter/material.dart';

import '../../../core/widgets/operation_button.dart';

class MorningSubmitButton extends StatelessWidget {
  final VoidCallback onPressed;
  final bool isEdit;

  const MorningSubmitButton({
    super.key,
    required this.onPressed,
    this.isEdit = false,
  });
  @override
  Widget build(BuildContext context) {
    return OperationButton(
      icon: Icons.save,
      text: isEdit ? 'Update Morning' : 'Save Morning',
      onPressed: onPressed,
    );
  }
}
