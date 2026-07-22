import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/operation_button.dart';
import '../../../core/widgets/operation_card.dart';
import '../../../core/widgets/section_header.dart';

import '../models/training_exercise_controller.dart';
import 'exercise_selector.dart';
import 'training_set_list.dart';

class TrainingExerciseCard extends StatefulWidget {
  final TrainingExerciseController controller;
  final VoidCallback onCopy;
  final VoidCallback onDelete;
  final bool canDelete;
  final bool isEditMode;
  final int index;

  const TrainingExerciseCard({
    super.key,
    required this.controller,
    required this.onCopy,
    required this.onDelete,
    required this.canDelete,
    required this.isEditMode,
    required this.index,
  });

  @override
  State<TrainingExerciseCard> createState() => _TrainingExerciseCardState();
}

class _TrainingExerciseCardState extends State<TrainingExerciseCard> {
  @override
  Widget build(BuildContext context) {
    return OperationCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(icon: Icons.fitness_center, title: 'EXERCISE'),

          AppSpacing.gapMD,

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.isEditMode)
                ReorderableDragStartListener(
                  index: widget.index,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8, top: 8),
                    child: Icon(
                      Icons.drag_handle,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ),
              Expanded(
                child: ExerciseSelector(
                  controller: widget.controller.exerciseController,
                ),
              ),

              const SizedBox(width: 4),
              if (widget.isEditMode)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.copy_outlined),
                  tooltip: 'Copy exercise',
                  onPressed: widget.onCopy,
                ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  Icons.delete_outline,
                  color: Theme.of(context).colorScheme.error,
                ),
                tooltip: 'Delete exercise',
                onPressed: widget.canDelete ? widget.onDelete : null,
              ),
            ],
          ),
          AppSpacing.gapLG,

          TrainingSetList(
            sets: widget.controller.sets,
            isEditMode: widget.isEditMode,

            onCopy: (index) {
              setState(() {
                widget.controller.addSetCopy(index);
              });
            },

            onDelete: (index) {
              setState(() {
                widget.controller.removeSet(index);
              });
            },
          ),

          AppSpacing.gapSM,

          OperationButton(
            icon: Icons.add,
            text: 'Add Set',
            onPressed: () {
              setState(() {
                widget.controller.addSet();
              });
            },
          ),
        ],
      ),
    );
  }
}
