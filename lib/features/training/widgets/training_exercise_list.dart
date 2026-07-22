import 'package:flutter/material.dart';

import '../models/training_exercise_controller.dart';
import 'training_exercise_card.dart';

class TrainingExerciseList extends StatefulWidget {
  final List<TrainingExerciseController> exercises;
  final bool isEditMode;
  final Function(TrainingExerciseController) onCopy;
  final Function(TrainingExerciseController) onDelete;

  const TrainingExerciseList({
    super.key,
    required this.exercises,
    required this.isEditMode,
    required this.onCopy,
    required this.onDelete,
  });

  @override
  State<TrainingExerciseList> createState() => _TrainingExerciseListState();
}

class _TrainingExerciseListState extends State<TrainingExerciseList> {
  @override
  Widget build(BuildContext context) {
    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,

      itemCount: widget.exercises.length,

      onReorder: (oldIndex, newIndex) {
        setState(() {
          if (newIndex > oldIndex) {
            newIndex--;
          }

          final item = widget.exercises.removeAt(oldIndex);
          widget.exercises.insert(newIndex, item);
        });
      },

      itemBuilder: (context, index) {
        final exercise = widget.exercises[index];

        return Padding(
          key: ValueKey(exercise),
          padding: const EdgeInsets.only(bottom: 24),
          child: TrainingExerciseCard(
            index: index,
            controller: exercise,

            isEditMode: widget.isEditMode,
            canDelete: widget.exercises.length > 1,

            onCopy: () => widget.onCopy(exercise),

            onDelete: () => widget.onDelete(exercise),
          ),
        );
      },
    );
  }
}
