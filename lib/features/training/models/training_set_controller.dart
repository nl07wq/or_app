import 'package:flutter/material.dart';

class TrainingSetController {
  final TextEditingController weightController;

  final TextEditingController repsController;

  TrainingSetController({
    TextEditingController? weightController,
    TextEditingController? repsController,
  }) : weightController = weightController ?? TextEditingController(),
       repsController = repsController ?? TextEditingController();

  TrainingSetController clone() {
    return TrainingSetController(
      weightController: TextEditingController(text: weightController.text),
      repsController: TextEditingController(text: repsController.text),
    );
  }

  void dispose() {
    weightController.dispose();
    repsController.dispose();
  }
}
