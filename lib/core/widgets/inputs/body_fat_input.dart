import 'package:flutter/material.dart';

import '../global_touch_ripple.dart';
import 'wheel/wheel_ruler.dart';

class BodyFatInput extends StatelessWidget {
  final TextEditingController controller;

  const BodyFatInput({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return InputFeedbackRegion(
      child: WheelRuler(
        controller: controller,
        min: 0,
        max: 60,
        step: 0.1,
        unit: "%",
        initialValue: 20,
      ),
    );
  }
}
