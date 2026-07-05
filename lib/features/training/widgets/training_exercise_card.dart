import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/operation_button.dart';
import '../../../core/widgets/operation_card.dart';
import '../../../core/widgets/operation_text_field.dart';
import '../../../core/widgets/section_header.dart';

import '../models/training_exercise_controller.dart';
import 'training_set_list.dart';

class TrainingExerciseCard extends StatefulWidget {
  final TrainingExerciseController controller;
  final VoidCallback onDelete;
  final bool isEditMode;
  final int index;

  const TrainingExerciseCard({
    super.key,
    required this.controller,
    required this.onDelete,
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
                child: OperationTextField(
                  controller: widget.controller.exerciseController,
                  label: 'Exercise',
                  hint: 'Bench Press',
                ),
              ),

              if (widget.isEditMode) ...[
                const SizedBox(width: 8),

                IconButton(
                  icon: Icon(
                    Icons.delete_outline,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  tooltip: 'Delete Exercise',
                  onPressed: widget.onDelete,
                ),
              ],
            ],
          ),
          AppSpacing.gapLG,

          TrainingSetList(
            sets: widget.controller.sets,
            isEditMode: widget.isEditMode,
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
