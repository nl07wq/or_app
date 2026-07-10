import 'package:flutter/material.dart';

import '../operation_text_field.dart';

class BodyFatInput extends StatelessWidget {
  final TextEditingController controller;

  const BodyFatInput({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return OperationTextField(
      controller: controller,
      hint: "%",
      keyboardType: TextInputType.number,
    );
  }
}