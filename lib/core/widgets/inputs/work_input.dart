import 'package:flutter/material.dart';

import '../operation_text_field.dart';

class WorkInput extends StatelessWidget {
  final TextEditingController controller;

  const WorkInput({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return OperationTextField(
      controller: controller,
      hint: "例）8:30",
      keyboardType: TextInputType.datetime,
    );
  }
}
