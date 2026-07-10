import 'package:flutter/material.dart';
import 'ruler_input.dart';

class WeightInput extends StatelessWidget {
  final TextEditingController controller;

  const WeightInput({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return RulerInput(
      controller: controller,
      min: 40,
      max: 180,
      step: 0.1,
      unit: "kg",
    );
  }
}
