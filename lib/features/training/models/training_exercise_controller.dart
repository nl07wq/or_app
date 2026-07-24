import 'package:flutter/material.dart';

import 'training_set_controller.dart';

class TrainingExerciseController {
  final TextEditingController exerciseController;
  final ValueNotifier<String?> equipmentController;

  final List<TrainingSetController> sets;

  TrainingExerciseController({
    TextEditingController? exerciseController,
    ValueNotifier<String?>? equipmentController,
    List<TrainingSetController>? sets,
  }) : exerciseController = exerciseController ?? TextEditingController(),
       equipmentController = equipmentController ?? ValueNotifier(null),
       sets = sets ?? [TrainingSetController()];

  TrainingExerciseController clone() {
    return TrainingExerciseController(
      exerciseController: TextEditingController(text: exerciseController.text),
      equipmentController: ValueNotifier(equipmentController.value),
      sets: sets.map((set) => set.clone()).toList(),
    );
  }
            
  void addSet() {
    sets.add(TrainingSetController());
  }

  void addSetCopy(int index) {
    sets.insert(index + 1, sets[index].clone());
  }

  void removeSet(int index) {
    if (sets.length <= 1) return;

    sets[index].dispose();
    sets.removeAt(index);
  }

  void dispose() {
    exerciseController.dispose();
    equipmentController.dispose();

    for (final set in sets) {
      set.dispose();
    }
  }
}
