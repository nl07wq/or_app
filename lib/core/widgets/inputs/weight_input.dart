import 'package:flutter/material.dart';

import '../operation_text_field.dart';

class WeightInput extends StatelessWidget {
  final TextEditingController controller;

  const WeightInput({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return OperationTextField(
      controller: controller,
      hint: "kg",
      keyboardType: TextInputType.number,
    );
  }
}