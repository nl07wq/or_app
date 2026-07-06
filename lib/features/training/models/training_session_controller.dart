import 'package:flutter/material.dart';

import 'training_exercise_controller.dart';

class TrainingSessionController {
  final TextEditingController memoController;

  final List<TrainingExerciseController> exercises;

  TrainingSessionController({
    TextEditingController? memoController,
    List<TrainingExerciseController>? exercises,
  }) : memoController = memoController ?? TextEditingController(),
       exercises = exercises ?? [TrainingExerciseController()];

  void addExercise() {
    exercises.add(TrainingExerciseController());
  }

  void addExerciseWithName(String name) {
    final exercise = TrainingExerciseController();
    exercise.exerciseController.text = name;
    exercises.add(exercise);
  }

  void clearExercises() {
    for (final exercise in exercises) {
      exercise.dispose();
    }

    exercises.clear();
  }

  void addExerciseCopy(TrainingExerciseController exercise) {
    exercises.add(exercise.clone());
  }

  void clearSession() {
    memoController.clear();

    for (final exercise in exercises) {
      exercise.dispose();
    }

    exercises.clear();

    addExercise();
  }

  void removeExercise(TrainingExerciseController controller) {
    if (exercises.length <= 1) return;

    controller.dispose();
    exercises.remove(controller);
  }

  void dispose() {
    memoController.dispose();

    for (final exercise in exercises) {
      exercise.dispose();
    }
  }
}
