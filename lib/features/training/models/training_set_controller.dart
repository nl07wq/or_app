import 'package:flutter/material.dart';

class TrainingSetController {
  final TextEditingController weightController;

  final TextEditingController repsController;

  TrainingSetController({
    TextEditingController? weightController,
    TextEditingController? repsController,
  }) : weightController = weightController ?? TextEditingController(),
       repsController = repsController ?? TextEditingController();

  void dispose() {
    weightController.dispose();
    repsController.dispose();
  }
}
