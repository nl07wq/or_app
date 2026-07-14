import 'package:flutter/material.dart';

import 'operation_ruler.dart';

class WeightInput extends StatelessWidget {
  final TextEditingController controller;

  const WeightInput({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return OperationRuler(
      controller: controller,
      min: 40,
      max: 180,
      step: 0.1,
      unit: "kg",
    );
  }
}
