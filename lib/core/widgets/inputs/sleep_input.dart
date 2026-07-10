import 'package:flutter/material.dart';

import '../operation_text_field.dart';

class SleepInput extends StatelessWidget {
  final TextEditingController controller;

  const SleepInput({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return OperationTextField(
      controller: controller,
      hint: "例）7:30",
      keyboardType: TextInputType.datetime
    );
  }
}