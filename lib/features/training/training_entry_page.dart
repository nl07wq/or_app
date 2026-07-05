import 'package:flutter/material.dart';

import '../../core/models/training_exercise.dart';
import '../../core/models/training_session.dart';
import '../../core/models/training_set.dart';
import '../../core/repositories/training_repository.dart';
import '../../core/theme/app_spacing.dart';

import 'models/training_session_controller.dart';

import 'widgets/training_exercise_list.dart';
import 'widgets/training_session_card.dart';
import 'widgets/training_submit_button.dart';
import '../../core/widgets/operation_menu_button.dart';

class TrainingEntryPage extends StatefulWidget {
  const TrainingEntryPage({super.key});

  @override
  State<TrainingEntryPage> createState() => _TrainingEntryPageState();
}

class _TrainingEntryPageState extends State<TrainingEntryPage> {
  final sessionController = TrainingSessionController();

  bool isEditMode = false;

  void _showError(String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('入力エラー'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final exercises = <TrainingExercise>[];

    for (
      int exerciseIndex = 0;
      exerciseIndex < sessionController.exercises.length;
      exerciseIndex++
    ) {
      final controller = sessionController.exercises[exerciseIndex];

      if (controller.exerciseController.text.trim().isEmpty) {
        _showError('種目を入力してください');
        return;
      }

      final sets = <TrainingSet>[];

      for (int i = 0; i < controller.sets.length; i++) {
        final set = controller.sets[i];

        final weight = double.tryParse(set.weightController.text.trim());

        final reps = int.tryParse(set.repsController.text.trim());

        if (weight == null) {
          _showError('重量を入力してください');
          return;
        }

        if (reps == null) {
          _showError('回数を入力してください');
          return;
        }

        sets.add(TrainingSet(setNo: i + 1, weight: weight, reps: reps));
      }

      exercises.add(
        TrainingExercise(
          exerciseName: controller.exerciseController.text.trim(),
          order: exerciseIndex + 1,
          sets: sets,
        ),
      );
    }

    final session = TrainingSession(
      date: DateTime.now().toIso8601String(),
      memo: sessionController.memoController.text.trim(),
      exercises: exercises,
    );

    await TrainingRepository.save(session);

    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Training Saved')));

    Navigator.pop(context);
  }

  @override
  void dispose() {
    sessionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Training Entry'),
        actions: [
          OperationMenuButton(
            items: [
              OperationMenuItem(
                icon: isEditMode ? Icons.check : Icons.edit_outlined,
                title: isEditMode ? 'Finish Editing' : 'Edit Mode',
                onTap: () {
                  setState(() {
                    isEditMode = !isEditMode;
                  });
                },
              ),

              OperationMenuItem(
                icon: Icons.delete_sweep_outlined,
                title: 'Clear Session',
                onTap: () {
                  // Phase2
                },
              ),
            ],
          ),
        ],
      ),
      body: Padding(
        padding: AppSpacing.cardPadding,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TrainingSessionCard(
                memoController: sessionController.memoController,
              ),

              AppSpacing.gapMD,

              TrainingExerciseList(
                exercises: sessionController.exercises,
                isEditMode: isEditMode,
                onDelete: (exercise) {
                  setState(() {
                    sessionController.removeExercise(exercise);
                  });
                },
              ),

              AppSpacing.gapXL,

              OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    sessionController.addExercise();
                  });
                },
                icon: const Icon(Icons.add),
                label: const Text('Add Exercise'),
              ),

              AppSpacing.gapXL,

              TrainingSubmitButton(onPressed: _save),
            ],
          ),
        ),
      ),
    );
  }
}
