import 'package:flutter/material.dart';

import '../wheel/wheel_input_card.dart';

class WorkTypeWheel extends StatelessWidget {
  final TextEditingController controller;

  const WorkTypeWheel({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return WheelInputCard(
      title: "Work Type",
      unit: "",
      controller: controller,
      min: 0,
      max: 4,
      step: 1,
      labels: const {0: "出勤", 1: "公休日", 2: "有給", 3: "半休", 4: "その他"},
      initialValue: 0,
    );
  }
}
