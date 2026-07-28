import 'package:flutter/material.dart';

import '../../../core/models/training_set.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/operation_button.dart';

import '../models/training_exercise_controller.dart';
import '../models/training_set_controller.dart';
import '../services/exercise_name_localization.dart';
import '../services/statistics_service.dart';
import 'equipment_selector.dart';
import 'exercise_selector.dart';
import 'training_collapsible_card.dart';
import 'training_metric_format.dart';
import 'training_set_list.dart';
import 'training_summary_section.dart';

class TrainingExerciseCard extends StatefulWidget {
  final TrainingExerciseController controller;
  final VoidCallback onCopy;
  final VoidCallback onDelete;
  final bool canDelete;
  final bool isEditMode;
  final int index;
  final TrainingSetController? activeSet;
  final ValueChanged<TrainingSetController?> onSetActivated;
  final bool isExpanded;
  final VoidCallback onToggleExpanded;

  const TrainingExerciseCard({
    super.key,
    required this.controller,
    required this.onCopy,
    required this.onDelete,
    required this.canDelete,
    required this.isEditMode,
    required this.index,
    required this.activeSet,
    required this.onSetActivated,
    required this.isExpanded,
    required this.onToggleExpanded,
  });

  @override
  State<TrainingExerciseCard> createState() => _TrainingExerciseCardState();
}

class _TrainingExerciseCardState extends State<TrainingExerciseCard> {
  @override
  Widget build(BuildContext context) {
    final header = _buildHeader();

    return TrainingCollapsibleCard(
      icon: Icons.fitness_center,
      title: header.title,
      summary: header.summary,
      isExpanded: widget.isExpanded,
      onToggle: widget.onToggleExpanded,
      headerKey: ValueKey(
        'exercise-header-${identityHashCode(widget.controller)}',
      ),
      contentKey: ValueKey(
        'exercise-content-${identityHashCode(widget.controller)}',
      ),
      semanticsLabel:
          '${header.title}, '
          '${widget.isExpanded ? 'expanded' : 'collapsed'}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
          AppSpacing.gapXS,

          EquipmentSelector(
            exerciseController: widget.controller.exerciseController,
            controller: widget.controller.equipmentController,
          ),

          AppSpacing.gapXS,

          TrainingSummarySection(
            exerciseController: widget.controller.exerciseController,
            equipmentController: widget.controller.equipmentController,
            sets: widget.controller.sets,
          ),

          AppSpacing.gapMD,

          TrainingSetList(
            sets: widget.controller.sets,
            isEditMode: widget.isEditMode,
            activeSet: widget.activeSet,
            onSetActivated: widget.onSetActivated,

            onCopy: (index) {
              setState(() {
                widget.controller.addSetCopy(index);
              });
            },

            onDelete: (index) {
              final set = widget.controller.sets[index];
              if (identical(widget.activeSet, set)) {
                widget.onSetActivated(null);
              }
              setState(() {
                widget.controller.removeSet(index);
              });
            },
          ),

          SizedBox(
            height: 56,
            child: OperationButton(
              icon: Icons.add,
              text: 'ADD SET',
              onPressed: () {
                setState(() {
                  widget.controller.addSet();
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  _ExerciseHeader _buildHeader() {
    final exerciseName = widget.controller.exerciseController.text.trim();
    if (exerciseName.isEmpty) {
      return _ExerciseHeader(
        title: 'EXERCISE ${widget.index + 1}',
        summary: 'Not configured',
      );
    }

    final sets = <TrainingSet>[];
    for (var index = 0; index < widget.controller.sets.length; index++) {
      final setController = widget.controller.sets[index];
      final weight = double.tryParse(
        setController.weightController.text.trim(),
      );
      final reps = int.tryParse(setController.repsController.text.trim());
      if (weight == null ||
          !weight.isFinite ||
          weight < 0 ||
          reps == null ||
          reps <= 0) {
        continue;
      }
      sets.add(TrainingSet(setNo: index + 1, weight: weight, reps: reps));
    }

    final statistics = StatisticsService.calculate(sets);
    final summaryParts = <String>[
      if (statistics.heaviestSet case final heaviestSet?)
        '${formatTrainingNumber(heaviestSet.weight)} kg',
      if (statistics.workingSets > 0)
        '${statistics.workingSets} '
            '${statistics.workingSets == 1 ? 'Set' : 'Sets'}',
      if (statistics.totalRepetitions > 0)
        '${statistics.totalRepetitions} Reps',
    ];

    return _ExerciseHeader(
      title: exerciseDisplayName(exerciseName),
      summary: summaryParts.isEmpty ? null : summaryParts.join(' · '),
    );
  }
}

class _ExerciseHeader {
  const _ExerciseHeader({required this.title, required this.summary});

  final String title;
  final String? summary;
}
