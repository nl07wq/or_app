import 'package:flutter/material.dart';

import '../operation_text_field.dart';

class SleepScoreInput extends StatelessWidget {
  final TextEditingController controller;

  const SleepScoreInput({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return OperationTextField(controller: controller, hint: "0〜100",
    keyboardType: TextInputType.number);
    
  }
}
